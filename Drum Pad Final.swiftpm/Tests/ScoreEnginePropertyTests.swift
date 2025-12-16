import Testing
import Foundation
@testable import DrumPadApp

// MARK: - Test Data Generators

struct ScoreEngineTestGenerators {
    
    static func generateMIDIEvent(noteRange: ClosedRange<Int> = 24...127, 
                                 velocityRange: ClosedRange<Int> = 1...127,
                                 timestampRange: ClosedRange<TimeInterval> = 0...10) -> MIDIEvent {
        return MIDIEvent(
            timestamp: TimeInterval.random(in: timestampRange),
            noteNumber: Int.random(in: noteRange),
            velocity: Int.random(in: velocityRange),
            channel: Int.random(in: 0...15)
        )
    }
    
    static func generateTargetEvent(noteRange: ClosedRange<Int> = 24...127,
                                   timestampRange: ClosedRange<TimeInterval> = 0...10) -> TargetEvent {
        let laneIds = ["KICK", "SNARE", "HI HAT", "OPEN HI HAT", "CLAP", "LO TOM", "HI TOM", "CRASH"]
        return TargetEvent(
            timestamp: TimeInterval.random(in: timestampRange),
            laneId: laneIds.randomElement()!,
            noteNumber: Int.random(in: noteRange),
            velocity: Int.random(in: 1...127),
            duration: TimeInterval.random(in: 0.1...2.0)
        )
    }
    
    static func generateTargetEventSequence(count: Int, 
                                          duration: TimeInterval = 10.0,
                                          noteRange: ClosedRange<Int> = 24...127) -> [TargetEvent] {
        var events: [TargetEvent] = []
        let timeStep = duration / TimeInterval(count)
        
        for i in 0..<count {
            let baseTime = TimeInterval(i) * timeStep
            let jitter = TimeInterval.random(in: -0.1...0.1)
            let timestamp = max(0, baseTime + jitter)
            
            events.append(TargetEvent(
                timestamp: timestamp,
                laneId: "LANE_\(i % 4)",
                noteNumber: Int.random(in: noteRange),
                velocity: Int.random(in: 1...127),
                duration: TimeInterval.random(in: 0.1...1.0)
            ))
        }
        
        return events.sorted { $0.timestamp < $1.timestamp }
    }
    
    static func generateScoringProfile() -> ScoringProfile {
        return ScoringProfile(
            perfectWindow: TimeInterval.random(in: 0.010...0.050),
            earlyWindow: TimeInterval.random(in: 0.030...0.100),
            lateWindow: TimeInterval.random(in: 0.030...0.100),
            missThreshold: TimeInterval.random(in: 0.080...0.200),
            extraPenalty: Float.random(in: 0.01...0.10),
            gradePenaltyMultiplier: Float.random(in: 0.5...2.0),
            streakBonus: Float.random(in: 0.005...0.020)
        )
    }
    
    static func generatePerfectUserInputs(for targets: [TargetEvent]) -> [MIDIEvent] {
        return targets.map { target in
            MIDIEvent(
                timestamp: target.timestamp,
                noteNumber: target.noteNumber,
                velocity: target.velocity ?? 100,
                channel: 0
            )
        }
    }
    
    static func generateUserInputsWithTiming(for targets: [TargetEvent], 
                                           timingOffset: TimeInterval) -> [MIDIEvent] {
        return targets.map { target in
            MIDIEvent(
                timestamp: target.timestamp + timingOffset,
                noteNumber: target.noteNumber,
                velocity: target.velocity ?? 100,
                channel: 0
            )
        }
    }
}

// MARK: - Property Tests for Scoring Engine

@Suite("Score Engine Property Tests")
struct ScoreEnginePropertyTests {
    
    // **Feature: melodic-drum-trainer, Property 8: 实时判定准确性**
    // *For any* 用户输入的MIDI事件，时间判定结果应该基于预定义的时间窗口准确分类
    @Test("Property 8: Real-time Timing Judgment Accuracy", .tags(.propertyBased))
    func testTimingJudgmentAccuracy() async throws {
        for _ in 0..<100 {
            let scoreEngine = ScoreEngine()
            let profile = ScoreEngineTestGenerators.generateScoringProfile()
            let targetEvent = ScoreEngineTestGenerators.generateTargetEvent()
            
            scoreEngine.setScoringProfile(profile)
            scoreEngine.setTargetEvents([targetEvent])
            scoreEngine.startScoring()
            
            // Test perfect timing
            let perfectEvent = MIDIEvent(
                timestamp: targetEvent.timestamp,
                noteNumber: targetEvent.noteNumber,
                velocity: 100,
                channel: 0
            )
            let perfectFeedback = scoreEngine.getTimingFeedback(for: perfectEvent)
            #expect(perfectFeedback == .perfect, "Perfect timing should be classified as perfect")
            
            // Test early timing
            let earlyOffset = -profile.perfectWindow - 0.001
            let earlyEvent = MIDIEvent(
                timestamp: targetEvent.timestamp + earlyOffset,
                noteNumber: targetEvent.noteNumber,
                velocity: 100,
                channel: 0
            )
            let earlyFeedback = scoreEngine.getTimingFeedback(for: earlyEvent)
            if abs(earlyOffset) <= profile.earlyWindow {
                #expect(earlyFeedback == .early, "Early timing within window should be classified as early")
            } else {
                #expect(earlyFeedback == .miss, "Early timing outside window should be classified as miss")
            }
            
            // Test late timing
            let lateOffset = profile.perfectWindow + 0.001
            let lateEvent = MIDIEvent(
                timestamp: targetEvent.timestamp + lateOffset,
                noteNumber: targetEvent.noteNumber,
                velocity: 100,
                channel: 0
            )
            let lateFeedback = scoreEngine.getTimingFeedback(for: lateEvent)
            if abs(lateOffset) <= profile.lateWindow {
                #expect(lateFeedback == .late, "Late timing within window should be classified as late")
            } else {
                #expect(lateFeedback == .miss, "Late timing outside window should be classified as miss")
            }
        }
    }
    
    // **Feature: melodic-drum-trainer, Property 9: 评分计算一致性**
    // *For any* 相同的演奏输入序列，在相同配置下应该产生相同的分数结果
    @Test("Property 9: Score Calculation Consistency", .tags(.propertyBased))
    func testScoreCalculationConsistency() async throws {
        for _ in 0..<100 {
            let profile = ScoreEngineTestGenerators.generateScoringProfile()
            let targetEvents = ScoreEngineTestGenerators.generateTargetEventSequence(count: Int.random(in: 5...20))
            let userInputs = ScoreEngineTestGenerators.generatePerfectUserInputs(for: targetEvents)
            
            // First calculation
            let scoreEngine1 = ScoreEngine()
            scoreEngine1.setScoringProfile(profile)
            scoreEngine1.setTargetEvents(targetEvents)
            scoreEngine1.startScoring()
            
            for input in userInputs {
                scoreEngine1.processUserInput(input, at: input.timestamp)
            }
            let result1 = scoreEngine1.calculateScore()
            
            // Second calculation with same inputs
            let scoreEngine2 = ScoreEngine()
            scoreEngine2.setScoringProfile(profile)
            scoreEngine2.setTargetEvents(targetEvents)
            scoreEngine2.startScoring()
            
            for input in userInputs {
                scoreEngine2.processUserInput(input, at: input.timestamp)
            }
            let result2 = scoreEngine2.calculateScore()
            
            #expect(abs(result1.totalScore - result2.totalScore) < 0.001, 
                   "Same inputs should produce same score: \(result1.totalScore) vs \(result2.totalScore)")
            #expect(result1.starRating == result2.starRating, 
                   "Same inputs should produce same star rating")
            #expect(result1.perfectCount == result2.perfectCount, 
                   "Same inputs should produce same perfect count")
        }
    }
    
    // **Feature: melodic-drum-trainer, Property 19: 连击计数准确性**
    // *For any* 连续的Perfect音符序列，当达到4个时应该触发连击提示
    @Test("Property 19: Streak Count Accuracy", .tags(.propertyBased))
    func testStreakCountAccuracy() async throws {
        for _ in 0..<100 {
            let scoreEngine = ScoreEngine()
            let profile = ScoringProfile.defaultProfile()
            
            // Generate a sequence of target events
            let streakLength = Int.random(in: 4...10)
            let targetEvents = ScoreEngineTestGenerators.generateTargetEventSequence(count: streakLength)
            
            scoreEngine.setScoringProfile(profile)
            scoreEngine.setTargetEvents(targetEvents)
            scoreEngine.startScoring()
            
            // Process perfect inputs to build streak
            var currentStreak = 0
            for (index, target) in targetEvents.enumerated() {
                let perfectInput = MIDIEvent(
                    timestamp: target.timestamp,
                    noteNumber: target.noteNumber,
                    velocity: 100,
                    channel: 0
                )
                
                scoreEngine.processUserInput(perfectInput, at: perfectInput.timestamp)
                currentStreak += 1
                
                let reportedStreak = scoreEngine.currentStreak
                #expect(reportedStreak == currentStreak, 
                       "Streak count should match expected: \(reportedStreak) vs \(currentStreak) at index \(index)")
                
                if currentStreak >= 4 {
                    #expect(reportedStreak >= 4, "Streak should be at least 4 when 4+ perfect hits achieved")
                }
            }
            
            // Verify final result
            let result = scoreEngine.calculateScore()
            #expect(result.maxStreak >= 4, "Max streak should be at least 4 for perfect sequence")
            #expect(result.perfectCount == streakLength, "All hits should be perfect")
        }
    }
    
    // **Feature: melodic-drum-trainer, Property 20: 错误惩罚一致性**
    // *For any* 错误音符输入，扣分应该根据当前难度等级应用相应的惩罚权重
    @Test("Property 20: Error Penalty Consistency", .tags(.propertyBased))
    func testErrorPenaltyConsistency() async throws {
        for _ in 0..<100 {
            let scoreEngine = ScoreEngine()
            let profile = ScoreEngineTestGenerators.generateScoringProfile()
            let targetEvents = ScoreEngineTestGenerators.generateTargetEventSequence(count: 5)
            
            scoreEngine.setScoringProfile(profile)
            scoreEngine.setTargetEvents(targetEvents)
            scoreEngine.startScoring()
            
            // Add some perfect hits
            for target in targetEvents.prefix(3) {
                let perfectInput = MIDIEvent(
                    timestamp: target.timestamp,
                    noteNumber: target.noteNumber,
                    velocity: 100,
                    channel: 0
                )
                scoreEngine.processUserInput(perfectInput, at: perfectInput.timestamp)
            }
            
            let scoreAfterPerfect = scoreEngine.currentScore
            
            // Add extra hits (errors)
            let extraHitCount = Int.random(in: 1...3)
            for i in 0..<extraHitCount {
                let extraInput = MIDIEvent(
                    timestamp: TimeInterval(i) * 0.1,
                    noteNumber: 999, // Invalid note that won't match any target
                    velocity: 100,
                    channel: 0
                )
                scoreEngine.processUserInput(extraInput, at: extraInput.timestamp)
            }
            
            let result = scoreEngine.calculateScore()
            let expectedPenalty = Float(extraHitCount) * profile.extraPenalty * 100.0
            
            #expect(result.extraCount == extraHitCount, 
                   "Extra count should match number of extra hits")
            
            // Score should be reduced by penalty (allowing for some calculation variance)
            let actualPenalty = scoreAfterPerfect - result.totalScore
            #expect(abs(actualPenalty - expectedPenalty) < 10.0, 
                   "Penalty should be consistent with profile: expected \(expectedPenalty), actual \(actualPenalty)")
        }
    }
}

// MARK: - Test Tags

extension Tag {
    @Tag static var propertyBased: Self
}