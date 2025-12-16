import Foundation
import CoreData
import CloudKit
import Combine

// MARK: - Core Data Manager

public class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    // MARK: - Published Properties
    @Published var isCloudKitEnabled: Bool = false
    @Published var syncStatus: String = "Not syncing"
    
    // MARK: - Private Properties
    private var cloudKitSyncManager: CloudKitSyncManager?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "DrumTrainerModel")
        
        // Configure for CloudKit
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // CloudKit configuration
        storeDescription?.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.drumtrainer.data"
        )
        
        container.loadPersistentStores { [weak self] _, error in
            if let error = error as NSError? {
                print("Core Data error: \(error), \(error.userInfo)")
                self?.handleCoreDataError(error)
            } else {
                self?.setupCloudKitSync()
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - CloudKit Integration
    
    private func setupCloudKitSync() {
        cloudKitSyncManager = CloudKitSyncManager(coreDataManager: self)
        
        // Subscribe to sync status updates
        cloudKitSyncManager?.syncStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status.displayMessage
                self?.isCloudKitEnabled = status != .accountUnavailable
            }
            .store(in: &cancellables)
        
        // Start syncing
        cloudKitSyncManager?.startSync()
    }
    
    func enableCloudKitSync() {
        cloudKitSyncManager?.startSync()
    }
    
    func disableCloudKitSync() {
        cloudKitSyncManager?.stopSync()
    }
    
    func forceSyncNow() async throws {
        try await cloudKitSyncManager?.forceSyncNow()
    }
    
    func checkCloudKitAccountStatus() async -> CKAccountStatus {
        return await cloudKitSyncManager?.checkAccountStatus() ?? .couldNotDetermine
    }
    
    // MARK: - Core Data Operations
    
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                
                // Trigger CloudKit sync for modified entities
                Task {
                    try? await cloudKitSyncManager?.forceSyncNow()
                }
            } catch {
                let nsError = error as NSError
                print("Core Data save error: \(nsError), \(nsError.userInfo)")
                handleCoreDataError(nsError)
            }
        }
    }
    
    func saveWithoutSync() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Core Data save error: \(nsError), \(nsError.userInfo)")
                handleCoreDataError(nsError)
            }
        }
    }
    
    func delete(_ object: NSManagedObject) {
        context.delete(object)
        save()
    }
    
    // MARK: - Lesson Operations
    
    func createLesson(
        id: String = UUID().uuidString,
        title: String,
        courseId: String? = nil,
        instrument: String = "drums",
        defaultBPM: Float,
        timeSignature: TimeSignature = .fourFour,
        duration: TimeInterval,
        tags: [String] = [],
        difficulty: Int = 1
    ) -> Lesson {
        let lesson = Lesson(context: context)
        lesson.id = id
        lesson.title = title
        lesson.courseId = courseId
        lesson.instrument = instrument
        lesson.defaultBPM = defaultBPM
        lesson.timeSignature = timeSignature
        lesson.duration = duration
        lesson.tagsArray = tags
        lesson.difficulty = Int16(difficulty)
        lesson.createdAt = Date()
        lesson.updatedAt = Date()
        
        // Create default scoring profile
        let scoringProfile = createDefaultScoringProfile()
        lesson.scoringProfile = scoringProfile
        
        save()
        return lesson
    }
    
    func fetchLessons() -> [Lesson] {
        let request: NSFetchRequest<Lesson> = Lesson.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Lesson.createdAt, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching lessons: \(error)")
            return []
        }
    }
    
    func fetchLesson(by id: String) -> Lesson? {
        let request: NSFetchRequest<Lesson> = Lesson.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching lesson: \(error)")
            return nil
        }
    }
    
    // MARK: - Course Operations
    
    func createCourse(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        difficulty: Int = 1,
        tags: [String] = []
    ) -> Course {
        let course = Course(context: context)
        course.id = id
        course.title = title
        course.courseDescription = description
        course.difficulty = Int16(difficulty)
        course.tagsArray = tags
        course.estimatedDuration = 0
        course.createdAt = Date()
        course.updatedAt = Date()
        course.isPublished = false
        
        save()
        return course
    }
    
    func fetchCourses() -> [Course] {
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Course.createdAt, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching courses: \(error)")
            return []
        }
    }
    
    // MARK: - LessonStep Operations
    
    func createLessonStep(
        id: String = UUID().uuidString,
        lessonId: String,
        order: Int,
        title: String,
        description: String,
        targetEvents: [TargetEvent] = [],
        bpmOverride: Float = 0,
        assistLevel: AssistLevel = .full
    ) -> LessonStep {
        let step = LessonStep(context: context)
        step.id = id
        step.lessonId = lessonId
        step.order = Int16(order)
        step.title = title
        step.stepDescription = description
        step.targetEvents = targetEvents
        step.bpmOverride = bpmOverride
        step.assistLevelEnum = assistLevel
        step.createdAt = Date()
        
        // Link to lesson if it exists
        if let lesson = fetchLesson(by: lessonId) {
            step.lesson = lesson
        }
        
        save()
        return step
    }
    
    func fetchLessonSteps(for lessonId: String) -> [LessonStep] {
        let request: NSFetchRequest<LessonStep> = LessonStep.fetchRequest()
        request.predicate = NSPredicate(format: "lessonId == %@", lessonId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LessonStep.order, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching lesson steps: \(error)")
            return []
        }
    }
    
    // MARK: - ScoreResult Operations
    
    func saveScoreResult(_ scoreResult: ScoreResult, for lessonId: String, mode: PlaybackMode) -> ScoreResultEntity {
        let entity = ScoreResultEntity(context: context)
        entity.id = UUID().uuidString
        entity.lessonId = lessonId
        entity.totalScore = scoreResult.totalScore
        entity.starRating = Int16(scoreResult.starRating)
        entity.isPlatinum = scoreResult.isPlatinum
        entity.isBlackStar = scoreResult.isBlackStar
        entity.streakCount = Int16(scoreResult.streakCount)
        entity.maxStreak = Int16(scoreResult.maxStreak)
        entity.missCount = Int16(scoreResult.missCount)
        entity.extraCount = Int16(scoreResult.extraCount)
        entity.perfectCount = Int16(scoreResult.perfectCount)
        entity.earlyCount = Int16(scoreResult.earlyCount)
        entity.lateCount = Int16(scoreResult.lateCount)
        entity.completionTime = scoreResult.completionTime
        entity.completedAt = Date()
        entity.playbackModeEnum = mode
        entity.timingResults = scoreResult.timingResults
        
        // Link to lesson if it exists
        if let lesson = fetchLesson(by: lessonId) {
            entity.lesson = lesson
        }
        
        save()
        return entity
    }
    
    func fetchScoreResults(for lessonId: String) -> [ScoreResultEntity] {
        let request: NSFetchRequest<ScoreResultEntity> = ScoreResultEntity.fetchRequest()
        request.predicate = NSPredicate(format: "lessonId == %@", lessonId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ScoreResultEntity.completedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching score results: \(error)")
            return []
        }
    }
    
    // MARK: - UserProgress Operations
    
    func getUserProgress(for userId: String) -> UserProgress {
        let request: NSFetchRequest<UserProgress> = UserProgress.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.fetchLimit = 1
        
        do {
            if let existing = try context.fetch(request).first {
                return existing
            }
        } catch {
            print("Error fetching user progress: \(error)")
        }
        
        // Create new user progress if none exists
        let progress = UserProgress(context: context)
        progress.id = UUID().uuidString
        progress.userId = userId
        progress.currentLevel = 1
        progress.totalStars = 0
        progress.currentStreak = 0
        progress.maxStreak = 0
        progress.totalTrophies = 0
        progress.dailyGoalMinutes = 5
        progress.totalPracticeTime = 0
        progress.createdAt = Date()
        progress.updatedAt = Date()
        
        save()
        return progress
    }
    
    func updateUserProgress(_ progress: UserProgress, with scoreResult: ScoreResultEntity) {
        progress.totalStars += scoreResult.starRating
        progress.totalPracticeTime += scoreResult.completionTime
        progress.updatedAt = Date()
        
        // Update daily progress
        updateDailyProgress(for: progress.userId, practiceTime: scoreResult.completionTime)
        
        save()
    }
    
    // MARK: - DailyProgress Operations
    
    func updateDailyProgress(for userId: String, practiceTime: TimeInterval) {
        let today = Calendar.current.startOfDay(for: Date())
        
        let request: NSFetchRequest<DailyProgress> = DailyProgress.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND date == %@", userId, today as NSDate)
        request.fetchLimit = 1
        
        do {
            let dailyProgress: DailyProgress
            if let existing = try context.fetch(request).first {
                dailyProgress = existing
            } else {
                dailyProgress = DailyProgress(context: context)
                dailyProgress.id = UUID().uuidString
                dailyProgress.userId = userId
                dailyProgress.date = today
                dailyProgress.practiceTimeMinutes = 0
                dailyProgress.goalAchieved = false
                dailyProgress.lessonsCompleted = 0
                dailyProgress.starsEarned = 0
                dailyProgress.createdAt = Date()
                
                // Link to user progress
                dailyProgress.userProgress = getUserProgress(for: userId)
            }
            
            dailyProgress.practiceTimeMinutes += Int16(practiceTime / 60)
            dailyProgress.lessonsCompleted += 1
            dailyProgress.goalAchieved = dailyProgress.isGoalMet
            
            save()
        } catch {
            print("Error updating daily progress: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createDefaultScoringProfile() -> ScoringProfileEntity {
        let profile = ScoringProfileEntity(context: context)
        profile.id = UUID().uuidString
        profile.perfectWindow = 0.020      // ±20ms
        profile.earlyWindow = 0.050        // ±50ms
        profile.lateWindow = 0.050         // ±50ms
        profile.missThreshold = 0.100      // ±100ms
        profile.extraPenalty = 0.05        // 5% penalty per extra hit
        profile.gradePenaltyMultiplier = 1.0
        profile.streakBonus = 0.01         // 1% bonus per streak hit
        
        return profile
    }
    
    // MARK: - Data Integrity Checks
    
    func validateDataIntegrity() -> [String] {
        var issues: [String] = []
        
        // Check for orphaned lesson steps
        let stepsRequest: NSFetchRequest<LessonStep> = LessonStep.fetchRequest()
        stepsRequest.predicate = NSPredicate(format: "lesson == nil")
        
        do {
            let orphanedSteps = try context.fetch(stepsRequest)
            if !orphanedSteps.isEmpty {
                issues.append("Found \(orphanedSteps.count) orphaned lesson steps")
            }
        } catch {
            issues.append("Error checking lesson steps: \(error)")
        }
        
        // Check for orphaned score results
        let scoresRequest: NSFetchRequest<ScoreResultEntity> = ScoreResultEntity.fetchRequest()
        scoresRequest.predicate = NSPredicate(format: "lesson == nil")
        
        do {
            let orphanedScores = try context.fetch(scoresRequest)
            if !orphanedScores.isEmpty {
                issues.append("Found \(orphanedScores.count) orphaned score results")
            }
        } catch {
            issues.append("Error checking score results: \(error)")
        }
        
        return issues
    }
    
    func repairDataIntegrity() {
        let issues = validateDataIntegrity()
        if issues.isEmpty {
            print("Data integrity check passed")
            return
        }
        
        print("Repairing data integrity issues: \(issues)")
        
        // Remove orphaned lesson steps
        let stepsRequest: NSFetchRequest<LessonStep> = LessonStep.fetchRequest()
        stepsRequest.predicate = NSPredicate(format: "lesson == nil")
        
        do {
            let orphanedSteps = try context.fetch(stepsRequest)
            for step in orphanedSteps {
                context.delete(step)
            }
        } catch {
            print("Error removing orphaned steps: \(error)")
        }
        
        // Remove orphaned score results
        let scoresRequest: NSFetchRequest<ScoreResultEntity> = ScoreResultEntity.fetchRequest()
        scoresRequest.predicate = NSPredicate(format: "lesson == nil")
        
        do {
            let orphanedScores = try context.fetch(scoresRequest)
            for score in orphanedScores {
                context.delete(score)
            }
        } catch {
            print("Error removing orphaned scores: \(error)")
        }
        
        save()
        print("Data integrity repair completed")
    }
    
    // MARK: - Error Handling
    
    private func handleCoreDataError(_ error: NSError) {
        // Log error details
        print("Core Data Error: \(error.localizedDescription)")
        print("Error Info: \(error.userInfo)")
        
        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: .coreDataError,
            object: error
        )
        
        // Attempt recovery based on error type
        if error.code == NSPersistentStoreIncompatibleVersionHashError {
            // Handle model migration
            handleModelMigrationError()
        } else if error.code == NSPersistentStoreIncompatibleSchemaError {
            // Handle schema incompatibility
            handleSchemaError()
        }
    }
    
    private func handleModelMigrationError() {
        print("Attempting automatic model migration...")
        // In a production app, you might want to implement custom migration logic
    }
    
    private func handleSchemaError() {
        print("Schema error detected. CloudKit sync may be affected.")
        // Disable CloudKit sync temporarily
        disableCloudKitSync()
    }
    
    // MARK: - CloudKit Conflict Resolution
    
    func resolveCloudKitConflicts() async throws {
        try await cloudKitSyncManager?.resolveConflicts()
    }
    
    // MARK: - Data Export/Import for Backup
    
    func exportUserData() -> [String: Any] {
        var exportData: [String: Any] = [:]
        
        // Export user progress
        let userProgressRequest: NSFetchRequest<UserProgress> = UserProgress.fetchRequest()
        if let userProgress = try? context.fetch(userProgressRequest) {
            exportData["userProgress"] = userProgress.map { progress in
                [
                    "id": progress.id,
                    "userId": progress.userId,
                    "currentLevel": progress.currentLevel,
                    "totalStars": progress.totalStars,
                    "currentStreak": progress.currentStreak,
                    "maxStreak": progress.maxStreak,
                    "totalTrophies": progress.totalTrophies,
                    "dailyGoalMinutes": progress.dailyGoalMinutes,
                    "totalPracticeTime": progress.totalPracticeTime,
                    "createdAt": progress.createdAt,
                    "updatedAt": progress.updatedAt
                ]
            }
        }
        
        // Export score results
        let scoresRequest: NSFetchRequest<ScoreResultEntity> = ScoreResultEntity.fetchRequest()
        if let scores = try? context.fetch(scoresRequest) {
            exportData["scoreResults"] = scores.map { score in
                [
                    "id": score.id,
                    "lessonId": score.lessonId,
                    "totalScore": score.totalScore,
                    "starRating": score.starRating,
                    "isPlatinum": score.isPlatinum,
                    "isBlackStar": score.isBlackStar,
                    "completedAt": score.completedAt,
                    "playbackMode": score.playbackMode
                ]
            }
        }
        
        return exportData
    }
    
    func importUserData(_ data: [String: Any]) throws {
        // Import user progress
        if let userProgressData = data["userProgress"] as? [[String: Any]] {
            for progressDict in userProgressData {
                // Create or update user progress
                // Implementation would depend on specific requirements
            }
        }
        
        // Import score results
        if let scoresData = data["scoreResults"] as? [[String: Any]] {
            for scoreDict in scoresData {
                // Create or update score results
                // Implementation would depend on specific requirements
            }
        }
        
        save()
    }
}

// MARK: - Fetch Request Extensions

extension Lesson {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Lesson> {
        return NSFetchRequest<Lesson>(entityName: "Lesson")
    }
}

extension Course {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Course> {
        return NSFetchRequest<Course>(entityName: "Course")
    }
}

extension LessonStep {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<LessonStep> {
        return NSFetchRequest<LessonStep>(entityName: "LessonStep")
    }
}

extension ScoreResultEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ScoreResultEntity> {
        return NSFetchRequest<ScoreResultEntity>(entityName: "ScoreResultEntity")
    }
}

extension UserProgress {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserProgress> {
        return NSFetchRequest<UserProgress>(entityName: "UserProgress")
    }
}

extension DailyProgress {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DailyProgress> {
        return NSFetchRequest<DailyProgress>(entityName: "DailyProgress")
    }
}

extension ScoringProfileEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ScoringProfileEntity> {
        return NSFetchRequest<ScoringProfileEntity>(entityName: "ScoringProfileEntity")
    }
}

extension AudioAssetsEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AudioAssetsEntity> {
        return NSFetchRequest<AudioAssetsEntity>(entityName: "AudioAssetsEntity")
    }
}