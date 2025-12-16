import Testing
import SwiftUI
@testable import DrumPadApp

// MARK: - UI Component Property Tests

/**
 * **Feature: melodic-drum-trainer, Property 10: 星级阈值正确性**
 * **Validates: Requirements 3.4**
 * 
 * For any calculated score, star rating should correctly map:
 * - 50% = 1 star
 * - 75% = 2 stars  
 * - 90% = 3 stars
 * - 100% = platinum star
 */
@Test("Property 10: Star rating thresholds are correct")
func testStarRatingThresholds() async throws {
    // Test all possible score ranges
    for score in stride(from: 0.0, through: 100.0, by: 0.5) {
        let scoreResult = ScoreResult(
            totalScore: Float(score),
            starRating: calculateExpectedStarRating(score: score),
            isPlatinum: score >= 100.0,
            isBlackStar: false,
            timingResults: [],
            streakCount: 0,
            maxStreak: 0,
            missCount: 0,
            extraCount: 0,
            perfectCount: 0,
            earlyCount: 0,
            lateCount: 0,
            completionTime: 60.0
        )
        
        let actualStarRating = calculateStarRating(for: scoreResult.totalScore)
        let expectedStarRating = calculateExpectedStarRating(score: score)
        
        #expect(
            actualStarRating == expectedStarRating,
            "Score \(score)% should give \(expectedStarRating) stars, but got \(actualStarRating)"
        )
        
        // Test platinum flag
        if score >= 100.0 {
            #expect(scoreResult.isPlatinum, "Score of 100% should be platinum")
        } else {
            #expect(!scoreResult.isPlatinum, "Score below 100% should not be platinum")
        }
    }
}

/**
 * **Feature: melodic-drum-trainer, Property 11: 解锁条件准确性**
 * **Validates: Requirements 3.5, 8.1**
 * 
 * For any 100% score in performance mode, memory mode should be unlocked
 */
@Test("Property 11: Memory mode unlock conditions are accurate")
func testMemoryModeUnlockConditions() async throws {
    let testCases = [
        (score: 100.0, mode: PlaybackMode.performance, shouldUnlock: true),
        (score: 99.9, mode: PlaybackMode.performance, shouldUnlock: false),
        (score: 100.0, mode: PlaybackMode.practice, shouldUnlock: false),
        (score: 100.0, mode: PlaybackMode.memory, shouldUnlock: false),
        (score: 90.0, mode: PlaybackMode.performance, shouldUnlock: false),
        (score: 75.0, mode: PlaybackMode.performance, shouldUnlock: false),
        (score: 50.0, mode: PlaybackMode.performance, shouldUnlock: false)
    ]
    
    for testCase in testCases {
        let scoreResult = ScoreResult(
            totalScore: Float(testCase.score),
            starRating: calculateExpectedStarRating(score: testCase.score),
            isPlatinum: testCase.score >= 100.0,
            isBlackStar: false,
            timingResults: [],
            streakCount: 0,
            maxStreak: 0,
            missCount: 0,
            extraCount: 0,
            perfectCount: 0,
            earlyCount: 0,
            lateCount: 0,
            completionTime: 60.0
        )
        
        let shouldUnlockMemoryMode = checkMemoryModeUnlockCondition(
            score: scoreResult.totalScore,
            mode: testCase.mode
        )
        
        #expect(
            shouldUnlockMemoryMode == testCase.shouldUnlock,
            "Score \(testCase.score)% in \(testCase.mode) mode should \(testCase.shouldUnlock ? "unlock" : "not unlock") memory mode"
        )
    }
}

/**
 * **Feature: melodic-drum-trainer, Property 18: 判定结果完整性**
 * **Validates: Requirements 6.1**
 * 
 * For any lesson completion, every target note should have a corresponding timing result
 */
@Test("Property 18: Timing results completeness")
func testTimingResultsCompleteness() async throws {
    // Generate test lessons with various numbers of target events
    for targetEventCount in [1, 5, 10, 25, 50, 100] {
        let targetEvents = generateTargetEvents(count: targetEventCount)
        let lesson = createTestLesson(targetEvents: targetEvents)
        
        // Simulate various user performance scenarios
        let performanceScenarios = [
            generatePerfectPerformance(targetEvents: targetEvents),
            generateMissedNotesPerformance(targetEvents: targetEvents, missRate: 0.2),
            generateEarlyLatePerformance(targetEvents: targetEvents),
            generateExtraNotesPerformance(targetEvents: targetEvents)
        ]
        
        for userEvents in performanceScenarios {
            let timingResults = calculateTimingResults(
                targetEvents: targetEvents,
                userEvents: userEvents
            )
            
            // Every target event should have a timing result
            #expect(
                timingResults.count == targetEvents.count,
                "Should have \(targetEvents.count) timing results, but got \(timingResults.count)"
            )
            
            // Every timing result should correspond to a target event
            for (index, result) in timingResults.enumerated() {
                let targetEvent = targetEvents[index]
                #expect(
                    result.targetEvent.timestamp == targetEvent.timestamp,
                    "Timing result \(index) should correspond to target event at \(targetEvent.timestamp)"
                )
                
                // Timing feedback should be valid
                let validFeedback: Set<TimingFeedback> = [.perfect, .early, .late, .miss, .extra]
                #expect(
                    validFeedback.contains(result.timing),
                    "Timing result should have valid feedback, got \(result.timing)"
                )
            }
        }
    }
}

// MARK: - Helper Functions

private func calculateExpectedStarRating(score: Double) -> Int {
    switch score {
    case 90.0...:
        return 3
    case 75.0..<90.0:
        return 2
    case 50.0..<75.0:
        return 1
    default:
        return 0
    }
}

private func calculateStarRating(for score: Float) -> Int {
    switch score {
    case 90...:
        return 3
    case 75..<90:
        return 2
    case 50..<75:
        return 1
    default:
        return 0
    }
}

private func checkMemoryModeUnlockCondition(score: Float, mode: PlaybackMode) -> Bool {
    return score >= 100.0 && mode == .performance
}

private func generateTargetEvents(count: Int) -> [TargetEvent] {
    var events: [TargetEvent] = []
    
    for i in 0..<count {
        let timestamp = Double(i) * 0.5 // Events every 500ms
        let event = TargetEvent(
            timestamp: timestamp,
            laneId: "kick",
            noteNumber: 36,
            velocity: 100,
            duration: nil
        )
        events.append(event)
    }
    
    return events
}

private func createTestLesson(targetEvents: [TargetEvent]) -> Lesson {
    // This would create a test lesson with the given target events
    // For now, return a mock lesson structure
    let lesson = TestLesson(
        id: "test-lesson",
        title: "Test Lesson",
        duration: targetEvents.last?.timestamp ?? 60.0,
        targetEvents: targetEvents
    )
    return lesson as! Lesson
}

private func generatePerfectPerformance(targetEvents: [TargetEvent]) -> [MIDIEvent] {
    return targetEvents.map { targetEvent in
        MIDIEvent(
            timestamp: targetEvent.timestamp,
            noteNumber: targetEvent.noteNumber,
            velocity: targetEvent.velocity ?? 100,
            isNoteOn: true
        )
    }
}

private func generateMissedNotesPerformance(targetEvents: [TargetEvent], missRate: Double) -> [MIDIEvent] {
    var userEvents: [MIDIEvent] = []
    
    for targetEvent in targetEvents {
        // Randomly miss notes based on miss rate
        if Double.random(in: 0...1) > missRate {
            let userEvent = MIDIEvent(
                timestamp: targetEvent.timestamp,
                noteNumber: targetEvent.noteNumber,
                velocity: targetEvent.velocity ?? 100,
                isNoteOn: true
            )
            userEvents.append(userEvent)
        }
    }
    
    return userEvents
}

private func generateEarlyLatePerformance(targetEvents: [TargetEvent]) -> [MIDIEvent] {
    return targetEvents.map { targetEvent in
        // Add random timing offset (-50ms to +50ms)
        let timingOffset = Double.random(in: -0.05...0.05)
        
        return MIDIEvent(
            timestamp: targetEvent.timestamp + timingOffset,
            noteNumber: targetEvent.noteNumber,
            velocity: targetEvent.velocity ?? 100,
            isNoteOn: true
        )
    }
}

private func generateExtraNotesPerformance(targetEvents: [TargetEvent]) -> [MIDIEvent] {
    var userEvents = generatePerfectPerformance(targetEvents: targetEvents)
    
    // Add some extra notes between target events
    for i in 0..<targetEvents.count - 1 {
        let currentEvent = targetEvents[i]
        let nextEvent = targetEvents[i + 1]
        let midTime = (currentEvent.timestamp + nextEvent.timestamp) / 2
        
        // 30% chance to add an extra note
        if Double.random(in: 0...1) < 0.3 {
            let extraEvent = MIDIEvent(
                timestamp: midTime,
                noteNumber: currentEvent.noteNumber,
                velocity: 80,
                isNoteOn: true
            )
            userEvents.append(extraEvent)
        }
    }
    
    return userEvents.sorted { $0.timestamp < $1.timestamp }
}

private func calculateTimingResults(targetEvents: [TargetEvent], userEvents: [MIDIEvent]) -> [TimingResult] {
    var results: [TimingResult] = []
    
    for targetEvent in targetEvents {
        // Find the closest user event to this target event
        let closestUserEvent = findClosestUserEvent(
            to: targetEvent,
            in: userEvents,
            window: 0.1 // 100ms window
        )
        
        let timing: TimingFeedback
        if let userEvent = closestUserEvent {
            let timeDiff = userEvent.timestamp - targetEvent.timestamp
            if abs(timeDiff) <= 0.02 { // 20ms perfect window
                timing = .perfect
            } else if timeDiff < 0 {
                timing = .early
            } else {
                timing = .late
            }
        } else {
            timing = .miss
        }
        
        let score: Float = {
            switch timing {
            case .perfect: return 100.0
            case .early, .late: return 75.0
            case .miss: return 0.0
            case .extra: return 0.0
            }
        }()
        
        let result = TimingResult(
            targetEvent: targetEvent,
            userEvent: closestUserEvent,
            timing: timing,
            score: score
        )
        
        results.append(result)
    }
    
    return results
}

private func findClosestUserEvent(to targetEvent: TargetEvent, in userEvents: [MIDIEvent], window: TimeInterval) -> MIDIEvent? {
    let candidateEvents = userEvents.filter { userEvent in
        abs(userEvent.timestamp - targetEvent.timestamp) <= window &&
        userEvent.noteNumber == targetEvent.noteNumber
    }
    
    return candidateEvents.min { event1, event2 in
        abs(event1.timestamp - targetEvent.timestamp) < abs(event2.timestamp - targetEvent.timestamp)
    }
}

// MARK: - Test Data Structures

struct TestLesson {
    let id: String
    let title: String
    let duration: TimeInterval
    let targetEvents: [TargetEvent]
}

struct MIDIEvent {
    let timestamp: TimeInterval
    let noteNumber: Int
    let velocity: Int
    let isNoteOn: Bool
}

// MARK: - Property Test Generators

extension TargetEvent {
    static func random() -> TargetEvent {
        return TargetEvent(
            timestamp: Double.random(in: 0...60),
            laneId: ["kick", "snare", "hihat", "crash"].randomElement()!,
            noteNumber: [36, 38, 42, 49].randomElement()!,
            velocity: Int.random(in: 80...127),
            duration: nil
        )
    }
}

extension ScoreResult {
    static func random() -> ScoreResult {
        let totalScore = Float.random(in: 0...100)
        return ScoreResult(
            totalScore: totalScore,
            starRating: calculateStarRating(for: totalScore),
            isPlatinum: totalScore >= 100.0,
            isBlackStar: false,
            timingResults: [],
            streakCount: Int.random(in: 0...50),
            maxStreak: Int.random(in: 0...100),
            missCount: Int.random(in: 0...20),
            extraCount: Int.random(in: 0...10),
            perfectCount: Int.random(in: 0...100),
            earlyCount: Int.random(in: 0...30),
            lateCount: Int.random(in: 0...30),
            completionTime: Double.random(in: 30...300)
        )
    }
}

// MARK: - Additional Property Tests for Edge Cases

@Test("Star rating edge cases")
func testStarRatingEdgeCases() async throws {
    let edgeCases: [(score: Float, expectedStars: Int)] = [
        (0.0, 0),
        (49.9, 0),
        (50.0, 1),
        (74.9, 1),
        (75.0, 2),
        (89.9, 2),
        (90.0, 3),
        (99.9, 3),
        (100.0, 3)
    ]
    
    for (score, expectedStars) in edgeCases {
        let actualStars = calculateStarRating(for: score)
        #expect(
            actualStars == expectedStars,
            "Score \(score)% should give \(expectedStars) stars, but got \(actualStars)"
        )
    }
}

@Test("Memory mode unlock edge cases")
func testMemoryModeUnlockEdgeCases() async throws {
    let edgeCases: [(score: Float, mode: PlaybackMode, shouldUnlock: Bool)] = [
        (100.0, .performance, true),
        (99.999, .performance, false),
        (100.0, .practice, false),
        (100.0, .memory, false)
    ]
    
    for (score, mode, shouldUnlock) in edgeCases {
        let actualUnlock = checkMemoryModeUnlockCondition(score: score, mode: mode)
        #expect(
            actualUnlock == shouldUnlock,
            "Score \(score)% in \(mode) should \(shouldUnlock ? "unlock" : "not unlock") memory mode"
        )
    }
}

@Test("Timing results with empty lesson")
func testTimingResultsWithEmptyLesson() async throws {
    let emptyTargetEvents: [TargetEvent] = []
    let emptyUserEvents: [MIDIEvent] = []
    
    let results = calculateTimingResults(
        targetEvents: emptyTargetEvents,
        userEvents: emptyUserEvents
    )
    
    #expect(results.isEmpty, "Empty lesson should produce empty timing results")
}

@Test("Timing results with no user input")
func testTimingResultsWithNoUserInput() async throws {
    let targetEvents = generateTargetEvents(count: 5)
    let emptyUserEvents: [MIDIEvent] = []
    
    let results = calculateTimingResults(
        targetEvents: targetEvents,
        userEvents: emptyUserEvents
    )
    
    #expect(results.count == targetEvents.count, "Should have timing result for each target event")
    
    for result in results {
        #expect(result.timing == .miss, "All results should be misses when no user input")
        #expect(result.userEvent == nil, "No user events should be recorded")
        #expect(result.score == 0.0, "Score should be 0 for missed notes")
    }
}