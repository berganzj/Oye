//
//  AudioManager.swift
//  Oye
//
//  Created by Jberg on 2025-11-15.
//

import AVFoundation
import Accelerate
import Combine
import SwiftUI

@MainActor
class AudioManager: ObservableObject {
    @Published var currentFrequency: Double = 0.0
    @Published var isListening: Bool = false
    @Published var permissionGranted: Bool = false
    
    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode!
    private var fftAnalyzer: FFTAnalyzer!
    
    private let sampleRate: Double = 44100.0
    private let bufferSize: AVAudioFrameCount = 4096
    
    init() {
        setupAudioEngine()
        requestMicrophonePermission()
    }
    
    private func setupAudioEngine() {
        inputNode = audioEngine.inputNode
        fftAnalyzer = FFTAnalyzer(sampleRate: sampleRate, bufferSize: Int(bufferSize))
        
        // Get the input format from the microphone
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Create our desired recording format (mono, 44.1kHz)
        guard let recordingFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            print("Failed to create recording format")
            return
        }
        
        // Install tap with the input's native format, we'll handle conversion in the callback
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] (buffer, time) in
            Task { @MainActor in
                self?.processAudioBuffer(buffer, inputFormat: inputFormat, targetFormat: recordingFormat)
            }
        }
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                self?.permissionGranted = granted
                if granted {
                    self?.configureAudioSession()
                }
            }
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setPreferredSampleRate(sampleRate)
            try audioSession.setPreferredInputNumberOfChannels(1)
            try audioSession.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
    }
    
    func startListening() {
        guard permissionGranted && !isListening else { return }
        
        do {
            // Reset audio engine if needed
            if audioEngine.isRunning {
                audioEngine.stop()
                audioEngine.reset()
            }
            
            // Reconfigure audio session
            configureAudioSession()
            
            // Prepare and start the audio engine
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            print("Audio engine started successfully")
        } catch {
            print("Audio engine start failed: \(error)")
            isListening = false
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        isListening = false
        currentFrequency = 0.0
        
        // Re-setup the tap for next time
        setupAudioEngine()
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat, targetFormat: AVAudioFormat) {
        // Convert buffer to our target format if needed
        let processedBuffer: AVAudioPCMBuffer
        
        if inputFormat.sampleRate != targetFormat.sampleRate || inputFormat.channelCount != targetFormat.channelCount {
            // Create converter
            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                print("Failed to create audio converter")
                return
            }
            
            // Create output buffer
            let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * targetFormat.sampleRate / inputFormat.sampleRate)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else {
                print("Failed to create converted buffer")
                return
            }
            
            // Convert
            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            guard status != .error, error == nil else {
                print("Audio conversion failed: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            processedBuffer = convertedBuffer
        } else {
            processedBuffer = buffer
        }
        
        // Process the audio data
        guard let channelData = processedBuffer.floatChannelData?[0] else { return }
        
        let frameCount = Int(processedBuffer.frameLength)
        let audioData = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        
        if let dominantFrequency = fftAnalyzer.findDominantFrequency(in: audioData) {
            // Only update if we have a significant frequency (above background noise)
            if dominantFrequency > 60.0 && dominantFrequency < 2000.0 {
                currentFrequency = dominantFrequency
            }
        }
    }
}

// MARK: - FFT Analysis
class FFTAnalyzer {
    private let sampleRate: Double
    private let bufferSize: Int
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    
    init(sampleRate: Double, bufferSize: Int) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        self.log2n = vDSP_Length(log2(Float(bufferSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))!
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    func findDominantFrequency(in audioData: [Float]) -> Double? {
        guard audioData.count >= bufferSize else { return nil }
        
        // Apply window function to reduce spectral leakage
        var windowedData = audioData.prefix(bufferSize).map { $0 }
        applyHannWindow(&windowedData)
        
        // Prepare for FFT
        let halfSize = bufferSize / 2
        var realParts = [Float](repeating: 0.0, count: halfSize)
        var imaginaryParts = [Float](repeating: 0.0, count: halfSize)
        
        // Convert to split complex format
        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imaginaryParts)
        
        // Convert input to packed format for FFT
        windowedData.withUnsafeBufferPointer { inputPtr in
            vDSP_ctoz(UnsafePointer<DSPComplex>(OpaquePointer(inputPtr.baseAddress!)), 2, &splitComplex, 1, vDSP_Length(halfSize))
        }
        
        // Perform FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, Int32(FFT_FORWARD))
        
        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0.0, count: halfSize)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))
        
        // Find peak frequency
        var maxIndex: vDSP_Length = 0
        var maxValue: Float = 0
        vDSP_maxvi(&magnitudes, 1, &maxValue, &maxIndex, vDSP_Length(halfSize))
        
        // Convert bin index to frequency
        let frequency = Double(maxIndex) * sampleRate / Double(bufferSize)
        
        // Apply threshold to filter out noise
        let threshold: Float = magnitudes.max()! * 0.1
        return maxValue > threshold ? frequency : nil
    }
    
    private func applyHannWindow(_ data: inout [Float]) {
        let count = data.count
        for i in 0..<count {
            let multiplier = 0.5 * (1.0 - cos(2.0 * .pi * Float(i) / Float(count - 1)))
            data[i] *= multiplier
        }
    }
}