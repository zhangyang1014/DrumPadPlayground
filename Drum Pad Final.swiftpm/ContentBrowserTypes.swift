import Foundation
import SwiftUI

// MARK: - Content Item

struct ContentItem: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let type: ContentType
    let difficulty: DifficultyLevel
    let duration: TimeInterval
    let tags: Set<String>
    let source: ContentSource
    let createdAt: Date
    
    init(id: String, title: String, description: String, type: ContentType, difficulty: DifficultyLevel, duration: TimeInterval, tags: Set<String>, source: ContentSource) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.difficulty = difficulty
        self.duration = duration
        self.tags = tags
        self.source = source
        self.createdAt = Date() // Default to current date, could be extracted from source
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ContentItem, rhs: ContentItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Content Source

enum ContentSource {
    case lesson(Lesson)
    case course(Course)
    
    var id: String {
        switch self {
        case .lesson(let lesson):
            return lesson.id
        case .course(let course):
            return course.id
        }
    }
}

// MARK: - Content Type

enum ContentType: String, CaseIterable, CustomStringConvertible {
    case lesson = "lesson"
    case course = "course"
    
    var description: String {
        switch self {
        case .lesson: return "Lesson"
        case .course: return "Course"
        }
    }
    
    var iconName: String {
        switch self {
        case .lesson: return "music.note"
        case .course: return "folder"
        }
    }
    
    var color: Color {
        switch self {
        case .lesson: return .blue
        case .course: return .green
        }
    }
}

// MARK: - Difficulty Level

enum DifficultyLevel: Int, CaseIterable, CustomStringConvertible {
    case beginner = 1
    case intermediate = 2
    case advanced = 3
    case expert = 4
    case master = 5
    
    var description: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        case .master: return "Master"
        }
    }
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .expert: return .red
        case .master: return .purple
        }
    }
    
    var stars: Int {
        return rawValue
    }
}

// MARK: - Content Filter

struct ContentFilter {
    var searchText: String = ""
    var contentType: ContentType?
    var difficulty: DifficultyLevel?
    var tags: Set<String> = []
    var minDuration: TimeInterval?
    var maxDuration: TimeInterval?
    
    var isEmpty: Bool {
        return searchText.isEmpty &&
               contentType == nil &&
               difficulty == nil &&
               tags.isEmpty &&
               minDuration == nil &&
               maxDuration == nil
    }
    
    func matches(_ item: ContentItem) -> Bool {
        // Search text filter
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            let titleMatch = item.title.lowercased().contains(searchLower)
            let descriptionMatch = item.description.lowercased().contains(searchLower)
            let tagMatch = item.tags.contains { $0.lowercased().contains(searchLower) }
            
            if !titleMatch && !descriptionMatch && !tagMatch {
                return false
            }
        }
        
        // Content type filter
        if let type = contentType, item.type != type {
            return false
        }
        
        // Difficulty filter
        if let diff = difficulty, item.difficulty != diff {
            return false
        }
        
        // Tags filter
        if !tags.isEmpty && tags.isDisjoint(with: item.tags) {
            return false
        }
        
        // Duration filters
        if let minDur = minDuration, item.duration < minDur {
            return false
        }
        
        if let maxDur = maxDuration, item.duration > maxDur {
            return false
        }
        
        return true
    }
}

// MARK: - Content Preview

struct ContentPreview {
    let contentId: String
    let audioURL: URL?
    let thumbnailURL: URL?
    let previewDuration: TimeInterval
    let highlights: [TimeInterval] // Key moments to preview
    
    static func empty(for contentId: String) -> ContentPreview {
        return ContentPreview(
            contentId: contentId,
            audioURL: nil,
            thumbnailURL: nil,
            previewDuration: 0,
            highlights: []
        )
    }
}

// MARK: - Content Recommendation

struct ContentRecommendation {
    let content: ContentItem
    let reason: RecommendationReason
    let confidence: Float // 0.0 to 1.0
    
    enum RecommendationReason {
        case beginnerFriendly
        case similarToCompleted
        case nextInProgression
        case popularTag
        case shortDuration
        case matchesSkillLevel
        
        var description: String {
            switch self {
            case .beginnerFriendly:
                return "Great for beginners"
            case .similarToCompleted:
                return "Similar to lessons you've completed"
            case .nextInProgression:
                return "Next step in your learning path"
            case .popularTag:
                return "Popular in your favorite categories"
            case .shortDuration:
                return "Quick practice session"
            case .matchesSkillLevel:
                return "Matches your current skill level"
            }
        }
    }
}

// MARK: - Content Search Result

struct ContentSearchResult {
    let item: ContentItem
    let relevanceScore: Float
    let matchedFields: [MatchedField]
    
    enum MatchedField {
        case title(range: Range<String.Index>)
        case description(range: Range<String.Index>)
        case tag(String)
        
        var fieldName: String {
            switch self {
            case .title: return "Title"
            case .description: return "Description"
            case .tag: return "Tag"
            }
        }
    }
}

// MARK: - Content Category

enum ContentCategory: String, CaseIterable {
    case fundamentals = "fundamentals"
    case grooves = "grooves"
    case fills = "fills"
    case rudiments = "rudiments"
    case coordination = "coordination"
    case independence = "independence"
    case timing = "timing"
    case dynamics = "dynamics"
    case genres = "genres"
    case techniques = "techniques"
    
    var displayName: String {
        switch self {
        case .fundamentals: return "Fundamentals"
        case .grooves: return "Grooves"
        case .fills: return "Fills"
        case .rudiments: return "Rudiments"
        case .coordination: return "Coordination"
        case .independence: return "Independence"
        case .timing: return "Timing"
        case .dynamics: return "Dynamics"
        case .genres: return "Genres"
        case .techniques: return "Techniques"
        }
    }
    
    var description: String {
        switch self {
        case .fundamentals:
            return "Basic drumming concepts and techniques"
        case .grooves:
            return "Rhythmic patterns and beats"
        case .fills:
            return "Drum fills and transitions"
        case .rudiments:
            return "Standard drumming rudiments"
        case .coordination:
            return "Hand and foot coordination exercises"
        case .independence:
            return "Limb independence training"
        case .timing:
            return "Timing and metronome exercises"
        case .dynamics:
            return "Volume and accent control"
        case .genres:
            return "Genre-specific patterns"
        case .techniques:
            return "Advanced playing techniques"
        }
    }
    
    var iconName: String {
        switch self {
        case .fundamentals: return "book"
        case .grooves: return "waveform"
        case .fills: return "burst"
        case .rudiments: return "list.bullet"
        case .coordination: return "hand.raised"
        case .independence: return "figure.walk"
        case .timing: return "metronome"
        case .dynamics: return "speaker.wave.3"
        case .genres: return "music.note.house"
        case .techniques: return "gear"
        }
    }
    
    var color: Color {
        switch self {
        case .fundamentals: return .blue
        case .grooves: return .green
        case .fills: return .orange
        case .rudiments: return .red
        case .coordination: return .purple
        case .independence: return .pink
        case .timing: return .cyan
        case .dynamics: return .yellow
        case .genres: return .indigo
        case .techniques: return .brown
        }
    }
}

// MARK: - Content Validation

struct ContentValidationResult {
    let isValid: Bool
    let errors: [ValidationError]
    let warnings: [ValidationWarning]
    
    enum ValidationError: LocalizedError {
        case emptyTitle
        case invalidDuration
        case missingAudioAssets
        case invalidDifficulty
        case noTargetEvents
        case invalidBPM
        
        var errorDescription: String? {
            switch self {
            case .emptyTitle:
                return "Content must have a title"
            case .invalidDuration:
                return "Duration must be greater than 0"
            case .missingAudioAssets:
                return "Content must have audio assets"
            case .invalidDifficulty:
                return "Difficulty must be between 1 and 5"
            case .noTargetEvents:
                return "Lessons must have target events"
            case .invalidBPM:
                return "BPM must be between 60 and 300"
            }
        }
    }
    
    enum ValidationWarning: LocalizedError {
        case noDescription
        case noTags
        case shortDuration
        case longDuration
        case unusualBPM
        
        var errorDescription: String? {
            switch self {
            case .noDescription:
                return "Consider adding a description"
            case .noTags:
                return "Consider adding tags for better discoverability"
            case .shortDuration:
                return "Content is very short (< 30 seconds)"
            case .longDuration:
                return "Content is very long (> 10 minutes)"
            case .unusualBPM:
                return "BPM is outside typical range (60-200)"
            }
        }
    }
    
    static func validate(_ item: ContentItem) -> ContentValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // Check title
        if item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyTitle)
        }
        
        // Check duration
        if item.duration <= 0 {
            errors.append(.invalidDuration)
        } else if item.duration < 30 {
            warnings.append(.shortDuration)
        } else if item.duration > 600 {
            warnings.append(.longDuration)
        }
        
        // Check difficulty
        if item.difficulty.rawValue < 1 || item.difficulty.rawValue > 5 {
            errors.append(.invalidDifficulty)
        }
        
        // Check description
        if item.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append(.noDescription)
        }
        
        // Check tags
        if item.tags.isEmpty {
            warnings.append(.noTags)
        }
        
        // Validate based on content type
        switch item.source {
        case .lesson(let lesson):
            // Check BPM
            if lesson.defaultBPM < 60 || lesson.defaultBPM > 300 {
                errors.append(.invalidBPM)
            } else if lesson.defaultBPM < 80 || lesson.defaultBPM > 200 {
                warnings.append(.unusualBPM)
            }
            
            // Check target events
            let hasTargetEvents = lesson.stepsArray.contains { !$0.targetEvents.isEmpty }
            if !hasTargetEvents {
                errors.append(.noTargetEvents)
            }
            
        case .course(let course):
            // Check if course has lessons
            if course.lessonsArray.isEmpty {
                errors.append(.noTargetEvents) // Reuse this error for empty courses
            }
        }
        
        return ContentValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
}

// MARK: - Content Import Result

struct ContentImportResult {
    let success: Bool
    let importedContent: [ContentItem]
    let errors: [ImportError]
    let warnings: [ImportWarning]
    
    enum ImportError: LocalizedError {
        case invalidFileFormat
        case corruptedFile
        case unsupportedVersion
        case missingRequiredData
        case duplicateContent
        
        var errorDescription: String? {
            switch self {
            case .invalidFileFormat:
                return "File format is not supported"
            case .corruptedFile:
                return "File appears to be corrupted"
            case .unsupportedVersion:
                return "File version is not supported"
            case .missingRequiredData:
                return "Required data is missing from file"
            case .duplicateContent:
                return "Content with this ID already exists"
            }
        }
    }
    
    enum ImportWarning: LocalizedError {
        case partialImport
        case dataLoss
        case performanceImpact
        
        var errorDescription: String? {
            switch self {
            case .partialImport:
                return "Some content could not be imported"
            case .dataLoss:
                return "Some data may have been lost during import"
            case .performanceImpact:
                return "Large import may affect app performance"
            }
        }
    }
}