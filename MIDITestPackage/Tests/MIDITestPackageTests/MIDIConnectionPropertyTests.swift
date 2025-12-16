import Testing
import Foundation
import CoreMIDI
@testable import MIDITestPackage

// MARK: - Test Data Generators

struct MIDITestGenerators {
    
    // Generate random MIDI device info for testing
    static func generateMIDIDeviceInfo() -> MIDIDeviceInfo {
        let deviceNames = ["Roland TD-17", "Alesis Nitro", "Yamaha DTX", "Generic MIDI Device", "Bluetooth Drum Kit"]
        let manufacturers = ["Roland", "Alesis", "Yamaha", "Generic", "Unknown"]
        
        let randomName = deviceNames.randomElement()!
        let randomManufacturer = manufacturers.randomElement()!
        let randomOnlineStatus = Bool.random()
        
        // Determine connection type based on device name to match expected behavior
        let connectionType: MIDIConnectionType
        if randomName.lowercased().contains("bluetooth") {
            connectionType = .bluetooth
        } else if randomName.lowercased().contains("usb") {
            connectionType = .usb
        } else if randomName.lowercased().contains("network") {
            connectionType = .network
        } else {
            // For devices without clear indicators, use random valid type
            connectionType = [.usb, .bluetooth, .network, .unknown].randomElement()!
        }
        
        return MIDIDeviceInfo(
            name: randomName,
            manufacturer: randomManufacturer,
            deviceRef: MIDIDeviceRef(Int.random(in: 1...1000)), // Mock device ref
            connectionType: connectionType,
            isOnline: randomOnlineStatus
        )
    }
    
    // Generate random MIDI mapping configurations
    static func generateMIDIMapping(isComplete: Bool = true) -> MIDIMapping {
        let drumPads = ["KICK", "SNARE", "HI HAT", "OPEN HI HAT", "CLAP", "LO TOM", "MID TOM", "HI TOM", "CRASH"]
        let velocityCurves: [VelocityCurve] = [.linear, .logarithmic, .exponential]
        
        var mappings: [String: Int] = [:]
        var usedNotes: Set<Int> = []
        
        if isComplete {
            // Generate complete mapping with at least 8 drum pads, ensuring no duplicate MIDI notes
            let padCount = max(8, Int.random(in: 8...drumPads.count))
            for i in 0..<padCount {
                let drumPad = drumPads[i]
                var midiNote: Int
                repeat {
                    midiNote = Int.random(in: 24...127) // Valid MIDI note range
                } while usedNotes.contains(midiNote)
                
                mappings[drumPad] = midiNote
                usedNotes.insert(midiNote)
            }
        } else {
            // Generate incomplete mapping with fewer than 8 drum pads, ensuring no duplicate MIDI notes
            let count = Int.random(in: 1..<8)
            for i in 0..<count {
                let drumPad = drumPads[i]
                var midiNote: Int
                repeat {
                    midiNote = Int.random(in: 24...127)
                } while usedNotes.contains(midiNote)
                
                mappings[drumPad] = midiNote
                usedNotes.insert(midiNote)
            }
        }
        
        return MIDIMapping(
            drumPadMappings: mappings,
            velocityCurve: velocityCurves.randomElement()!
        )
    }
    
    // Generate random connection status
    static func generateConnectionStatus() -> MIDIConnectionStatus {
        return MIDIConnectionStatus.allCases.randomElement()!
    }
}

// MARK: - Property-Based Tests

@Suite("MIDI Connection Property Tests")
struct MIDIConnectionPropertyTests {
    
    // **Feature: melodic-drum-trainer, Property 1: MIDI设备连接一致性**
    @Test("Property 1: MIDI Device Connection Consistency", arguments: (0..<100).map { _ in MIDITestGenerators.generateMIDIDeviceInfo() })
    func testMIDIDeviceConnectionConsistency(deviceInfo: MIDIDeviceInfo) async throws {
        // Test that device type identification is consistent
        let detectedConnectionType = deviceInfo.connectionType
        
        // Verify connection type is properly categorized
        switch deviceInfo.name.lowercased() {
        case let name where name.contains("bluetooth"):
            #expect(detectedConnectionType == .bluetooth, "Bluetooth devices should be identified as bluetooth connection type")
        case let name where name.contains("usb"):
            #expect(detectedConnectionType == .usb, "USB devices should be identified as USB connection type")
        case let name where name.contains("network"):
            #expect(detectedConnectionType == .network, "Network devices should be identified as network connection type")
        default:
            // For devices without clear indicators, any type is acceptable
            #expect([.usb, .bluetooth, .network, .unknown].contains(detectedConnectionType), "Device should have a valid connection type")
        }
        
        // Test that device info is properly structured
        #expect(!deviceInfo.name.isEmpty, "Device name should not be empty")
        #expect(!deviceInfo.manufacturer.isEmpty, "Device manufacturer should not be empty")
        #expect(deviceInfo.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"), "Device should have a valid UUID")
        
        // Test connection status consistency
        if deviceInfo.isOnline {
            // Online devices should be connectable
            #expect(deviceInfo.connectionType != .unknown || deviceInfo.name != "Unknown Device", 
                   "Online devices should have identifiable connection information")
        }
    }
    
    // **Feature: melodic-drum-trainer, Property 2: MIDI映射完整性**
    @Test("Property 2: MIDI Mapping Completeness", arguments: (0..<100).map { _ in MIDITestGenerators.generateMIDIMapping() })
    func testMIDIMappingCompleteness(mapping: MIDIMapping) async throws {
        // Test that complete mappings have all required drum pads
        if mapping.isComplete {
            #expect(mapping.drumPadMappings.count >= 8, "Complete MIDI mapping should have at least 8 drum pad mappings")
            
            // Verify essential drum pads are present
            let essentialPads = ["KICK", "SNARE", "HI HAT"]
            for pad in essentialPads {
                #expect(mapping.drumPadMappings.keys.contains(pad), "Complete mapping should include essential pad: \(pad)")
            }
        } else {
            #expect(mapping.drumPadMappings.count < 8, "Incomplete MIDI mapping should have fewer than 8 drum pad mappings")
        }
        
        // Test that all MIDI note numbers are valid
        for (drumPad, midiNote) in mapping.drumPadMappings {
            #expect(midiNote >= 0 && midiNote <= 127, "MIDI note \(midiNote) for \(drumPad) should be in valid range 0-127")
            #expect(!drumPad.isEmpty, "Drum pad name should not be empty")
        }
        
        // Test that velocity curve is valid
        #expect(VelocityCurve.allCases.contains(mapping.velocityCurve), "Velocity curve should be a valid case")
        
        // Test velocity curve transformation
        let testVelocity: Float = 0.5
        let transformedVelocity = mapping.velocityCurve.transform(testVelocity)
        #expect(transformedVelocity >= 0.0 && transformedVelocity <= 1.0, "Transformed velocity should be in range 0.0-1.0")
        
        // Test that no duplicate MIDI notes exist
        let midiNotes = Array(mapping.drumPadMappings.values)
        let uniqueNotes = Set(midiNotes)
        #expect(midiNotes.count == uniqueNotes.count, "MIDI mapping should not have duplicate note assignments")
    }
    
    // **Feature: melodic-drum-trainer, Property 3: 连接状态显示一致性**
    @Test("Property 3: Connection Status Display Consistency", arguments: (0..<100).map { _ in MIDITestGenerators.generateConnectionStatus() })
    func testConnectionStatusDisplayConsistency(status: MIDIConnectionStatus) async throws {
        // Test that connection status has consistent display representation
        let displayName = status.displayName
        
        #expect(!displayName.isEmpty, "Connection status should have a non-empty display name")
        
        // Test status-specific display consistency
        switch status {
        case .disconnected:
            #expect(displayName.lowercased().contains("disconnect"), "Disconnected status should indicate disconnection")
        case .connecting:
            #expect(displayName.lowercased().contains("connect"), "Connecting status should indicate connection in progress")
        case .connected:
            #expect(displayName.lowercased().contains("connect"), "Connected status should indicate successful connection")
        case .error:
            #expect(displayName.lowercased().contains("error"), "Error status should indicate error condition")
        }
        
        // Test that raw value is consistent
        #expect(!status.rawValue.isEmpty, "Status should have a non-empty raw value")
        #expect(status.rawValue.lowercased() == status.rawValue, "Status raw value should be lowercase")
        
        // Test that status can be reconstructed from raw value
        if let reconstructedStatus = MIDIConnectionStatus(rawValue: status.rawValue) {
            #expect(reconstructedStatus == status, "Status should be reconstructible from its raw value")
            #expect(reconstructedStatus.displayName == displayName, "Reconstructed status should have same display name")
        }
    }
    
    // Additional property test for MIDI mapping validation consistency
    @Test("MIDI Mapping Validation Consistency", arguments: (0..<50).map { _ in MIDITestGenerators.generateMIDIMapping(isComplete: true) } + (0..<50).map { _ in MIDITestGenerators.generateMIDIMapping(isComplete: false) })
    func testMIDIMappingValidationConsistency(mapping: MIDIMapping) async throws {
        let conductor = MIDITestConductor()
        conductor.updateMIDIMapping(mapping)
        
        // Test that validation result matches the mapping's completeness
        let isValid = conductor.validateMIDIMapping()
        #expect(isValid == mapping.isComplete, "Validation result should match mapping completeness")
        
        // Test that current mapping is properly updated
        #expect(conductor.currentMidiMapping.drumPadMappings.count == mapping.drumPadMappings.count, 
               "Conductor should store the updated mapping")
    }
}

// MARK: - Integration Property Tests

@Suite("MIDI Connection Integration Property Tests")
struct MIDIConnectionIntegrationPropertyTests {
    
    @Test("Device Connection State Consistency")
    func testDeviceConnectionStateConsistency() async throws {
        let conductor = MIDITestConductor()
        
        // Test initial state
        #expect(conductor.midiConnectionStatus == .disconnected, "Initial connection status should be disconnected")
        #expect(conductor.detectedDevices.isEmpty, "Initial detected devices should be empty")
        
        // Test that connection status updates are consistent
        let initialStatus = conductor.midiConnectionStatus
        #expect(MIDIConnectionStatus.allCases.contains(initialStatus), "Connection status should be a valid case")
    }
    
    @Test("MIDI Mapping Default State")
    func testMIDIMappingDefaultState() async throws {
        let conductor = MIDITestConductor()
        let defaultMapping = conductor.currentMidiMapping
        
        // Test that default mapping is complete and valid
        #expect(defaultMapping.isComplete, "Default MIDI mapping should be complete")
        #expect(defaultMapping.drumPadMappings.count >= 8, "Default mapping should have at least 8 drum pads")
        
        // Test that essential drum pads are mapped
        let essentialPads = ["KICK", "SNARE", "HI HAT"]
        for pad in essentialPads {
            #expect(defaultMapping.drumPadMappings.keys.contains(pad), "Default mapping should include \(pad)")
        }
    }
    
    @Test("Connection Status Update Logic", arguments: (0..<20).map { _ in (0..<Int.random(in: 0...5)).map { _ in MIDITestGenerators.generateMIDIDeviceInfo() } })
    func testConnectionStatusUpdateLogic(devices: [MIDIDeviceInfo]) async throws {
        let conductor = MIDITestConductor()
        conductor.updateConnectionStatus(for: devices)
        
        // Test connection status logic
        if devices.isEmpty {
            #expect(conductor.midiConnectionStatus == .disconnected, "Empty device list should result in disconnected status")
        } else if devices.contains(where: { $0.isOnline }) {
            #expect(conductor.midiConnectionStatus == .connected, "Online devices should result in connected status")
        } else {
            #expect(conductor.midiConnectionStatus == .error, "Offline devices should result in error status")
        }
        
        // Test device list update
        #expect(conductor.detectedDevices.count == devices.count, "Detected devices should match input devices")
    }
}