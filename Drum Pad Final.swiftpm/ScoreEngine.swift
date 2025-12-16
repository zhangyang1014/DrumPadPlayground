import Foundation
import AudioKit

// MARK: - Scoring Data Models

struct TargetEvent: Codable, Identifiable {
    let id = UUID()
    let timestamp: TimeInterval
    let laneId: String
    let noteNumber: Int
    let velocity: Int?
    let duration: TimeInterval?
}

struct MIDIEvent: Codable {
    let timestamp: TimeInterval
    let noteNumber: Int
    let velocity: Int
    let channel: Int
}

enum TimingFeedback: String, Codable, CaseIterable {
    case perfect = "perfect"
    case early = "early"
    case late = "late"
    case miss = "miss"
    case extra = "extra"
    
    var displayName: String {
        switch self {
        case .perfect: return "Perfect"
        case .early: return "Early"
        case .late: return "Late"
        case .miss: return "Miss"
        case .extra: return "Extra"
        }
    }
    
    var scoreMultiplier: Float {
        switch self {
        case .perfect: return 1.0
        case .early: return 0.8
        case .late: return 0.8
        case .miss: return 0.0
        case .extra: return 0.0
        }
    }
}

struct TimingResult: Codable, Identifiable {
    let id = UUID()
    let targetEvent: TargetEvent
    let userEvent: MIDIEvent?
    let timing: TimingFeedback
    let score: Float
    let timestamp: TimeInterval
}

struct ScoreResult: Codable {
    let totalScore: Float // 0-100
    let starRating: Int // 1-3
    let isPlatinum: Bool // 100% in Performance Mode
    let isBlackStar: Bool // 100% in Memory Mode
    let timingResults: [TimingResult]
    let streakCount: Int
    let maxStreak: Int
    let missCount: Int
    let extraCount: Int
    let perfectCount: Int
    let earlyCount: Int
    let lateCount: Int
    let completionTime: TimeInterval
}

struct ScoringProfile: Codable {
    let perfectWindow: TimeInterval // ±20ms
    let earlyWindow: TimeInterval   // ±50ms  
    let lateWindow: TimeInterval    // ±50ms
    let missThreshold: TimeInterval // ±100ms
    let extraPenalty: Float
    let gradePenaltyMultiplier: Float
    let streakBonus: Float
    
    static func defaultProfile() -> ScoringProfile {
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

protocol ScoreEngineProtocol {
    func processUserInput(_ event: MIDIEvent, at timestamp: TimeInterval)
    func calculateScore() -> ScoreResult
    func getTimingFeedback(for event: MIDIEvent) -> TimingFeedback
    func resetScore()
    func setTargetEvents(_ events: [TargetEvent])
    func setScoringProfile(_ profile: ScoringProfile)
}

// MARK: - Real-time Score Engine Implementation

class ScoreEngine: ObservableObject, ScoreEngineProtocol {
    
    // MARK: - Published Properties
    @Published var currentScore: Float = 0.0
    @Published var currentStreak: Int = 0
    @Published var realtimeFeedback: TimingFeedback?
    @Published var isScoring: Bool = false
    
    // MARK: - Private Properties
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
    
    // Real-time processing
    private var lastProcessedTargetIndex: Int = 0
    private let processingQueue = DispatchQueue(label: "scoreEngine.processing", qos: .userInteractive)
    
    // MARK: - Initialization
    
    init() {
        resetScore()
    }
    
    // MARK: - Public Interface
    
    func setTargetEvents(_ events: [TargetEvent]) {
        processingQueue.async {
            self.targetEvents = events.sorted { $0.timestamp < $1.timestamp }
            DispatchQueue.main.async {
                self.resetScore()
            }
        }
    }
    
    func setScoringProfile(_ profile: ScoringProfile) {
        processingQueue.async {
            self.scoringProfile = profile
        }
    }
    
    func startScoring() {
        processingQueue.async {
            self.startTime = CACurrentMediaTime()
            DispatchQueue.main.async {
                self.isScoring = true
                self.resetScore()
            }
        }
    }
    
    func stopScoring() {
        processingQueue.async {
            DispatchQueue.main.async {
                self.isScoring = false
            }
        }
    }
    
    func processUserInput(_ event: MIDIEvent, at timestamp: TimeInterval) {
        guard isScoring else { return }
        
        processingQueue.async {
            self.userEvents.append(event)
            let feedback = self.evaluateUserInput(event, at: timestamp)
            
            DispatchQueue.main.async {
                self.realtimeFeedback = feedback
                self.updateRealtimeScore()
                
                // Clear feedback after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self.realtimeFeedback == feedback {
                        self.realtimeFeedback = nil
                    }
                }
            }
        }
    }
    
    func calculateScore() -> ScoreResult {
        return processingQueue.sync {
            // Process any remaining unmatched target events as misses
            self.processRemainingTargets()
            
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
            
            // Apply penalties and bonuses
            // Extra penalty should be applied as a percentage reduction, not a flat subtraction
            let extraPenaltyMultiplier = 1.0 - (Float(extraCount) * scoringProfile.extraPenalty)
            let streakBonus = Float(maxStreak) * scoringProfile.streakBonus * 100.0
            
            let scoreAfterPenalty = baseScore * max(0.0, extraPenaltyMultiplier)
            let finalScore = max(0, min(100, scoreAfterPenalty + streakBonus))
            
            return ScoreResult(
                totalScore: finalScore,
                starRating: calculateStarRating(finalScore),
                isPlatinum: finalScore >= 100.0,
                isBlackStar: false, // Set by memory mode
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
    }
    
    func getTimingFeedback(for event: MIDIEvent) -> TimingFeedback {
        return processingQueue.sync {
            return calculateTimingFeedback(event, at: event.timestamp)
        }
    }
    
    func resetScore() {
        processingQueue.async {
            self.userEvents.removeAll()
            self.timingResults.removeAll()
            self.processedTargetIndices.removeAll()
            self.lastProcessedTargetIndex = 0
            self.maxStreak = 0
            self.missCount = 0
            self.extraCount = 0
            self.perfectCount = 0
            self.earlyCount = 0
            self.lateCount = 0
            self.startTime = CACurrentMediaTime()
            
            DispatchQueue.main.async {
                self.currentScore = 0.0
                self.currentStreak = 0
                self.realtimeFeedback = nil
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func calculateTimingFeedback(_ event: MIDIEvent, at timestamp: TimeInterval) -> TimingFeedback {
        // Find the closest target event that matches this input (read-only version)
        var bestMatch: (index: Int, target: TargetEvent, timeDiff: TimeInterval)?
        
        for (index, target) in targetEvents.enumerated() {
            // Skip already processed targets to match evaluateUserInput behavior
            if processedTargetIndices.contains(index) {
                continue
            }
            
            // Check if note numbers match (considering MIDI mapping)
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
    
    private func evaluateUserInput(_ event: MIDIEvent, at timestamp: TimeInterval) -> TimingFeedback {
        // Find the closest target event that matches this input
        var bestMatch: (index: Int, target: TargetEvent, timeDiff: TimeInterval)?
        
        for (index, target) in targetEvents.enumerated() {
            // Skip already processed targets
            if processedTargetIndices.contains(index) {
                continue
            }
            
            // Check if note numbers match (considering MIDI mapping)
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
            // Early hit: user hit before the target time
            feedback = .early
            earlyCount += 1
            currentStreak = 0
        } else if timeDiff > scoringProfile.perfectWindow && abs(timeDiff) <= scoringProfile.lateWindow {
            // Late hit: user hit after the target time
            feedback = .late
            lateCount += 1
            currentStreak = 0
        } else {
            // Outside all timing windows
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
        
        // Apply real-time penalties and bonuses - use same logic as calculateScore
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

