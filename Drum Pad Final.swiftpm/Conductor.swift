import AudioKit
import AVFoundation
import Combine
import CoreMIDI

// MARK: - Metronome Support Structures

enum MetronomeSound: String, CaseIterable {
    case click = "click"
    case beep = "beep"
    case tick = "tick"
    case wood = "wood"
    case digital = "digital"
    case cowbell = "cowbell"
    
    var displayName: String {
        switch self {
        case .click: return "Click"
        case .beep: return "Beep"
        case .tick: return "Tick"
        case .wood: return "Wood"
        case .digital: return "Digital"
        case .cowbell: return "Cowbell"
        }
    }
    
    var fileName: String {
        return "metronome_\(rawValue)"
    }
}

enum MetronomeSubdivision: String, CaseIterable {
    case quarter = "1/4"
    case eighth = "1/8"
    case sixteenth = "1/16"
    
    var displayName: String {
        return rawValue
    }
    
    var multiplier: Double {
        switch self {
        case .quarter: return 1.0
        case .eighth: return 2.0
        case .sixteenth: return 4.0
        }
    }
}

struct CountInSettings {
    var isEnabled: Bool = true
    var measures: Int = 1
    var isIndependentOfMetronome: Bool = true
    
    static func defaultSettings() -> CountInSettings {
        return CountInSettings()
    }
}

// MARK: - MIDI Support Structures

enum MIDIConnectionStatus: String, CaseIterable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error: return "Connection Error"
        }
    }
}

struct MIDIDeviceInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let manufacturer: String
    let deviceRef: MIDIDeviceRef
    let connectionType: MIDIConnectionType
    let isOnline: Bool
    
    static func == (lhs: MIDIDeviceInfo, rhs: MIDIDeviceInfo) -> Bool {
        return lhs.deviceRef == rhs.deviceRef
    }
}

enum MIDIConnectionType: String, CaseIterable {
    case usb = "usb"
    case bluetooth = "bluetooth"
    case network = "network"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .usb: return "USB"
        case .bluetooth: return "Bluetooth"
        case .network: return "Network"
        case .unknown: return "Unknown"
        }
    }
}

struct MIDIMapping: Codable {
    var drumPadMappings: [String: Int] // drum pad name -> MIDI note number
    var velocityCurve: VelocityCurve
    var isComplete: Bool {
        return drumPadMappings.count >= 8 // Assuming 8 drum pads minimum
    }
    
    static func defaultMapping() -> MIDIMapping {
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

enum VelocityCurve: String, CaseIterable, Codable {
    case linear = "linear"
    case logarithmic = "logarithmic"
    case exponential = "exponential"
    
    var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .logarithmic: return "Logarithmic"
        case .exponential: return "Exponential"
        }
    }
    
    func transform(_ velocity: Float) -> Float {
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

class Conductor: ObservableObject {
    let engine = AudioEngine()
    let drums = AppleSampler()
    let metronome = AppleSampler()
    let delay: Delay
    let reverb: Reverb
    let mixer = Mixer()
    let metronomeMixer = Mixer()
    
    // MIDI Input Management
    private var midiClient: MIDIClientRef = 0
    private var midiInputPort: MIDIPortRef = 0
    private var connectedDevices: [MIDIDeviceInfo] = []
    
    // Real-time Scoring Engine
    let scoreEngine = ScoreEngine()
    
    // Metronome Management
    private var metronomeTimer: Timer?
    private var countInTimer: Timer?
    private var currentBeat: Int = 0
    private var isCountingIn: Bool = false
    
    @Published var midiConnectionStatus: MIDIConnectionStatus = .disconnected
    @Published var currentMidiMapping: MIDIMapping = MIDIMapping.defaultMapping()
    @Published var detectedDevices: [MIDIDeviceInfo] = []
    @Published var audioLatency: TimeInterval = 0.0
    
    // Metronome Properties
    @Published var isMetronomeEnabled: Bool = false {
        didSet {
            if isMetronomeEnabled {
                startMetronome()
            } else {
                stopMetronome()
            }
        }
    }
    @Published var metronomeSound: MetronomeSound = .click {
        didSet {
            loadMetronomeSounds()
        }
    }
    @Published var metronomeSubdivision: MetronomeSubdivision = .quarter
    @Published var metronomeVolume: Float = 80 {
        didSet {
            metronomeMixer.volume = metronomeVolume / 100.0
        }
    }
    @Published var countInSettings: CountInSettings = CountInSettings.defaultSettings()
    
    let drumSamples: [DrumSample] = 
    [
        DrumSample("HI TOM", file: "hi_tom_D2", note: 38),
        DrumSample("CRASH", file: "crash_F1", note: 29),
        DrumSample("HI HAT", file: "closed_hi_hat_F#1", note: 30),
        DrumSample("OPEN HI HAT", file: "open_hi_hat_A#1", note: 34),
        DrumSample("LO TOM", file: "mid_tom_B1", note: 35),
        DrumSample("CLAP", file: "clap_D#1", note: 27),
        DrumSample("KICK", file: "bass_drum_C1", note: 24),
        DrumSample("SNARE", file: "snare_D1", note: 26),
    ]
    
    var drumPadTouchCounts: [Int] = [] {
        willSet {
            for index in 0..<drumPadTouchCounts.count {
                if newValue[index] > drumPadTouchCounts[index] {
                    playPad(padNumber: index)
                }
            }
        }
    }
    
    @Published var mixerVolume: Float = 80 {
        didSet {
            mixer.volume = mixerVolume / 100.0
        }
    }
    
    @Published var reverbMix: Float = 5 {
        didSet {
            reverb.dryWetMix = reverbMix / 100.0
        }
    }
    
    @Published var reverbPreset: AVAudioUnitReverbPreset = .smallRoom {
        didSet {
            reverb.loadFactoryPreset(reverbPreset)
        }
    }
    
    @Published var delayMix: Float = 20 {
        didSet {
            delay.dryWetMix = delayMix
        }
    }
    
    @Published var delayFeedback: Float = 10 {
        didSet {
            delay.feedback = delayFeedback
        }
    }
    
    @Published var tempo: Float = 120.0 {
        didSet { 
            updateDelayTime()
            updateMetronomeForTempo()
        }
    }
    
    @Published var delayDuration: MusicalDuration = .eighth {
        didSet { updateDelayTime() }
    }
    
    @Published var isDelayTimeMaxed: Bool = false
    
    func updateDelayTime() {
        let time = (60.0 / tempo) * Float(delayDuration.multiplier) * 4.0
        isDelayTimeMaxed = time > 2.0
        delay.time = time
    }
    
    init() {
        delay = Delay(drums)
        reverb = Reverb(delay)
        
        // Setup audio routing: drums -> delay -> reverb -> mixer
        mixer.addInput(reverb)
        
        // Setup metronome routing: metronome -> metronomeMixer -> mixer
        metronomeMixer.addInput(metronome)
        mixer.addInput(metronomeMixer)
        
        engine.output = mixer
        
        drumPadTouchCounts = Array(repeating: 0, count: drumSamples.count)
        
        // initialize effects
        reverb.dryWetMix = reverbMix / 100.0
        delay.dryWetMix = delayMix
        delay.feedback = delayFeedback
        metronomeMixer.volume = metronomeVolume / 100.0
        
        // Initialize MIDI
        setupMIDIClient()
        scanForMIDIDevices()
    }
    
    func start() {
        do {
            try engine.start() 
        } catch {
            Log("AudioKit did not start! \(error)")
        }
        do {
            let files = drumSamples.compactMap { $0.audioFile }
            try drums.loadAudioFiles(files)
        } catch {
            Log("Could not load audio files \(error)")
        }
        
        // Load metronome sounds
        loadMetronomeSounds()
        
        // Load saved MIDI mapping
        loadSavedMIDIMapping()
        
        // Measure audio latency
        measureAudioLatency()
    }
    
    func playPad(padNumber: Int, velocity: Float = 1.0) {
        if !engine.avEngine.isRunning {
            start()
        }
        drums.play(noteNumber: MIDINoteNumber(drumSamples[padNumber].midiNote),
                   velocity: MIDIVelocity(velocity * 127.0))
    }
    
    // MARK: - MIDI Input Management
    
    private func setupMIDIClient() {
        let clientName = "DrumTrainerMIDIClient" as CFString
        let status = MIDIClientCreate(clientName, { (notification, refCon) in
            // Handle MIDI system notifications
            guard let conductor = Unmanaged<Conductor>.fromOpaque(refCon!).takeUnretainedValue() as Conductor? else { return }
            conductor.handleMIDINotification(notification.pointee)
        }, Unmanaged.passUnretained(self).toOpaque(), &midiClient)
        
        if status != noErr {
            print("Error creating MIDI client: \(status)")
            DispatchQueue.main.async {
                self.midiConnectionStatus = .error
            }
            return
        }
        
        // Create input port
        let portName = "DrumTrainerInputPort" as CFString
        let inputStatus = MIDIInputPortCreate(midiClient, portName, { (packetList, readProcRefCon, srcConnRefCon) in
            guard let conductor = Unmanaged<Conductor>.fromOpaque(readProcRefCon!).takeUnretainedValue() as Conductor? else { return }
            conductor.handleMIDIPacketList(packetList.pointee)
        }, Unmanaged.passUnretained(self).toOpaque(), &midiInputPort)
        
        if inputStatus != noErr {
            print("Error creating MIDI input port: \(inputStatus)")
            DispatchQueue.main.async {
                self.midiConnectionStatus = .error
            }
        }
    }
    
    private func handleMIDINotification(_ notification: MIDINotification) {
        switch notification.messageID {
        case .msgObjectAdded, .msgObjectRemoved:
            DispatchQueue.main.async {
                self.scanForMIDIDevices()
            }
        case .msgPropertyChanged:
            DispatchQueue.main.async {
                self.updateDeviceConnectionStatus()
            }
        default:
            break
        }
    }
    
    private func handleMIDIPacketList(_ packetList: MIDIPacketList) {
        let packets = packetList.packets
        var packet = packets
        
        for _ in 0..<packetList.numPackets {
            let data = withUnsafePointer(to: &packet.data) {
                $0.withMemoryRebound(to: UInt8.self, capacity: Int(packet.length)) {
                    Array(UnsafeBufferPointer(start: $0, count: Int(packet.length)))
                }
            }
            
            processMIDIData(data, timestamp: packet.timeStamp)
            packet = MIDIPacketNext(&packet).pointee
        }
    }
    
    private func processMIDIData(_ data: [UInt8], timestamp: MIDITimeStamp) {
        guard data.count >= 3 else { return }
        
        let status = data[0]
        let noteNumber = data[1]
        let velocity = data[2]
        
        // Check if it's a note on message (0x90-0x9F)
        if (status & 0xF0) == 0x90 && velocity > 0 {
            DispatchQueue.main.async {
                self.handleMIDINoteOn(noteNumber: noteNumber, velocity: velocity)
            }
        }
    }
    
    private func handleMIDINoteOn(noteNumber: UInt8, velocity: UInt8) {
        // Create MIDI event for scoring
        let midiEvent = MIDIEvent(
            timestamp: CACurrentMediaTime(),
            noteNumber: Int(noteNumber),
            velocity: Int(velocity),
            channel: 0
        )
        
        // Process for scoring if scoring is active
        if scoreEngine.isScoring {
            scoreEngine.processUserInput(midiEvent, at: midiEvent.timestamp)
        }
        
        // Find matching drum pad based on MIDI mapping
        for (drumName, mappedNote) in currentMidiMapping.drumPadMappings {
            if mappedNote == Int(noteNumber) {
                if let padIndex = drumSamples.firstIndex(where: { $0.name == drumName }) {
                    let normalizedVelocity = currentMidiMapping.velocityCurve.transform(Float(velocity) / 127.0)
                    playPad(padNumber: padIndex, velocity: normalizedVelocity)
                }
                break
            }
        }
    }
    
    func scanForMIDIDevices() {
        var devices: [MIDIDeviceInfo] = []
        let deviceCount = MIDIGetNumberOfDevices()
        
        for i in 0..<deviceCount {
            let device = MIDIGetDevice(i)
            if let deviceInfo = createDeviceInfo(from: device) {
                devices.append(deviceInfo)
            }
        }
        
        DispatchQueue.main.async {
            self.detectedDevices = devices
            self.updateConnectionStatus()
        }
    }
    
    private func createDeviceInfo(from deviceRef: MIDIDeviceRef) -> MIDIDeviceInfo? {
        var name: Unmanaged<CFString>?
        var manufacturer: Unmanaged<CFString>?
        var isOnline: Int32 = 0
        
        // Get device name
        MIDIObjectGetStringProperty(deviceRef, kMIDIPropertyName, &name)
        let deviceName = name?.takeRetainedValue() as String? ?? "Unknown Device"
        
        // Get manufacturer
        MIDIObjectGetStringProperty(deviceRef, kMIDIPropertyManufacturer, &manufacturer)
        let deviceManufacturer = manufacturer?.takeRetainedValue() as String? ?? "Unknown"
        
        // Check if device is online
        MIDIObjectGetIntegerProperty(deviceRef, kMIDIPropertyOffline, &isOnline)
        
        // Determine connection type (simplified)
        let connectionType: MIDIConnectionType = deviceName.lowercased().contains("bluetooth") ? .bluetooth : .usb
        
        return MIDIDeviceInfo(
            name: deviceName,
            manufacturer: deviceManufacturer,
            deviceRef: deviceRef,
            connectionType: connectionType,
            isOnline: isOnline == 0
        )
    }
    
    func connectToDevice(_ device: MIDIDeviceInfo) {
        midiConnectionStatus = .connecting
        
        // Get all sources from the device
        let sourceCount = MIDIDeviceGetNumberOfSources(device.deviceRef)
        
        for i in 0..<sourceCount {
            let source = MIDIDeviceGetSource(device.deviceRef, i)
            let status = MIDIPortConnectSource(midiInputPort, source, nil)
            
            if status == noErr {
                DispatchQueue.main.async {
                    self.midiConnectionStatus = .connected
                    if !self.connectedDevices.contains(device) {
                        self.connectedDevices.append(device)
                    }
                }
            } else {
                print("Failed to connect to MIDI source: \(status)")
                DispatchQueue.main.async {
                    self.midiConnectionStatus = .error
                }
            }
        }
    }
    
    func disconnectFromDevice(_ device: MIDIDeviceInfo) {
        let sourceCount = MIDIDeviceGetNumberOfSources(device.deviceRef)
        
        for i in 0..<sourceCount {
            let source = MIDIDeviceGetSource(device.deviceRef, i)
            MIDIPortDisconnectSource(midiInputPort, source)
        }
        
        DispatchQueue.main.async {
            self.connectedDevices.removeAll { $0 == device }
            self.updateConnectionStatus()
        }
    }
    
    private func updateConnectionStatus() {
        if connectedDevices.isEmpty {
            midiConnectionStatus = .disconnected
        } else {
            midiConnectionStatus = .connected
        }
    }
    
    private func updateDeviceConnectionStatus() {
        // Refresh device list to update online status
        scanForMIDIDevices()
    }
    
    func updateMIDIMapping(_ mapping: MIDIMapping) {
        currentMidiMapping = mapping
        // Save to UserDefaults for persistence
        if let encoded = try? JSONEncoder().encode(mapping) {
            UserDefaults.standard.set(encoded, forKey: "MIDIMapping")
        }
    }
    
    func loadSavedMIDIMapping() {
        if let data = UserDefaults.standard.data(forKey: "MIDIMapping"),
           let mapping = try? JSONDecoder().decode(MIDIMapping.self, from: data) {
            currentMidiMapping = mapping
        }
    }
    
    func validateMIDIMapping() -> Bool {
        return currentMidiMapping.isComplete
    }
    
    private func measureAudioLatency() {
        // Get the audio session's I/O buffer duration and sample rate
        let audioSession = AVAudioSession.sharedInstance()
        let bufferDuration = audioSession.ioBufferDuration
        let sampleRate = audioSession.sampleRate
        
        // Calculate estimated latency (simplified calculation)
        let estimatedLatency = bufferDuration + (1024.0 / sampleRate) // Add processing buffer estimate
        
        DispatchQueue.main.async {
            self.audioLatency = estimatedLatency
        }
    }
    
    // MARK: - Scoring Session Management
    
    func startScoringSession(targetEvents: [TargetEvent], profile: ScoringProfile = ScoringProfile.defaultProfile()) {
        scoreEngine.setTargetEvents(targetEvents)
        scoreEngine.setScoringProfile(profile)
        scoreEngine.startScoring()
    }
    
    func stopScoringSession() -> ScoreResult {
        scoreEngine.stopScoring()
        return scoreEngine.calculateScore()
    }
    
    func getCurrentScore() -> Float {
        return scoreEngine.currentScore
    }
    
    func getCurrentStreak() -> Int {
        return scoreEngine.currentStreak
    }
    
    func getRealtimeFeedback() -> TimingFeedback? {
        return scoreEngine.realtimeFeedback
    }
    
    func resetScoring() {
        scoreEngine.resetScore()
    }
    
    // MARK: - Metronome Management
    
    private func loadMetronomeSounds() {
        // Create metronome audio files for each sound type
        let metronomeFiles = MetronomeSound.allCases.compactMap { sound -> AKAudioFile? in
            guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: "wav") else {
                // If specific metronome files don't exist, create synthetic sounds
                return createSyntheticMetronomeSound(for: sound)
            }
            return try? AKAudioFile(forReading: url)
        }
        
        do {
            try metronome.loadAudioFiles(metronomeFiles)
        } catch {
            Log("Could not load metronome audio files: \(error)")
        }
    }
    
    private func createSyntheticMetronomeSound(for sound: MetronomeSound) -> AKAudioFile? {
        // Create a simple synthetic metronome sound if audio files don't exist
        // This is a fallback - in production, you'd have actual audio files
        
        let sampleRate = 44100.0
        let duration = 0.1 // 100ms click
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return nil
        }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        // Generate a simple click sound based on the sound type
        let frequency: Float = {
            switch sound {
            case .click: return 1000.0
            case .beep: return 800.0
            case .tick: return 1200.0
            case .wood: return 600.0
            case .digital: return 1500.0
            case .cowbell: return 900.0
            }
        }()
        
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        
        for i in 0..<Int(frameCount) {
            let time = Float(i) / Float(sampleRate)
            let amplitude = exp(-time * 10.0) // Exponential decay
            channelData[i] = amplitude * sin(2.0 * .pi * frequency * time)
        }
        
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sound.fileName).wav")
        
        do {
            let audioFile = try AVAudioFile(forWriting: tempURL, settings: format.settings)
            try audioFile.write(from: buffer)
            return try AKAudioFile(forReading: tempURL)
        } catch {
            Log("Could not create synthetic metronome sound: \(error)")
            return nil
        }
    }
    
    private func startMetronome() {
        stopMetronome() // Stop any existing metronome
        
        let interval = 60.0 / Double(tempo) / metronomeSubdivision.multiplier
        
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.playMetronomeClick()
        }
    }
    
    private func stopMetronome() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
        currentBeat = 0
    }
    
    private func playMetronomeClick() {
        guard !engine.avEngine.isRunning || isMetronomeEnabled else { return }
        
        // Play the metronome sound
        let noteNumber: MIDINoteNumber = 60 // Middle C for metronome
        let velocity: MIDIVelocity = MIDIVelocity(metronomeVolume * 127.0 / 100.0)
        
        metronome.play(noteNumber: noteNumber, velocity: velocity)
        currentBeat += 1
    }
    
    func startCountIn(completion: @escaping () -> Void) {
        guard countInSettings.isEnabled else {
            completion()
            return
        }
        
        isCountingIn = true
        currentBeat = 0
        let totalBeats = countInSettings.measures * 4 // Assuming 4/4 time
        let interval = 60.0 / Double(tempo)
        
        countInTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.currentBeat += 1
            
            // Play count-in click (always plays regardless of metronome setting)
            if self.countInSettings.isIndependentOfMetronome || self.isMetronomeEnabled {
                let noteNumber: MIDINoteNumber = 60
                let velocity: MIDIVelocity = MIDIVelocity(self.metronomeVolume * 127.0 / 100.0)
                self.metronome.play(noteNumber: noteNumber, velocity: velocity)
            }
            
            if self.currentBeat >= totalBeats {
                timer.invalidate()
                self.countInTimer = nil
                self.isCountingIn = false
                self.currentBeat = 0
                completion()
            }
        }
    }
    
    func stopCountIn() {
        countInTimer?.invalidate()
        countInTimer = nil
        isCountingIn = false
        currentBeat = 0
    }
    
    func updateMetronomeForTempo() {
        if isMetronomeEnabled {
            startMetronome() // Restart with new tempo
        }
    }
    
    // MARK: - Metronome Configuration
    
    func setMetronomeSound(_ sound: MetronomeSound) {
        metronomeSound = sound
        // Sound loading is handled by the didSet observer
    }
    
    func setMetronomeSubdivision(_ subdivision: MetronomeSubdivision) {
        metronomeSubdivision = subdivision
        if isMetronomeEnabled {
            startMetronome() // Restart with new subdivision
        }
    }
    
    func setMetronomeVolume(_ volume: Float) {
        metronomeVolume = max(0, min(100, volume))
        // Volume setting is handled by the didSet observer
    }
    
    func setCountInSettings(_ settings: CountInSettings) {
        countInSettings = settings
    }
    
    func toggleMetronome() {
        isMetronomeEnabled.toggle()
    }
    
    deinit {
        // Clean up metronome timers
        stopMetronome()
        stopCountIn()
        
        // Clean up MIDI resources
        if midiInputPort != 0 {
            MIDIPortDispose(midiInputPort)
        }
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
        }
    }
}

