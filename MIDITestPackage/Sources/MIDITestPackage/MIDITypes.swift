import Foundation
import CoreMIDI
import AudioKit
import AVFoundation

// MARK: - MIDI Support Structures (Copied from Conductor for testing)

public enum MIDIConnectionStatus: String, CaseIterable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case error = "error"
    
    public var displayName: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error: return "Connection Error"
        }
    }
}

public struct MIDIDeviceInfo: Identifiable, Equatable {
    public let id = UUID()
    public let name: String
    public let manufacturer: String
    public let deviceRef: MIDIDeviceRef
    public let connectionType: MIDIConnectionType
    public let isOnline: Bool
    
    public init(name: String, manufacturer: String, deviceRef: MIDIDeviceRef, connectionType: MIDIConnectionType, isOnline: Bool) {
        self.name = name
        self.manufacturer = manufacturer
        self.deviceRef = deviceRef
        self.connectionType = connectionType
        self.isOnline = isOnline
    }
    
    public static func == (lhs: MIDIDeviceInfo, rhs: MIDIDeviceInfo) -> Bool {
        return lhs.deviceRef == rhs.deviceRef
    }
}

public enum MIDIConnectionType: String, CaseIterable {
    case usb = "usb"
    case bluetooth = "bluetooth"
    case network = "network"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .usb: return "USB"
        case .bluetooth: return "Bluetooth"
        case .network: return "Network"
        case .unknown: return "Unknown"
        }
    }
}

public struct MIDIMapping: Codable {
    public var drumPadMappings: [String: Int] // drum pad name -> MIDI note number
    public var velocityCurve: VelocityCurve
    public var isComplete: Bool {
        return drumPadMappings.count >= 8 // Assuming 8 drum pads minimum
    }
    
    public init(drumPadMappings: [String: Int], velocityCurve: VelocityCurve) {
        self.drumPadMappings = drumPadMappings
        self.velocityCurve = velocityCurve
    }
    
    public static func defaultMapping() -> MIDIMapping {
        return MIDIMapping(
            drumPadMappings: [
                "KICK": 36,      // C2
                "SNARE": 38,     // D2
                "HI HAT": 42,    // F#2
                "OPEN HI HAT": 46, // A#2
                "CLAP": 39,      // D#2
                "LO TOM": 43,    // G2
                "HI TOM": 50,    // D3
                "CRASH": 49      // C#3
            ],
            velocityCurve: .linear
        )
    }
}

public enum VelocityCurve: String, CaseIterable, Codable {
    case linear = "linear"
    case logarithmic = "logarithmic"
    case exponential = "exponential"
    
    public var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .logarithmic: return "Logarithmic"
        case .exponential: return "Exponential"
        }
    }
    
    public func transform(_ velocity: Float) -> Float {
        switch self {
        case .linear:
            return velocity
        case .logarithmic:
            return log10(velocity * 9 + 1)
        case .exponential:
            return pow(velocity, 2)
        }
    }
}

// MARK: - Test Helper Class

public class MIDITestConductor {
    public var midiConnectionStatus: MIDIConnectionStatus = .disconnected
    public var currentMidiMapping: MIDIMapping = MIDIMapping.defaultMapping()
    public var detectedDevices: [MIDIDeviceInfo] = []
    public var audioLatency: TimeInterval = 0.0
    
    public init() {}
    
    public func updateMIDIMapping(_ mapping: MIDIMapping) {
        currentMidiMapping = mapping
    }
    
    public func validateMIDIMapping() -> Bool {
        return currentMidiMapping.isComplete
    }
    
    public func updateConnectionStatus(for devices: [MIDIDeviceInfo]) {
        detectedDevices = devices
        if devices.isEmpty {
            midiConnectionStatus = .disconnected
        } else if devices.contains(where: { $0.isOnline }) {
            midiConnectionStatus = .connected
        } else {
            midiConnectionStatus = .error
        }
    }
}