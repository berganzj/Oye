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
        
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let recordingFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] (buffer, time) in
            Task { @MainActor in
                self?.processAudioBuffer(buffer)
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
            try audioSession.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
    }
    
    func startListening() {
        guard permissionGranted && !isListening else { return }
        
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            print("Audio engine start failed: \(error)")
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        
        audioEngine.stop()
        isListening = false
        currentFrequency = 0.0
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameCount = Int(buffer.frameLength)
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
    private let fftSetup: vDSP_DFT_Setup
    
    init(sampleRate: Double, bufferSize: Int) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        self.fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(bufferSize), vDSP_DFT_Direction.FORWARD)!
    }
    
    deinit {
        vDSP_DFT_DestroySetup(fftSetup)
    }
    
    func findDominantFrequency(in audioData: [Float]) -> Double? {
        guard audioData.count >= bufferSize else { return nil }
        
        // Apply window function to reduce spectral leakage
        var windowedData = audioData.prefix(bufferSize).map { $0 }
        applyHannWindow(&windowedData)
        
        // Prepare for FFT
        var realParts = windowedData
        var imaginaryParts = [Float](repeating: 0.0, count: bufferSize)
        
        // Perform FFT
        realParts.withUnsafeMutableBufferPointer { realPtr in
            imaginaryParts.withUnsafeMutableBufferPointer { imagPtr in
                vDSP_DFT_Execute(fftSetup, realPtr.baseAddress!, imagPtr.baseAddress!, realPtr.baseAddress!, imagPtr.baseAddress!)
            }
        }
        
        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0.0, count: bufferSize / 2)
        vDSP_zvmags(&realParts, 1, &magnitudes, 1, vDSP_Length(bufferSize / 2))
        
        // Find peak frequency
        var maxIndex: vDSP_Length = 0
        var maxValue: Float = 0
        vDSP_maxvi(&magnitudes, 1, &maxValue, &maxIndex, vDSP_Length(bufferSize / 2))
        
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