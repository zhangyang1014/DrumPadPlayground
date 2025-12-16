import Foundation
import QuartzCore

// MARK: - Scoring Data Models for Testing

public struct TargetEvent: Codable, Identifiable {
    public let id = UUID()
    public let timestamp: TimeInterval
    public let laneId: String
    public let noteNumber: Int
    public let velocity: Int?
    public let duration: TimeInterval?
    
    public init(timestamp: TimeInterval, laneId: String, noteNumber: Int, velocity: Int?, duration: TimeInterval?) {
        self.timestamp = timestamp
        self.laneId = laneId
        self.noteNumber = noteNumber
        self.velocity = velocity
        self.duration = duration
    }
}

public struct MIDIEvent: Codable {
    public let timestamp: TimeInterval
    public let noteNumber: Int
    public let velocity: Int
    public let channel: Int
    
    public init(timestamp: TimeInterval, noteNumber: Int, velocity: Int, channel: Int) {
        self.timestamp = timestamp
        self.noteNumber = noteNumber
        self.velocity = velocity
        self.channel = channel
    }
}

public enum TimingFeedback: String, Codable, CaseIterable {
    case perfect = "perfect"
    case early = "early"
    case late = "late"
    case miss = "miss"
    case extra = "extra"
    
    public var displayName: String {
        switch self {
        case .perfect: return "Perfect"
        case .early: return "Early"
        case .late: return "Late"
        case .miss: return "Miss"
        case .extra: return "Extra"
        }
    }
    
    public var scoreMultiplier: Float {
        switch self {
        case .perfect: return 1.0
        case .early: return 0.8
        case .late: return 0.8
        case .miss: return 0.0
        case .extra: return 0.0
        }
    }
}

public struct TimingResult: Codable, Identifiable {
    public let id = UUID()
    public let targetEvent: TargetEvent
    public let userEvent: MIDIEvent?
    public let timing: TimingFeedback
    public let score: Float
    public let timestamp: TimeInterval
    
    public init(targetEvent: TargetEvent, userEvent: MIDIEvent?, timing: TimingFeedback, score: Float, timestamp: TimeInterval) {
        self.targetEvent = targetEvent
        self.userEvent = userEvent
        self.timing = timing
        self.score = score
        self.timestamp = timestamp
    }
}

public struct ScoreResult: Codable {
    public let totalScore: Float // 0-100
    public let starRating: Int // 1-3
    public let isPlatinum: Bool // 100% in Performance Mode
    public let isBlackStar: Bool // 100% in Memory Mode
    public let timingResults: [TimingResult]
    public let streakCount: Int
    public let maxStreak: Int
    public let missCount: Int
    public let extraCount: Int
    public let perfectCount: Int
    public let earlyCount: Int
    public let lateCount: Int
    public let completionTime: TimeInterval
    
    public init(totalScore: Float, starRating: Int, isPlatinum: Bool, isBlackStar: Bool, timingResults: [TimingResult], streakCount: Int, maxStreak: Int, missCount: Int, extraCount: Int, perfectCount: Int, earlyCount: Int, lateCount: Int, completionTime: TimeInterval) {
        self.totalScore = totalScore
        self.starRating = starRating
        self.isPlatinum = isPlatinum
        self.isBlackStar = isBlackStar
        self.timingResults = timingResults
        self.streakCount = streakCount
        self.maxStreak = maxStreak
        self.missCount = missCount
        self.extraCount = extraCount
        self.perfectCount = perfectCount
        self.earlyCount = earlyCount
        self.lateCount = lateCount
        self.completionTime = completionTime
    }
}

public struct ScoringProfile: Codable {
    public let perfectWindow: TimeInterval // ±20ms
    public let earlyWindow: TimeInterval   // ±50ms  
    public let lateWindow: TimeInterval    // ±50ms
    public let missThreshold: TimeInterval // ±100ms
    public let extraPenalty: Float
    public let gradePenaltyMultiplier: Float
    public let streakBonus: Float
    
    public init(perfectWindow: TimeInterval, earlyWindow: TimeInterval, lateWindow: TimeInterval, missThreshold: TimeInterval, extraPenalty: Float, gradePenaltyMultiplier: Float, streakBonus: Float) {
        self.perfectWindow = perfectWindow
        self.earlyWindow = earlyWindow
        self.lateWindow = lateWindow
        self.missThreshold = missThreshold
        self.extraPenalty = extraPenalty
        self.gradePenaltyMultiplier = gradePenaltyMultiplier
        self.streakBonus = streakBonus
    }
    
    public static func defaultProfile() -> ScoringProfile {
        return ScoringProfile(
            perfectWindow: 0.020,      // ±20ms
            earlyWindow: 0.050,        // ±50ms
            lateWindow: 0.050,         // ±50ms
            missThreshold: 0.100,      // ±100ms
            extraPenalty: 0.05,        // 5% penalty per extra hit
            gradePenaltyMultiplier: 1.0,
            streakBonus: 0.01          // 1% bonus per streak hit
        )
    }
}

// MARK: - Score Engine Protocol

public protocol ScoreEngineProtocol {
    func processUserInput(_ event: MIDIEvent, at timestamp: TimeInterval)
    func calculateScore() -> ScoreResult
    func getTimingFeedback(for event: MIDIEvent) -> TimingFeedback
    func resetScore()
    func setTargetEvents(_ events: [TargetEvent])
    func setScoringProfile(_ profile: ScoringProfile)
}

// MARK: - Mock Score Engine for Testing

public class MockScoreEngine: ScoreEngineProtocol {
    
    public var currentScore: Float = 0.0
    public var currentStreak: Int = 0
    public var realtimeFeedback: TimingFeedback?
    public var isScoring: Bool = false
    
    private var targetEvents: [TargetEvent] = []
    private var userEvents: [MIDIEvent] = []
    private var timingResults: [TimingResult] = []
    private var scoringProfile: ScoringProfile = ScoringProfile.defaultProfile()
    
    // Scoring state
    private var processedTargetIndices: Set<Int> = []
    private var maxStreak: Int = 0
    private var missCount: Int = 0
    private var extraCount: Int = 0
    private var perfectCount: Int = 0
    private var earlyCount: Int = 0
    private var lateCount: Int = 0
    private var startTime: TimeInterval = 0
    
    public init() {
        resetScore()
    }
    
    public func setTargetEvents(_ events: [TargetEvent]) {
        self.targetEvents = events.sorted { $0.timestamp < $1.timestamp }
        resetScore()
    }
    
    public func setScoringProfile(_ profile: ScoringProfile) {
        self.scoringProfile = profile
    }
    
    public func startScoring() {
        self.startTime = CACurrentMediaTime()
        self.isScoring = true
        resetScore()
    }
    
    public func stopScoring() {
        self.isScoring = false
    }
    
    public func processUserInput(_ event: MIDIEvent, at timestamp: TimeInterval) {
        guard isScoring else { return }
        
        userEvents.append(event)
        let feedback = evaluateUserInput(event, at: timestamp)
        realtimeFeedback = feedback
        updateRealtimeScore()
    }
    
    public func calculateScore() -> ScoreResult {
        // Process any remaining unmatched target events as misses
        processRemainingTargets()
        
        let totalTargets = Float(targetEvents.count)
        guard totalTargets > 0 else {
            return ScoreResult(
                totalScore: 0,
                starRating: 0,
                isPlatinum: false,
                isBlackStar: false,
                timingResults: [],
                streakCount: currentStreak,
                maxStreak: maxStreak,
                missCount: 0,
                extraCount: 0,
                perfectCount: 0,
                earlyCount: 0,
                lateCount: 0,
                completionTime: CACurrentMediaTime() - startTime
            )
        }
        
        // Calculate base score from timing results
        let baseScore = timingResults.reduce(0.0) { $0 + $1.score } / totalTargets * 100.0
        
        // Apply penalties and bonuses - use same logic as main ScoreEngine
        let extraPenaltyMultiplier = 1.0 - (Float(extraCount) * scoringProfile.extraPenalty)
        let streakBonus = Float(maxStreak) * scoringProfile.streakBonus * 100.0
        
        let scoreAfterPenalty = baseScore * max(0.0, extraPenaltyMultiplier)
        let finalScore = max(0, min(100, scoreAfterPenalty + streakBonus))
        
        return ScoreResult(
            totalScore: finalScore,
            starRating: calculateStarRating(finalScore),
            isPlatinum: finalScore >= 100.0,
            isBlackStar: false,
            timingResults: timingResults,
            streakCount: currentStreak,
            maxStreak: maxStreak,
            missCount: missCount,
            extraCount: extraCount,
            perfectCount: perfectCount,
            earlyCount: earlyCount,
            lateCount: lateCount,
            completionTime: CACurrentMediaTime() - startTime
        )
    }
    
    public func getTimingFeedback(for event: MIDIEvent) -> TimingFeedback {
        return calculateTimingFeedback(event, at: event.timestamp)
    }
    
    private func calculateTimingFeedback(_ event: MIDIEvent, at timestamp: TimeInterval) -> TimingFeedback {
        // Find the closest target event that matches this input (read-only version)
        var bestMatch: (index: Int, target: TargetEvent, timeDiff: TimeInterval)?
        
        for (index, target) in targetEvents.enumerated() {
            // Skip already processed targets to match evaluateUserInput behavior
            if processedTargetIndices.contains(index) {
                continue
            }
            
            // Check if note numbers match
            if target.noteNumber == event.noteNumber {
                let timeDiff = abs(timestamp - target.timestamp)
                
                // Only consider targets within miss threshold
                if timeDiff <= scoringProfile.missThreshold {
                    if bestMatch == nil || timeDiff < bestMatch!.timeDiff {
                        bestMatch = (index, target, timeDiff)
                    }
                }
            }
        }
        
        guard let match = bestMatch else {
            // No matching target found - this is an extra hit
            return .extra
        }
        
        // Determine timing feedback based on time difference
        let timeDiff = timestamp - match.target.timestamp
        
        if abs(timeDiff) <= scoringProfile.perfectWindow {
            return .perfect
        } else if timeDiff < -scoringProfile.perfectWindow && abs(timeDiff) <= scoringProfile.earlyWindow {
            // Early hit: user hit before the target time
            return .early
        } else if timeDiff > scoringProfile.perfectWindow && abs(timeDiff) <= scoringProfile.lateWindow {
            // Late hit: user hit after the target time
            return .late
        } else {
            // Outside all timing windows
            return .miss
        }
    }
    
    public func resetScore() {
        userEvents.removeAll()
        timingResults.removeAll()
        processedTargetIndices.removeAll()
        maxStreak = 0
        missCount = 0
        extraCount = 0
        perfectCount = 0
        earlyCount = 0
        lateCount = 0
        startTime = CACurrentMediaTime()
        currentScore = 0.0
        currentStreak = 0
        realtimeFeedback = nil
    }
    
    // MARK: - Private Implementation
    
    private func evaluateUserInput(_ event: MIDIEvent, at timestamp: TimeInterval) -> TimingFeedback {
        // Find the closest target event that matches this input
        var bestMatch: (index: Int, target: TargetEvent, timeDiff: TimeInterval)?
        
        for (index, target) in targetEvents.enumerated() {
            // Skip already processed targets
            if processedTargetIndices.contains(index) {
                continue
            }
            
            // Check if note numbers match
            if target.noteNumber == event.noteNumber {
                let timeDiff = abs(timestamp - target.timestamp)
                
                // Only consider targets within miss threshold
                if timeDiff <= scoringProfile.missThreshold {
                    if bestMatch == nil || timeDiff < bestMatch!.timeDiff {
                        bestMatch = (index, target, timeDiff)
                    }
                }
            }
        }
        
        guard let match = bestMatch else {
            // No matching target found - this is an extra hit
            extraCount += 1
            currentStreak = 0
            
            let result = TimingResult(
                targetEvent: TargetEvent(timestamp: timestamp, laneId: "extra", noteNumber: event.noteNumber, velocity: event.velocity, duration: nil),
                userEvent: event,
                timing: .extra,
                score: 0.0,
                timestamp: timestamp
            )
            timingResults.append(result)
            
            return .extra
        }
        
        // Mark target as processed
        processedTargetIndices.insert(match.index)
        
        // Determine timing feedback based on time difference
        let timeDiff = timestamp - match.target.timestamp
        let feedback: TimingFeedback
        
        if abs(timeDiff) <= scoringProfile.perfectWindow {
            feedback = .perfect
            perfectCount += 1
            currentStreak += 1
            maxStreak = max(maxStreak, currentStreak)
        } else if timeDiff < -scoringProfile.perfectWindow && abs(timeDiff) <= scoringProfile.earlyWindow {
            feedback = .early
            earlyCount += 1
            currentStreak = 0
        } else if timeDiff > scoringProfile.perfectWindow && abs(timeDiff) <= scoringProfile.lateWindow {
            feedback = .late
            lateCount += 1
            currentStreak = 0
        } else {
            feedback = .miss
            missCount += 1
            currentStreak = 0
        }
        
        // Calculate score for this hit
        let baseScore = feedback.scoreMultiplier
        let streakMultiplier = currentStreak >= 4 ? 1.0 + scoringProfile.streakBonus : 1.0
        let finalScore = baseScore * streakMultiplier
        
        let result = TimingResult(
            targetEvent: match.target,
            userEvent: event,
            timing: feedback,
            score: finalScore,
            timestamp: timestamp
        )
        timingResults.append(result)
        
        return feedback
    }
    
    private func processRemainingTargets() {
        for (index, target) in targetEvents.enumerated() {
            if !processedTargetIndices.contains(index) {
                // This target was missed
                missCount += 1
                currentStreak = 0
                
                let result = TimingResult(
                    targetEvent: target,
                    userEvent: nil,
                    timing: .miss,
                    score: 0.0,
                    timestamp: target.timestamp
                )
                timingResults.append(result)
                processedTargetIndices.insert(index)
            }
        }
    }
    
    private func updateRealtimeScore() {
        let processedCount = Float(timingResults.count)
        guard processedCount > 0 else {
            currentScore = 0.0
            return
        }
        
        let currentSum = timingResults.reduce(0.0) { $0 + $1.score }
        let baseScore = (currentSum / processedCount) * 100.0
        
        // Apply real-time penalties and bonuses - use same logic as main ScoreEngine
        let extraPenaltyMultiplier = 1.0 - (Float(extraCount) * scoringProfile.extraPenalty)
        let streakBonus = Float(maxStreak) * scoringProfile.streakBonus * 100.0
        
        let scoreAfterPenalty = baseScore * max(0.0, extraPenaltyMultiplier)
        currentScore = max(0, min(100, scoreAfterPenalty + streakBonus))
    }
    
    private func calculateStarRating(_ score: Float) -> Int {
        if score >= 90.0 {
            return 3
        } else if score >= 75.0 {
            return 2
        } else if score >= 50.0 {
            return 1
        } else {
            return 0
        }
    }
}