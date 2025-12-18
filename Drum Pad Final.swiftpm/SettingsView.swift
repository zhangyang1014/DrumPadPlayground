import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - Settings View

struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var availableAudioDevices: [AudioDevice] = []
    @State private var showingLatencyTest = false
    @State private var bluetoothWarningShown = false
    @State private var showingResetConfirmation = false
    @State private var showingImportExport = false
    
    var body: some View {
        NavigationView {
            Form {
                // Accessibility section
                Section("Accessibility") {
                    Toggle("High Contrast Mode", isOn: $settingsManager.highContrastMode)
                    
                    Toggle("Streak Flash Effects", isOn: $settingsManager.streakFlashEnabled)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("High contrast mode replaces colored feedback with white icons for better visibility")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Audio settings section
                Section("Audio Settings") {
                    // Audio device selection
                    Picker("Audio Output", selection: $settingsManager.selectedAudioDevice) {
                        ForEach(availableAudioDevices, id: \.id) { device in
                            HStack {
                                Text(device.name)
                                if device.isBluetooth {
                                    Image(systemName: "bluetooth")
                                        .foregroundColor(.blue)
                                }
                            }
                            .tag(device.id)
                        }
                    }
                    
                    // Latency compensation
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Latency Compensation")
                            Spacer()
                            Text("\(Int(settingsManager.audioLatencyCompensation))ms")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: $settingsManager.audioLatencyCompensation,
                            in: -100...100,
                            step: 5
                        )
                        
                        HStack {
                            Button("Test Latency") {
                                showingLatencyTest = true
                            }
                            .font(.caption)
                            
                            Spacer()
                            
                            Button("Reset") {
                                settingsManager.audioLatencyCompensation = 0.0
                            }
                            .font(.caption)
                        }
                    }
                    
                    // Metronome settings
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Metronome Volume")
                            Spacer()
                            Text("\(Int(settingsManager.metronomeVolume * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: $settingsManager.metronomeVolume,
                            in: 0...1,
                            step: 0.1
                        )
                    }
                    
                    Picker("Metronome Sound", selection: $settingsManager.metronomeSound) {
                        Text("Click").tag("click")
                        Text("Beep").tag("beep")
                        Text("Wood Block").tag("wood")
                        Text("Cowbell").tag("cowbell")
                        Text("Rim Shot").tag("rim")
                        Text("Hi-Hat").tag("hihat")
                    }
                }
                
                // Practice settings section
                Section("Practice Settings") {
                    Stepper(
                        "Daily Goal: \(settingsManager.dailyGoalMinutes) minutes",
                        value: $settingsManager.dailyGoalMinutes,
                        in: 1...120,
                        step: 5
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set your daily practice goal to build a consistent habit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Data and privacy section
                Section("Data & Privacy") {
                    NavigationLink("Export Practice Data") {
                        DataExportView()
                    }
                    
                    NavigationLink("CloudKit Sync Status") {
                        CloudKitSyncStatusView()
                    }
                    
                    Button("Import/Export Settings") {
                        showingImportExport = true
                    }
                    
                    Button("Reset Settings to Default") {
                        showingResetConfirmation = true
                    }
                    .foregroundColor(.orange)
                    
                    Button("Reset All Progress") {
                        // Handle reset with confirmation - this would be handled by CoreDataManager
                    }
                    .foregroundColor(.red)
                }
                
                // About section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink("Acknowledgments") {
                        AcknowledgmentsView()
                    }
                    
                    NavigationLink("Legacy Drum Pad") {
                        LegacyDrumPadView()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadAudioDevices()
                checkBluetoothConnection()
            }
            .alert("Bluetooth Audio Detected", isPresented: $bluetoothWarningShown) {
                Button("OK") { }
            } message: {
                Text("Bluetooth audio may introduce latency. Consider using wired headphones for the best experience.")
            }
            .sheet(isPresented: $showingLatencyTest) {
                LatencyTestView(
                    currentCompensation: $settingsManager.audioLatencyCompensation,
                    onCompensationChange: { }
                )
            }
            .sheet(isPresented: $showingImportExport) {
                SettingsImportExportView()
            }
            .alert("Reset Settings", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    settingsManager.resetToDefaults()
                }
            } message: {
                Text("This will reset all settings to their default values. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadAudioDevices() {
        availableAudioDevices = AudioDeviceManager.shared.getAvailableDevices()
    }
    
    private func checkBluetoothConnection() {
        if AudioDeviceManager.shared.isBluetoothAudioActive() && !bluetoothWarningShown {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                bluetoothWarningShown = true
            }
        }
        
        // Show bluetooth warning if selected device is bluetooth
        if let selectedDevice = availableAudioDevices.first(where: { $0.id == settingsManager.selectedAudioDevice }),
           selectedDevice.isBluetooth && !bluetoothWarningShown {
            bluetoothWarningShown = true
        }
    }
}

// MARK: - Audio Device

struct AudioDevice: Hashable, Identifiable {
    let id: String
    let name: String
    let isBluetooth: Bool
    let deviceType: AudioDeviceType
    
    init(id: String, name: String, isBluetooth: Bool, deviceType: AudioDeviceType = .unknown) {
        self.id = id
        self.name = name
        self.isBluetooth = isBluetooth
        self.deviceType = deviceType
    }
}

enum AudioDeviceType: String, CaseIterable {
    case bluetoothA2DP = "bluetoothA2DP"
    case bluetoothHFP = "bluetoothHFP"
    case bluetoothLE = "bluetoothLE"
    case headphones = "headphones"
    case wiredHeadset = "wiredHeadset"
    case builtInSpeaker = "builtInSpeaker"
    case builtInReceiver = "builtInReceiver"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .bluetoothA2DP:
            return "Bluetooth Audio"
        case .bluetoothHFP:
            return "Bluetooth Headset"
        case .bluetoothLE:
            return "Bluetooth LE Audio"
        case .headphones:
            return "Wired Headphones"
        case .wiredHeadset:
            return "Wired Headset"
        case .builtInSpeaker:
            return "Built-in Speaker"
        case .builtInReceiver:
            return "Built-in Receiver"
        case .unknown:
            return "Unknown Device"
        }
    }
    
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

// MARK: - Audio Device Manager

class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()
    
    @Published var currentDevice: AudioDevice?
    @Published var availableDevices: [AudioDevice] = []
    @Published var bluetoothWarningShown = false
    
    private var audioSession: AVAudioSession
    private var routeChangeObserver: NSObjectProtocol?
    
    private init() {
        self.audioSession = AVAudioSession.sharedInstance()
        setupAudioSession()
        loadAvailableDevices()
        observeRouteChanges()
    }
    
    deinit {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Methods
    
    func getAvailableDevices() -> [AudioDevice] {
        loadAvailableDevices()
        return availableDevices
    }
    
    func selectDevice(_ deviceId: String) {
        guard let device = availableDevices.first(where: { $0.id == deviceId }) else {
            print("Device not found: \(deviceId)")
            return
        }
        
        do {
            // Configure audio session for the selected device
            try configureAudioSession(for: device)
            currentDevice = device
            
            // Show bluetooth warning if needed
            if device.isBluetooth && !bluetoothWarningShown {
                DispatchQueue.main.async {
                    self.bluetoothWarningShown = true
                }
            }
            
            // Notify other components of device change
            NotificationCenter.default.post(
                name: .audioDeviceChanged,
                object: device
            )
            
            print("Successfully selected audio device: \(device.name)")
            
        } catch {
            print("Failed to select audio device: \(error.localizedDescription)")
        }
    }
    
    func isBluetoothAudioActive() -> Bool {
        let currentRoute = audioSession.currentRoute
        
        for output in currentRoute.outputs {
            if isBluetoothPortType(output.portType) {
                return true
            }
        }
        
        for input in currentRoute.inputs {
            if isBluetoothPortType(input.portType) {
                return true
            }
        }
        
        return false
    }
    
    func getCurrentDevice() -> AudioDevice? {
        return currentDevice
    }
    
    func refreshDevices() {
        loadAvailableDevices()
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord,
                                       mode: .default,
                                       options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    private func loadAvailableDevices() {
        var devices: [AudioDevice] = []
        
        // Add built-in devices
        devices.append(AudioDevice(
            id: "builtin-speaker", 
            name: "Built-in Speakers", 
            isBluetooth: false,
            deviceType: .builtInSpeaker
        ))
        
        devices.append(AudioDevice(
            id: "builtin-receiver", 
            name: "Built-in Receiver", 
            isBluetooth: false,
            deviceType: .builtInReceiver
        ))
        
        // Get available inputs
        if let availableInputs = audioSession.availableInputs {
            for input in availableInputs {
                let isBluetooth = isBluetoothPortType(input.portType)
                let deviceType = mapPortTypeToDeviceType(input.portType)
                
                devices.append(AudioDevice(
                    id: input.uid,
                    name: input.portName,
                    isBluetooth: isBluetooth,
                    deviceType: deviceType
                ))
            }
        }
        
        // Get current route outputs
        let currentRoute = audioSession.currentRoute
        for output in currentRoute.outputs {
            let isBluetooth = isBluetoothPortType(output.portType)
            let deviceType = mapPortTypeToDeviceType(output.portType)
            
            // Avoid duplicates
            if !devices.contains(where: { $0.id == output.uid }) {
                devices.append(AudioDevice(
                    id: output.uid,
                    name: output.portName,
                    isBluetooth: isBluetooth,
                    deviceType: deviceType
                ))
            }
        }
        
        // Remove duplicates and sort
        let uniqueDevices = Array(Set(devices))
        availableDevices = uniqueDevices.sorted { device1, device2 in
            // Built-in devices first, then wired, then bluetooth
            if device1.isBluetooth != device2.isBluetooth {
                return !device1.isBluetooth
            }
            return device1.name < device2.name
        }
        
        // Set current device if not already set
        if currentDevice == nil {
            currentDevice = getCurrentActiveDevice()
        }
    }
    
    private func configureAudioSession(for device: AudioDevice) throws {
        // Configure audio session based on device type
        var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker]
        
        if device.isBluetooth {
            options.insert(.allowBluetoothHFP)
        }
        
        switch device.deviceType {
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            options.insert(.allowBluetoothHFP)
        case .headphones, .wiredHeadset:
            // No special options needed for wired devices
            break
        case .builtInSpeaker:
            options.insert(.defaultToSpeaker)
        case .builtInReceiver:
            // Use receiver (earpiece)
            options.remove(.defaultToSpeaker)
        case .unknown:
            break
        }
        
        try audioSession.setCategory(.playAndRecord, mode: .default, options: options)
        try audioSession.setActive(true)
    }
    
    private func getCurrentActiveDevice() -> AudioDevice? {
        let currentRoute = audioSession.currentRoute
        
        // Check outputs first
        if let output = currentRoute.outputs.first {
            return availableDevices.first { $0.id == output.uid }
        }
        
        // Fallback to inputs
        if let input = currentRoute.inputs.first {
            return availableDevices.first { $0.id == input.uid }
        }
        
        return nil
    }
    
    private func observeRouteChanges() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }
    
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            loadAvailableDevices()
            currentDevice = getCurrentActiveDevice()
            
            // Show bluetooth warning if bluetooth device was connected
            if isBluetoothAudioActive() && !bluetoothWarningShown {
                bluetoothWarningShown = true
            }
            
        case .categoryChange, .override:
            currentDevice = getCurrentActiveDevice()
            
        default:
            break
        }
    }
    
    private func isBluetoothPortType(_ portType: AVAudioSession.Port) -> Bool {
        return portType == .bluetoothA2DP || 
               portType == .bluetoothHFP ||
               portType == .bluetoothLE
    }
    
    private func mapPortTypeToDeviceType(_ portType: AVAudioSession.Port) -> AudioDeviceType {
        switch portType {
        case .bluetoothA2DP:
            return .bluetoothA2DP
        case .bluetoothHFP:
            return .bluetoothHFP
        case .bluetoothLE:
            return .bluetoothLE
        case .headphones:
            return .headphones
        case .headsetMic:
            return .wiredHeadset
        case .builtInSpeaker:
            return .builtInSpeaker
        case .builtInReceiver:
            return .builtInReceiver
        default:
            return .unknown
        }
    }
}

// MARK: - Audio Latency Manager

class AudioLatencyManager: ObservableObject {
    static let shared = AudioLatencyManager()
    
    @Published var currentCompensation: Double = 0.0
    @Published var measuredLatency: Double = 0.0
    @Published var recommendedCompensation: Double = 0.0
    
    private var audioSession: AVAudioSession
    private var deviceChangeObserver: NSObjectProtocol?
    
    private init() {
        self.audioSession = AVAudioSession.sharedInstance()
        observeDeviceChanges()
    }
    
    deinit {
        if let observer = deviceChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Methods
    
    func setCompensation(_ milliseconds: Double) {
        currentCompensation = milliseconds
        
        // Apply latency compensation to the scoring system
        NotificationCenter.default.post(
            name: .latencyCompensationChanged,
            object: milliseconds
        )
        
        print("Setting latency compensation: \(milliseconds)ms")
    }
    
    func measureLatency(completion: @escaping (Double) -> Void) {
        // Start latency measurement process
        LatencyTestManager.shared.startLatencyMeasurement { [weak self] latency in
            DispatchQueue.main.async {
                self?.measuredLatency = latency
                self?.recommendedCompensation = -latency // Negative to compensate for delay
                completion(latency)
            }
        }
    }
    
    func getRecommendedCompensation(for device: AudioDevice) -> Double {
        // Base recommendation on device type
        let baseLatency = device.deviceType.expectedLatency * 1000 // Convert to milliseconds
        
        // Add system-specific adjustments
        let systemLatency = getSystemLatency()
        
        // Return negative value to compensate for the delay
        return -(baseLatency + systemLatency)
    }
    
    func autoDetectAndApplyCompensation() {
        guard let currentDevice = AudioDeviceManager.shared.getCurrentDevice() else {
            return
        }
        
        let recommended = getRecommendedCompensation(for: currentDevice)
        setCompensation(recommended)
        
        print("Auto-applied latency compensation: \(recommended)ms for device: \(currentDevice.name)")
    }
    
    func resetCompensation() {
        setCompensation(0.0)
    }
    
    // MARK: - Private Methods
    
    private func getSystemLatency() -> Double {
        // Get system-reported latency values
        let inputLatency = audioSession.inputLatency * 1000 // Convert to milliseconds
        let outputLatency = audioSession.outputLatency * 1000
        let ioBufferDuration = audioSession.ioBufferDuration * 1000
        
        return inputLatency + outputLatency + ioBufferDuration
    }
    
    private func observeDeviceChanges() {
        deviceChangeObserver = NotificationCenter.default.addObserver(
            forName: .audioDeviceChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let device = notification.object as? AudioDevice {
                self?.handleDeviceChange(device)
            }
        }
    }
    
    private func handleDeviceChange(_ device: AudioDevice) {
        // Auto-suggest compensation based on new device
        let recommended = getRecommendedCompensation(for: device)
        recommendedCompensation = recommended
        
        // Optionally auto-apply if user has enabled auto-compensation
        if UserDefaults.standard.bool(forKey: "autoApplyLatencyCompensation") {
            setCompensation(recommended)
        }
    }
}

// MARK: - Latency Test View

struct LatencyTestView: View {
    @Binding var currentCompensation: Double
    let onCompensationChange: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @StateObject private var latencyTestManager = LatencyTestManager.shared
    @StateObject private var latencyManager = AudioLatencyManager.shared
    @StateObject private var deviceManager = AudioDeviceManager.shared
    
    @State private var testResults: [Double] = []
    @State private var recommendedCompensation: Double = 0
    @State private var showingAutoMeasurement = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerSection
                currentDeviceSection
                testOptionsSection
                Spacer()
            }
            .padding(24)
            .navigationTitle("Latency Test")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Latency Test")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("This test will help determine the optimal latency compensation for your audio setup")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var currentDeviceSection: some View {
        if let currentDevice = deviceManager.currentDevice {
            VStack(spacing: 8) {
                HStack {
                    Text("Current Device:")
                        .font(.headline)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: currentDevice.isBluetooth ? "bluetooth" : "headphones")
                        .foregroundColor(currentDevice.isBluetooth ? .blue : .gray)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentDevice.name)
                            .font(.body)
                        Text(currentDevice.deviceType.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if currentDevice.isBluetooth {
                        Text("~\(Int(currentDevice.deviceType.expectedLatency * 1000))ms")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private var testOptionsSection: some View {
        VStack(spacing: 16) {
            if showingAutoMeasurement {
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Measuring system latency...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Button("Auto-Detect Latency") {
                    showingAutoMeasurement = true
                    autoMeasureLatency()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            
            Text("or")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if testResults.isEmpty && !latencyTestManager.isTestRunning {
                manualTestSection
            } else if latencyTestManager.isTestRunning {
                runningTestSection
            } else if !testResults.isEmpty {
                resultSection
            }
        }
    }
    
    private var manualTestSection: some View {
        VStack(spacing: 8) {
            Text("Manual Test")
                .font(.headline)
            
            Text("Tap the button below when you hear the metronome click")
                .font(.body)
                .multilineTextAlignment(.center)
            
            Button("Start Manual Test") {
                startManualTest()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
    
    private var runningTestSection: some View {
        VStack(spacing: 12) {
            Text("Listen for the click and tap when you hear it")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            ProgressView(value: latencyTestManager.testProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
            
            Button("Tap Now!") {
                recordTap()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Text("Test \(Int(latencyTestManager.testProgress * 10) + 1) of 10")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Cancel Test") {
                cancelTest()
            }
            .font(.caption)
            .foregroundColor(.red)
        }
    }
    
    private var resultSection: some View {
        VStack(spacing: 12) {
            Text("Test Complete")
                .font(.headline)
                .foregroundColor(.green)
            
            Text("Recommended compensation: \(Int(recommendedCompensation))ms")
                .font(.title3)
                .fontWeight(.semibold)
            
            Button("Apply Recommendation") {
                currentCompensation = recommendedCompensation
                onCompensationChange()
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Run Test Again") {
                resetTest()
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func autoMeasureLatency() {
        latencyManager.measureLatency { latency in
            DispatchQueue.main.async {
                self.recommendedCompensation = -latency // Negative to compensate for delay
                self.showingAutoMeasurement = false
                
                // Show result
                self.testResults = [latency] // Fake a single result to show completion UI
            }
        }
    }
    
    private func startManualTest() {
        testResults.removeAll()
        recommendedCompensation = 0
        
        latencyTestManager.startTest { result in
            DispatchQueue.main.async {
                self.testResults.append(result)
                if self.testResults.count >= 10 {
                    self.completeManualTest()
                }
            }
        }
    }
    
    private func recordTap() {
        latencyTestManager.recordTap()
    }
    
    private func completeManualTest() {
        // Calculate recommended compensation
        let averageLatency = testResults.reduce(0, +) / Double(testResults.count)
        recommendedCompensation = -averageLatency // Negative to compensate for delay
        latencyTestManager.stopTest()
    }
    
    private func cancelTest() {
        latencyTestManager.stopTest()
        testResults.removeAll()
        recommendedCompensation = 0
    }
    
    private func resetTest() {
        testResults.removeAll()
        recommendedCompensation = 0
        latencyTestManager.stopTest()
    }
}

// MARK: - Latency Test Manager

class LatencyTestManager: ObservableObject {
    static let shared = LatencyTestManager()
    
    @Published var isTestRunning = false
    @Published var testProgress: Double = 0.0
    
    private var testCallback: ((Double) -> Void)?
    private var measurementCallback: ((Double) -> Void)?
    private var testStartTime: Date?
    private var testResults: [Double] = []
    private var currentTestIndex = 0
    private let totalTestCount = 10
    
    private init() {}
    
    // MARK: - User Latency Test (Manual)
    
    func startTest(callback: @escaping (Double) -> Void) {
        testCallback = callback
        testResults.removeAll()
        currentTestIndex = 0
        isTestRunning = true
        testProgress = 0.0
        
        // Start playing metronome clicks for testing
        playTestClick()
    }
    
    func recordTap() {
        guard let startTime = testStartTime else { return }
        let latency = Date().timeIntervalSince(startTime) * 1000 // Convert to milliseconds
        
        testResults.append(latency)
        testCallback?(latency)
        
        currentTestIndex += 1
        testProgress = Double(currentTestIndex) / Double(totalTestCount)
        
        if currentTestIndex < totalTestCount {
            // Schedule next click
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.playTestClick()
            }
        } else {
            // Test complete
            completeTest()
        }
    }
    
    func stopTest() {
        isTestRunning = false
        testCallback = nil
        measurementCallback = nil
        testStartTime = nil
        testProgress = 0.0
    }
    
    // MARK: - Automatic Latency Measurement
    
    func startLatencyMeasurement(completion: @escaping (Double) -> Void) {
        measurementCallback = completion
        
        // Perform automatic latency measurement using system APIs
        measureSystemLatency()
    }
    
    // MARK: - Private Methods
    
    private func playTestClick() {
        testStartTime = Date()
        
        // Play a test click sound
        // This would integrate with the actual audio system (AudioKit/Conductor)
        // For now, we'll simulate with a system sound
        AudioServicesPlaySystemSound(1057) // Pop sound
        
        print("Test click played at: \(testStartTime!)")
    }
    
    private func completeTest() {
        isTestRunning = false
        
        // Calculate average latency
        let averageLatency = testResults.reduce(0, +) / Double(testResults.count)
        
        // Remove outliers (values more than 2 standard deviations from mean)
        let filteredResults = removeOutliers(from: testResults)
        let filteredAverage = filteredResults.reduce(0, +) / Double(filteredResults.count)
        
        print("Test completed. Average latency: \(filteredAverage)ms")
        
        // Store the result
        UserDefaults.standard.set(filteredAverage, forKey: "lastMeasuredLatency")
        
        testCallback = nil
        testStartTime = nil
    }
    
    private func measureSystemLatency() {
        let audioSession = AVAudioSession.sharedInstance()
        
        // Get system-reported latency values
        let inputLatency = audioSession.inputLatency * 1000 // Convert to milliseconds
        let outputLatency = audioSession.outputLatency * 1000
        let ioBufferDuration = audioSession.ioBufferDuration * 1000
        
        let totalSystemLatency = inputLatency + outputLatency + ioBufferDuration
        
        // Add estimated processing latency based on current device
        var deviceLatency: Double = 0.0
        if let currentDevice = AudioDeviceManager.shared.getCurrentDevice() {
            deviceLatency = currentDevice.deviceType.expectedLatency * 1000
        }
        
        let totalLatency = totalSystemLatency + deviceLatency
        
        print("Measured system latency: \(totalLatency)ms")
        print("  - Input latency: \(inputLatency)ms")
        print("  - Output latency: \(outputLatency)ms")
        print("  - Buffer duration: \(ioBufferDuration)ms")
        print("  - Device latency: \(deviceLatency)ms")
        
        measurementCallback?(totalLatency)
        measurementCallback = nil
    }
    
    private func removeOutliers(from values: [Double]) -> [Double] {
        guard values.count > 2 else { return values }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let standardDeviation = sqrt(variance)
        
        return values.filter { abs($0 - mean) <= 2 * standardDeviation }
    }
}

// MARK: - Data Export View

struct DataExportView: View {
    @State private var exportFormat: ExportFormat = .json
    @State private var includePersonalData = false
    @State private var showingExportSheet = false
    
    var body: some View {
        Form {
            Section("Export Format") {
                Picker("Format", selection: $exportFormat) {
                    Text("JSON").tag(ExportFormat.json)
                    Text("CSV").tag(ExportFormat.csv)
                    Text("PDF Report").tag(ExportFormat.pdf)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section("Data Options") {
                Toggle("Include Personal Information", isOn: $includePersonalData)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export includes:")
                    Text("• Practice sessions and scores")
                    Text("• Progress statistics")
                    Text("• Achievement history")
                    if includePersonalData {
                        Text("• User preferences and settings")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Section {
                Button("Export Data") {
                    showingExportSheet = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExportSheet) {
            // Export activity view would go here
            Text("Export functionality would be implemented here")
        }
    }
}

enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"
    case pdf = "PDF"
}

// MARK: - Acknowledgments View

struct AcknowledgmentsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("This app was built using the following open source libraries and resources:")
                    .font(.body)
                
                AcknowledgmentItem(
                    name: "AudioKit",
                    description: "Audio synthesis, processing, and analysis platform",
                    url: "https://audiokit.io"
                )
                
                AcknowledgmentItem(
                    name: "Swift Testing",
                    description: "Property-based testing framework for Swift",
                    url: "https://swift.org/testing"
                )
                
                Text("Special thanks to the drum education community for inspiration and feedback.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Acknowledgments")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AcknowledgmentItem: View {
    let name: String
    let description: String
    let url: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline)
                .foregroundColor(Color("textColor1"))
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
            
            Link(url, destination: URL(string: url)!)
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Notification Extensions


// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}