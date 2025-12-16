import Foundation
import CoreData
import CloudKit

// MARK: - Core Data Models

// MARK: - Lesson Entity
@objc(Lesson)
public class Lesson: NSManagedObject, Identifiable {
    @NSManaged public var id: String
    @NSManaged public var title: String
    @NSManaged public var courseId: String?
    @NSManaged public var instrument: String
    @NSManaged public var defaultBPM: Float
    @NSManaged public var timeSignatureNumerator: Int16
    @NSManaged public var timeSignatureDenominator: Int16
    @NSManaged public var duration: TimeInterval
    @NSManaged public var tags: String // JSON encoded array
    @NSManaged public var difficulty: Int16 // 1-5 scale
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    
    // Relationships
    @NSManaged public var course: Course?
    @NSManaged public var steps: NSSet?
    @NSManaged public var scoreResults: NSSet?
    @NSManaged public var scoringProfile: ScoringProfileEntity?
    @NSManaged public var audioAssets: AudioAssetsEntity?
    
    // Computed properties
    public var tagsArray: [String] {
        get {
            guard let data = tags.data(using: .utf8),
                  let array = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return array
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                tags = string
            }
        }
    }
    
    public var timeSignature: TimeSignature {
        get {
            return TimeSignature(numerator: Int(timeSignatureNumerator), denominator: Int(timeSignatureDenominator))
        }
        set {
            timeSignatureNumerator = Int16(newValue.numerator)
            timeSignatureDenominator = Int16(newValue.denominator)
        }
    }
    
    public var stepsArray: [LessonStep] {
        return (steps?.allObjects as? [LessonStep])?.sorted { $0.order < $1.order } ?? []
    }
    
    public var scoreResultsArray: [ScoreResultEntity] {
        return (scoreResults?.allObjects as? [ScoreResultEntity])?.sorted { $0.completedAt > $1.completedAt } ?? []
    }
}

// MARK: - Course Entity
@objc(Course)
public class Course: NSManagedObject, Identifiable {
    @NSManaged public var id: String
    @NSManaged public var title: String
    @NSManaged public var courseDescription: String
    @NSManaged public var difficulty: Int16
    @NSManaged public var tags: String // JSON encoded array
    @NSManaged public var estimatedDuration: TimeInterval
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var isPublished: Bool
    
    // Relationships
    @NSManaged public var lessons: NSSet?
    
    public var tagsArray: [String] {
        get {
            guard let data = tags.data(using: .utf8),
                  let array = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return array
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                tags = string
            }
        }
    }
    
    public var lessonsArray: [Lesson] {
        return (lessons?.allObjects as? [Lesson])?.sorted { $0.createdAt < $1.createdAt } ?? []
    }
}

// MARK: - LessonStep Entity
@objc(LessonStep)
public class LessonStep: NSManagedObject, Identifiable {
    @NSManaged public var id: String
    @NSManaged public var lessonId: String
    @NSManaged public var order: Int16
    @NSManaged public var title: String
    @NSManaged public var stepDescription: String
    @NSManaged public var targetEventsData: Data // JSON encoded TargetEvent array
    @NSManaged public var bpmOverride: Float // 0 means use lesson default
    @NSManaged public var assistLevel: String
    @NSManaged public var createdAt: Date
    
    // Relationships
    @NSManaged public var lesson: Lesson?
    
    public var targetEvents: [TargetEvent] {
        get {
            guard let events = try? JSONDecoder().decode([TargetEvent].self, from: targetEventsData) else {
                return []
            }
            return events
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                targetEventsData = data
            }
        }
    }
    
    public var assistLevelEnum: AssistLevel {
        get {
            return AssistLevel(rawValue: assistLevel) ?? .full
        }
        set {
            assistLevel = newValue.rawValue
        }
    }
}

// MARK: - ScoreResult Entity
@objc(ScoreResultEntity)
public class ScoreResultEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: String
    @NSManaged public var lessonId: String
    @NSManaged public var totalScore: Float
    @NSManaged public var starRating: Int16
    @NSManaged public var isPlatinum: Bool
    @NSManaged public var isBlackStar: Bool
    @NSManaged public var streakCount: Int16
    @NSManaged public var maxStreak: Int16
    @NSManaged public var missCount: Int16
    @NSManaged public var extraCount: Int16
    @NSManaged public var perfectCount: Int16
    @NSManaged public var earlyCount: Int16
    @NSManaged public var lateCount: Int16
    @NSManaged public var completionTime: TimeInterval
    @NSManaged public var completedAt: Date
    @NSManaged public var playbackMode: String
    @NSManaged public var timingResultsData: Data // JSON encoded TimingResult array
    
    // Relationships
    @NSManaged public var lesson: Lesson?
    @NSManaged public var userProgress: UserProgress?
    
    public var timingResults: [TimingResult] {
        get {
            guard let results = try? JSONDecoder().decode([TimingResult].self, from: timingResultsData) else {
                return []
            }
            return results
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                timingResultsData = data
            }
        }
    }
    
    public var playbackModeEnum: PlaybackMode {
        get {
            return PlaybackMode(rawValue: playbackMode) ?? .performance
        }
        set {
            playbackMode = newValue.rawValue
        }
    }
    
    // Convert to ScoreResult struct
    public func toScoreResult() -> ScoreResult {
        return ScoreResult(
            totalScore: totalScore,
            starRating: Int(starRating),
            isPlatinum: isPlatinum,
            isBlackStar: isBlackStar,
            timingResults: timingResults,
            streakCount: Int(streakCount),
            maxStreak: Int(maxStreak),
            missCount: Int(missCount),
            extraCount: Int(extraCount),
            perfectCount: Int(perfectCount),
            earlyCount: Int(earlyCount),
            lateCount: Int(lateCount),
            completionTime: completionTime
        )
    }
}

// MARK: - UserProgress Entity
@objc(UserProgress)
public class UserProgress: NSManagedObject, Identifiable {
    @NSManaged public var id: String
    @NSManaged public var userId: String
    @NSManaged public var currentLevel: Int16
    @NSManaged public var totalStars: Int16
    @NSManaged public var currentStreak: Int16
    @NSManaged public var maxStreak: Int16
    @NSManaged public var totalTrophies: Int16
    @NSManaged public var dailyGoalMinutes: Int16
    @NSManaged public var lastPracticeDate: Date?
    @NSManaged public var totalPracticeTime: TimeInterval
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    
    // Relationships
    @NSManaged public var scoreResults: NSSet?
    @NSManaged public var dailyProgress: NSSet?
    
    public var scoreResultsArray: [ScoreResultEntity] {
        return (scoreResults?.allObjects as? [ScoreResultEntity])?.sorted { $0.completedAt > $1.completedAt } ?? []
    }
    
    public var dailyProgressArray: [DailyProgress] {
        return (dailyProgress?.allObjects as? [DailyProgress])?.sorted { $0.date > $1.date } ?? []
    }
}

// MARK: - DailyProgress Entity
@objc(DailyProgress)
public class DailyProgress: NSManagedObject, Identifiable {
    @NSManaged public var id: String
    @NSManaged public var userId: String
    @NSManaged public var date: Date
    @NSManaged public var practiceTimeMinutes: Int16
    @NSManaged public var goalAchieved: Bool
    @NSManaged public var lessonsCompleted: Int16
    @NSManaged public var starsEarned: Int16
    @NSManaged public var createdAt: Date
    
    // Relationships
    @NSManaged public var userProgress: UserProgress?
    
    public var isGoalMet: Bool {
        return practiceTimeMinutes >= (userProgress?.dailyGoalMinutes ?? 5)
    }
}

// MARK: - ScoringProfile Entity
@objc(ScoringProfileEntity)
public class ScoringProfileEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var perfectWindow: TimeInterval
    @NSManaged public var earlyWindow: TimeInterval
    @NSManaged public var lateWindow: TimeInterval
    @NSManaged public var missThreshold: TimeInterval
    @NSManaged public var extraPenalty: Float
    @NSManaged public var gradePenaltyMultiplier: Float
    @NSManaged public var streakBonus: Float
    
    // Relationships
    @NSManaged public var lessons: NSSet?
    
    // Convert to ScoringProfile struct
    public func toScoringProfile() -> ScoringProfile {
        return ScoringProfile(
            perfectWindow: perfectWindow,
            earlyWindow: earlyWindow,
            lateWindow: lateWindow,
            missThreshold: missThreshold,
            extraPenalty: extraPenalty,
            gradePenaltyMultiplier: gradePenaltyMultiplier,
            streakBonus: streakBonus
        )
    }
}

// MARK: - AudioAssets Entity
@objc(AudioAssetsEntity)
public class AudioAssetsEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var backingTrackURL: String?
    @NSManaged public var clickTrackURL: String?
    @NSManaged public var previewURL: String?
    @NSManaged public var stemURLsData: Data // JSON encoded [String: String] dictionary
    
    // Relationships
    @NSManaged public var lessons: NSSet?
    
    public var stemURLs: [String: URL] {
        get {
            guard let data = try? JSONDecoder().decode([String: String].self, from: stemURLsData) else {
                return [:]
            }
            return data.compactMapValues { URL(string: $0) }
        }
        set {
            let stringDict = newValue.compactMapValues { $0.absoluteString }
            if let data = try? JSONEncoder().encode(stringDict) {
                stemURLsData = data
            }
        }
    }
    
    // Convert to AudioAssets struct
    public func toAudioAssets() -> AudioAssets {
        return AudioAssets(
            backingTrackURL: backingTrackURL.flatMap { URL(string: $0) },
            clickTrackURL: clickTrackURL.flatMap { URL(string: $0) },
            previewURL: previewURL.flatMap { URL(string: $0) },
            stemURLs: stemURLs
        )
    }
}

// MARK: - Supporting Structs

public struct TimeSignature: Codable {
    public let numerator: Int
    public let denominator: Int
    
    public init(numerator: Int, denominator: Int) {
        self.numerator = numerator
        self.denominator = denominator
    }
    
    public static let fourFour = TimeSignature(numerator: 4, denominator: 4)
    public static let threeFour = TimeSignature(numerator: 3, denominator: 4)
    public static let sixEight = TimeSignature(numerator: 6, denominator: 8)
}

public enum AssistLevel: String, CaseIterable, Codable {
    case full = "full"           // 显示所有引导
    case reduced = "reduced"     // 部分引导
    case minimal = "minimal"     // 最少引导
    case none = "none"          // 无引导（记忆模式）
    
    public var displayName: String {
        switch self {
        case .full: return "Full Assistance"
        case .reduced: return "Reduced Assistance"
        case .minimal: return "Minimal Assistance"
        case .none: return "No Assistance"
        }
    }
}

public enum PlaybackMode: String, CaseIterable, Codable {
    case performance = "performance"
    case practice = "practice"
    case memory = "memory"
    
    public var displayName: String {
        switch self {
        case .performance: return "Performance Mode"
        case .practice: return "Practice Mode"
        case .memory: return "Memory Mode"
        }
    }
}

// MARK: - Data Validation

extension Lesson {
    public func validate() throws {
        guard !id.isEmpty else {
            throw ValidationError.invalidID
        }
        guard !title.isEmpty else {
            throw ValidationError.invalidTitle
        }
        guard defaultBPM > 0 && defaultBPM <= 300 else {
            throw ValidationError.invalidBPM
        }
        guard duration > 0 else {
            throw ValidationError.invalidDuration
        }
        guard difficulty >= 1 && difficulty <= 5 else {
            throw ValidationError.invalidDifficulty
        }
    }
}

extension Course {
    public func validate() throws {
        guard !id.isEmpty else {
            throw ValidationError.invalidID
        }
        guard !title.isEmpty else {
            throw ValidationError.invalidTitle
        }
        guard difficulty >= 1 && difficulty <= 5 else {
            throw ValidationError.invalidDifficulty
        }
    }
}

extension LessonStep {
    public func validate() throws {
        guard !id.isEmpty else {
            throw ValidationError.invalidID
        }
        guard !lessonId.isEmpty else {
            throw ValidationError.invalidLessonID
        }
        guard order >= 0 else {
            throw ValidationError.invalidOrder
        }
        guard !title.isEmpty else {
            throw ValidationError.invalidTitle
        }
    }
}

extension ScoreResultEntity {
    public func validate() throws {
        guard !id.isEmpty else {
            throw ValidationError.invalidID
        }
        guard !lessonId.isEmpty else {
            throw ValidationError.invalidLessonID
        }
        guard totalScore >= 0 && totalScore <= 100 else {
            throw ValidationError.invalidScore
        }
        guard starRating >= 0 && starRating <= 3 else {
            throw ValidationError.invalidStarRating
        }
    }
}

public enum ValidationError: Error, LocalizedError {
    case invalidID
    case invalidTitle
    case invalidBPM
    case invalidDuration
    case invalidDifficulty
    case invalidLessonID
    case invalidOrder
    case invalidScore
    case invalidStarRating
    
    public var errorDescription: String? {
        switch self {
        case .invalidID:
            return "Invalid ID: ID cannot be empty"
        case .invalidTitle:
            return "Invalid title: Title cannot be empty"
        case .invalidBPM:
            return "Invalid BPM: BPM must be between 1 and 300"
        case .invalidDuration:
            return "Invalid duration: Duration must be greater than 0"
        case .invalidDifficulty:
            return "Invalid difficulty: Difficulty must be between 1 and 5"
        case .invalidLessonID:
            return "Invalid lesson ID: Lesson ID cannot be empty"
        case .invalidOrder:
            return "Invalid order: Order must be non-negative"
        case .invalidScore:
            return "Invalid score: Score must be between 0 and 100"
        case .invalidStarRating:
            return "Invalid star rating: Star rating must be between 0 and 3"
        }
    }
}