//
//  ContentView.swift
//  Oye
//
//  Created by Jberg on 2025-11-15.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var tuningEngine = TuningEngine()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                // Settings Section
                SettingsSection(tuningEngine: tuningEngine)
                
                // Simple Instrument Selector (Guitar/Ukulele text only)
                InstrumentSelector(tuningEngine: tuningEngine)
                
                // Main Tuning Display
                TunerDisplay(
                    audioManager: audioManager,
                    tuningEngine: tuningEngine
                )
                
                // Control Buttons
                TunerControls(audioManager: audioManager)
                
                // String Reference with accurate frequencies
                StringReference(tuningEngine: tuningEngine)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Oye Tuner")
            .navigationBarTitleDisplayMode(.large)
        }
        .onReceive(audioManager.$currentFrequency) { frequency in
            tuningEngine.analyzeFrequency(frequency)
        }
    }
}

// MARK: - Settings Section
struct SettingsSection: View {
    @ObservedObject var tuningEngine: TuningEngine
    @State private var showSettings = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation {
                    showSettings.toggle()
                }
            }) {
                HStack {
                    Text("Tuning Settings")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: showSettings ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            
            if showSettings {
                VStack(spacing: 16) {
                    // Reference Frequency Section
                    VStack(spacing: 8) {
                        HStack {
                            Text("Reference Frequency")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("A4 = \(tuningEngine.referenceFrequency, specifier: "%.1f") Hz")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { tuningEngine.referenceFrequency },
                                set: { tuningEngine.setReferenceFrequency($0) }
                            ),
                            in: tuningEngine.minReferenceFrequency...tuningEngine.maxReferenceFrequency,
                            step: 0.1
                        ) {
                            Text("Reference Frequency")
                        } minimumValueLabel: {
                            Text("431")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("449")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Reset to 440 Hz") {
                            tuningEngine.setReferenceFrequency(440.0)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    Divider()
                    
                    // Tuning Threshold Section
                    VStack(spacing: 8) {
                        HStack {
                            Text("Out-of-Range Threshold")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(tuningEngine.tuningThresholdCents)) cents")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { tuningEngine.tuningThresholdCents },
                                set: { tuningEngine.setTuningThreshold($0) }
                            ),
                            in: tuningEngine.minThresholdCents...tuningEngine.maxThresholdCents,
                            step: 5.0
                        ) {
                            Text("Tuning Threshold")
                        } minimumValueLabel: {
                            Text("10")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("100")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Button("Reset to 45 cents") {
                                tuningEngine.setTuningThreshold(45.0)
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Text("Shows red warning when beyond threshold")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Simple Instrument Selector (Text Only)
struct InstrumentSelector: View {
    @ObservedObject var tuningEngine: TuningEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Instrument")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 0) {
                ForEach(InstrumentType.allCases, id: \.self) { instrument in
                    Button(action: {
                        tuningEngine.selectInstrument(instrument)
                    }) {
                        Text(instrument.rawValue)
                            .font(.headline)
                            .foregroundColor(tuningEngine.selectedInstrument == instrument ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(tuningEngine.selectedInstrument == instrument ? Color.blue : Color.gray.opacity(0.1))
                    }
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Main Tuner Display
struct TunerDisplay: View {
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var tuningEngine: TuningEngine
    
    var body: some View {
        VStack(spacing: 20) {
            // Frequency Display
            FrequencyDisplay(
                frequency: audioManager.currentFrequency,
                isListening: audioManager.isListening
            )
            
            // Note Display
            if let note = tuningEngine.currentNote {
                NoteDisplay(note: note)
                
                // Tuning Meter
                TuningMeter(cents: note.cents, threshold: tuningEngine.tuningThresholdCents)
                
                // String Recommendation
                if let recommendation = tuningEngine.getStringRecommendation(for: note) {
                    Text(recommendation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if audioManager.isListening {
                if tuningEngine.detectedString == nil {
                    Text("Note out of instrument range...")
                        .font(.title2)
                        .foregroundColor(.orange)
                } else {
                    Text("Play a note...")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(minHeight: 200)
    }
}

// MARK: - Frequency Display
struct FrequencyDisplay: View {
    let frequency: Double
    let isListening: Bool
    
    var body: some View {
        VStack(spacing: 5) {
            Text("Frequency")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(frequency, specifier: "%.1f") Hz")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(isListening ? .primary : .secondary)
        }
    }
}

// MARK: - Note Display
struct NoteDisplay: View {
    let note: MusicalNote
    
    var body: some View {
        VStack(spacing: 10) {
            // Note Name
            Text(note.displayName)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(tuningColor)
            
            // Tuning Status
            HStack(spacing: 8) {
                Text(note.tuningStatus.symbol)
                    .font(.title2)
                Text(statusText)
                    .font(.headline)
            }
            .foregroundColor(tuningColor)
        }
    }
    
    private var tuningColor: Color {
        switch note.tuningStatus {
        case .inTune:
            return .green
        case .sharp, .flat:
            return .orange
        case .outOfRange:
            return .red
        }
    }
    
    private var statusText: String {
        switch note.tuningStatus {
        case .inTune:
            return "In Tune"
        case .sharp:
            return "Sharp"
        case .flat:
            return "Flat"
        case .outOfRange:
            return "Out of Range"
        }
    }
}

// MARK: - Tuning Meter
struct TuningMeter: View {
    let cents: Double
    let threshold: Double
    private let maxCents: Double = 50
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Cents: \(Int(cents))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack {
                // Background track
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 20)
                
                // Threshold markers
                ForEach([-threshold, threshold], id: \.self) { thresholdValue in
                    Rectangle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 1, height: 20)
                        .offset(x: CGFloat(thresholdValue / maxCents) * 140)
                }
                
                // Center line (perfect pitch)
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 2, height: 20)
                
                // Tuning indicator
                Circle()
                    .fill(tuningIndicatorColor)
                    .frame(width: 16, height: 16)
                    .offset(x: CGFloat(cents / maxCents) * 140) // 140 is approximate half-width
                    .animation(.easeOut(duration: 0.1), value: cents)
            }
            .frame(width: 300)
            .clipped()
        }
    }
    
    private var tuningIndicatorColor: Color {
        if abs(cents) <= 5 {
            return .green
        } else if abs(cents) > threshold {
            return .red
        } else {
            return .orange
        }
    }
}

// MARK: - Tuner Controls
struct TunerControls: View {
    @ObservedObject var audioManager: AudioManager
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: {
                if audioManager.isListening {
                    audioManager.stopListening()
                } else {
                    audioManager.startListening()
                }
            }) {
                HStack {
                    Image(systemName: audioManager.isListening ? "stop.fill" : "play.fill")
                    Text(audioManager.isListening ? "Stop" : "Start")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(audioManager.isListening ? Color.red : Color.blue)
                .cornerRadius(25)
            }
            .disabled(!audioManager.permissionGranted)
        }
        
        if !audioManager.permissionGranted {
            Text("Microphone access required for tuning")
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - String Reference
struct StringReference: View {
    @ObservedObject var tuningEngine: TuningEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(tuningEngine.selectedInstrument.rawValue) Strings")
                .font(.headline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: tuningEngine.selectedInstrument == .guitar ? 3 : 2), spacing: 10) {
                ForEach(tuningEngine.selectedInstrument.strings, id: \.stringNumber) { string in
                    StringReferenceCard(
                        string: string, 
                        tuningEngine: tuningEngine,
                        isDetected: tuningEngine.detectedString?.stringNumber == string.stringNumber
                    )
                }
            }
        }
    }
}

struct StringReferenceCard: View {
    let string: InstrumentString
    let tuningEngine: TuningEngine
    let isDetected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text("String \(string.stringNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(string.name)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("\(string.targetFrequency(referenceA4: tuningEngine.referenceFrequency), specifier: "%.1f") Hz")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(isDetected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDetected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    ContentView()
}
