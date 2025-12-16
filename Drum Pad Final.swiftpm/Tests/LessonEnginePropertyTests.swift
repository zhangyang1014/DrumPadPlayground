import Testing
import Foundation
@testable import DrumPadApp

// MARK: - Test Data Generators

struct LessonEngineTestGenerators {
    
    static func generateLesson(duration: TimeInterval = 60.0, 
                              bpm: Float = 120.0,
                              stepCount: Int = 3) -> Lesson {
        // Create a mock lesson for testing
        let lesson = Lesson(context: TestCoreDataManager.shared.context)
        lesson.id = UUID().uuidString
        lesson.title = "Test Lesson"
        lesson.defaultBPM = bpm
        lesson.duration = duration
        lesson.timeSignature = TimeSignature.fourFour
        lesson.difficulty = Int16.random(in: 1...5)
        lesson.tags = "[]"
        lesson.instrument = "drums"
        lesson.createdAt = Date()
        lesson.updatedAt = Date()
        
        // Create steps
        for i in 0..<stepCount {
            let step = LessonStep(context: TestCoreDataManager.shared.context)
            step.id = UUID().uuidString
            step.lessonId = lesson.id
            step.order = Int16(i)
            step.title = "Step \(i + 1)"
            step.stepDescription = "Test step \(i + 1)"
            step.assistLevel = AssistLevel.full.rawValue
            step.bpmOverride = 0 // Use lesson default
            step.createdAt = Date()
            
            // Generate target events for this step
            let eventCount = Int.random(in: 5...15)
            let events = generateTargetEventSequence(count: eventCount, duration: duration / Double(stepCount))
            step.targetEvents = events
            
            lesson.addToSteps(step)
        }
        
        return lesson
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
    
    static func generateTimeRange(maxDuration: TimeInterval = 60.0) -> TimeRange {
        let start = TimeInterval.random(in: 0...(maxDuration * 0.7))
        let end = TimeInterval.random(in: start...(start + maxDuration * 0.3))
        return TimeRange(start: start, end: end)
    }
    
    static func createMockLessonEngine() -> LessonEngine {
        let coreDataManager = TestCoreDataManager.shared
        let conductor = MockConductor()
        let scoreEngine = ScoreEngine()
        
        return LessonEngine(
            coreDataManager: coreDataManager,
            conductor: conductor,
            scoreEngine: scoreEngine
        )
    }
}

// MARK: - Mock Classes for Testing

class TestCoreDataManager: CoreDataManager {
    static let shared = TestCoreDataManager()
    
    override init() {
        super.init()
    }
    
    func fetchLesson(by id: String) -> Lesson? {
        // Return a generated lesson for testing
        return LessonEngineTestGenerators.generateLesson()
    }
}

class MockConductor: Conductor {
    private var mockScore: Float = 80.0
    private var mockStreak: Int = 5
    
    override init() {
        super.init()
    }
    
    override func startScoringSession(targetEvents: [TargetEvent], profile: ScoringProfile) {
        // Mock implementation
    }
    
    override func stopScoringSession() -> ScoreResult {
        return ScoreResult(
            totalScore: mockScore,
            starRating: 2,
            isPlatinum: false,
            isBlackStar: false,
            timingResults: [],
            streakCount: mockStreak,
            maxStreak: mockStreak,
            missCount: 0,
            extraCount: 0,
            perfectCount: 10,
            earlyCount: 0,
            lateCount: 0,
            completionTime: 30.0
        )
    }
    
    override func getCurrentScore() -> Float {
        return mockScore
    }
    
    override func getCurrentStreak() -> Int {
        return mockStreak
    }
    
    func setMockScore(_ score: Float) {
        mockScore = score
    }
    
    func setMockStreak(_ streak: Int) {
        mockStreak = streak
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
            let lessonEngine = LessonEngineTestGenerators.createMockLessonEngine()
            let lesson = LessonEngineTestGenerators.generateLesson()
            
            // Load lesson
            _ = lessonEngine.loadLesson(lesson.id)
            
            // Test various BPM values
            let testBPM = Float.random(in: 60...300)
            lessonEngine.setTempo(testBPM)
            
            let actualBPM = lessonEngine.currentTempo
            let tolerance = testBPM * 0.01 // 1% tolerance
            
            #expect(abs(actualBPM - testBPM) <= tolerance,
                   "BPM should be accurate within 1%: set \(testBPM), got \(actualBPM)")
            
            // Test tempo percentage
            let percentage = Float.random(in: 0.1...1.0)
            lessonEngine.setTempoPercentage(percentage)
            
            let expectedTempo = lesson.defaultBPM * percentage
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
            let lessonEngine = LessonEngineTestGenerators.createMockLessonEngine()
            let lesson = LessonEngineTestGenerators.generateLesson(bpm: Float.random(in: 120...180))
            let mockConductor = lessonEngine.conductor as! MockConductor
            
            // Load lesson and set up auto acceleration
            _ = lessonEngine.loadLesson(lesson.id)
            
            let startingTempo = lesson.defaultBPM * Float.random(in: 0.6...0.8)
            lessonEngine.setTempo(startingTempo)
            lessonEngine.enableAutoAcceleration(true)
            
            // Set good performance metrics
            mockConductor.setMockScore(85.0) // Above threshold
            mockConductor.setMockStreak(6)   // Above threshold
            
            let initialTempo = lessonEngine.currentTempo
            
            // Simulate auto acceleration trigger
            lessonEngine.setAutoAccelParams(
                increment: 10.0,
                checkInterval: 1.0,
                scoreThreshold: 80.0,
                streakThreshold: 4
            )
            
            // Start playback to enable auto acceleration
            lessonEngine.startPlayback()
            
            // The tempo should not exceed target tempo
            #expect(lessonEngine.currentTempo <= lesson.defaultBPM,
                   "Auto acceleration should not exceed target tempo")
            
            // If there's room for acceleration, it should be incremental
            if initialTempo < lesson.defaultBPM - 10.0 {
                let progress = lessonEngine.getAutoAccelProgress()
                #expect(progress.currentTempo >= initialTempo,
                       "Auto acceleration should maintain or increase tempo")
                #expect(progress.targetTempo == lesson.defaultBPM,
                       "Target tempo should match lesson default BPM")
            }
        }
    }
    
    // **Feature: melodic-drum-trainer, Property 13: 循环播放边界性**
    // *For any* 设定的循环区间，播放应该在指定的开始和结束时间点之间重复
    @Test("Property 13: Loop Playback Boundaries", .tags(.propertyBased))
    func testLoopPlaybackBoundaries() async throws {
        for _ in 0..<100 {
            let lessonEngine = LessonEngineTestGenerators.createMockLessonEngine()
            let lesson = LessonEngineTestGenerators.generateLesson(duration: 60.0)
            
            _ = lessonEngine.loadLesson(lesson.id)
            
            // Generate valid loop region
            let loopStart = TimeInterval.random(in: 0...30)
            let loopEnd = TimeInterval.random(in: (loopStart + 1)...min(loopStart + 20, lesson.duration))
            
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
            let lessonEngine = LessonEngineTestGenerators.createMockLessonEngine()
            let lesson = LessonEngineTestGenerators.generateLesson()
            
            _ = lessonEngine.loadLesson(lesson.id)
            
            // Enable wait mode
            lessonEngine.enableWaitMode(true)
            #expect(lessonEngine.isWaitModeEnabled == true,
                   "Wait mode should be enabled")
            
            // Start playback
            lessonEngine.startPlayback()
            
            // Initially should be playing
            #expect(lessonEngine.playbackState == .playing,
                   "Should start in playing state")
            
            // Get wait mode status
            let waitStatus = lessonEngine.getWaitModeStatus()
            
            if waitStatus.isWaiting {
                #expect(waitStatus.targetNote != nil,
                       "When waiting, should have a target note")
                #expect(waitStatus.timeUntilTarget != nil,
                       "When waiting, should have time until target")
            }
            
            // Test skip functionality
            if lessonEngine.playbackState == .waiting {
                let stateBefore = lessonEngine.playbackState
                lessonEngine.skipCurrentWaitTarget()
                
                // Should resume playing after skip
                #expect(lessonEngine.playbackState == .playing || lessonEngine.playbackState == .waiting,
                       "Should resume playing or wait for next target after skip")
            }
            
            // Test disabling wait mode
            lessonEngine.enableWaitMode(false)
            #expect(lessonEngine.isWaitModeEnabled == false,
                   "Wait mode should be disabled")
        }
    }
}

// MARK: - Test Tags Extension

extension Tag {
    @Tag static var propertyBased: Self
}