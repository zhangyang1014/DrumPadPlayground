import Foundation
import AVFoundation
import Combine

// MARK: - MIDI Parser

class MIDIParser: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isParsingActive: Bool = false
    
    // Progress publisher for import operations
    let progressPublisher = PassthroughSubject<Float, Never>()
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    
    // MARK: - Public Methods
    
    func parseMIDIFile(_ url: URL) async throws -> MIDIData {
        isParsingActive = true
        defer { isParsingActive = false }
        
        // Update progress
        progressPublisher.send(0.1)
        
        // Read MIDI file data
        let data = try Data(contentsOf: url)
        
        progressPublisher.send(0.3)
        
        // Parse MIDI data
        let midiData = try parseMIDIData(data)
        
        progressPublisher.send(0.8)
        
        // Process and filter drum events
        let processedData = try processDrumEvents(midiData)
        
        progressPublisher.send(1.0)
        
        return processedData
    }
    
    // MARK: - Private Methods
    
    private func parseMIDIData(_ data: Data) throws -> MIDIData {
        // Basic MIDI file parsing
        // This is a simplified implementation - in a real app you'd use a proper MIDI library
        
        guard data.count >= 14 else {
            throw MIDIParsingError.invalidFormat
        }
        
        // Check MIDI header
        let headerChunk = data.subdata(in: 0..<4)
        guard String(data: headerChunk, encoding: .ascii) == "MThd" else {
            throw MIDIParsingError.invalidFormat
        }
        
        // Read header length
        let headerLength = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        guard headerLength == 6 else {
            throw MIDIParsingError.unsupportedFormat
        }
        
        // Read format type
        let formatType = data.subdata(in: 8..<10).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        
        // Read number of tracks
        let trackCount = data.subdata(in: 10..<12).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        
        // Read time division
        let timeDivision = data.subdata(in: 12..<14).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        
        // Parse tracks
        var tracks: [MIDITrack] = []
        var offset = 14
        
        for _ in 0..<trackCount {
            let track = try parseTrack(data, offset: &offset)
            tracks.append(track)
        }
        
        // Extract tempo and time signature events
        let (tempoEvents, timeSignatureEvents) = extractMetaEvents(from: tracks)
        
        // Filter and convert drum events
        let drumEvents = extractDrumEvents(from: tracks, timeDivision: Int(timeDivision))
        
        // Calculate total duration
        let totalDuration = calculateTotalDuration(drumEvents)
        
        return MIDIData(
            formatType: Int(formatType),
            trackCount: Int(trackCount),
            timeDivision: Int(timeDivision),
            tracks: tracks,
            drumEvents: drumEvents,
            tempoEvents: tempoEvents,
            timeSignatureEvents: timeSignatureEvents,
            totalDuration: totalDuration,
            timeSignature: timeSignatureEvents.first?.timeSignature ?? .fourFour
        )
    }
    
    private func parseTrack(_ data: Data, offset: inout Int) throws -> MIDITrack {
        guard offset + 8 <= data.count else {
            throw MIDIParsingError.truncatedFile
        }
        
        // Check track header
        let trackHeader = data.subdata(in: offset..<offset+4)
        guard String(data: trackHeader, encoding: .ascii) == "MTrk" else {
            throw MIDIParsingError.invalidTrackHeader
        }
        
        // Read track length
        let trackLength = data.subdata(in: offset+4..<offset+8).withUnsafeBytes { 
            $0.load(as: UInt32.self).bigEndian 
        }
        
        offset += 8
        let trackEndOffset = offset + Int(trackLength)
        
        guard trackEndOffset <= data.count else {
            throw MIDIParsingError.truncatedFile
        }
        
        // Parse track events
        var events: [MIDITrackEvent] = []
        var currentTime: UInt32 = 0
        var runningStatus: UInt8 = 0
        
        while offset < trackEndOffset {
            // Read delta time
            let (deltaTime, newOffset) = try readVariableLength(data, offset: offset)
            offset = newOffset
            currentTime += deltaTime
            
            // Read event
            let (event, eventOffset) = try parseTrackEvent(data, offset: offset, runningStatus: &runningStatus)
            offset = eventOffset
            
            events.append(MIDITrackEvent(
                deltaTime: deltaTime,
                absoluteTime: currentTime,
                event: event
            ))
        }
        
        return MIDITrack(events: events)
    }
    
    private func readVariableLength(_ data: Data, offset: Int) throws -> (UInt32, Int) {
        var value: UInt32 = 0
        var currentOffset = offset
        
        for _ in 0..<4 {
            guard currentOffset < data.count else {
                throw MIDIParsingError.truncatedFile
            }
            
            let byte = data[currentOffset]
            currentOffset += 1
            
            value = (value << 7) | UInt32(byte & 0x7F)
            
            if (byte & 0x80) == 0 {
                break
            }
        }
        
        return (value, currentOffset)
    }
    
    private func parseTrackEvent(_ data: Data, offset: Int, runningStatus: inout UInt8) throws -> (MIDIEventType, Int) {
        guard offset < data.count else {
            throw MIDIParsingError.truncatedFile
        }
        
        var currentOffset = offset
        var statusByte = data[currentOffset]
        
        // Handle running status
        if (statusByte & 0x80) == 0 {
            statusByte = runningStatus
        } else {
            runningStatus = statusByte
            currentOffset += 1
        }
        
        switch statusByte & 0xF0 {
        case 0x80: // Note Off
            guard currentOffset + 2 <= data.count else {
                throw MIDIParsingError.truncatedFile
            }
            let noteNumber = data[currentOffset]
            let velocity = data[currentOffset + 1]
            return (.noteOff(channel: statusByte & 0x0F, note: noteNumber, velocity: velocity), currentOffset + 2)
            
        case 0x90: // Note On
            guard currentOffset + 2 <= data.count else {
                throw MIDIParsingError.truncatedFile
            }
            let noteNumber = data[currentOffset]
            let velocity = data[currentOffset + 1]
            return (.noteOn(channel: statusByte & 0x0F, note: noteNumber, velocity: velocity), currentOffset + 2)
            
        case 0xFF: // Meta Event
            guard currentOffset < data.count else {
                throw MIDIParsingError.truncatedFile
            }
            let metaType = data[currentOffset]
            currentOffset += 1
            
            let (length, lengthOffset) = try readVariableLength(data, offset: currentOffset)
            currentOffset = lengthOffset
            
            guard currentOffset + Int(length) <= data.count else {
                throw MIDIParsingError.truncatedFile
            }
            
            let metaData = data.subdata(in: currentOffset..<currentOffset + Int(length))
            currentOffset += Int(length)
            
            return (.metaEvent(type: metaType, data: metaData), currentOffset)
            
        default:
            // Skip unknown events
            return (.unknown, currentOffset + 1)
        }
    }
    
    private func extractMetaEvents(from tracks: [MIDITrack]) -> ([TempoEvent], [TimeSignatureEvent]) {
        var tempoEvents: [TempoEvent] = []
        var timeSignatureEvents: [TimeSignatureEvent] = []
        
        for track in tracks {
            for trackEvent in track.events {
                if case .metaEvent(let type, let data) = trackEvent.event {
                    switch type {
                    case 0x51: // Set Tempo
                        if data.count == 3 {
                            let microsecondsPerQuarter = (UInt32(data[0]) << 16) | (UInt32(data[1]) << 8) | UInt32(data[2])
                            let bpm = 60_000_000.0 / Float(microsecondsPerQuarter)
                            tempoEvents.append(TempoEvent(
                                timestamp: Double(trackEvent.absoluteTime),
                                bpm: bpm,
                                microsecondsPerQuarter: microsecondsPerQuarter
                            ))
                        }
                        
                    case 0x58: // Time Signature
                        if data.count >= 4 {
                            let numerator = Int(data[0])
                            let denominatorPower = Int(data[1])
                            let denominator = 1 << denominatorPower
                            timeSignatureEvents.append(TimeSignatureEvent(
                                timestamp: Double(trackEvent.absoluteTime),
                                timeSignature: TimeSignature(numerator: numerator, denominator: denominator)
                            ))
                        }
                        
                    default:
                        break
                    }
                }
            }
        }
        
        // Add default tempo if none found
        if tempoEvents.isEmpty {
            tempoEvents.append(TempoEvent(timestamp: 0, bpm: 120.0, microsecondsPerQuarter: 500_000))
        }
        
        // Add default time signature if none found
        if timeSignatureEvents.isEmpty {
            timeSignatureEvents.append(TimeSignatureEvent(timestamp: 0, timeSignature: .fourFour))
        }
        
        return (tempoEvents, timeSignatureEvents)
    }
    
    private func extractDrumEvents(from tracks: [MIDITrack], timeDivision: Int) -> [MIDIEvent] {
        var drumEvents: [MIDIEvent] = []
        
        for track in tracks {
            var activeNotes: [UInt8: (timestamp: Double, velocity: Int)] = [:]
            
            for trackEvent in track.events {
                let timestamp = convertTicksToSeconds(UInt32(trackEvent.absoluteTime), timeDivision: timeDivision)
                
                switch trackEvent.event {
                case .noteOn(let channel, let note, let velocity):
                    // Channel 9 (0-indexed) is typically the drum channel
                    if channel == 9 && velocity > 0 {
                        activeNotes[note] = (timestamp: timestamp, velocity: Int(velocity))
                    }
                    
                case .noteOff(let channel, let note, _):
                    if channel == 9, let activeNote = activeNotes.removeValue(forKey: note) {
                        let duration = timestamp - activeNote.timestamp
                        drumEvents.append(MIDIEvent(
                            timestamp: activeNote.timestamp,
                            noteNumber: Int(note),
                            velocity: activeNote.velocity,
                            duration: duration > 0 ? duration : nil
                        ))
                    }
                    
                default:
                    break
                }
            }
            
            // Handle any remaining active notes (treat as short notes)
            for (note, activeNote) in activeNotes {
                drumEvents.append(MIDIEvent(
                    timestamp: activeNote.timestamp,
                    noteNumber: Int(note),
                    velocity: activeNote.velocity,
                    duration: 0.1 // Default short duration
                ))
            }
        }
        
        return drumEvents.sorted { $0.timestamp < $1.timestamp }
    }
    
    private func convertTicksToSeconds(_ ticks: UInt32, timeDivision: Int) -> Double {
        // Simplified conversion assuming 120 BPM and 4/4 time
        // In a real implementation, you'd track tempo changes
        let beatsPerSecond = 120.0 / 60.0
        let ticksPerBeat = Double(timeDivision)
        let secondsPerTick = 1.0 / (beatsPerSecond * ticksPerBeat)
        
        return Double(ticks) * secondsPerTick
    }
    
    private func calculateTotalDuration(_ events: [MIDIEvent]) -> TimeInterval {
        guard let lastEvent = events.last else { return 0 }
        
        let lastEventEnd = lastEvent.timestamp + (lastEvent.duration ?? 0.1)
        return lastEventEnd + 1.0 // Add 1 second buffer
    }
    
    private func processDrumEvents(_ midiData: MIDIData) throws -> MIDIData {
        // Filter out very quiet notes (velocity < 10)
        let filteredEvents = midiData.drumEvents.filter { $0.velocity >= 10 }
        
        // Remove duplicate events (same note at nearly same time)
        let deduplicatedEvents = removeDuplicateEvents(filteredEvents)
        
        // Quantize timing if needed (optional)
        let quantizedEvents = quantizeEvents(deduplicatedEvents, timeDivision: midiData.timeDivision)
        
        return MIDIData(
            formatType: midiData.formatType,
            trackCount: midiData.trackCount,
            timeDivision: midiData.timeDivision,
            tracks: midiData.tracks,
            drumEvents: quantizedEvents,
            tempoEvents: midiData.tempoEvents,
            timeSignatureEvents: midiData.timeSignatureEvents,
            totalDuration: calculateTotalDuration(quantizedEvents),
            timeSignature: midiData.timeSignature
        )
    }
    
    private func removeDuplicateEvents(_ events: [MIDIEvent]) -> [MIDIEvent] {
        var filteredEvents: [MIDIEvent] = []
        let timeThreshold: Double = 0.01 // 10ms threshold
        
        for event in events {
            let isDuplicate = filteredEvents.contains { existingEvent in
                existingEvent.noteNumber == event.noteNumber &&
                abs(existingEvent.timestamp - event.timestamp) < timeThreshold
            }
            
            if !isDuplicate {
                filteredEvents.append(event)
            }
        }
        
        return filteredEvents
    }
    
    private func quantizeEvents(_ events: [MIDIEvent], timeDivision: Int) -> [MIDIEvent] {
        // Optional quantization to nearest 16th note
        let quantizeGrid: Double = 0.125 // 16th note at 120 BPM
        
        return events.map { event in
            let quantizedTime = round(event.timestamp / quantizeGrid) * quantizeGrid
            return MIDIEvent(
                timestamp: max(0, quantizedTime),
                noteNumber: event.noteNumber,
                velocity: event.velocity,
                duration: event.duration
            )
        }
    }
}

// MARK: - MIDI Data Structures

struct MIDIData {
    let formatType: Int
    let trackCount: Int
    let timeDivision: Int
    let tracks: [MIDITrack]
    let drumEvents: [MIDIEvent]
    let tempoEvents: [TempoEvent]
    let timeSignatureEvents: [TimeSignatureEvent]
    let totalDuration: TimeInterval
    let timeSignature: TimeSignature
}

struct MIDITrack {
    let events: [MIDITrackEvent]
}

struct MIDITrackEvent {
    let deltaTime: UInt32
    let absoluteTime: UInt32
    let event: MIDIEventType
}

enum MIDIEventType {
    case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)
    case noteOff(channel: UInt8, note: UInt8, velocity: UInt8)
    case metaEvent(type: UInt8, data: Data)
    case unknown
}

struct MIDIEvent {
    let timestamp: TimeInterval
    let noteNumber: Int
    let velocity: Int
    let duration: TimeInterval?
}

struct TempoEvent {
    let timestamp: TimeInterval
    let bpm: Float
    let microsecondsPerQuarter: UInt32
}

struct TimeSignatureEvent {
    let timestamp: TimeInterval
    let timeSignature: TimeSignature
}

// MARK: - MIDI Parsing Errors

enum MIDIParsingError: LocalizedError {
    case invalidFormat
    case unsupportedFormat
    case truncatedFile
    case invalidTrackHeader
    case corruptedData
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid MIDI file format"
        case .unsupportedFormat:
            return "Unsupported MIDI format"
        case .truncatedFile:
            return "MIDI file appears to be truncated"
        case .invalidTrackHeader:
            return "Invalid track header in MIDI file"
        case .corruptedData:
            return "MIDI file data is corrupted"
        }
    }
}

// MARK: - MIDI Utilities

extension MIDIParser {
    
    // Get drum kit mapping for common MIDI note numbers
    static func getDrumKitMapping() -> [Int: String] {
        return [
            35: "Bass Drum 2",
            36: "Bass Drum 1",
            37: "Side Stick",
            38: "Snare Drum 1",
            39: "Hand Clap",
            40: "Snare Drum 2",
            41: "Low Tom 2",
            42: "Closed Hi-hat",
            43: "Low Tom 1",
            44: "Pedal Hi-hat",
            45: "Mid Tom 2",
            46: "Open Hi-hat",
            47: "Mid Tom 1",
            48: "High Tom 2",
            49: "Crash Cymbal 1",
            50: "High Tom 1",
            51: "Ride Cymbal 1",
            52: "Chinese Cymbal",
            53: "Ride Bell",
            54: "Tambourine",
            55: "Splash Cymbal",
            56: "Cowbell",
            57: "Crash Cymbal 2",
            58: "Vibra Slap",
            59: "Ride Cymbal 2"
        ]
    }
    
    // Check if a MIDI note number is a drum sound
    static func isDrumNote(_ noteNumber: Int) -> Bool {
        return noteNumber >= 35 && noteNumber <= 81
    }
    
    // Get the drum name for a MIDI note number
    static func getDrumName(for noteNumber: Int) -> String {
        return getDrumKitMapping()[noteNumber] ?? "Unknown Drum (\(noteNumber))"
    }
}