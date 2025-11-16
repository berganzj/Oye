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
        print("Input format: \(inputFormat)")
        
        // Validate that our input format is acceptable
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            print("Invalid input format detected")
            return
        }
        
        // For iOS 18 compatibility, use the input format directly instead of converting
        // This avoids format validation issues
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] (buffer, time) in
            Task { @MainActor in
                self?.processAudioBuffer(buffer, originalFormat: inputFormat)
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
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, originalFormat: AVAudioFormat) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(originalFormat.channelCount)
        
        // Convert to mono if needed, otherwise use first channel
        var audioData: [Float]
        
        if channelCount == 1 {
            // Already mono
            audioData = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        } else {
            // Convert stereo/multi-channel to mono by averaging channels
            audioData = Array(0..<frameCount).map { frameIndex in
                var sum: Float = 0
                for channel in 0..<channelCount {
                    sum += channelData[channel][frameIndex]
                }
                return sum / Float(channelCount)
            }
        }
        
        // Resample if the sample rate is different from our target
        let actualSampleRate = originalFormat.sampleRate
        if actualSampleRate != sampleRate && audioData.count >= 2 {
            // Simple resampling for different sample rates
            let resampleRatio = sampleRate / actualSampleRate
            let targetLength = Int(Double(audioData.count) * resampleRatio)
            audioData = resampleAudio(audioData, targetLength: targetLength)
        }
        
        if let dominantFrequency = fftAnalyzer.findDominantFrequency(in: audioData) {
            // Only update if we have a significant frequency (above background noise)
            if dominantFrequency > 60.0 && dominantFrequency < 2000.0 {
                currentFrequency = dominantFrequency
            }
        }
    }
    
    private func resampleAudio(_ input: [Float], targetLength: Int) -> [Float] {
        guard targetLength > 0 && input.count > 1 else { return input }
        
        let inputLength = input.count
        let ratio = Double(inputLength - 1) / Double(targetLength - 1)
        
        var output = [Float](repeating: 0, count: targetLength)
        
        for i in 0..<targetLength {
            let position = Double(i) * ratio
            let index = Int(position)
            let fraction = Float(position - Double(index))
            
            if index < inputLength - 1 {
                // Linear interpolation
                output[i] = input[index] * (1 - fraction) + input[index + 1] * fraction
            } else {
                output[i] = input[inputLength - 1]
            }
        }
        
        return output
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