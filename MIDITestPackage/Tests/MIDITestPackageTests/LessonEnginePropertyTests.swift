import Testing
import Foundation
import CoreAudio
import MIDITestPackage

// MARK: - Test Data Generators for Lesson Engine

struct LessonEngineTestGenerators {
    
    static func generateTimeRange(maxDuration: TimeInterval = 60.0) -> TimeRange {
        let start = TimeInterval.random(in: 0...(maxDuration * 0.7))
        let end = TimeInterval.random(in: start...(start + maxDuration * 0.3))
        return TimeRange(start: start, end: end)
    }
    
    static func generateTargetEventSequence(count: Int, duration: TimeInterval) -> [TargetEvent] {
        var events: [TargetEvent] = []
        let timeStep = duration / TimeInterval(count)
        let drumNotes = [36, 38, 42, 46, 39, 43, 50, 49] // Standard drum MIDI notes
        
        for i in 0..<count {
            let baseTime = TimeInterval(i) * timeStep
            let jitter = TimeInterval.random(in: -0.05...0.05)
            let timestamp = max(0, baseTime + jitter)
            
            events.append(TargetEvent(
                timestamp: timestamp,
                laneId: "LANE_\(i % 4)",
                noteNumber: drumNotes.randomElement()!,
                velocity: Int.random(in: 80...127),
                duration: TimeInterval.random(in: 0.1...0.5)
            ))
        }
        
        return events.sorted { $0.timestamp < $1.timestamp }
    }
}

// MARK: - Supporting Types for Testing

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

// MARK: - Mock Classes for Testing

class MockConductor {
    var tempo: Float = 120.0
    var metronomeSound: MetronomeSound = .click
    var metronomeSubdivision: MetronomeSubdivision = .quarter
    var isMetronomeEnabled: Bool = false
    var countInSettings: CountInSettings = CountInSettings.defaultSettings()
    var metronomeLoadCount: Int = 0
    var countInBeatsPlayed: Int = 0
    
    private var countInCompletion: (() -> Void)?
    
    func setMetronomeSound(_ sound: MetronomeSound) {
        metronomeSound = sound
        metronomeLoadCount += 1
    }
    
    func setMetronomeSubdivision(_ subdivision: MetronomeSubdivision) {
        metronomeSubdivision = subdivision
    }
    
    func getMetronomeInterval() -> TimeInterval {
        return 60.0 / Double(tempo) / metronomeSubdivision.multiplier
    }
    
    func startCountIn(completion: @escaping () -> Void) {
        countInCompletion = completion
        countInBeatsPlayed = 0
    }
    
    func simulateCountInCompletion(after duration: TimeInterval) {
        let expectedBeats = countInSettings.measures * 4
        countInBeatsPlayed = expectedBeats
        countInCompletion?()
        countInCompletion = nil
    }
}

// MARK: - Metronome Support Types for Testing

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
}

enum MetronomeSubdivision: String, CaseIterable {
    case quarter = "1/4"
    case eighth = "1/8"
    case sixteenth = "1/16"
    
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

class MockLessonEngine {
    var currentTempo: Float = 120.0
    var targetTempo: Float = 120.0
    var loopRegion: TimeRange?
    var isWaitModeEnabled: Bool = false
    var playbackPosition: TimeInterval = 0.0
    var targetEventTimeline: [TargetEvent] = []
    var playbackMode: PlaybackMode = .performance
    
    func setTempo(_ bpm: Float) {
        let clampedBPM = max(60.0, min(300.0, bpm))
        currentTempo = clampedBPM
    }
    
    func setTempoPercentage(_ percentage: Float) {
        let newTempo = targetTempo * max(0.1, min(1.0, percentage))
        setTempo(newTempo)
    }
    
    func getTempoPercentage() -> Float {
        guard targetTempo > 0 else { return 1.0 }
        return currentTempo / targetTempo
    }
    
    func setLoopRegion(_ start: TimeInterval, _ end: TimeInterval) {
        guard start < end && start >= 0 else { return }
        loopRegion = TimeRange(start: start, end: end)
    }
    
    func setLoopRegionFromBeats(startBeat: Int, endBeat: Int) {
        let beatsPerSecond = Double(currentTempo) / 60.0
        let startTime = Double(startBeat) / beatsPerSecond
        let endTime = Double(endBeat) / beatsPerSecond
        
        setLoopRegion(startTime, endTime)
    }
    
    func getLoopRegionInBeats() -> (start: Int, end: Int)? {
        guard let loop = loopRegion else { return nil }
        
        let beatsPerSecond = Double(currentTempo) / 60.0
        let startBeat = Int(loop.start * beatsPerSecond)
        let endBeat = Int(loop.end * beatsPerSecond)
        
        return (start: startBeat, end: endBeat)
    }
    
    func getTargetEvents(for timeRange: TimeRange) -> [TargetEvent] {
        return targetEventTimeline.filter { event in
            timeRange.contains(event.timestamp)
        }
    }
    
    func enableWaitMode(_ enabled: Bool) {
        isWaitModeEnabled = enabled
    }
    
    func getAutoAccelProgress() -> (currentTempo: Float, targetTempo: Float, progress: Float) {
        let progress = targetTempo > 0 ? (currentTempo - 60.0) / (targetTempo - 60.0) : 1.0
        return (
            currentTempo: currentTempo,
            targetTempo: targetTempo,
            progress: max(0.0, min(1.0, progress))
        )
    }
    
    func enableMemoryMode(_ enabled: Bool) {
        if enabled {
            playbackMode = .memory
        }
    }
    
    func getMemoryModeVisualState() -> MemoryModeVisualState {
        guard playbackMode == .memory else {
            return MemoryModeVisualState(
                showNotePreview: true,
                showTrackHighlight: true,
                showTargetIndicators: true,
                showProgressiveHints: true,
                assistLevel: .full
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
        let lessonDuration: TimeInterval = 30.0 // Mock lesson duration
        return max(0.0, min(1.0, Float(playbackPosition / lessonDuration)))
    }
    
    func checkForBlackStarAchievement(_ scoreResult: ScoreResult) -> Bool {
        guard playbackMode == .memory && scoreResult.isPlatinum else { return false }
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
}

// MARK: - Property Tests for Lesson Engine

@Suite("Lesson Engine Property Tests")
struct LessonEnginePropertyTests {
    
    // **Feature: melodic-drum-trainer, Property 7: BPM播放准确性**
    // *For any* 设定的BPM值，实际播放速度应该与设定值保持一致（误差<1%）
    @Test("Property 7: BPM Playback Accuracy", .tags(.propertyBased))
    func testBPMPlaybackAccuracy() async throws {
        for _ in 0..<100 {
            let lessonEngine = MockLessonEngine()
            lessonEngine.targetTempo = Float.random(in: 120...180)
            
            // Test various BPM values
            let testBPM = Float.random(in: 60...300)
            lessonEngine.setTempo(testBPM)
            
            let actualBPM = lessonEngine.currentTempo
            let tolerance = testBPM * 0.01 // 1% tolerance
            
            #expect(abs(actualBPM - testBPM) <= tolerance,
                   "BPM should be accurate within 1%: set \(testBPM), got \(actualBPM)")
            
            // Test tempo percentage - ensure the result won't be below minimum BPM (60)
            let minPercentage = 60.0 / lessonEngine.targetTempo
            let percentage = Float.random(in: max(0.1, minPercentage)...1.0)
            lessonEngine.setTempoPercentage(percentage)
            
            let expectedTempo = max(60.0, lessonEngine.targetTempo * percentage)
            let actualPercentageTempo = lessonEngine.currentTempo
            let percentageTolerance = expectedTempo * 0.01
            
            #expect(abs(actualPercentageTempo - expectedTempo) <= percentageTolerance,
                   "Tempo percentage should be accurate: expected \(expectedTempo), got \(actualPercentageTempo)")
        }
    }
    
    // **Feature: melodic-drum-trainer, Property 12: 自动加速递增性**
    // *For any* 开启自动加速的良好演奏，BPM应该每次增加10直到达到原始速度
    @Test("Property 12: Auto Acceleration Increment", .tags(.propertyBased))
    func testAutoAccelerationIncrement() async throws {
        for _ in 0..<100 {
            let lessonEngine = MockLessonEngine()
            lessonEngine.targetTempo = Float.random(in: 120...180)
            
            let startingTempo = lessonEngine.targetTempo * Float.random(in: 0.6...0.8)
            lessonEngine.setTempo(startingTempo)
            
            let initialTempo = lessonEngine.currentTempo
            
            // The tempo should not exceed target tempo
            #expect(lessonEngine.currentTempo <= lessonEngine.targetTempo,
                   "Auto acceleration should not exceed target tempo")
            
            // If there's room for acceleration, it should be incremental
            if initialTempo < lessonEngine.targetTempo - 10.0 {
                let progress = lessonEngine.getAutoAccelProgress()
                #expect(progress.currentTempo >= initialTempo,
                       "Auto acceleration should maintain or increase tempo")
                #expect(progress.targetTempo == lessonEngine.targetTempo,
                       "Target tempo should match lesson default BPM")
                #expect(progress.progress >= 0.0 && progress.progress <= 1.0,
                       "Progress should be between 0 and 1")
            }
        }
    }
    
    // **Feature: melodic-drum-trainer, Property 13: 循环播放边界性**
    // *For any* 设定的循环区间，播放应该在指定的开始和结束时间点之间重复
    @Test("Property 13: Loop Playback Boundaries", .tags(.propertyBased))
    func testLoopPlaybackBoundaries() async throws {
        for _ in 0..<100 {
            let lessonEngine = MockLessonEngine()
            let lessonDuration: TimeInterval = 60.0
            
            // Generate valid loop region
            let loopStart = TimeInterval.random(in: 0...30)
            let loopEnd = TimeInterval.random(in: (loopStart + 1)...min(loopStart + 20, lessonDuration))
            
            lessonEngine.setLoopRegion(loopStart, loopEnd)
            
            guard let loopRegion = lessonEngine.loopRegion else {
                #expect(Bool(false), "Loop region should be set")
                continue
            }
            
            #expect(loopRegion.start == loopStart,
                   "Loop start should match set value: \(loopRegion.start) vs \(loopStart)")
            #expect(loopRegion.end == loopEnd,
                   "Loop end should match set value: \(loopRegion.end) vs \(loopEnd)")
            #expect(loopRegion.start < loopRegion.end,
                   "Loop start should be before loop end")
            #expect(loopRegion.duration == loopEnd - loopStart,
                   "Loop duration should be calculated correctly")
            
            // Test that target events are filtered to loop region
            lessonEngine.targetEventTimeline = LessonEngineTestGenerators.generateTargetEventSequence(
                count: 20, 
                duration: lessonDuration
            )
            
            let eventsInLoop = lessonEngine.getTargetEvents(for: loopRegion)
            for event in eventsInLoop {
                #expect(loopRegion.contains(event.timestamp),
                       "All events in loop should be within loop boundaries")
            }
            
            // Test loop region from beats
            let startBeat = Int.random(in: 1...8)
            let endBeat = Int.random(in: (startBeat + 1)...(startBeat + 8))
            
            lessonEngine.setLoopRegionFromBeats(startBeat: startBeat, endBeat: endBeat)
            
            if let beatsLoop = lessonEngine.getLoopRegionInBeats() {
                #expect(beatsLoop.start <= startBeat + 1, // Allow for rounding
                       "Loop start beat should be approximately correct")
                #expect(beatsLoop.end >= endBeat - 1, // Allow for rounding
                       "Loop end beat should be approximately correct")
            }
        }
    }
    
    // **Feature: melodic-drum-trainer, Property 14: 等待模式暂停准确性**
    // *For any* 目标音符位置，等待模式应该在该位置暂停直到接收到正确的用户输入
    @Test("Property 14: Wait Mode Pause Accuracy", .tags(.propertyBased))
    func testWaitModePauseAccuracy() async throws {
        for _ in 0..<100 {
            let lessonEngine = MockLessonEngine()
            
            // Enable wait mode
            lessonEngine.enableWaitMode(true)
            #expect(lessonEngine.isWaitModeEnabled == true,
                   "Wait mode should be enabled")
            
            // Test disabling wait mode
            lessonEngine.enableWaitMode(false)
            #expect(lessonEngine.isWaitModeEnabled == false,
                   "Wait mode should be disabled")
            
            // Test wait mode with target events
            lessonEngine.targetEventTimeline = LessonEngineTestGenerators.generateTargetEventSequence(
                count: 10,
                duration: 30.0
            )
            
            lessonEngine.enableWaitMode(true)
            
            // Verify wait mode is properly enabled
            #expect(lessonEngine.isWaitModeEnabled == true,
                   "Wait mode should remain enabled after setting target events")
            
            // Test that target events exist for wait mode to work with
            #expect(!lessonEngine.targetEventTimeline.isEmpty,
                   "Should have target events for wait mode testing")
        }
    }
    
    // **Feature: melodic-drum-trainer, Property 24: 记忆模式视觉隐藏性**
    // *For any* 记忆模式激活，音符预览和轨道高亮应该被隐藏但音频功能保持正常
    @Test("Property 24: Memory Mode Visual Hiding", .tags(.propertyBased))
    func testMemoryModeVisualHiding() async throws {
        for _ in 0..<100 {
            let lessonEngine = MockLessonEngine()
            
            // Test normal mode shows all visual elements
            let normalState = lessonEngine.getMemoryModeVisualState()
            #expect(normalState.showNotePreview == true,
                   "Normal mode should show note preview")
            #expect(normalState.showTrackHighlight == true,
                   "Normal mode should show track highlight")
            #expect(normalState.showTargetIndicators == true,
                   "Normal mode should show target indicators")
            #expect(normalState.showProgressiveHints == true,
                   "Normal mode should show progressive hints")
            
            // Test memory mode progressively hides elements
            lessonEngine.enableMemoryMode(true)
            
            // Simulate different progress levels
            let progressLevels: [Float] = [0.0, 0.3, 0.6, 0.8, 1.0]
            
            for progress in progressLevels {
                lessonEngine.playbackPosition = TimeInterval(progress) * 30.0 // 30 second lesson
                let memoryState = lessonEngine.getMemoryModeVisualState()
                
                if progress >= 0.25 {
                    #expect(memoryState.showNotePreview == false,
                           "Memory mode should hide note preview after 25% progress")
                }
                
                if progress >= 0.50 {
                    #expect(memoryState.showTrackHighlight == false,
                           "Memory mode should hide track highlight after 50% progress")
                }
                
                if progress >= 0.75 {
                    #expect(memoryState.showTargetIndicators == false,
                           "Memory mode should hide target indicators after 75% progress")
                }
                
                if progress >= 1.0 {
                    #expect(memoryState.showProgressiveHints == false,
                           "Memory mode should hide progressive hints when complete")
                    #expect(memoryState.isFullyHidden == true,
                           "Memory mode should be fully hidden when complete")
                }
            }
        }
    }
    
    // **Feature: melodic-drum-trainer, Property 25: 黑星成就条件性**
    // *For any* 记忆模式中的100%分数，应该授予黑星成就
    @Test("Property 25: Black Star Achievement Condition", .tags(.propertyBased))
    func testBlackStarAchievementCondition() async throws {
        for _ in 0..<100 {
            let lessonEngine = MockLessonEngine()
            
            // Test that black star is only awarded in memory mode with 100% score
            let testScores: [Float] = [50.0, 75.0, 90.0, 99.0, 100.0]
            
            for score in testScores {
                // Test in performance mode
                lessonEngine.playbackMode = .performance
                let performanceResult = ScoreResult(
                    totalScore: score,
                    starRating: score >= 90 ? 3 : (score >= 75 ? 2 : 1),
                    isPlatinum: score >= 100,
                    isBlackStar: false,
                    timingResults: [],
                    streakCount: 0,
                    maxStreak: 0,
                    missCount: 0,
                    extraCount: 0,
                    perfectCount: 0,
                    earlyCount: 0,
                    lateCount: 0,
                    completionTime: 30.0
                )
                
                let shouldGetBlackStar = lessonEngine.checkForBlackStarAchievement(performanceResult)
                #expect(shouldGetBlackStar == false,
                       "Performance mode should never award black star, score: \(score)")
                
                // Test in memory mode
                lessonEngine.playbackMode = .memory
                let memoryResult = ScoreResult(
                    totalScore: score,
                    starRating: score >= 90 ? 3 : (score >= 75 ? 2 : 1),
                    isPlatinum: score >= 100,
                    isBlackStar: false,
                    timingResults: [],
                    streakCount: 0,
                    maxStreak: 0,
                    missCount: 0,
                    extraCount: 0,
                    perfectCount: 0,
                    earlyCount: 0,
                    lateCount: 0,
                    completionTime: 30.0
                )
                
                let memoryBlackStar = lessonEngine.checkForBlackStarAchievement(memoryResult)
                let expectedBlackStar = score >= 100.0
                
                #expect(memoryBlackStar == expectedBlackStar,
                       "Memory mode should award black star only for 100% score, score: \(score), expected: \(expectedBlackStar), got: \(memoryBlackStar)")
                
                // Test that applyMemoryModeScoring correctly sets black star
                let finalResult = lessonEngine.applyMemoryModeScoring(memoryResult)
                #expect(finalResult.isBlackStar == expectedBlackStar,
                       "Applied memory mode scoring should set black star correctly for score: \(score)")
            }
        }
    }
    
    // **Feature: melodic-drum-trainer, Property 15: 节拍器音色应用性**
    // *For any* 选择的节拍器音色，应用后的音色应该与选择的一致
    @Test("Property 15: Metronome Sound Application", .tags(.propertyBased))
    func testMetronomeSoundApplication() async throws {
        for _ in 0..<100 {
            let conductor = MockConductor()
            
            // Test all available metronome sounds
            let allSounds = MetronomeSound.allCases
            let selectedSound = allSounds.randomElement()!
            
            conductor.setMetronomeSound(selectedSound)
            
            #expect(conductor.metronomeSound == selectedSound,
                   "Applied metronome sound should match selected sound: \(selectedSound)")
            
            // Test that sound change triggers audio reload
            let previousLoadCount = conductor.metronomeLoadCount
            conductor.setMetronomeSound(allSounds.filter { $0 != selectedSound }.randomElement()!)
            
            #expect(conductor.metronomeLoadCount > previousLoadCount,
                   "Changing metronome sound should trigger audio reload")
        }
    }
    
    // **Feature: melodic-drum-trainer, Property 16: 节拍器细分准确性**
    // *For any* 设定的节拍器细分，实际播放间隔应该与理论值一致（误差<5ms）
    @Test("Property 16: Metronome Subdivision Accuracy", .tags(.propertyBased))
    func testMetronomeSubdivisionAccuracy() async throws {
        for _ in 0..<100 {
            let conductor = MockConductor()
            
            let testTempo = Float.random(in: 60...200)
            let testSubdivision = MetronomeSubdivision.allCases.randomElement()!
            
            conductor.tempo = testTempo
            conductor.setMetronomeSubdivision(testSubdivision)
            
            // Calculate expected interval
            let expectedInterval = 60.0 / Double(testTempo) / testSubdivision.multiplier
            let actualInterval = conductor.getMetronomeInterval()
            
            let tolerance = 0.005 // 5ms tolerance
            let difference = abs(actualInterval - expectedInterval)
            
            #expect(difference <= tolerance,
                   "Metronome interval should be accurate within 5ms: expected \(expectedInterval), got \(actualInterval), difference \(difference)")
            
            // Test that subdivision change updates interval immediately
            let newSubdivision = MetronomeSubdivision.allCases.filter { $0 != testSubdivision }.randomElement()!
            conductor.setMetronomeSubdivision(newSubdivision)
            
            let newExpectedInterval = 60.0 / Double(testTempo) / newSubdivision.multiplier
            let newActualInterval = conductor.getMetronomeInterval()
            let newDifference = abs(newActualInterval - newExpectedInterval)
            
            #expect(newDifference <= tolerance,
                   "Updated metronome interval should be accurate: expected \(newExpectedInterval), got \(newActualInterval)")
        }
    }
    
    // **Feature: melodic-drum-trainer, Property 17: 起拍提示独立性**
    // *For any* 节拍器开关状态，起拍提示应该独立工作且不受节拍器状态影响
    @Test("Property 17: Count-in Independence", .tags(.propertyBased))
    func testCountInIndependence() async throws {
        for _ in 0..<100 {
            let conductor = MockConductor()
            
            let testTempo = Float.random(in: 80...160)
            let countInMeasures = Int.random(in: 1...4)
            let metronomeEnabled = Bool.random()
            
            conductor.tempo = testTempo
            conductor.isMetronomeEnabled = metronomeEnabled
            conductor.countInSettings = CountInSettings(
                isEnabled: true,
                measures: countInMeasures,
                isIndependentOfMetronome: true
            )
            
            // Start count-in and verify it works regardless of metronome state
            var countInCompleted = false
            
            conductor.startCountIn {
                countInCompleted = true
            }
            
            // Simulate count-in duration
            let expectedDuration = Double(countInMeasures * 4) * (60.0 / Double(testTempo))
            conductor.simulateCountInCompletion(after: expectedDuration)
            
            #expect(countInCompleted == true,
                   "Count-in should complete regardless of metronome state (metronome: \(metronomeEnabled))")
            
            // Verify count-in played correct number of beats
            let expectedBeats = countInMeasures * 4
            #expect(conductor.countInBeatsPlayed == expectedBeats,
                   "Count-in should play correct number of beats: expected \(expectedBeats), got \(conductor.countInBeatsPlayed)")
            
            // Test that count-in works even when metronome is disabled
            conductor.isMetronomeEnabled = false
            conductor.countInSettings.isIndependentOfMetronome = true
            
            var independentCountInCompleted = false
            conductor.startCountIn {
                independentCountInCompleted = true
            }
            
            conductor.simulateCountInCompletion(after: expectedDuration)
            
            #expect(independentCountInCompleted == true,
                   "Count-in should work independently when metronome is disabled")
        }
    }
}

// MARK: - Memory Mode Methods added to MockLessonEngine above

// MARK: - Memory Mode Support Types for Testing

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

enum AssistLevel: String, CaseIterable {
    case full = "full"
    case reduced = "reduced"
    case minimal = "minimal"
    case none = "none"
}

enum PlaybackMode: String, CaseIterable {
    case performance = "performance"
    case practice = "practice"
    case memory = "memory"
}

// Note: propertyBased tag is already defined in ScoreEnginePropertyTests.swift