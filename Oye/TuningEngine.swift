//
//  TuningEngine.swift
//  Oye
//
//  Created by Jberg on 2025-11-15.
//

import Foundation

// MARK: - Musical Note Representation
struct MusicalNote {
    let name: String
    let octave: Int
    let frequency: Double
    let cents: Double // Deviation from perfect pitch in cents
    let threshold: Double // Configurable threshold for tuning status
    
    var displayName: String {
        return "\(name)\(octave)"
    }
    
    var tuningStatus: TuningStatus {
        if abs(cents) <= threshold {
            return .inTune
        } else if cents > 0 {
            return .sharp
        } else {
            return .flat
        }
    }
}

enum TuningStatus {
    case inTune
    case sharp
    case flat
    
    var color: String {
        switch self {
        case .inTune: return "green"
        case .sharp, .flat: return "red"
        }
    }
    
    var symbol: String {
        switch self {
        case .inTune: return "✓"
        case .sharp: return "♯"
        case .flat: return "♭"
        }
    }
}

// MARK: - Instrument Definitions
enum InstrumentType: String, CaseIterable {
    case guitar = "Guitar"
    case ukulele = "Ukulele"
    
    var strings: [InstrumentString] {
        switch self {
        case .guitar:
            return GuitarTuning.standard
        case .ukulele:
            return UkuleleTuning.standard
        }
    }
}

struct InstrumentString {
    let name: String
    let semitoneOffset: Int // Offset from A4 in semitones
    let stringNumber: Int
    
    func targetFrequency(referenceA4: Double) -> Double {
        return referenceA4 * pow(2.0, Double(semitoneOffset) / 12.0)
    }
    
    // Frequency range for this string (±3 semitones for detection)
    func frequencyRange(referenceA4: Double) -> ClosedRange<Double> {
        let target = targetFrequency(referenceA4: referenceA4)
        let lowerBound = target * pow(2.0, -3.0 / 12.0) // 3 semitones below
        let upperBound = target * pow(2.0, 3.0 / 12.0)  // 3 semitones above
        return lowerBound...upperBound
    }
}

// MARK: - Guitar Tunings
struct GuitarTuning {
    // Standard tuning: E2, A2, D3, G3, B3, E4 (relative to A4 = 440 Hz)
    static let standard: [InstrumentString] = [
        InstrumentString(name: "E", semitoneOffset: -29, stringNumber: 6), // Low E (E2)
        InstrumentString(name: "A", semitoneOffset: -24, stringNumber: 5), // A (A2)
        InstrumentString(name: "D", semitoneOffset: -19, stringNumber: 4), // D (D3)
        InstrumentString(name: "G", semitoneOffset: -14, stringNumber: 3), // G (G3)
        InstrumentString(name: "B", semitoneOffset: -10, stringNumber: 2), // B (B3)
        InstrumentString(name: "E", semitoneOffset: -5, stringNumber: 1)   // High E (E4)
    ]
}

// MARK: - Ukulele Tunings
struct UkuleleTuning {
    // Standard tuning: G4, C4, E4, A4 (relative to A4 = 440 Hz)
    static let standard: [InstrumentString] = [
        InstrumentString(name: "G", semitoneOffset: -2, stringNumber: 4),  // G4
        InstrumentString(name: "C", semitoneOffset: -9, stringNumber: 3),  // C4
        InstrumentString(name: "E", semitoneOffset: -5, stringNumber: 2),  // E4
        InstrumentString(name: "A", semitoneOffset: 0, stringNumber: 1)    // A4 (reference)
    ]
}

// MARK: - Tuning Engine
import Combine

class TuningEngine: ObservableObject {
    @Published var currentNote: MusicalNote?
    @Published var selectedInstrument: InstrumentType = .guitar
    @Published var detectedString: InstrumentString?
    @Published var referenceFrequency: Double = 440.0 // A4 - adjustable between 431-449 Hz
    @Published var tuningThresholdCents: Double = 45.0 // Configurable threshold for out-of-tune warning
    
    private let noteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    
    // Valid range for reference frequency
    let minReferenceFrequency: Double = 431.0
    let maxReferenceFrequency: Double = 449.0
    
    // Valid range for tuning threshold
    let minThresholdCents: Double = 10.0
    let maxThresholdCents: Double = 100.0
    
    func setReferenceFrequency(_ frequency: Double) {
        referenceFrequency = max(minReferenceFrequency, min(maxReferenceFrequency, frequency))
        // Recalculate current note with new reference if we have a frequency
        if let currentFreq = currentNote?.frequency {
            analyzeFrequency(currentFreq)
        }
    }
    
    func setTuningThreshold(_ cents: Double) {
        tuningThresholdCents = max(minThresholdCents, min(maxThresholdCents, cents))
    }
    
    func analyzeFrequency(_ frequency: Double) {
        guard frequency > 0 else {
            currentNote = nil
            detectedString = nil
            return
        }
        
        // Convert frequency to musical note
        let note = frequencyToNote(frequency)
        currentNote = note
        
        // Find closest string for current instrument
        detectedString = findClosestString(for: frequency)
    }
    
    private func frequencyToNote(_ frequency: Double) -> MusicalNote {
        // Calculate semitones from A4 (440 Hz)
        let semitoneFromA4 = 12 * log2(frequency / referenceFrequency)
        let noteIndex = Int(round(semitoneFromA4))
        
        // Calculate exact cents deviation
        let exactSemitone = semitoneFromA4
        let cents = (exactSemitone - Double(noteIndex)) * 100
        
        // Get note name and octave
        let noteInOctave = (noteIndex + 9 + 1200) % 12 // +9 to shift A to index 9, +1200 to handle negatives
        let noteName = noteNames[noteInOctave]
        let octave = ((noteIndex + 9) / 12) + 4 // A4 is our reference
        
        // Calculate the target frequency for this note
        let targetFrequency = referenceFrequency * pow(2.0, Double(noteIndex) / 12.0)
        
        return MusicalNote(
            name: noteName,
            octave: octave,
            frequency: targetFrequency,
            cents: cents,
            threshold: tuningThresholdCents
        )
    }
    
    private func findClosestString(for frequency: Double) -> InstrumentString? {
        let strings = selectedInstrument.strings
        
        // First, find strings whose frequency range contains the detected frequency
        let candidateStrings = strings.filter { string in
            string.frequencyRange(referenceA4: referenceFrequency).contains(frequency)
        }
        
        // If no string's range contains the frequency, return nil (out of range)
        guard !candidateStrings.isEmpty else { return nil }
        
        // Among candidate strings, find the one with the closest target frequency
        return candidateStrings.min { string1, string2 in
            let freq1 = string1.targetFrequency(referenceA4: referenceFrequency)
            let freq2 = string2.targetFrequency(referenceA4: referenceFrequency)
            return abs(freq1 - frequency) < abs(freq2 - frequency)
        }
    }
    
    func selectInstrument(_ instrument: InstrumentType) {
        selectedInstrument = instrument
        // Clear current detection when switching instruments
        currentNote = nil
        detectedString = nil
    }
}

// MARK: - Tuning Helpers
extension TuningEngine {
    func getStringRecommendation(for note: MusicalNote) -> String? {
        guard let string = detectedString else { return nil }
        
        let cents = note.cents
        if abs(cents) <= 5 {
            return "Perfect! \(string.name) string is in tune."
        } else if cents > 0 {
            return "\(string.name) string is \(Int(abs(cents))) cents sharp. Tune down."
        } else {
            return "\(string.name) string is \(Int(abs(cents))) cents flat. Tune up."
        }
    }
    
    func getCentsDeviation() -> Double {
        return currentNote?.cents ?? 0
    }
    
    func getTargetFrequency() -> Double? {
        return detectedString?.targetFrequency(referenceA4: referenceFrequency)
    }
}