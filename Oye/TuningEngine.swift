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
    
    var displayName: String {
        return "\(name)\(octave)"
    }
    
    var tuningStatus: TuningStatus {
        if abs(cents) <= 5 {
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
        case .sharp: return "red"
        case .flat: return "red"
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
    let targetFrequency: Double
    let stringNumber: Int
}

// MARK: - Guitar Tunings
struct GuitarTuning {
    static let standard: [InstrumentString] = [
        InstrumentString(name: "E", targetFrequency: 82.41, stringNumber: 6),  // Low E
        InstrumentString(name: "A", targetFrequency: 110.00, stringNumber: 5), // A
        InstrumentString(name: "D", targetFrequency: 146.83, stringNumber: 4), // D
        InstrumentString(name: "G", targetFrequency: 196.00, stringNumber: 3), // G
        InstrumentString(name: "B", targetFrequency: 246.94, stringNumber: 2), // B
        InstrumentString(name: "E", targetFrequency: 329.63, stringNumber: 1)  // High E
    ]
    
    static let dropD: [InstrumentString] = [
        InstrumentString(name: "D", targetFrequency: 73.42, stringNumber: 6),  // Drop D
        InstrumentString(name: "A", targetFrequency: 110.00, stringNumber: 5),
        InstrumentString(name: "D", targetFrequency: 146.83, stringNumber: 4),
        InstrumentString(name: "G", targetFrequency: 196.00, stringNumber: 3),
        InstrumentString(name: "B", targetFrequency: 246.94, stringNumber: 2),
        InstrumentString(name: "E", targetFrequency: 329.63, stringNumber: 1)
    ]
}

// MARK: - Ukulele Tunings
struct UkuleleTuning {
    static let standard: [InstrumentString] = [
        InstrumentString(name: "G", targetFrequency: 392.00, stringNumber: 4), // High G
        InstrumentString(name: "C", targetFrequency: 261.63, stringNumber: 3), // C
        InstrumentString(name: "E", targetFrequency: 329.63, stringNumber: 2), // E
        InstrumentString(name: "A", targetFrequency: 440.00, stringNumber: 1)  // A
    ]
    
    static let lowG: [InstrumentString] = [
        InstrumentString(name: "G", targetFrequency: 196.00, stringNumber: 4), // Low G
        InstrumentString(name: "C", targetFrequency: 261.63, stringNumber: 3),
        InstrumentString(name: "E", targetFrequency: 329.63, stringNumber: 2),
        InstrumentString(name: "A", targetFrequency: 440.00, stringNumber: 1)
    ]
}

// MARK: - Tuning Engine
import Combine

class TuningEngine: ObservableObject {
    @Published var currentNote: MusicalNote?
    @Published var selectedInstrument: InstrumentType = .guitar
    @Published var detectedString: InstrumentString?
    
    private let noteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    private let referenceFrequency: Double = 440.0 // A4
    
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
            cents: cents
        )
    }
    
    private func findClosestString(for frequency: Double) -> InstrumentString? {
        let strings = selectedInstrument.strings
        
        // Find the string with frequency closest to detected frequency
        return strings.min { string1, string2 in
            abs(string1.targetFrequency - frequency) < abs(string2.targetFrequency - frequency)
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
        return detectedString?.targetFrequency
    }
}