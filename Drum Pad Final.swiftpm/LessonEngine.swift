import Foundation
import AudioKit
import Combine

// MARK: - Lesson Engine Protocol

protocol LessonEngineProtocol {
    func loadLesson(_ lessonId: String) -> Lesson?
    func getCurrentStep() -> LessonStep?
    func advanceToNextStep()
    func setPlaybackMode(_ mode: PlaybackMode)
    func getTargetEvents(for timeRange: TimeRange) -> [TargetEvent]
    func startPlayback()
    func pausePlayback()
    func stopPlayback()
    func setTempo(_ bpm: Float)
    func setLoopRegion(_ start: TimeInterval, _ end: TimeInterval)
    func enableWaitMode(_ enabled: Bool)
}

// MARK: - Supporting Types

struct TimeRange {
    let start: TimeInterval
    let end: TimeInterval
    
    init(start: TimeInterval, end: TimeInterval) {
        self.start = start
        self.end = end
    }
    
    func contains(_ time: TimeInterval) -> Bool {
        return time >= start && time <= end
    }
    
    var duration: TimeInterval {
        return end - start
    }
}

enum PlaybackState: String, CaseIterable {
    case stopped = "stopped"
    case playing = "playing"
    case paused = "paused"
    case waiting = "waiting"
    
    var displayName: String {
        switch self {
        case .stopped: return "Stopped"
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .waiting: return "Waiting"
        }
    }
}

// MARK: - Lesson Engine Implementation

class LessonEngine: ObservableObject, LessonEngineProtocol {
    
    // MARK: - Published Properties
    @Published var currentLesson: Lesson?
    @Published var currentStep: LessonStep?
    @Published var playbackMode: PlaybackMode = .performance
    @Published var playbackState: PlaybackState = .stopped
    @Published var currentTempo: Float = 120.0
    @Published var playbackPosition: TimeInterval = 0.0
    @Published var loopRegion: TimeRange?
    @Published var isWaitModeEnabled: Bool = false
    @Published var isAutoAccelEnabled: Bool = false
    @Published var targetTempo: Float = 120.0
    
    // MARK: - Private Properties
    private var coreDataManager: CoreDataManager
    private var conductor: Conductor
    private var scoreEngine: ScoreEngine
    
    // Playback management
    private var playbackTimer: Timer?
    private var startTime: TimeInterval = 0
    private var pausedTime: TimeInterval = 0
    private var currentStepIndex: Int = 0
    private var targetEventTimeline: [TargetEvent] = []
    private var nextTargetEventIndex: Int = 0
    
    // Wait mode management
    private var waitingForTargetIndex: Int?
    private var waitModeTargetEvents: [TargetEvent] = []
    
    // Auto acceleration
    private var autoAccelCheckpoints: [TimeInterval] = []
    private var lastAccelTime: TimeInterval = 0
    
    // Auto acceleration parameters (configurable)
    private var accelIncrement: Float {
        return UserDefaults.standard.object(forKey: "autoAccelIncrement") as? Float ?? 10.0
    }
    
    private var accelCheckInterval: TimeInterval {
        return UserDefaults.standard.object(forKey: "autoAccelCheckInterval") as? TimeInterval ?? 8.0
    }
    
    private var accelScoreThreshold: Float {
        return UserDefaults.standard.object(forKey: "autoAccelScoreThreshold") as? Float ?? 80.0
    }
    
    private var accelStreakThreshold: Int {
        return UserDefaults.standard.object(forKey: "autoAccelStreakThreshold") as? Int ?? 4
    }
    
    // MARK: - Initialization
    
    init(coreDataManager: CoreDataManager, conductor: Conductor, scoreEngine: ScoreEngine) {
        self.coreDataManager = coreDataManager
        self.conductor = conductor
        self.scoreEngine = scoreEngine
        
        setupObservers()
    }
    
    private func setupObservers() {
        // Listen for score engine feedback to handle wait mode
        scoreEngine.$realtimeFeedback
            .sink { [weak self] feedback in
                self?.handleScoreFeedback(feedback)
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Interface
    
    func loadLesson(_ lessonId: String) -> Lesson? {
        guard let lesson = coreDataManager.fetchLesson(by: lessonId) else {
            print("Failed to load lesson with ID: \(lessonId)")
            return nil
        }
        
        currentLesson = lesson
        currentStepIndex = 0
        currentStep = lesson.stepsArray.first
        currentTempo = lesson.defaultBPM
        targetTempo = lesson.defaultBPM
        
        // Build target event timeline from all steps
        buildTargetEventTimeline()
        
        // Reset playback state
        resetPlayback()
        
        return lesson
    }
    
    func getCurrentStep() -> LessonStep? {
        return currentStep
    }
    
    func advanceToNextStep() {
        guard let lesson = currentLesson else { return }
        
        let steps = lesson.stepsArray
        if currentStepIndex < steps.count - 1 {
            currentStepIndex += 1
            currentStep = steps[currentStepIndex]
            
            // Update tempo if step has override
            if let step = currentStep, step.bpmOverride > 0 {
                setTempo(step.bpmOverride)
            }
            
            // Rebuild timeline for new step
            buildTargetEventTimeline()
            resetPlayback()
        }
    }
    
    func setPlaybackMode(_ mode: PlaybackMode) {
        let previousMode = playbackMode
        playbackMode = mode
        
        // Configure scoring based on mode
        switch mode {
        case .performance:
            isWaitModeEnabled = false
            isAutoAccelEnabled = false
            currentTempo = targetTempo
        case .practice:
            // Practice mode allows all features
            break
        case .memory:
            // Memory mode requires unlocking first
            if !isMemoryModeUnlocked() {
                print("Memory mode not unlocked - reverting to performance mode")
                playbackMode = .performance
                return
            }
            isWaitModeEnabled = false
            isAutoAccelEnabled = false
            currentTempo = targetTempo
        }
        
        // Update assist level based on mode
        updateAssistLevel()
        
        // Notify about memory mode visual state changes
        if mode == .memory || previousMode == .memory {
            NotificationCenter.default.post(
                name: .memoryModeVisualStateChanged,
                object: self,
                userInfo: ["visualState": getMemoryModeVisualState()]
            )
        }
    }
    
    func getTargetEvents(for timeRange: TimeRange) -> [TargetEvent] {
        return targetEventTimeline.filter { event in
            timeRange.contains(event.timestamp)
        }
    }
    
    func startPlayback() {
        guard let lesson = currentLesson else { return }
        
        // Start count-in if enabled, then begin actual playback
        conductor.startCountIn { [weak self] in
            guard let self = self else { return }
            
            // Setup scoring session
            let scoringProfile = lesson.scoringProfile?.toScoringProfile() ?? ScoringProfile.defaultProfile()
            let eventsToScore = self.getEventsForScoring()
            
            self.conductor.startScoringSession(targetEvents: eventsToScore, profile: scoringProfile)
            
            // Start playback timer
            self.startTime = CACurrentMediaTime() - self.pausedTime
            self.playbackState = .playing
            
            self.startPlaybackTimer()
            
            // Setup wait mode if enabled
            if self.isWaitModeEnabled {
                self.setupWaitMode()
            }
            
            // Setup auto acceleration if enabled
            if self.isAutoAccelEnabled {
                self.setupAutoAcceleration()
            }
        }
    }
    
    func pausePlayback() {
        guard playbackState == .playing else { return }
        
        pausedTime = playbackPosition
        playbackState = .paused
        stopPlaybackTimer()
    }
    
    func stopPlayback() {
        playbackState = .stopped
        stopPlaybackTimer()
        
        // Stop count-in if it's running
        conductor.stopCountIn()
        
        // Get final score and apply memory mode logic
        let baseResult = conductor.stopScoringSession()
        let finalResult = applyMemoryModeScoring(baseResult)
        
        // Check for black star achievement
        if checkForBlackStarAchievement(finalResult) {
            NotificationCenter.default.post(
                name: .blackStarAchieved,
                object: self,
                userInfo: [
                    "lessonId": currentLesson?.id ?? "",
                    "score": finalResult.totalScore,
                    "achievement": MemoryModeAchievement(
                        lessonId: currentLesson?.id ?? "",
                        achievedAt: Date(),
                        finalScore: finalResult.totalScore,
                        completionTime: finalResult.completionTime
                    )
                ]
            )
        }
        
        resetPlayback()
    }
    
    func setTempo(_ bpm: Float) {
        let clampedBPM = max(60.0, min(300.0, bpm))
        currentTempo = clampedBPM
        
        // Update conductor tempo
        conductor.tempo = clampedBPM
        
        // Rebuild timeline with new tempo if needed
        if playbackState != .playing {
            buildTargetEventTimeline()
        }
    }
    
    func setLoopRegion(_ start: TimeInterval, _ end: TimeInterval) {
        guard start < end && start >= 0 else { return }
        
        loopRegion = TimeRange(start: start, end: end)
        
        // If currently playing and position is outside loop, jump to start
        if playbackState == .playing, let loop = loopRegion {
            if !loop.contains(playbackPosition) {
                seekToTime(loop.start)
            }
        }
    }
    
    func enableWaitMode(_ enabled: Bool) {
        isWaitModeEnabled = enabled
        
        if enabled && playbackState == .playing {
            setupWaitMode()
        }
    }
    
    // MARK: - Private Implementation
    
    private func buildTargetEventTimeline() {
        guard let step = currentStep else {
            targetEventTimeline = []
            return
        }
        
        // Scale target events based on current tempo vs original tempo
        let tempoRatio = currentTempo / targetTempo
        
        targetEventTimeline = step.targetEvents.map { event in
            TargetEvent(
                timestamp: event.timestamp / Double(tempoRatio),
                laneId: event.laneId,
                noteNumber: event.noteNumber,
                velocity: event.velocity,
                duration: event.duration.map { $0 / Double(tempoRatio) }
            )
        }.sorted { $0.timestamp < $1.timestamp }
        
        nextTargetEventIndex = 0
    }
    
    private func getEventsForScoring() -> [TargetEvent] {
        if let loopRegion = loopRegion {
            return getTargetEvents(for: loopRegion)
        } else {
            return targetEventTimeline
        }
    }
    
    private func resetPlayback() {
        playbackPosition = 0.0
        pausedTime = 0.0
        nextTargetEventIndex = 0
        waitingForTargetIndex = nil
        lastAccelTime = 0
        autoAccelCheckpoints = []
    }
    
    private func startPlaybackTimer() {
        stopPlaybackTimer()
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.updatePlaybackPosition()
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func updatePlaybackPosition() {
        guard playbackState == .playing else { return }
        
        let currentTime = CACurrentMediaTime()
        let previousPosition = playbackPosition
        playbackPosition = currentTime - startTime
        
        // Handle loop region
        if let loop = loopRegion {
            if playbackPosition >= loop.end {
                seekToTime(loop.start)
                return
            }
        }
        
        // Check for lesson completion
        if let lesson = currentLesson, playbackPosition >= lesson.duration {
            stopPlayback()
            return
        }
        
        // Handle memory mode visual state updates
        if playbackMode == .memory {
            let previousProgress = Float(previousPosition / (currentLesson?.duration ?? 1.0))
            let currentProgress = getMemoryModeProgress()
            
            // Check if we've crossed a visual state threshold
            let thresholds: [Float] = [0.25, 0.50, 0.75, 1.0]
            for threshold in thresholds {
                if previousProgress < threshold && currentProgress >= threshold {
                    NotificationCenter.default.post(
                        name: .memoryModeVisualStateChanged,
                        object: self,
                        userInfo: ["visualState": getMemoryModeVisualState()]
                    )
                    break
                }
            }
        }
        
        // Handle wait mode
        if isWaitModeEnabled {
            checkWaitModeConditions()
        }
        
        // Handle auto acceleration
        if isAutoAccelEnabled {
            checkAutoAcceleration()
        }
    }
    
    private func seekToTime(_ time: TimeInterval) {
        playbackPosition = time
        pausedTime = time
        startTime = CACurrentMediaTime() - time
        
        // Update next target event index
        nextTargetEventIndex = targetEventTimeline.firstIndex { $0.timestamp >= time } ?? targetEventTimeline.count
    }
    
    private func setupWaitMode() {
        waitModeTargetEvents = getEventsForScoring()
        findNextWaitTarget()
    }
    
    private func findNextWaitTarget() {
        guard isWaitModeEnabled else { return }
        
        // Find next target event that hasn't been hit yet
        for (index, event) in waitModeTargetEvents.enumerated() {
            if event.timestamp > playbackPosition {
                waitingForTargetIndex = index
                return
            }
        }
        
        waitingForTargetIndex = nil
    }
    
    private func checkWaitModeConditions() {
        guard let waitIndex = waitingForTargetIndex,
              waitIndex < waitModeTargetEvents.count else { return }
        
        let targetEvent = waitModeTargetEvents[waitIndex]
        
        // If we've reached the target time, pause and wait
        if playbackPosition >= targetEvent.timestamp && playbackState == .playing {
            playbackState = .waiting
            stopPlaybackTimer()
        }
    }
    
    private func handleScoreFeedback(_ feedback: TimingFeedback?) {
        guard isWaitModeEnabled,
              playbackState == .waiting,
              let feedback = feedback,
              feedback != .miss && feedback != .extra else { return }
        
        // User hit the target, continue playback
        waitingForTargetIndex = nil
        findNextWaitTarget()
        
        if playbackState == .waiting {
            playbackState = .playing
            startPlaybackTimer()
        }
    }
    
    private func setupAutoAcceleration() {
        guard isAutoAccelEnabled else { return }
        
        autoAccelCheckpoints = []
        lastAccelTime = 0
        
        // Create checkpoints every accelCheckInterval seconds
        let duration = currentLesson?.duration ?? 0
        var checkpoint: TimeInterval = accelCheckInterval
        
        while checkpoint < duration {
            autoAccelCheckpoints.append(checkpoint)
            checkpoint += accelCheckInterval
        }
    }
    
    private func checkAutoAcceleration() {
        guard isAutoAccelEnabled,
              !autoAccelCheckpoints.isEmpty,
              currentTempo < targetTempo else { return }
        
        let nextCheckpoint = autoAccelCheckpoints.first!
        
        if playbackPosition >= nextCheckpoint {
            // Check if performance is good enough for acceleration
            let currentScore = conductor.getCurrentScore()
            let currentStreak = conductor.getCurrentStreak()
            
            // Use configurable thresholds
            if currentScore > accelScoreThreshold && currentStreak > accelStreakThreshold {
                let newTempo = min(targetTempo, currentTempo + accelIncrement)
                setTempo(newTempo)
                lastAccelTime = playbackPosition
                
                // Notify about acceleration
                NotificationCenter.default.post(
                    name: NSNotification.Name("LessonEngineAutoAccelerated"),
                    object: self,
                    userInfo: ["newTempo": newTempo, "targetTempo": targetTempo]
                )
            }
            
            // Remove processed checkpoint
            autoAccelCheckpoints.removeFirst()
        }
    }
    
    private func updateAssistLevel() {
        guard let step = currentStep else { return }
        
        let assistLevel: AssistLevel
        switch playbackMode {
        case .performance:
            assistLevel = .reduced
        case .practice:
            assistLevel = step.assistLevelEnum
        case .memory:
            assistLevel = .none
        }
        
        // Update step assist level if needed
        if step.assistLevelEnum != assistLevel {
            step.assistLevelEnum = assistLevel
            try? coreDataManager.saveContext()
        }
    }
    
    deinit {
        stopPlaybackTimer()
    }
}

// MARK: - Extensions

extension LessonEngine {
    
    // MARK: - Practice Mode Specific Methods
    
    func enableAutoAcceleration(_ enabled: Bool) {
        isAutoAccelEnabled = enabled
        
        if enabled && playbackState == .playing {
            setupAutoAcceleration()
        } else if !enabled {
            // Reset to current tempo when disabling auto accel
            autoAccelCheckpoints = []
        }
    }
    
    func clearLoopRegion() {
        loopRegion = nil
        
        // Rebuild timeline for full lesson
        buildTargetEventTimeline()
    }
    
    func setLoopRegionFromSelection(start: TimeInterval, end: TimeInterval) {
        setLoopRegion(start, end)
    }
    
    // MARK: - BPM Control Methods
    
    func adjustTempo(by delta: Float) {
        let newTempo = currentTempo + delta
        setTempo(newTempo)
    }
    
    func setTempoPercentage(_ percentage: Float) {
        // percentage should be 0.0 to 1.0, where 1.0 = target tempo
        let newTempo = targetTempo * max(0.1, min(1.0, percentage))
        setTempo(newTempo)
    }
    
    func getTempoPercentage() -> Float {
        guard targetTempo > 0 else { return 1.0 }
        return currentTempo / targetTempo
    }
    
    func resetToTargetTempo() {
        setTempo(targetTempo)
    }
    
    // MARK: - Loop Region Management
    
    func setLoopRegionFromBeats(startBeat: Int, endBeat: Int) {
        guard let lesson = currentLesson else { return }
        
        let beatsPerSecond = Double(currentTempo) / 60.0
        let startTime = Double(startBeat) / beatsPerSecond
        let endTime = Double(endBeat) / beatsPerSecond
        
        setLoopRegion(startTime, min(endTime, lesson.duration))
    }
    
    func expandLoopRegion(by seconds: TimeInterval) {
        guard let loop = loopRegion,
              let lesson = currentLesson else { return }
        
        let newStart = max(0, loop.start - seconds)
        let newEnd = min(lesson.duration, loop.end + seconds)
        
        setLoopRegion(newStart, newEnd)
    }
    
    func getLoopRegionInBeats() -> (start: Int, end: Int)? {
        guard let loop = loopRegion else { return nil }
        
        let beatsPerSecond = Double(currentTempo) / 60.0
        let startBeat = Int(loop.start * beatsPerSecond)
        let endBeat = Int(loop.end * beatsPerSecond)
        
        return (start: startBeat, end: endBeat)
    }
    
    // MARK: - Wait Mode Management
    
    func skipCurrentWaitTarget() {
        guard isWaitModeEnabled,
              playbackState == .waiting else { return }
        
        // Mark current target as skipped and continue
        waitingForTargetIndex = nil
        findNextWaitTarget()
        
        if playbackState == .waiting {
            playbackState = .playing
            startPlaybackTimer()
        }
    }
    
    func getWaitModeStatus() -> (isWaiting: Bool, targetNote: Int?, timeUntilTarget: TimeInterval?) {
        guard isWaitModeEnabled,
              let waitIndex = waitingForTargetIndex,
              waitIndex < waitModeTargetEvents.count else {
            return (isWaiting: false, targetNote: nil, timeUntilTarget: nil)
        }
        
        let targetEvent = waitModeTargetEvents[waitIndex]
        let timeUntil = targetEvent.timestamp - playbackPosition
        
        return (
            isWaiting: playbackState == .waiting,
            targetNote: targetEvent.noteNumber,
            timeUntilTarget: max(0, timeUntil)
        )
    }
    
    // MARK: - Auto Acceleration Management
    
    func setAutoAccelParams(increment: Float, checkInterval: TimeInterval, scoreThreshold: Float, streakThreshold: Int) {
        // Store custom auto accel parameters
        UserDefaults.standard.set(increment, forKey: "autoAccelIncrement")
        UserDefaults.standard.set(checkInterval, forKey: "autoAccelCheckInterval")
        UserDefaults.standard.set(scoreThreshold, forKey: "autoAccelScoreThreshold")
        UserDefaults.standard.set(streakThreshold, forKey: "autoAccelStreakThreshold")
        
        // Rebuild checkpoints if auto accel is active
        if isAutoAccelEnabled && playbackState == .playing {
            setupAutoAcceleration()
        }
    }
    
    func getAutoAccelProgress() -> (currentTempo: Float, targetTempo: Float, progress: Float) {
        let progress = targetTempo > 0 ? (currentTempo - 60.0) / (targetTempo - 60.0) : 1.0
        return (
            currentTempo: currentTempo,
            targetTempo: targetTempo,
            progress: max(0.0, min(1.0, progress))
        )
    }
    
    // MARK: - Memory Mode Specific Methods
    
    func isMemoryModeUnlocked() -> Bool {
        guard let lesson = currentLesson else { return false }
        
        // Check if user has achieved 100% in performance mode
        let scoreResults = lesson.scoreResultsArray
        return scoreResults.contains { result in
            result.playbackModeEnum == .performance && result.isPlatinum
        }
    }
    
    func enableMemoryMode() -> Bool {
        guard isMemoryModeUnlocked() else { return false }
        
        setPlaybackMode(.memory)
        return true
    }
    
    func getMemoryModeVisualState() -> MemoryModeVisualState {
        guard playbackMode == .memory else {
            return MemoryModeVisualState(
                showNotePreview: true,
                showTrackHighlight: true,
                showTargetIndicators: true,
                showProgressiveHints: true,
                assistLevel: currentStep?.assistLevelEnum ?? .full
            )
        }
        
        // In memory mode, progressively hide visual elements
        let progress = getMemoryModeProgress()
        
        return MemoryModeVisualState(
            showNotePreview: progress < 0.25,           // Hide after 25% progress
            showTrackHighlight: progress < 0.50,        // Hide after 50% progress  
            showTargetIndicators: progress < 0.75,      // Hide after 75% progress
            showProgressiveHints: progress < 1.0,       // Hide when complete
            assistLevel: .none
        )
    }
    
    func getMemoryModeProgress() -> Float {
        guard let lesson = currentLesson else { return 0.0 }
        
        if let loop = loopRegion {
            let loopProgress = (playbackPosition - loop.start) / loop.duration
            return max(0.0, min(1.0, Float(loopProgress)))
        } else {
            return max(0.0, min(1.0, Float(playbackPosition / lesson.duration)))
        }
    }
    
    func checkForBlackStarAchievement(_ scoreResult: ScoreResult) -> Bool {
        guard playbackMode == .memory && scoreResult.isPlatinum else { return false }
        
        // Award black star for 100% in memory mode
        return true
    }
    
    func applyMemoryModeScoring(_ baseResult: ScoreResult) -> ScoreResult {
        guard playbackMode == .memory else { return baseResult }
        
        // Memory mode gets black star achievement for 100% scores
        let isBlackStar = baseResult.totalScore >= 100.0
        
        return ScoreResult(
            totalScore: baseResult.totalScore,
            starRating: baseResult.starRating,
            isPlatinum: baseResult.isPlatinum,
            isBlackStar: isBlackStar,
            timingResults: baseResult.timingResults,
            streakCount: baseResult.streakCount,
            maxStreak: baseResult.maxStreak,
            missCount: baseResult.missCount,
            extraCount: baseResult.extraCount,
            perfectCount: baseResult.perfectCount,
            earlyCount: baseResult.earlyCount,
            lateCount: baseResult.lateCount,
            completionTime: baseResult.completionTime
        )
    }
    
    // MARK: - Utility Methods
    
    func getPlaybackProgress() -> Float {
        guard let lesson = currentLesson, lesson.duration > 0 else { return 0.0 }
        
        if let loop = loopRegion {
            let loopProgress = (playbackPosition - loop.start) / loop.duration
            return max(0.0, min(1.0, Float(loopProgress)))
        } else {
            return max(0.0, min(1.0, Float(playbackPosition / lesson.duration)))
        }
    }
    
    func getEstimatedTimeRemaining() -> TimeInterval {
        guard let lesson = currentLesson else { return 0 }
        
        if let loop = loopRegion {
            return max(0, loop.end - playbackPosition)
        } else {
            return max(0, lesson.duration - playbackPosition)
        }
    }
    
    func getCurrentTargetEvents() -> [TargetEvent] {
        let currentTime = playbackPosition
        let lookAheadTime: TimeInterval = 2.0 // Look ahead 2 seconds
        
        return targetEventTimeline.filter { event in
            event.timestamp >= currentTime && event.timestamp <= currentTime + lookAheadTime
        }
    }
    
    // MARK: - Practice Session Management
    
    func startPracticeSession(withSettings settings: PracticeSettings) {
        // Apply practice settings
        setTempo(settings.startingTempo)
        enableAutoAcceleration(settings.autoAccelEnabled)
        enableWaitMode(settings.waitModeEnabled)
        
        if let loopStart = settings.loopStart, let loopEnd = settings.loopEnd {
            setLoopRegion(loopStart, loopEnd)
        }
        
        // Set practice mode
        setPlaybackMode(.practice)
        
        // Start playback
        startPlayback()
    }
    
    func getPracticeSessionStats() -> PracticeSessionStats {
        let scoreResult = conductor.stopScoringSession()
        
        return PracticeSessionStats(
            duration: playbackPosition,
            averageScore: scoreResult.totalScore,
            perfectHits: scoreResult.perfectCount,
            earlyHits: scoreResult.earlyCount,
            lateHits: scoreResult.lateCount,
            missedHits: scoreResult.missCount,
            extraHits: scoreResult.extraCount,
            maxStreak: scoreResult.maxStreak,
            tempoProgression: getTempoProgression(),
            loopsCompleted: getLoopsCompleted()
        )
    }
    
    private func getTempoProgression() -> [Float] {
        // Return tempo changes during session
        // This would be tracked during auto acceleration
        return [targetTempo] // Simplified for now
    }
    
    private func getLoopsCompleted() -> Int {
        guard let loop = loopRegion else { return 0 }
        
        return Int(playbackPosition / loop.duration)
    }
}

// MARK: - Supporting Types for Practice Mode

struct PracticeSettings {
    let startingTempo: Float
    let autoAccelEnabled: Bool
    let waitModeEnabled: Bool
    let loopStart: TimeInterval?
    let loopEnd: TimeInterval?
    
    static func defaultSettings() -> PracticeSettings {
        return PracticeSettings(
            startingTempo: 80.0,
            autoAccelEnabled: false,
            waitModeEnabled: false,
            loopStart: nil,
            loopEnd: nil
        )
    }
}

struct PracticeSessionStats {
    let duration: TimeInterval
    let averageScore: Float
    let perfectHits: Int
    let earlyHits: Int
    let lateHits: Int
    let missedHits: Int
    let extraHits: Int
    let maxStreak: Int
    let tempoProgression: [Float]
    let loopsCompleted: Int
    
    var totalHits: Int {
        return perfectHits + earlyHits + lateHits + missedHits + extraHits
    }
    
    var accuracy: Float {
        guard totalHits > 0 else { return 0.0 }
        let goodHits = perfectHits + earlyHits + lateHits
        return Float(goodHits) / Float(totalHits) * 100.0
    }
}

// MARK: - Memory Mode Support Types

struct MemoryModeVisualState {
    let showNotePreview: Bool
    let showTrackHighlight: Bool
    let showTargetIndicators: Bool
    let showProgressiveHints: Bool
    let assistLevel: AssistLevel
    
    var isFullyHidden: Bool {
        return !showNotePreview && !showTrackHighlight && !showTargetIndicators && !showProgressiveHints
    }
}

struct MemoryModeAchievement {
    let lessonId: String
    let achievedAt: Date
    let finalScore: Float
    let completionTime: TimeInterval
    
    var isBlackStar: Bool {
        return finalScore >= 100.0
    }
}

// MARK: - Memory Mode Notifications

extension Notification.Name {
    static let memoryModeUnlocked = Notification.Name("memoryModeUnlocked")
    static let blackStarAchieved = Notification.Name("blackStarAchieved")
    static let memoryModeVisualStateChanged = Notification.Name("memoryModeVisualStateChanged")
}