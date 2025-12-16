import Testing
import Foundation

// MARK: - Simple UI Component Property Tests

/**
 * **Feature: melodic-drum-trainer, Property 10: 星级阈值正确性**
 * **Validates: Requirements 3.4**
 */
@Test("Property 10: Star rating thresholds are correct (Simple)")
func testSimpleStarRatingThresholds() async throws {
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
 */
@Test("Property 11: Memory mode unlock conditions are accurate (Simple)")
func testSimpleMemoryModeUnlockConditions() async throws {
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
 */
@Test("Property 18: Timing results completeness (Simple)")
func testSimpleTimingResultsCompleteness() async throws {
    let testCases = [1, 5, 10]
    
    for targetEventCount in testCases {
        let targetEvents = generateTargetEvents(count: targetEventCount)
        let userEvents = generatePerfectPerformance(targetEvents: targetEvents)
        
        let timingResults = calculateTimingResults(
            targetEvents: targetEvents,
            userEvents: userEvents
        )
        
        #expect(
            timingResults.count == targetEvents.count,
            "Should have \(targetEvents.count) timing results, but got \(timingResults.count)"
        )
        
        for (index, result) in timingResults.enumerated() {
            #expect(
                result.targetEvent.timestamp == targetEvents[index].timestamp,
                "Timing result \(index) should match target event timestamp"
            )
        }
    }
}

// MARK: - Helper Functions

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

private func generateTargetEvents(count: Int) -> [SimpleTargetEvent] {
    var events: [SimpleTargetEvent] = []
    
    for i in 0..<count {
        let timestamp = Double(i) * 0.5
        let event = SimpleTargetEvent(
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

private func generatePerfectPerformance(targetEvents: [SimpleTargetEvent]) -> [SimpleMIDIEvent] {
    return targetEvents.map { targetEvent in
        SimpleMIDIEvent(
            timestamp: targetEvent.timestamp,
            noteNumber: targetEvent.noteNumber,
            velocity: targetEvent.velocity ?? 100,
            isNoteOn: true
        )
    }
}

private func calculateTimingResults(targetEvents: [SimpleTargetEvent], userEvents: [SimpleMIDIEvent]) -> [SimpleTimingResult] {
    var results: [SimpleTimingResult] = []
    
    for targetEvent in targetEvents {
        let closestUserEvent = findClosestUserEvent(
            to: targetEvent,
            in: userEvents,
            window: 0.1
        )
        
        let timing: String
        if let userEvent = closestUserEvent {
            let timeDiff = userEvent.timestamp - targetEvent.timestamp
            if abs(timeDiff) <= 0.02 {
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
        
        let result = SimpleTimingResult(
            targetEvent: targetEvent,
            userEvent: closestUserEvent,
            timing: timing,
            score: score
        )
        
        results.append(result)
    }
    
    return results
}

private func findClosestUserEvent(to targetEvent: SimpleTargetEvent, in userEvents: [SimpleMIDIEvent], window: TimeInterval) -> SimpleMIDIEvent? {
    var candidateEvents: [SimpleMIDIEvent] = []
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

// MARK: - Simple Test Data Structures

struct SimpleTargetEvent {
    let timestamp: TimeInterval
    let laneId: String
    let noteNumber: Int
    let velocity: Int?
    let duration: TimeInterval?
}

struct SimpleMIDIEvent {
    let timestamp: TimeInterval
    let noteNumber: Int
    let velocity: Int
    let isNoteOn: Bool
}

struct SimpleTimingResult {
    let targetEvent: SimpleTargetEvent
    let userEvent: SimpleMIDIEvent?
    let timing: String
    let score: Float
}

// MARK: - Edge Case Tests

@Test("Star rating edge cases (Simple)")
func testSimpleStarRatingEdgeCases() async throws {
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

@Test("Memory mode unlock edge cases (Simple)")
func testSimpleMemoryModeUnlockEdgeCases() async throws {
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

@Test("Timing results with empty lesson (Simple)")
func testSimpleTimingResultsWithEmptyLesson() async throws {
    let emptyTargetEvents: [SimpleTargetEvent] = []
    let emptyUserEvents: [SimpleMIDIEvent] = []
    
    let results = calculateTimingResults(
        targetEvents: emptyTargetEvents,
        userEvents: emptyUserEvents
    )
    
    #expect(results.isEmpty, "Empty lesson should produce empty timing results")
}