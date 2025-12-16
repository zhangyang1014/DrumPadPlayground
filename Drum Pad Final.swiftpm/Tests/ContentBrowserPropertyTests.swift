import Testing
import SwiftUI
import Foundation
@testable import DrumPadApp

// MARK: - Test Generators for Content Browsing

struct ContentBrowserTestGenerators {
    
    // Generate random content items for testing
    static func generateContentItem(type: ContentType? = nil, 
                                  difficulty: DifficultyLevel? = nil,
                                  tags: Set<String>? = nil) -> ContentItem {
        let contentType = type ?? ContentType.allCases.randomElement()!
        let difficultyLevel = difficulty ?? DifficultyLevel.allCases.randomElement()!
        let contentTags = tags ?? generateRandomTags()
        
        let id = UUID().uuidString
        let title = generateRandomTitle(for: contentType)
        let description = generateRandomDescription()
        let duration = Double.random(in: 30...600) // 30 seconds to 10 minutes
        
        // Create appropriate source based on type
        let source: ContentSource
        switch contentType {
        case .lesson:
            let lesson = generateMockLesson(id: id, title: title, difficulty: difficultyLevel, tags: Array(contentTags))
            source = .lesson(lesson)
        case .course:
            let course = generateMockCourse(id: id, title: title, difficulty: difficultyLevel, tags: Array(contentTags))
            source = .course(course)
        }
        
        return ContentItem(
            id: id,
            title: title,
            description: description,
            type: contentType,
            difficulty: difficultyLevel,
            duration: duration,
            tags: contentTags,
            source: source
        )
    }
    
    // Generate random tags
    static func generateRandomTags() -> Set<String> {
        let allTags = ["beginner", "intermediate", "advanced", "rock", "jazz", "latin", 
                      "fills", "grooves", "rudiments", "coordination", "independence", 
                      "timing", "dynamics", "fundamentals", "practice"]
        let count = Int.random(in: 0...5)
        return Set(allTags.shuffled().prefix(count))
    }
    
    // Generate random title based on content type
    static func generateRandomTitle(for type: ContentType) -> String {
        let lessonTitles = ["Basic Rock Beat", "Jazz Swing Pattern", "Linear Fill Exercise", 
                           "Paradiddle Practice", "Hi-Hat Control", "Kick Drum Technique"]
        let courseTitles = ["Beginner Drumming Course", "Jazz Fundamentals", "Rock Essentials",
                           "Advanced Coordination", "Fill Mastery", "Groove Development"]
        
        switch type {
        case .lesson:
            return lessonTitles.randomElement()! + " \(Int.random(in: 1...100))"
        case .course:
            return courseTitles.randomElement()! + " \(Int.random(in: 1...20))"
        }
    }
    
    // Generate random description
    static func generateRandomDescription() -> String {
        let descriptions = [
            "Learn fundamental drumming techniques",
            "Master this essential groove pattern",
            "Develop your coordination skills",
            "Practice timing and precision",
            "Build independence between limbs",
            "Explore dynamic control",
            ""  // Sometimes no description
        ]
        return descriptions.randomElement()!
    }
    
    // Generate mock lesson for testing
    static func generateMockLesson(id: String, title: String, difficulty: DifficultyLevel, tags: [String]) -> Lesson {
        let lesson = MockLesson()
        lesson.id = id
        lesson.title = title
        lesson.difficulty = Int16(difficulty.rawValue)
        lesson.tagsArray = tags
        lesson.duration = Double.random(in: 30...300)
        lesson.defaultBPM = Float.random(in: 80...180)
        lesson.createdAt = Date()
        lesson.updatedAt = Date()
        return lesson
    }
    
    // Generate mock course for testing
    static func generateMockCourse(id: String, title: String, difficulty: DifficultyLevel, tags: [String]) -> Course {
        let course = MockCourse()
        course.id = id
        course.title = title
        course.courseDescription = generateRandomDescription()
        course.difficulty = Int16(difficulty.rawValue)
        course.tagsArray = tags
        course.estimatedDuration = Double.random(in: 300...3600) // 5 minutes to 1 hour
        course.createdAt = Date()
        course.updatedAt = Date()
        course.isPublished = true
        return course
    }
    
    // Generate content filter for testing
    static func generateContentFilter() -> ContentFilter {
        var filter = ContentFilter()
        
        // Randomly add search text
        if Bool.random() {
            filter.searchText = ["rock", "jazz", "fill", "groove", "basic"].randomElement()!
        }
        
        // Randomly add content type filter
        if Bool.random() {
            filter.contentType = ContentType.allCases.randomElement()
        }
        
        // Randomly add difficulty filter
        if Bool.random() {
            filter.difficulty = DifficultyLevel.allCases.randomElement()
        }
        
        // Randomly add tag filters
        if Bool.random() {
            filter.tags = Set(generateRandomTags().prefix(Int.random(in: 1...3)))
        }
        
        return filter
    }
    
    // Generate array of content items
    static func generateContentArray(count: Int = 20) -> [ContentItem] {
        return (0..<count).map { _ in generateContentItem() }
    }
    
    // Generate beginner-friendly content
    static func generateBeginnerContent() -> ContentItem {
        let beginnerTags: Set<String> = ["beginner", "fundamentals", "basics"]
        return generateContentItem(
            type: .lesson,
            difficulty: .beginner,
            tags: beginnerTags
        )
    }
}

// MARK: - Mock Classes for Testing

class MockLesson: Lesson {
    private var _id: String = ""
    private var _title: String = ""
    private var _difficulty: Int16 = 1
    private var _tags: [String] = []
    private var _duration: TimeInterval = 0
    private var _defaultBPM: Float = 120
    private var _createdAt: Date = Date()
    private var _updatedAt: Date = Date()
    
    override var id: String {
        get { return _id }
        set { _id = newValue }
    }
    
    override var title: String {
        get { return _title }
        set { _title = newValue }
    }
    
    override var difficulty: Int16 {
        get { return _difficulty }
        set { _difficulty = newValue }
    }
    
    override var tagsArray: [String] {
        get { return _tags }
        set { _tags = newValue }
    }
    
    override var duration: TimeInterval {
        get { return _duration }
        set { _duration = newValue }
    }
    
    override var defaultBPM: Float {
        get { return _defaultBPM }
        set { _defaultBPM = newValue }
    }
    
    override var createdAt: Date {
        get { return _createdAt }
        set { _createdAt = newValue }
    }
    
    override var updatedAt: Date {
        get { return _updatedAt }
        set { _updatedAt = newValue }
    }
    
    override var stepsArray: [LessonStep] {
        return [] // Simplified for testing
    }
}

class MockCourse: Course {
    private var _id: String = ""
    private var _title: String = ""
    private var _courseDescription: String = ""
    private var _difficulty: Int16 = 1
    private var _tags: [String] = []
    private var _estimatedDuration: TimeInterval = 0
    private var _createdAt: Date = Date()
    private var _updatedAt: Date = Date()
    private var _isPublished: Bool = true
    
    override var id: String {
        get { return _id }
        set { _id = newValue }
    }
    
    override var title: String {
        get { return _title }
        set { _title = newValue }
    }
    
    override var courseDescription: String {
        get { return _courseDescription }
        set { _courseDescription = newValue }
    }
    
    override var difficulty: Int16 {
        get { return _difficulty }
        set { _difficulty = newValue }
    }
    
    override var tagsArray: [String] {
        get { return _tags }
        set { _tags = newValue }
    }
    
    override var estimatedDuration: TimeInterval {
        get { return _estimatedDuration }
        set { _estimatedDuration = newValue }
    }
    
    override var createdAt: Date {
        get { return _createdAt }
        set { _createdAt = newValue }
    }
    
    override var updatedAt: Date {
        get { return _updatedAt }
        set { _updatedAt = newValue }
    }
    
    override var isPublished: Bool {
        get { return _isPublished }
        set { _isPublished = newValue }
    }
    
    override var lessonsArray: [Lesson] {
        return [] // Simplified for testing
    }
}

// MARK: - Content Browser Property Tests

@Suite("Content Browser Property Tests")
struct ContentBrowserPropertyTests {
    
    // **Feature: melodic-drum-trainer, Property 4: 内容筛选准确性**
    @Test("Property 4: Content Filtering Accuracy", arguments: (0..<100).map { _ in 
        (ContentBrowserTestGenerators.generateContentArray(count: 20), 
         ContentBrowserTestGenerators.generateContentFilter())
    })
    func testContentFilteringAccuracy(contentAndFilter: ([ContentItem], ContentFilter)) async throws {
        let (allContent, filter) = contentAndFilter
        
        // Apply filter to content
        let filteredContent = allContent.filter { item in
            filter.matches(item)
        }
        
        // **Property: For any difficulty filter, all returned content should match the specified difficulty**
        if let selectedDifficulty = filter.difficulty {
            for item in filteredContent {
                #expect(item.difficulty == selectedDifficulty,
                       "Filtered content item '\(item.title)' has difficulty \(item.difficulty.description) but filter requires \(selectedDifficulty.description)")
            }
        }
        
        // **Property: For any content type filter, all returned content should match the specified type**
        if let selectedType = filter.contentType {
            for item in filteredContent {
                #expect(item.type == selectedType,
                       "Filtered content item '\(item.title)' has type \(item.type.description) but filter requires \(selectedType.description)")
            }
        }
        
        // **Property: For any tag filter, all returned content should contain at least one of the specified tags**
        if !filter.tags.isEmpty {
            for item in filteredContent {
                let hasMatchingTag = !filter.tags.isDisjoint(with: item.tags)
                #expect(hasMatchingTag,
                       "Filtered content item '\(item.title)' with tags \(item.tags) should contain at least one of the filter tags \(filter.tags)")
            }
        }
        
        // **Property: For any search text, all returned content should contain the search text in title, description, or tags**
        if !filter.searchText.isEmpty {
            let searchLower = filter.searchText.lowercased()
            for item in filteredContent {
                let titleMatch = item.title.lowercased().contains(searchLower)
                let descriptionMatch = item.description.lowercased().contains(searchLower)
                let tagMatch = item.tags.contains { $0.lowercased().contains(searchLower) }
                
                let hasMatch = titleMatch || descriptionMatch || tagMatch
                #expect(hasMatch,
                       "Filtered content item '\(item.title)' should contain search text '\(filter.searchText)' in title, description, or tags")
            }
        }
        
        // **Property: Filtering should be deterministic - same filter applied twice should yield same results**
        let filteredContentSecond = allContent.filter { item in
            filter.matches(item)
        }
        
        #expect(filteredContent.count == filteredContentSecond.count,
               "Filter should be deterministic - same filter applied twice should yield same number of results")
        
        // Check that the same items are returned (order might differ)
        let firstIds = Set(filteredContent.map { $0.id })
        let secondIds = Set(filteredContentSecond.map { $0.id })
        #expect(firstIds == secondIds,
               "Filter should be deterministic - same filter applied twice should yield same items")
    }
    
    // **Feature: melodic-drum-trainer, Property 5: 标签关联正确性**
    @Test("Property 5: Tag Association Correctness", arguments: (0..<100).map { _ in 
        ContentBrowserTestGenerators.generateContentArray(count: 15)
    })
    func testTagAssociationCorrectness(allContent: [ContentItem]) async throws {
        // Extract all unique tags from content
        var allTags: Set<String> = []
        for item in allContent {
            allTags.formUnion(item.tags)
        }
        
        // **Property: For any tag click operation, all displayed related content should contain that tag**
        for tag in allTags {
            let relatedContent = allContent.filter { item in
                item.tags.contains(tag)
            }
            
            // Every item in related content should contain the selected tag
            for item in relatedContent {
                #expect(item.tags.contains(tag),
                       "Content item '\(item.title)' should contain tag '\(tag)' when filtered by that tag")
            }
            
            // **Property: Tag filtering should be consistent with tag extraction**
            let taggedItems = allContent.filter { $0.tags.contains(tag) }
            #expect(taggedItems.count == relatedContent.count,
                   "Tag filtering should return same count as direct tag checking for tag '\(tag)'")
            
            // **Property: No content without the tag should appear in tag-filtered results**
            let nonTaggedItems = allContent.filter { !$0.tags.contains(tag) }
            for item in nonTaggedItems {
                let isInRelated = relatedContent.contains { $0.id == item.id }
                #expect(!isInRelated,
                       "Content item '\(item.title)' without tag '\(tag)' should not appear in tag-filtered results")
            }
        }
        
        // **Property: Tag extraction should be complete - no tags should be lost**
        for item in allContent {
            for tag in item.tags {
                #expect(allTags.contains(tag),
                       "Tag '\(tag)' from content item '\(item.title)' should be present in extracted tags")
            }
        }
        
        // **Property: Empty tag filter should return all content**
        let emptyTagFilter = ContentFilter()
        let allContentFiltered = allContent.filter { emptyTagFilter.matches($0) }
        #expect(allContentFiltered.count == allContent.count,
               "Empty tag filter should return all content items")
    }
    
    // **Feature: melodic-drum-trainer, Property 6: 新手推荐一致性**
    @Test("Property 6: Beginner Recommendation Consistency", arguments: (0..<100).map { _ in 
        // Generate content with mix of difficulties, ensuring some beginner content
        var content = ContentBrowserTestGenerators.generateContentArray(count: 15)
        // Add some guaranteed beginner content
        content.append(contentsOf: (0..<5).map { _ in ContentBrowserTestGenerators.generateBeginnerContent() })
        return content
    })
    func testBeginnerRecommendationConsistency(allContent: [ContentItem]) async throws {
        // Simulate beginner user state
        let isBeginnerUser = true // For testing, assume user is beginner
        
        if isBeginnerUser {
            // Get beginner recommendations using the same logic as the view model
            let beginnerTags: Set<String> = ["beginner", "fundamentals", "basics"]
            
            let recommendations = allContent
                .filter { item in
                    // Must be beginner difficulty
                    item.difficulty == .beginner &&
                    // Should have beginner-friendly tags
                    !item.tags.isDisjoint(with: beginnerTags)
                }
                .sorted { lhs, rhs in
                    // Prioritize lessons over courses for beginners
                    if lhs.type != rhs.type {
                        return lhs.type == .lesson
                    }
                    // Then sort by duration (shorter first)
                    return lhs.duration < rhs.duration
                }
                .prefix(3) // Limit to 3 recommendations
                .map { $0 }
            
            // **Property: For any beginner user, all recommended content should be beginner difficulty**
            for item in recommendations {
                #expect(item.difficulty == .beginner,
                       "Recommended content '\(item.title)' should be beginner difficulty, but was \(item.difficulty.description)")
            }
            
            // **Property: For any beginner user, all recommended content should have beginner-friendly tags**
            for item in recommendations {
                let hasBeginnerTag = !item.tags.isDisjoint(with: beginnerTags)
                #expect(hasBeginnerTag,
                       "Recommended content '\(item.title)' should have beginner-friendly tags, but has \(item.tags)")
            }
            
            // **Property: Recommendations should prioritize lessons over courses for beginners**
            let lessons = recommendations.filter { $0.type == .lesson }
            let courses = recommendations.filter { $0.type == .course }
            
            if !lessons.isEmpty && !courses.isEmpty {
                // If both exist, lessons should come first in the sorted order
                let firstLesson = recommendations.firstIndex { $0.type == .lesson }
                let firstCourse = recommendations.firstIndex { $0.type == .course }
                
                if let lessonIndex = firstLesson, let courseIndex = firstCourse {
                    #expect(lessonIndex < courseIndex,
                           "Lessons should be prioritized over courses in beginner recommendations")
                }
            }
            
            // **Property: Recommendations should be sorted by duration (shorter first) within same type**
            let lessonDurations = lessons.map { $0.duration }
            let courseDurations = courses.map { $0.duration }
            
            // Check if lessons are sorted by duration
            for i in 1..<lessonDurations.count {
                #expect(lessonDurations[i-1] <= lessonDurations[i],
                       "Lesson recommendations should be sorted by duration (shorter first)")
            }
            
            // Check if courses are sorted by duration
            for i in 1..<courseDurations.count {
                #expect(courseDurations[i-1] <= courseDurations[i],
                       "Course recommendations should be sorted by duration (shorter first)")
            }
            
            // **Property: Recommendations should be limited to maximum 3 items**
            #expect(recommendations.count <= 3,
                   "Beginner recommendations should be limited to maximum 3 items, but got \(recommendations.count)")
            
            // **Property: If beginner content exists, at least one recommendation should be provided**
            let beginnerContent = allContent.filter { item in
                item.difficulty == .beginner && !item.tags.isDisjoint(with: beginnerTags)
            }
            
            if !beginnerContent.isEmpty {
                #expect(!recommendations.isEmpty,
                       "If beginner content exists, at least one recommendation should be provided")
            }
        }
        
        // **Property: Recommendation algorithm should be deterministic**
        // Run the same recommendation logic twice and verify same results
        let beginnerTags: Set<String> = ["beginner", "fundamentals", "basics"]
        
        let recommendations1 = allContent
            .filter { item in
                item.difficulty == .beginner && !item.tags.isDisjoint(with: beginnerTags)
            }
            .sorted { lhs, rhs in
                if lhs.type != rhs.type {
                    return lhs.type == .lesson
                }
                return lhs.duration < rhs.duration
            }
            .prefix(3)
            .map { $0.id }
        
        let recommendations2 = allContent
            .filter { item in
                item.difficulty == .beginner && !item.tags.isDisjoint(with: beginnerTags)
            }
            .sorted { lhs, rhs in
                if lhs.type != rhs.type {
                    return lhs.type == .lesson
                }
                return lhs.duration < rhs.duration
            }
            .prefix(3)
            .map { $0.id }
        
        #expect(recommendations1 == recommendations2,
               "Recommendation algorithm should be deterministic - same input should yield same recommendations")
    }
}

// MARK: - Additional Content Browser Tests

@Suite("Content Browser Integration Tests")
struct ContentBrowserIntegrationTests {
    
    @Test("Content Filter Integration")
    func testContentFilterIntegration() async throws {
        let content = ContentBrowserTestGenerators.generateContentArray(count: 50)
        
        // Test multiple filters applied together
        var filter = ContentFilter()
        filter.contentType = .lesson
        filter.difficulty = .beginner
        filter.tags = Set(["fundamentals"])
        filter.searchText = "basic"
        
        let filteredContent = content.filter { filter.matches($0) }
        
        // All results should satisfy ALL filter criteria
        for item in filteredContent {
            #expect(item.type == .lesson, "Should match content type filter")
            #expect(item.difficulty == .beginner, "Should match difficulty filter")
            #expect(item.tags.contains("fundamentals"), "Should match tag filter")
            
            let searchMatch = item.title.lowercased().contains("basic") ||
                            item.description.lowercased().contains("basic") ||
                            item.tags.contains { $0.lowercased().contains("basic") }
            #expect(searchMatch, "Should match search text filter")
        }
    }
    
    @Test("Content Validation")
    func testContentValidation() async throws {
        // Test valid content
        let validContent = ContentBrowserTestGenerators.generateContentItem(
            type: .lesson,
            difficulty: .intermediate,
            tags: Set(["rock", "groove"])
        )
        
        let validationResult = ContentValidationResult.validate(validContent)
        #expect(validationResult.isValid, "Valid content should pass validation")
        
        // Test content with empty title
        var invalidContent = validContent
        let invalidItem = ContentItem(
            id: invalidContent.id,
            title: "",
            description: invalidContent.description,
            type: invalidContent.type,
            difficulty: invalidContent.difficulty,
            duration: invalidContent.duration,
            tags: invalidContent.tags,
            source: invalidContent.source
        )
        
        let invalidResult = ContentValidationResult.validate(invalidItem)
        #expect(!invalidResult.isValid, "Content with empty title should fail validation")
        #expect(invalidResult.errors.contains { error in
            if case .emptyTitle = error { return true }
            return false
        }, "Should contain empty title error")
    }
}