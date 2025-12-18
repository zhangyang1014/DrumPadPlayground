import Foundation
import CoreData
import Combine

// MARK: - Content Browser View Model

class ContentBrowserViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var searchText: String = ""
    @Published var selectedContentType: ContentType?
    @Published var selectedDifficulty: DifficultyLevel?
    @Published var selectedTags: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var selectedContent: ContentItem?
    
    // MARK: - Computed Properties
    @Published private var allContent: [ContentItem] = []
    @Published private var allTags: Set<String> = []
    
    var filteredContent: [ContentItem] {
        return filterContent(allContent)
    }
    
    var availableTags: [String] {
        return Array(allTags).sorted()
    }
    
    var hasActiveFilters: Bool {
        return !searchText.isEmpty || 
               selectedContentType != nil || 
               selectedDifficulty != nil || 
               !selectedTags.isEmpty
    }
    
    var shouldShowBeginnerRecommendations: Bool {
        return !hasActiveFilters && isBeginnerUser()
    }
    
    var beginnerRecommendations: [ContentItem] {
        return getBeginnerRecommendations()
    }
    
    var contentSectionTitle: String {
        if hasActiveFilters {
            let count = filteredContent.count
            return "Results (\(count))"
        } else {
            return "All Content"
        }
    }
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let coreDataManager: CoreDataManager = .shared
    
    // MARK: - Initialization
    
    init() {
        setupSearchDebouncing()
    }
    
    private func setupSearchDebouncing() {
        // Debounce search text changes to avoid excessive filtering
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // React to filter changes
        Publishers.CombineLatest4(
            $selectedContentType,
            $selectedDifficulty,
            $selectedTags,
            $searchText
        )
        .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadContent(context: NSManagedObjectContext? = nil) {
        isLoading = true
        let contextToUse: NSManagedObjectContext? = context ?? coreDataManager.context
        
        guard let contextToUse = contextToUse else {
            isLoading = false
            return
        }
        
        // 在上下文队列内执行，避免跨线程访问导致崩溃
        contextToUse.perform { [weak self] in
            guard let self = self else { return }
            
            let lessons = self.fetchLessons(context: contextToUse)
            let courses = self.fetchCourses(context: contextToUse)
            
            let contentItems = lessons + courses
            let tags = self.extractTags(from: contentItems)
            
            DispatchQueue.main.async {
                self.allContent = contentItems
                self.allTags = tags
                self.isLoading = false
            }
        }
    }
    
    func clearFilters() {
        searchText = ""
        selectedContentType = nil
        selectedDifficulty = nil
        selectedTags.removeAll()
    }
    
    func selectContent(_ content: ContentItem) {
        selectedContent = content
    }
    
    func refreshContent() {
        loadContent(context: coreDataManager.context)
    }
    
    // MARK: - Private Methods
    
    private func fetchLessons(context: NSManagedObjectContext) -> [ContentItem] {
        // 防御：若当前模型未包含 Lesson 实体则直接返回空，避免 entityForName 崩溃
        guard context.persistentStoreCoordinator?.managedObjectModel.entitiesByName["Lesson"] != nil else {
            print("Warning: Lesson entity not found in managed object model.")
            return []
        }
        let request: NSFetchRequest<Lesson> = Lesson.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Lesson.difficulty, ascending: true),
            NSSortDescriptor(keyPath: \Lesson.createdAt, ascending: false)
        ]
        
        do {
            let lessons = try context.fetch(request)
            return lessons.map { lesson in
                ContentItem(
                    id: lesson.id,
                    title: lesson.title,
                    description: "", // Lessons don't have descriptions in the current model
                    type: .lesson,
                    difficulty: DifficultyLevel(rawValue: Int(lesson.difficulty)) ?? .beginner,
                    duration: lesson.duration,
                    tags: Set(lesson.tagsArray),
                    source: .lesson(lesson)
                )
            }
        } catch {
            print("Error fetching lessons: \(error)")
            return []
        }
    }
    
    private func fetchCourses(context: NSManagedObjectContext) -> [ContentItem] {
        // 防御：若当前模型未包含 Course 实体则直接返回空，避免 entityForName 崩溃
        guard context.persistentStoreCoordinator?.managedObjectModel.entitiesByName["Course"] != nil else {
            print("Warning: Course entity not found in managed object model.")
            return []
        }
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "isPublished == YES")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Course.difficulty, ascending: true),
            NSSortDescriptor(keyPath: \Course.createdAt, ascending: false)
        ]
        
        do {
            let courses = try context.fetch(request)
            return courses.map { course in
                ContentItem(
                    id: course.id,
                    title: course.title,
                    description: course.courseDescription,
                    type: .course,
                    difficulty: DifficultyLevel(rawValue: Int(course.difficulty)) ?? .beginner,
                    duration: course.estimatedDuration,
                    tags: Set(course.tagsArray),
                    source: .course(course)
                )
            }
        } catch {
            print("Error fetching courses: \(error)")
            return []
        }
    }
    
    private func extractTags(from content: [ContentItem]) -> Set<String> {
        var allTags: Set<String> = []
        for item in content {
            allTags.formUnion(item.tags)
        }
        return allTags
    }
    
    private func filterContent(_ content: [ContentItem]) -> [ContentItem] {
        return content.filter { item in
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
            if let selectedType = selectedContentType, item.type != selectedType {
                return false
            }
            
            // Difficulty filter
            if let selectedDiff = selectedDifficulty, item.difficulty != selectedDiff {
                return false
            }
            
            // Tags filter
            if !selectedTags.isEmpty {
                let hasMatchingTag = !selectedTags.isDisjoint(with: item.tags)
                if !hasMatchingTag {
                    return false
                }
            }
            
            return true
        }
    }
    
    private func isBeginnerUser() -> Bool {
        // Check if user is a beginner based on their progress
        let userProgress = coreDataManager.getUserProgress(for: "default_user")
        return userProgress.currentLevel <= 2 && userProgress.totalStars < 10
    }
    
    private func getBeginnerRecommendations() -> [ContentItem] {
        // Get beginner-friendly content with specific tags
        let beginnerTags: Set<String> = ["beginner", "basics", "fundamentals", "intro"]
        
        return allContent
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
    }
}

// MARK: - Content Filtering Extensions

extension ContentBrowserViewModel {
    
    func filterByDifficulty(_ difficulty: DifficultyLevel) {
        selectedDifficulty = difficulty
    }
    
    func filterByTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    func filterByContentType(_ type: ContentType) {
        selectedContentType = type
    }
    
    func searchFor(_ text: String) {
        searchText = text
    }
    
    func getFilterSummary() -> String {
        var components: [String] = []
        
        if let type = selectedContentType {
            components.append(type.description)
        }
        
        if let difficulty = selectedDifficulty {
            components.append(difficulty.description)
        }
        
        if !selectedTags.isEmpty {
            let tagList = Array(selectedTags).prefix(2).joined(separator: ", ")
            let tagSuffix = selectedTags.count > 2 ? " +\(selectedTags.count - 2)" : ""
            components.append("Tags: \(tagList)\(tagSuffix)")
        }
        
        if !searchText.isEmpty {
            components.append("Search: \"\(searchText)\"")
        }
        
        return components.isEmpty ? "No filters" : components.joined(separator: " • ")
    }
}

// MARK: - Content Sorting

extension ContentBrowserViewModel {
    
    enum SortOption: String, CaseIterable {
        case titleAscending = "title_asc"
        case titleDescending = "title_desc"
        case difficultyAscending = "difficulty_asc"
        case difficultyDescending = "difficulty_desc"
        case durationAscending = "duration_asc"
        case durationDescending = "duration_desc"
        case dateCreatedAscending = "created_asc"
        case dateCreatedDescending = "created_desc"
        
        var displayName: String {
            switch self {
            case .titleAscending: return "Title A-Z"
            case .titleDescending: return "Title Z-A"
            case .difficultyAscending: return "Difficulty: Easy First"
            case .difficultyDescending: return "Difficulty: Hard First"
            case .durationAscending: return "Duration: Short First"
            case .durationDescending: return "Duration: Long First"
            case .dateCreatedAscending: return "Oldest First"
            case .dateCreatedDescending: return "Newest First"
            }
        }
    }
    
    func sortContent(_ content: [ContentItem], by option: SortOption) -> [ContentItem] {
        switch option {
        case .titleAscending:
            return content.sorted { $0.title < $1.title }
        case .titleDescending:
            return content.sorted { $0.title > $1.title }
        case .difficultyAscending:
            return content.sorted { $0.difficulty.rawValue < $1.difficulty.rawValue }
        case .difficultyDescending:
            return content.sorted { $0.difficulty.rawValue > $1.difficulty.rawValue }
        case .durationAscending:
            return content.sorted { $0.duration < $1.duration }
        case .durationDescending:
            return content.sorted { $0.duration > $1.duration }
        case .dateCreatedAscending:
            return content.sorted { $0.createdAt < $1.createdAt }
        case .dateCreatedDescending:
            return content.sorted { $0.createdAt > $1.createdAt }
        }
    }
}

// MARK: - Content Statistics

extension ContentBrowserViewModel {
    
    struct ContentStatistics {
        let totalLessons: Int
        let totalCourses: Int
        let averageDifficulty: Double
        let totalDuration: TimeInterval
        let mostCommonTags: [String]
        let difficultyDistribution: [DifficultyLevel: Int]
    }
    
    func getContentStatistics() -> ContentStatistics {
        let lessons = allContent.filter { $0.type == .lesson }
        let courses = allContent.filter { $0.type == .course }
        
        let totalDuration = allContent.reduce(0) { $0 + $1.duration }
        
        let difficulties = allContent.map { $0.difficulty.rawValue }
        let averageDifficulty = difficulties.isEmpty ? 0 : Double(difficulties.reduce(0, +)) / Double(difficulties.count)
        
        // Calculate difficulty distribution
        var difficultyDistribution: [DifficultyLevel: Int] = [:]
        for item in allContent {
            difficultyDistribution[item.difficulty, default: 0] += 1
        }
        
        // Find most common tags
        var tagCounts: [String: Int] = [:]
        for item in allContent {
            for tag in item.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        let mostCommonTags = tagCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
        
        return ContentStatistics(
            totalLessons: lessons.count,
            totalCourses: courses.count,
            averageDifficulty: averageDifficulty,
            totalDuration: totalDuration,
            mostCommonTags: mostCommonTags,
            difficultyDistribution: difficultyDistribution
        )
    }
}