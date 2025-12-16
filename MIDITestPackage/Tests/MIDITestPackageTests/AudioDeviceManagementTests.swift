import Testing
import Foundation
import AVFoundation

// MARK: - Audio Device Management Unit Tests

@Suite("Audio Device Management Tests")
struct AudioDeviceManagementTests {
    
    // MARK: - Device Detection Tests
    
    @Test("Device detection returns available devices")
    func testDeviceDetection() async throws {
        let deviceManager = MockAudioDeviceManager()
        
        let devices = deviceManager.getAvailableDevices()
        
        #expect(!devices.isEmpty, "Should detect at least built-in devices")
        #expect(devices.contains { $0.deviceType == .builtInSpeaker }, "Should include built-in speaker")
        #expect(devices.contains { $0.deviceType == .builtInReceiver }, "Should include built-in receiver")
    }
    
    @Test("Bluetooth device detection")
    func testBluetoothDeviceDetection() async throws {
        let deviceManager = MockAudioDeviceManager()
        
        // Simulate bluetooth device connection
        let bluetoothDevice = MockAudioDevice(
            id: "bluetooth-test",
            name: "Test Bluetooth Headphones",
            isBluetooth: true,
            deviceType: .bluetoothA2DP
        )
        deviceManager.simulateDeviceConnection(bluetoothDevice)
        
        let devices = deviceManager.getAvailableDevices()
        let bluetoothDevices = devices.filter { $0.isBluetooth }
        
        #expect(!bluetoothDevices.isEmpty, "Should detect bluetooth devices")
        #expect(bluetoothDevices.first?.name == "Test Bluetooth Headphones", "Should correctly identify bluetooth device")
    }
    
    // MARK: - Device Selection Tests
    
    @Test("Device selection updates current device")
    func testDeviceSelection() async throws {
        let deviceManager = MockAudioDeviceManager()
        
        let testDevice = MockAudioDevice(
            id: "test-device",
            name: "Test Headphones",
            isBluetooth: false,
            deviceType: .headphones
        )
        deviceManager.simulateDeviceConnection(testDevice)
        
        deviceManager.selectDevice("test-device")
        
        #expect(deviceManager.currentDevice?.id == "test-device", "Should update current device")
        #expect(deviceManager.currentDevice?.name == "Test Headphones", "Should set correct device name")
    }
    
    @Test("Invalid device selection handling")
    func testInvalidDeviceSelection() async throws {
        let deviceManager = MockAudioDeviceManager()
        
        let originalDevice = deviceManager.currentDevice
        deviceManager.selectDevice("non-existent-device")
        
        #expect(deviceManager.currentDevice?.id == originalDevice?.id, "Should not change device for invalid ID")
    }
    
    // MARK: - Bluetooth Warning Tests
    
    @Test("Bluetooth warning triggered for bluetooth devices")
    func testBluetoothWarning() async throws {
        let deviceManager = MockAudioDeviceManager()
        
        let bluetoothDevice = MockAudioDevice(
            id: "bluetooth-test",
            name: "Test Bluetooth Device",
            isBluetooth: true,
            deviceType: .bluetoothA2DP
        )
        deviceManager.simulateDeviceConnection(bluetoothDevice)
        
        deviceManager.selectDevice("bluetooth-test")
        
        #expect(deviceManager.bluetoothWarningShown, "Should show bluetooth warning for bluetooth devices")
    }
    
    @Test("No bluetooth warning for wired devices")
    func testNoBluetoothWarningForWiredDevices() async throws {
        let deviceManager = MockAudioDeviceManager()
        
        let wiredDevice = MockAudioDevice(
            id: "wired-test",
            name: "Test Wired Headphones",
            isBluetooth: false,
            deviceType: .headphones
        )
        deviceManager.simulateDeviceConnection(wiredDevice)
        
        deviceManager.selectDevice("wired-test")
        
        #expect(!deviceManager.bluetoothWarningShown, "Should not show bluetooth warning for wired devices")
    }
    
    // MARK: - Latency Compensation Tests
    
    @Test("Latency compensation setting")
    func testLatencyCompensationSetting() async throws {
        let latencyManager = MockAudioLatencyManager()
        
        let testCompensation = 25.0
        latencyManager.setCompensation(testCompensation)
        
        #expect(latencyManager.currentCompensation == testCompensation, "Should set compensation value")
    }
    
    @Test("Recommended compensation calculation")
    func testRecommendedCompensationCalculation() async throws {
        let latencyManager = MockAudioLatencyManager()
        
        // Test different device types
        let bluetoothDevice = MockAudioDevice(id: "bt", name: "BT", isBluetooth: true, deviceType: .bluetoothA2DP)
        let wiredDevice = MockAudioDevice(id: "wired", name: "Wired", isBluetooth: false, deviceType: .headphones)
        let builtInDevice = MockAudioDevice(id: "builtin", name: "Built-in", isBluetooth: false, deviceType: .builtInSpeaker)
        
        let bluetoothCompensation = latencyManager.getRecommendedCompensation(for: bluetoothDevice)
        let wiredCompensation = latencyManager.getRecommendedCompensation(for: wiredDevice)
        let builtInCompensation = latencyManager.getRecommendedCompensation(for: builtInDevice)
        
        // Bluetooth should have higher compensation (more negative)
        #expect(bluetoothCompensation < wiredCompensation, "Bluetooth should have higher compensation than wired")
        #expect(wiredCompensation < builtInCompensation, "Wired should have higher compensation than built-in")
        
        // All compensations should be negative (to compensate for delay)
        #expect(bluetoothCompensation < 0, "Bluetooth compensation should be negative")
        #expect(wiredCompensation < 0, "Wired compensation should be negative")
        #expect(builtInCompensation < 0, "Built-in compensation should be negative")
    }
    
    @Test("Auto-apply compensation on device change")
    func testAutoApplyCompensationOnDeviceChange() async throws {
        let latencyManager = MockAudioLatencyManager()
        
        let bluetoothDevice = MockAudioDevice(
            id: "bluetooth-auto",
            name: "Auto Bluetooth",
            isBluetooth: true,
            deviceType: .bluetoothA2DP
        )
        
        // Simulate device change
        latencyManager.handleDeviceChange(bluetoothDevice)
        
        let expectedCompensation = latencyManager.getRecommendedCompensation(for: bluetoothDevice)
        
        #expect(latencyManager.recommendedCompensation == expectedCompensation, "Should calculate recommended compensation on device change")
    }
    
    // MARK: - Latency Test Manager Tests
    
    @Test("Latency test initialization")
    func testLatencyTestInitialization() async throws {
        let testManager = MockLatencyTestManager()
        
        #expect(!testManager.isTestRunning, "Test should not be running initially")
        #expect(testManager.testProgress == 0.0, "Test progress should be zero initially")
    }
    
    @Test("Latency test progress tracking")
    func testLatencyTestProgressTracking() async throws {
        let testManager = MockLatencyTestManager()
        
        var callbackResults: [Double] = []
        testManager.startTest { result in
            callbackResults.append(result)
        }
        
        #expect(testManager.isTestRunning, "Test should be running after start")
        
        // Simulate test taps
        for i in 1...5 {
            testManager.recordTap()
            let expectedProgress = Double(i) / 10.0 // 10 total tests
            #expect(abs(testManager.testProgress - expectedProgress) < 0.01, "Progress should update correctly")
        }
        
        #expect(callbackResults.count == 5, "Should receive callback for each tap")
    }
    
    @Test("Latency test completion")
    func testLatencyTestCompletion() async throws {
        let testManager = MockLatencyTestManager()
        
        testManager.startTest { _ in }
        
        // Simulate completing all 10 taps
        for _ in 1...10 {
            testManager.recordTap()
        }
        
        // Test should auto-complete after 10 taps
        #expect(!testManager.isTestRunning, "Test should stop after completion")
        #expect(testManager.testProgress == 1.0, "Progress should be 100% after completion")
    }
    
    @Test("Latency measurement calculation")
    func testLatencyMeasurementCalculation() async throws {
        let testManager = MockLatencyTestManager()
        
        var measuredLatency: Double?
        testManager.startLatencyMeasurement { latency in
            measuredLatency = latency
        }
        
        // Wait a bit for async completion
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        #expect(measuredLatency != nil, "Should provide latency measurement")
        #expect(measuredLatency! > 0, "Measured latency should be positive")
        #expect(measuredLatency! < 1000, "Measured latency should be reasonable (< 1 second)")
    }
}

// MARK: - Mock Models

private struct MockAudioDevice: Hashable, Identifiable {
    let id: String
    let name: String
    let isBluetooth: Bool
    let deviceType: MockAudioDeviceType
    
    var expectedLatency: TimeInterval {
        return deviceType.expectedLatency
    }
}

private enum MockAudioDeviceType: String, CaseIterable {
    case bluetoothA2DP = "bluetoothA2DP"
    case bluetoothHFP = "bluetoothHFP"
    case bluetoothLE = "bluetoothLE"
    case headphones = "headphones"
    case wiredHeadset = "wiredHeadset"
    case builtInSpeaker = "builtInSpeaker"
    case builtInReceiver = "builtInReceiver"
    case unknown = "unknown"
    
    var expectedLatency: TimeInterval {
        switch self {
        case .bluetoothA2DP:
            return 0.150 // ~150ms typical for A2DP
        case .bluetoothHFP:
            return 0.100 // ~100ms for HFP
        case .bluetoothLE:
            return 0.050 // ~50ms for LE Audio
        case .headphones, .wiredHeadset:
            return 0.010 // ~10ms for wired
        case .builtInSpeaker, .builtInReceiver:
            return 0.005 // ~5ms for built-in
        case .unknown:
            return 0.020 // Conservative estimate
        }
    }
}

// MARK: - Mock Classes

private class MockAudioDeviceManager {
    var currentDevice: MockAudioDevice?
    var availableDevices: [MockAudioDevice] = []
    var bluetoothWarningShown = false
    
    init() {
        // Add default built-in devices
        availableDevices = [
            MockAudioDevice(id: "builtin-speaker", name: "Built-in Speakers", isBluetooth: false, deviceType: .builtInSpeaker),
            MockAudioDevice(id: "builtin-receiver", name: "Built-in Receiver", isBluetooth: false, deviceType: .builtInReceiver)
        ]
        currentDevice = availableDevices.first
    }
    
    func getAvailableDevices() -> [MockAudioDevice] {
        return availableDevices
    }
    
    func selectDevice(_ deviceId: String) {
        guard let device = availableDevices.first(where: { $0.id == deviceId }) else {
            return
        }
        
        currentDevice = device
        
        if device.isBluetooth {
            bluetoothWarningShown = true
        }
    }
    
    func simulateDeviceConnection(_ device: MockAudioDevice) {
        if !availableDevices.contains(where: { $0.id == device.id }) {
            availableDevices.append(device)
        }
    }
    
    func isBluetoothAudioActive() -> Bool {
        return currentDevice?.isBluetooth ?? false
    }
}

private class MockAudioLatencyManager {
    var currentCompensation: Double = 0.0
    var measuredLatency: Double = 0.0
    var recommendedCompensation: Double = 0.0
    
    func setCompensation(_ milliseconds: Double) {
        currentCompensation = milliseconds
    }
    
    func getRecommendedCompensation(for device: MockAudioDevice) -> Double {
        // Simulate compensation calculation based on device type
        let baseLatency = device.deviceType.expectedLatency * 1000 // Convert to milliseconds
        let systemLatency = 10.0 // Simulated system latency
        
        return -(baseLatency + systemLatency) // Negative to compensate for delay
    }
    
    func handleDeviceChange(_ device: MockAudioDevice) {
        recommendedCompensation = getRecommendedCompensation(for: device)
    }
    
    func measureLatency(completion: @escaping (Double) -> Void) {
        // Simulate latency measurement
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let simulatedLatency = Double.random(in: 20...150) // 20-150ms range
            self.measuredLatency = simulatedLatency
            completion(simulatedLatency)
        }
    }
}

private class MockLatencyTestManager {
    var isTestRunning = false
    var testProgress: Double = 0.0
    
    private var testCallback: ((Double) -> Void)?
    private var measurementCallback: ((Double) -> Void)?
    private var testResults: [Double] = []
    private let totalTestCount = 10
    
    func startTest(callback: @escaping (Double) -> Void) {
        testCallback = callback
        testResults.removeAll()
        isTestRunning = true
        testProgress = 0.0
    }
    
    func recordTap() {
        guard isTestRunning else { return }
        
        // Simulate latency measurement
        let simulatedLatency = Double.random(in: 50...200)
        testResults.append(simulatedLatency)
        testCallback?(simulatedLatency)
        
        testProgress = Double(testResults.count) / Double(totalTestCount)
        
        if testResults.count >= totalTestCount {
            completeTest()
        }
    }
    
    func stopTest() {
        isTestRunning = false
        testCallback = nil
        measurementCallback = nil
        testProgress = 0.0
    }
    
    func startLatencyMeasurement(completion: @escaping (Double) -> Void) {
        measurementCallback = completion
        
        // Simulate automatic measurement
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let simulatedLatency = Double.random(in: 30...120)
            completion(simulatedLatency)
        }
    }
    
    private func completeTest() {
        isTestRunning = false
        testProgress = 1.0
        testCallback = nil
    }
}