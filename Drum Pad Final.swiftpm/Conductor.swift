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
    case rimshot = "rimshot"
    case clap = "clap"
    case hihat = "hihat"
    case shaker = "shaker"
    case triangle = "triangle"
    case bell = "bell"
    case vintage = "vintage"
    case modern = "modern"
    case soft = "soft"
    case sharp = "sharp"
    
    var displayName: String {
        switch self {
        case .click: return "Click"
        case .beep: return "Beep"
        case .tick: return "Tick"
        case .wood: return "Wood"
        case .digital: return "Digital"
        case .cowbell: return "Cowbell"
        case .rimshot: return "Rimshot"
        case .clap: return "Clap"
        case .hihat: return "Hi-Hat"
        case .shaker: return "Shaker"
        case .triangle: return "Triangle"
        case .bell: return "Bell"
        case .vintage: return "Vintage"
        case .modern: return "Modern"
        case .soft: return "Soft"
        case .sharp: return "Sharp"
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
    
    // Error Handling
    @Published var errorPresenter: ErrorPresenter?
    
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
            errorPresenter?.presentError(.audioEngineFailure(underlying: error))
            return
        }
        do {
            let files = drumSamples.compactMap { $0.audioFile }
            try drums.loadAudioFiles(files)
        } catch {
            Log("Could not load audio files \(error)")
            errorPresenter?.presentError(.audioEngineFailure(underlying: error))
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
                self.errorPresenter?.presentError(.midiConnectionFailure(deviceName: "Unknown", underlying: nil))
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
                self.errorPresenter?.presentError(.midiConnectionFailure(deviceName: "Input Port", underlying: nil))
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
                    self.errorPresenter?.presentError(.midiConnectionFailure(deviceName: device.name, underlying: nil))
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
            
            // Check for high latency and warn user
            if estimatedLatency > 0.050 { // 50ms threshold
                self.errorPresenter?.presentError(.audioLatencyTooHigh(latency: estimatedLatency))
            }
        }
    }
    
    // MARK: - Error Handling Setup
    
    func setErrorPresenter(_ presenter: ErrorPresenter) {
        self.errorPresenter = presenter
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
            errorPresenter?.presentError(.audioEngineFailure(underlying: error))
        }
    }
    
    private func createSyntheticMetronomeSound(for sound: MetronomeSound) -> AKAudioFile? {
        // Create a simple synthetic metronome sound if audio files don't exist
        // This is a fallback - in production, you'd have actual audio files
        
        let sampleRate = 44100.0
        let duration: Double = {
            switch sound {
            case .soft, .vintage: return 0.15 // Longer, softer sounds
            case .sharp, .digital: return 0.05 // Short, sharp sounds
            default: return 0.1 // Standard duration
            }
        }()
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return nil
        }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        // Generate enhanced metronome sounds with more variety
        let (frequency, waveform, envelope) = getMetronomeSoundParameters(for: sound)
        
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        
        for i in 0..<Int(frameCount) {
            let time = Float(i) / Float(sampleRate)
            let normalizedTime = time / Float(duration)
            
            // Apply envelope
            let amplitude = envelope(normalizedTime)
            
            // Generate waveform
            let sample = waveform(frequency, time) * amplitude
            
            channelData[i] = sample
        }
        
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(sound.fileName).wav")
        
        do {
            let audioFile = try AVAudioFile(forWriting: tempURL, settings: format.settings)
            try audioFile.write(from: buffer)
            return try AKAudioFile(forReading: tempURL)
        } catch {
            Log("Could not create synthetic metronome sound: \(error)")
            // Don't present error for synthetic sound creation failure - it's a fallback
            return nil
        }
    }
    
    private func getMetronomeSoundParameters(for sound: MetronomeSound) -> (Float, (Float, Float) -> Float, (Float) -> Float) {
        switch sound {
        case .click:
            return (1000.0, { freq, time in sin(2.0 * .pi * freq * time) }, { t in exp(-t * 10.0) })
        case .beep:
            return (800.0, { freq, time in sin(2.0 * .pi * freq * time) }, { t in exp(-t * 8.0) })
        case .tick:
            return (1200.0, { freq, time in sin(2.0 * .pi * freq * time) }, { t in exp(-t * 15.0) })
        case .wood:
            return (600.0, { freq, time in 
                let fundamental = sin(2.0 * .pi * freq * time)
                let harmonic = 0.3 * sin(2.0 * .pi * freq * 2.0 * time)
                return fundamental + harmonic
            }, { t in exp(-t * 12.0) })
        case .digital:
            return (1500.0, { freq, time in 
                sin(2.0 * .pi * freq * time) > 0 ? 0.8 : -0.8 // Square wave
            }, { t in exp(-t * 20.0) })
        case .cowbell:
            return (900.0, { freq, time in 
                let f1 = sin(2.0 * .pi * freq * time)
                let f2 = 0.5 * sin(2.0 * .pi * freq * 1.5 * time)
                return f1 + f2
            }, { t in exp(-t * 6.0) })
        case .rimshot:
            return (2000.0, { freq, time in 
                let noise = Float.random(in: -0.3...0.3)
                let tone = 0.7 * sin(2.0 * .pi * freq * time)
                return tone + noise
            }, { t in exp(-t * 25.0) })
        case .clap:
            return (1800.0, { _, _ in Float.random(in: -1.0...1.0) }, { t in 
                t < 0.1 ? 1.0 : exp(-(t - 0.1) * 30.0)
            })
        case .hihat:
            return (8000.0, { _, _ in Float.random(in: -0.8...0.8) }, { t in exp(-t * 40.0) })
        case .shaker:
            return (6000.0, { _, _ in Float.random(in: -0.6...0.6) }, { t in 
                let envelope = exp(-t * 8.0)
                let tremolo = 1.0 + 0.3 * sin(2.0 * .pi * 20.0 * t)
                return envelope * tremolo
            })
        case .triangle:
            return (1100.0, { freq, time in 
                let phase = fmod(freq * time, 1.0)
                return phase < 0.5 ? (4.0 * phase - 1.0) : (3.0 - 4.0 * phase)
            }, { t in exp(-t * 5.0) })
        case .bell:
            return (1400.0, { freq, time in 
                let f1 = sin(2.0 * .pi * freq * time)
                let f2 = 0.4 * sin(2.0 * .pi * freq * 2.76 * time)
                let f3 = 0.2 * sin(2.0 * .pi * freq * 5.4 * time)
                return f1 + f2 + f3
            }, { t in exp(-t * 3.0) })
        case .vintage:
            return (700.0, { freq, time in 
                let fundamental = sin(2.0 * .pi * freq * time)
                let warmth = 0.2 * sin(2.0 * .pi * freq * 0.5 * time)
                return fundamental + warmth
            }, { t in exp(-t * 4.0) })
        case .modern:
            return (1300.0, { freq, time in 
                let clean = sin(2.0 * .pi * freq * time)
                let bright = 0.3 * sin(2.0 * .pi * freq * 3.0 * time)
                return clean + bright
            }, { t in exp(-t * 18.0) })
        case .soft:
            return (500.0, { freq, time in 
                sin(2.0 * .pi * freq * time) * (1.0 - 0.3 * sin(2.0 * .pi * 5.0 * time))
            }, { t in exp(-t * 3.0) })
        case .sharp:
            return (2500.0, { freq, time in 
                let sharp = sin(2.0 * .pi * freq * time)
                let attack = sin(2.0 * .pi * freq * 4.0 * time) * exp(-time * 50.0)
                return sharp + 0.5 * attack
            }, { t in exp(-t * 30.0) })
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

