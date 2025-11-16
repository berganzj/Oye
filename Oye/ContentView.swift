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
            VStack(spacing: 30) {
                // Instrument Selector
                InstrumentSelector(tuningEngine: tuningEngine)
                
                // Main Tuning Display
                TunerDisplay(
                    audioManager: audioManager,
                    tuningEngine: tuningEngine
                )
                
                // Control Buttons
                TunerControls(audioManager: audioManager)
                
                // String Reference
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

// MARK: - Instrument Selector
struct InstrumentSelector: View {
    @ObservedObject var tuningEngine: TuningEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Instrument")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Picker("Instrument", selection: $tuningEngine.selectedInstrument) {
                ForEach(InstrumentType.allCases, id: \.self) { instrument in
                    HStack {
                        Image(systemName: instrumentIcon(for: instrument))
                        Text(instrument.rawValue)
                    }
                    .tag(instrument)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private func instrumentIcon(for instrument: InstrumentType) -> String {
        switch instrument {
        case .guitar:
            return "guitars"
        case .ukulele:
            return "music.note"
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
                TuningMeter(cents: note.cents)
                
                // String Recommendation
                if let recommendation = tuningEngine.getStringRecommendation(for: note) {
                    Text(recommendation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if audioManager.isListening {
                Text("Play a note...")
                    .font(.title2)
                    .foregroundColor(.secondary)
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
        }
    }
}

// MARK: - Tuning Meter
struct TuningMeter: View {
    let cents: Double
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
        } else if abs(cents) <= 15 {
            return .orange
        } else {
            return .red
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
                    StringReferenceCard(string: string, isDetected: tuningEngine.detectedString?.stringNumber == string.stringNumber)
                }
            }
        }
    }
}

struct StringReferenceCard: View {
    let string: InstrumentString
    let isDetected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text("String \(string.stringNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(string.name)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("\(string.targetFrequency, specifier: "%.1f") Hz")
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
