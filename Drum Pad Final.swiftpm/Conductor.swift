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

// AudioKit 5.x 未提供 MusicalDuration，这里自定义基础节拍时值
enum MusicalDuration: Double, CaseIterable {
    case whole = 1.0
    case half = 0.5
    case quarter = 0.25
    case eighth = 0.125
    case sixteenth = 0.0625
    case thirtysecond = 0.03125
    
    /// 返回用于节拍/延时计算的倍数（直接使用 rawValue）
    var multiplier: Double { rawValue }
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
    let drums = AppleSampler()  // 保留用于兼容，但不再使用
    let metronome = AppleSampler()
    let delay: Delay
    let reverb: Reverb
    let mixer = Mixer()
    let metronomeMixer = Mixer()
    
    // 使用独立的 AudioPlayer 数组替代 AppleSampler 的多样本映射
    // 这是因为 AppleSampler.loadAudioFiles() 的 MIDI 映射机制有问题
    private var drumPlayers: [AudioPlayer] = []
    private let drumPlayersMixer = Mixer()
    
    // MIDI Input Management
    private var midiClient: MIDIClientRef = 0
    private var midiInputPort: MIDIPortRef = 0
    private var connectedDevices: [MIDIDeviceInfo] = []
    var connectedDevicesCount: Int { connectedDevices.count }
    
    // Real-time Scoring Engine
    let scoreEngine = ScoreEngine()
    
    // Error Handling
    @Published var errorPresenter: ErrorPresenter?
    
    // MARK: - Per-Pad Configuration Support
    
    /// Pad配置管理器（引用单例）
    private let configManager = PadConfigurationManager.shared
    
    /// 当前pad配置数组（16个）
    @Published var padConfigurations: [PadConfiguration] = []
    
    /// 上一次播放的pad ID（用于效果器参数缓存优化）
    private var lastPlayedPadId: Int = -1
    
    // Metronome Management
    private var metronomeTimer: Timer?
    private var countInTimer: Timer?
    private var currentBeat: Int = 0
    private var isCountingIn: Bool = false
    
    @Published var midiConnectionStatus: MIDIConnectionStatus = .disconnected
    @Published var currentMidiMapping: MIDIMapping = MIDIMapping.defaultMapping()
    @Published var detectedDevices: [MIDIDeviceInfo] = []
    @Published var audioLatency: TimeInterval = 0.0
    
    // MARK: - 实时音频能量分析（用于波形可视化）
    @Published var audioEnergy: Float = 0.0
    @Published var audioPeakLevel: Float = 0.0
    var audioTapInstalled: Bool = false
    
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
    
    // 鼓样本配置 - 支持 4x4 打击垫布局
    // 包含所有基础鼓声音，每个样本对应一个唯一的 MIDI 音符
    let drumSamples: [DrumSample] = 
    [
        DrumSample("KICK", file: "bass_drum_C1", note: 36),        // C2 - 底鼓
        DrumSample("SNARE", file: "snare_D1", note: 38),           // D2 - 军鼓
        DrumSample("HI HAT", file: "closed_hi_hat_F#1", note: 42), // F#2 - 闭合踩镲
        DrumSample("OPEN HI HAT", file: "open_hi_hat_A#1", note: 46), // A#2 - 开放踩镲
        DrumSample("CRASH", file: "crash_F1", note: 49),           // C#3 - Crash 镲
        DrumSample("HI TOM", file: "hi_tom_D2", note: 50),         // D3 - 高音通鼓
        DrumSample("MID TOM", file: "mid_tom_B1", note: 47),       // B2 - 中音通鼓
        DrumSample("LO TOM", file: "lo_tom_F1", note: 43),         // G2 - 低音通鼓
        DrumSample("CLAP", file: "clap_D#1", note: 39),            // D#2 - 拍手
    ]
    
    var drumPadTouchCounts: [Int] = [] {
        didSet {
            let count = min(drumPadTouchCounts.count, oldValue.count)
            guard count > 0 else { return }
            for index in 0..<count {
                if drumPadTouchCounts[index] > oldValue[index] {
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
        // 使用 drumPlayersMixer 作为信号源（替代有问题的 AppleSampler）
        delay = Delay(drumPlayersMixer)
        reverb = Reverb(delay)
        
        // Setup audio routing: drumPlayersMixer -> delay -> reverb -> mixer
        mixer.addInput(reverb)
        
        // Setup metronome routing: metronome -> metronomeMixer -> mixer
        metronomeMixer.addInput(metronome)
        mixer.addInput(metronomeMixer)
        
        engine.output = mixer
        
        drumPadTouchCounts = Array(repeating: 0, count: drumSamples.count)
        
        // 初始化 AudioPlayer 数组
        initializeDrumPlayers()
        
        // initialize effects
        reverb.dryWetMix = reverbMix / 100.0
        delay.dryWetMix = delayMix
        delay.feedback = delayFeedback
        metronomeMixer.volume = metronomeVolume / 100.0
        
        // Initialize pad configurations from manager
        padConfigurations = configManager.getCurrentConfiguration()
        
        // 如果配置为空，初始化为默认配置
        if padConfigurations.isEmpty {
            padConfigurations = (0..<16).map { PadConfiguration.defaultConfiguration(for: $0) }
            configManager.currentConfigurations = padConfigurations
        }
        
        // 监听配置更新通知
        NotificationCenter.default.addObserver(
            forName: .padConfigurationUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let config = notification.object as? PadConfiguration {
                self?.updatePadConfiguration(config)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .padPresetApplied,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let preset = notification.object as? DrumPadPreset {
                self?.applyPreset(preset)
            }
        }
        
        // Initialize MIDI
        setupMIDIClient()
        scanForMIDIDevices()
    }
    
    /// 初始化独立的 AudioPlayer 数组（替代 AppleSampler 的多样本机制）
    private func initializeDrumPlayers() {
        print("🎵 Conductor: 初始化 AudioPlayer 数组...")
        
        for (index, sample) in drumSamples.enumerated() {
            if let audioFile = sample.audioFile {
                do {
                    let player = AudioPlayer(file: audioFile)
                    player?.isLooping = false
                    drumPlayers.append(player ?? AudioPlayer())
                    drumPlayersMixer.addInput(player ?? AudioPlayer())
                    print("✅ Conductor: 加载 AudioPlayer[\(index)] - \(sample.name)")
                } catch {
                    print("❌ Conductor: 无法创建 AudioPlayer[\(index)] - \(sample.name): \(error)")
                    // 添加一个空的 player 保持索引一致
                    drumPlayers.append(AudioPlayer())
                }
            } else {
                print("⚠️ Conductor: 样本 \(sample.name) 没有音频文件")
                drumPlayers.append(AudioPlayer())
            }
        }
        
        print("✅ Conductor: AudioPlayer 数组初始化完成，共 \(drumPlayers.count) 个")
    }
    
    // 标记是否已经初始化，防止重复初始化
    private var isInitialized = false
    
    func start() {
        // 防止重复初始化
        guard !isInitialized else {
            print("ℹ️ Conductor.start(): 已初始化，跳过重复调用")
            
            // 如果引擎没有运行，尝试重新启动
            if !engine.avEngine.isRunning {
                print("⚠️ Conductor.start(): 引擎未运行，尝试重新启动...")
                do {
                    try engine.start()
                    print("✅ Conductor.start(): 引擎重新启动成功")
                } catch {
                    print("❌ Conductor.start(): 引擎重新启动失败 - \(error)")
                }
            }
            return
        }
        
        print("🎵 Conductor.start(): 开始初始化音频系统...")
        
        // 配置音频会话（iOS 必需）
        configureAudioSession()
        
        // 启动音频引擎
        do {
            try engine.start()
            print("✅ Conductor: AudioEngine 已启动 (running: \(engine.avEngine.isRunning))")
        } catch {
            Log("AudioKit did not start! \(error)")
            print("❌ Conductor: AudioEngine 启动失败 - \(error)")
            errorPresenter?.presentError(.audioEngineFailure(underlying: error))
            return
        }
        
        print("🎵 Conductor: AudioPlayer 数组已初始化，共 \(drumPlayers.count) 个样本")
        
        // Load metronome sounds
        loadMetronomeSounds()
        
        // Load saved MIDI mapping
        loadSavedMIDIMapping()
        
        // Measure audio latency
        measureAudioLatency()
        
        // 延迟安装音频分析 Tap（确保音频引擎完全启动）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setupAudioTap()
        }
        
        // 标记初始化完成
        isInitialized = true
        
        print("✅ Conductor.start(): 音频系统初始化完成")
    }
    
    /// 配置音频会话，单独抽取以提高可读性和错误处理
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // 使用 .playAndRecord 以支持更稳定的音频处理，使用 .defaultToSpeaker 输出到扬声器
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            // 设置较低的延迟以提升性能
            try audioSession.setPreferredIOBufferDuration(0.005) // 5ms
            try audioSession.setActive(true)
            print("✅ Conductor: 音频会话已激活 (category: playAndRecord, latency: 5ms)")
        } catch {
            print("❌ Conductor: 音频会话配置失败 - \(error)")
            // 音频会话配置失败时回退到基础配置
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default, options: [])
                try audioSession.setActive(true)
                print("⚠️ Conductor: 使用回退音频会话配置 (.playback)")
            } catch {
                print("❌ Conductor: 回退音频会话配置也失败 - \(error)")
                errorPresenter?.presentError(.audioEngineFailure(underlying: error))
            }
        }
    }
    
    func playPad(padNumber: Int, velocity: Float = 1.0) {
        // 检查 padNumber 是否有效
        guard padNumber >= 0 && padNumber < drumSamples.count else {
            print("❌ Conductor.playPad: padNumber \(padNumber) 超出范围 (0..<\(drumSamples.count))")
            return
        }
        
        // 确保音频引擎正在运行
        if !engine.avEngine.isRunning {
            print("⚠️ Conductor.playPad: AudioEngine 未运行，正在启动...")
            start()
        }
        
        // 获取pad配置
        let config = getPadConfiguration(for: padNumber)
        
        // 检查是否静音
        guard !config.isMuted else {
            print("🔇 Conductor.playPad: Pad #\(padNumber) 已静音，跳过播放")
            return
        }
        
        // 应用per-pad效果器参数（仅在切换pad或效果器启用状态变化时）
        if lastPlayedPadId != padNumber || config.isEffectEnabled {
            applyPadEffects(config: config)
            lastPlayedPadId = padNumber
        }
        
        // 应用pad独立音量
        let finalVelocity = velocity * config.volume
        
        let sample = drumSamples[padNumber]
        
        // 使用 AudioPlayer 替代 AppleSampler（修复多样本映射问题）
        guard padNumber < drumPlayers.count else {
            print("❌ Conductor.playPad: 没有对应的 AudioPlayer (padNumber: \(padNumber))")
            return
        }
        
        let player = drumPlayers[padNumber]
        
        // 设置播放音量（基于 velocity）
        player.volume = finalVelocity
        
        // 从头开始播放
        player.seek(time: 0)
        player.play()
        
        print("🥁 Conductor.playPad: 播放 \(sample.name) - Volume: \(finalVelocity)")
    }
    
    // MARK: - Per-Pad Configuration Methods
    
    /// 获取指定pad的配置
    private func getPadConfiguration(for padNumber: Int) -> PadConfiguration {
        guard padNumber >= 0 && padNumber < padConfigurations.count else {
            return PadConfiguration.defaultConfiguration(for: padNumber)
        }
        return padConfigurations[padNumber]
    }
    
    /// 应用pad的效果器参数到全局效果器
    private func applyPadEffects(config: PadConfiguration) {
        guard config.isEffectEnabled else {
            // 效果器禁用时使用默认值
            reverb.dryWetMix = 0.0
            delay.dryWetMix = 0.0
            return
        }
        
        let effects = config.effectSettings
        
        // 应用混响设置
        reverb.dryWetMix = effects.reverbMix / 100.0
        reverb.loadFactoryPreset(effects.reverbPreset.avPreset)
        
        // 应用延迟设置
        delay.dryWetMix = effects.delayMix / 100.0
        delay.feedback = effects.delayFeedback / 100.0
        delay.time = effects.delayTime
        
        print("🎛 应用Pad #\(config.id)效果器: Reverb=\(effects.reverbMix)%, Delay=\(effects.delayMix)%")
    }
    
    /// 更新单个pad配置
    func updatePadConfiguration(_ config: PadConfiguration) {
        guard config.id >= 0 && config.id < padConfigurations.count else {
            print("⚠️ 无效的pad ID: \(config.id)")
            return
        }
        
        padConfigurations[config.id] = config
        print("✅ Conductor: Pad #\(config.id) 配置已更新")
    }
    
    /// 应用预设到Conductor
    func applyPreset(_ preset: DrumPadPreset) {
        padConfigurations = preset.padConfigurations
        
        // 重置上次播放的pad ID，强制下次播放时更新效果器
        lastPlayedPadId = -1
        
        print("✅ Conductor: 预设已应用 - \(preset.name)")
    }
    
    /// 获取当前所有pad配置
    func getCurrentPadConfigurations() -> [PadConfiguration] {
        return padConfigurations
    }
    
    /// 设置pad音量
    func setPadVolume(padId: Int, volume: Float) {
        guard padId >= 0 && padId < padConfigurations.count else { return }
        padConfigurations[padId].volume = max(0, min(1.0, volume))
    }
    
    /// 切换pad静音状态
    func togglePadMute(padId: Int) {
        guard padId >= 0 && padId < padConfigurations.count else { return }
        padConfigurations[padId].isMuted.toggle()
    }
    
    /// 切换pad效果器启用状态
    func togglePadEffects(padId: Int) {
        guard padId >= 0 && padId < padConfigurations.count else { return }
        padConfigurations[padId].isEffectEnabled.toggle()
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
            conductor.handleMIDIPacketList(packetList)
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
    
    private func handleMIDIPacketList(_ packetList: UnsafePointer<MIDIPacketList>) {
        // 复制到可变变量，避免直接对不可变 pointee 做 inout
        var packetListCopy = packetList.pointee
        var packetPointer = withUnsafeMutablePointer(to: &packetListCopy.packet) { $0 }
        
        for _ in 0..<packetListCopy.numPackets {
            let packet = packetPointer.pointee
            let data: [UInt8] = withUnsafeBytes(of: packet.data) { rawBuffer in
                let base = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                return Array(UnsafeBufferPointer(start: base, count: Int(packet.length)))
            }
            
            processMIDIData(data, timestamp: packet.timeStamp)
            packetPointer = MIDIPacketNext(packetPointer)
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
        
        // 遍历设备的实体和源
        let entityCount = MIDIDeviceGetNumberOfEntities(device.deviceRef)
        
        for entityIndex in 0..<entityCount {
            let entity = MIDIDeviceGetEntity(device.deviceRef, entityIndex)
            let sourceCount = MIDIEntityGetNumberOfSources(entity)
            
            for sourceIndex in 0..<sourceCount {
                let source = MIDIEntityGetSource(entity, sourceIndex)
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
    }
    
    func disconnectFromDevice(_ device: MIDIDeviceInfo) {
        let entityCount = MIDIDeviceGetNumberOfEntities(device.deviceRef)
        
        for entityIndex in 0..<entityCount {
            let entity = MIDIDeviceGetEntity(device.deviceRef, entityIndex)
            let sourceCount = MIDIEntityGetNumberOfSources(entity)
            
            for sourceIndex in 0..<sourceCount {
                let source = MIDIEntityGetSource(entity, sourceIndex)
                MIDIPortDisconnectSource(midiInputPort, source)
            }
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
        // Create metronome audio files for each sound type (AudioKit 5 需要 [AVAudioFile])
        let metronomeFiles: [AVAudioFile] = MetronomeSound.allCases.compactMap { sound in
            if let resourceURL = ResourceLoader.loadAudioFile(named: sound.fileName),
               let file = try? AVAudioFile(forReading: resourceURL) {
                return file
            }
            
            // If specific metronome files don't exist, create synthetic sounds
            Log("Metronome sound file not found: \(sound.fileName).wav, using synthetic sound")
            return createSyntheticMetronomeSound(for: sound)
        }

        do {
            try metronome.loadAudioFiles(metronomeFiles)
        } catch {
            Log("Could not load metronome audio files: \(error)")
            errorPresenter?.presentError(.audioEngineFailure(underlying: error))
        }
    }

    private func createSyntheticMetronomeSound(for sound: MetronomeSound) -> AVAudioFile? {
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
            return try AVAudioFile(forReading: tempURL)
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
        // 确保音频引擎正在运行且节拍器已启用
        guard engine.avEngine.isRunning && isMetronomeEnabled else { return }
        
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
    
    // MARK: - 音频能量分析（实时波形可视化）
    
    /// 安装音频分析 Tap，用于采集实时音频数据并计算能量
    func setupAudioTap() {
        // 避免重复安装
        guard !audioTapInstalled else {
            print("ℹ️ Conductor: AudioTap 已安装，跳过")
            return
        }
        
        // 确保音频引擎正在运行
        guard engine.avEngine.isRunning else {
            print("⚠️ Conductor: 音频引擎未运行，AudioTap 安装失败")
            return
        }
        
        // 获取混音器的输出格式
        let format = mixer.avAudioNode.outputFormat(forBus: 0)
        
        // 检查格式是否有效
        guard format.sampleRate > 0 && format.channelCount > 0 else {
            print("⚠️ Conductor: 无法获取有效的音频格式，AudioTap 安装失败")
            return
        }
        
        print("🎤 Conductor: 正在安装 AudioTap (sampleRate: \(format.sampleRate), channels: \(format.channelCount))...")
        
        // 使用 try-catch 保护 tap 安装
        do {
            // 安装 Tap 到混音器的输出
            mixer.avAudioNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }
            
            audioTapInstalled = true
            print("✅ Conductor: AudioTap 安装成功")
        } catch {
            print("❌ Conductor: AudioTap 安装失败 - \(error)")
        }
    }
    
    /// 处理音频缓冲区，计算 RMS 能量和峰值
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }
        
        var sum: Float = 0.0
        var peak: Float = 0.0
        
        // 计算 RMS（均方根）和峰值
        for frame in 0..<frameCount {
            let sample = channelData[0][frame]
            sum += sample * sample
            peak = max(peak, abs(sample))
        }
        
        let rms = sqrt(sum / Float(frameCount))
        
        // 更新到主线程（带平滑处理，避免抖动）
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 使用指数平滑来避免过快的能量变化
            let smoothingFactor: Float = 0.3
            let newEnergy = min(rms * 10.0, 1.0) // 放大并限制在 0-1
            let newPeak = min(peak * 2.0, 1.0)
            
            self.audioEnergy = self.audioEnergy * (1 - smoothingFactor) + newEnergy * smoothingFactor
            self.audioPeakLevel = max(self.audioPeakLevel * 0.95, newPeak) // 峰值慢衰减
        }
    }
    
    /// 移除音频分析 Tap
    func removeAudioTap() {
        guard audioTapInstalled else { return }
        
        mixer.avAudioNode.removeTap(onBus: 0)
        audioTapInstalled = false
        print("ℹ️ Conductor: AudioTap 已移除")
    }
    
    deinit {
        print("🗑 Conductor: 开始清理资源...")
        
        // Clean up audio tap
        removeAudioTap()
        
        // Clean up metronome timers
        stopMetronome()
        stopCountIn()
        
        // Stop audio engine before cleanup
        engine.stop()
        
        // Clean up MIDI resources
        if midiInputPort != 0 {
            MIDIPortDispose(midiInputPort)
        }
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
        }
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ Conductor: 音频会话已停用")
        } catch {
            print("⚠️ Conductor: 音频会话停用失败 - \(error)")
        }
        
        print("✅ Conductor: 资源清理完成")
    }
}

