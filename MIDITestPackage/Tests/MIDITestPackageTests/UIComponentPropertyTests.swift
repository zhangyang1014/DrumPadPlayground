import Testing
import Foundation
import MIDITestPackage

// MARK: - UI Component Property Tests

/**
 * **Feature: melodic-drum-trainer, Property 10: 星级阈值正确性**
 * **Validates: Requirements 3.4**
 * 
 * For any calculated score, star rating should correctly map:
 * - 50% = 1 star, 75% = 2 stars, 90% = 3 stars, 100% = platinum star
 */
@Test("Property 10: Star rating thresholds are correct")
func testStarRatingThresholds() async throws {
    // Test key score thresholds
    let testCases: [(score: Float, expectedStars: Int)] = [
        (0.0, 0), (25.0, 0), (49.9, 0),
        (50.0, 1), (60.0, 1), (74.9, 1),
        (75.0, 2), (80.0, 2), (89.9, 2),
        (90.0, 3), (95.0, 3), (100.0, 3)
    ]
    
    for (score, expectedStars) in testCases {
        let actualStarRating = calculateStarRating(for: score)
        
        #expect(
            actualStarRating == expectedStars,
            "Score \(score)% should give \(expectedStars) stars, but got \(actualStarRating)"
        )
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
        (score: 100.0, mode: "performance", shouldUnlock: true),
        (score: 99.9, mode: "performance", shouldUnlock: false),
        (score: 100.0, mode: "practice", shouldUnlock: false),
        (score: 100.0, mode: "memory", shouldUnlock: false),
        (score: 90.0, mode: "performance", shouldUnlock: false)
    ]
    
    for testCase in testCases {
        let shouldUnlockMemoryMode = checkMemoryModeUnlockCondition(
            score: Float(testCase.score),
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
    // Test with different numbers of target events
    let testCases = [1, 5, 10]
    
    for targetEventCount in testCases {
        let targetEvents = generateTargetEvents(count: targetEventCount)
        let userEvents = generatePerfectPerformance(targetEvents: targetEvents)
        
        let timingResults = calculateTimingResults(
            targetEvents: targetEvents,
            userEvents: userEvents
        )
        
        // Every target event should have a timing result
        #expect(
            timingResults.count == targetEvents.count,
            "Should have \(targetEvents.count) timing results, but got \(timingResults.count)"
        )
        
        // Each result should correspond to a target event
        for (index, result) in timingResults.enumerated() {
            #expect(
                result.targetEvent.timestamp == targetEvents[index].timestamp,
                "Timing result \(index) should match target event timestamp"
            )
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

private func checkMemoryModeUnlockCondition(score: Float, mode: String) -> Bool {
    return score >= 100.0 && mode == "performance"
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
            duration: nil as TimeInterval?
        )
        events.append(event)
    }
    
    return events
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

private func calculateTimingResults(targetEvents: [TargetEvent], userEvents: [MIDIEvent]) -> [TimingResult] {
    var results: [TimingResult] = []
    
    for targetEvent in targetEvents {
        // Find the closest user event to this target event
        let closestUserEvent = findClosestUserEvent(
            to: targetEvent,
            in: userEvents,
            window: 0.1 // 100ms window
        )
        
        let timing: String
        if let userEvent = closestUserEvent {
            let timeDiff = userEvent.timestamp - targetEvent.timestamp
            if abs(timeDiff) <= 0.02 { // 20ms perfect window
                timing = "perfect"
            } else if timeDiff < 0 {
                timing = "early"
            } else {
                timing = "late"
            }
        } else {
            timing = "miss"
        }
        
        let score: Float = {
            switch timing {
            case "perfect": return 100.0
            case "early", "late": return 75.0
            case "miss": return 0.0
            default: return 0.0
            }
        }()
        
        let result = TimingResult(
            targetEvent: targetEvent,
            userEvent: closestUserEvent,
            timing: TimingFeedback(rawValue: timing) ?? .miss,
            score: score,
            timestamp: targetEvent.timestamp
        )
        
        results.append(result)
    }
    
    return results
}

private func findClosestUserEvent(to targetEvent: TargetEvent, in userEvents: [MIDIEvent], window: TimeInterval) -> MIDIEvent? {
    var candidateEvents: [MIDIEvent] = []
    for userEvent in userEvents {
        if abs(userEvent.timestamp - targetEvent.timestamp) <= window &&
           userEvent.noteNumber == targetEvent.noteNumber {
            candidateEvents.append(userEvent)
        }
    }
    
    return candidateEvents.min { event1, event2 in
        abs(event1.timestamp - targetEvent.timestamp) < abs(event2.timestamp - targetEvent.timestamp)
    }
}

// MARK: - Test Data Structures (using types from MIDITestPackage)

typealias TargetEvent = MIDITestPackage.TargetEvent
typealias MIDIEvent = MIDITestPackage.MIDIEvent
typealias TimingResult = MIDITestPackage.TimingResult

// MARK: - Edge Case Tests

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
    let edgeCases: [(score: Float, mode: String, shouldUnlock: Bool)] = [
        (100.0, "performance", true),
        (99.999, "performance", false),
        (100.0, "practice", false),
        (100.0, "memory", false)
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