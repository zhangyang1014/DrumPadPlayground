import Foundation
import CoreData
import CloudKit
import Combine

// MARK: - CloudKit Sync Manager Protocol

protocol CloudKitSyncManagerProtocol {
    func startSync()
    func stopSync()
    func forceSyncNow() async throws
    func checkAccountStatus() async -> CKAccountStatus
    func resolveConflicts() async throws
    var syncStatus: CloudKitSyncStatus { get }
    var syncStatusPublisher: AnyPublisher<CloudKitSyncStatus, Never> { get }
}

// MARK: - CloudKit Sync Status

public enum CloudKitSyncStatus {
    case notStarted
    case syncing
    case synced
    case error(CloudKitSyncError)
    case accountUnavailable
    case networkUnavailable
    
    public var isActive: Bool {
        switch self {
        case .syncing:
            return true
        default:
            return false
        }
    }
    
    public var displayMessage: String {
        switch self {
        case .notStarted:
            return "Sync not started"
        case .syncing:
            return "Syncing with iCloud..."
        case .synced:
            return "Synced with iCloud"
        case .error(let error):
            return "Sync error: \(error.localizedDescription)"
        case .accountUnavailable:
            return "iCloud account unavailable"
        case .networkUnavailable:
            return "Network unavailable"
        }
    }
}

// MARK: - CloudKit Sync Errors

public enum CloudKitSyncError: Error, LocalizedError {
    case accountNotAvailable
    case networkUnavailable
    case quotaExceeded
    case conflictResolutionFailed
    case unknownError(Error)
    case recordNotFound
    case invalidRecordType
    case permissionFailure
    
    public var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            return "iCloud account is not available. Please sign in to iCloud in Settings."
        case .networkUnavailable:
            return "Network connection is unavailable. Please check your internet connection."
        case .quotaExceeded:
            return "iCloud storage quota exceeded. Please free up space in iCloud."
        case .conflictResolutionFailed:
            return "Failed to resolve data conflicts. Some changes may be lost."
        case .unknownError(let error):
            return "Unknown sync error: \(error.localizedDescription)"
        case .recordNotFound:
            return "Record not found in CloudKit"
        case .invalidRecordType:
            return "Invalid record type for CloudKit"
        case .permissionFailure:
            return "Permission denied for CloudKit operation"
        }
    }
}

// MARK: - CloudKit Sync Manager Implementation

public class CloudKitSyncManager: ObservableObject, CloudKitSyncManagerProtocol {
    
    // MARK: - Published Properties
    @Published private(set) var syncStatus: CloudKitSyncStatus = .notStarted
    
    // MARK: - Private Properties
    private let coreDataManager: CoreDataManager
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?
    private let syncInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Publishers
    public var syncStatusPublisher: AnyPublisher<CloudKitSyncStatus, Never> {
        $syncStatus.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init(coreDataManager: CoreDataManager = .shared) {
        self.coreDataManager = coreDataManager
        self.container = CKContainer(identifier: "iCloud.com.drumtrainer.data")
        self.privateDatabase = container.privateCloudDatabase
        
        setupNotifications()
    }
    
    deinit {
        stopSync()
    }
    
    // MARK: - Public Interface
    
    func startSync() {
        guard syncStatus != .syncing else { return }
        
        Task {
            await checkAndStartSync()
        }
        
        // Setup periodic sync
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performPeriodicSync()
            }
        }
    }
    
    func stopSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        
        if syncStatus.isActive {
            DispatchQueue.main.async {
                self.syncStatus = .notStarted
            }
        }
    }
    
    func forceSyncNow() async throws {
        try await performFullSync()
    }
    
    func checkAccountStatus() async -> CKAccountStatus {
        do {
            return try await container.accountStatus()
        } catch {
            print("Error checking CloudKit account status: \(error)")
            return .couldNotDetermine
        }
    }
    
    func resolveConflicts() async throws {
        try await performConflictResolution()
    }
    
    // MARK: - Private Sync Methods
    
    private func checkAndStartSync() async {
        let accountStatus = await checkAccountStatus()
        
        await MainActor.run {
            switch accountStatus {
            case .available:
                self.syncStatus = .syncing
            case .noAccount, .restricted:
                self.syncStatus = .accountUnavailable
                return
            case .couldNotDetermine:
                self.syncStatus = .error(.accountNotAvailable)
                return
            @unknown default:
                self.syncStatus = .error(.accountNotAvailable)
                return
            }
        }
        
        do {
            try await performFullSync()
            await MainActor.run {
                self.syncStatus = .synced
            }
        } catch {
            await MainActor.run {
                self.syncStatus = .error(self.mapError(error))
            }
        }
    }
    
    private func performPeriodicSync() async {
        guard syncStatus != .syncing else { return }
        
        do {
            await MainActor.run {
                self.syncStatus = .syncing
            }
            
            try await performIncrementalSync()
            
            await MainActor.run {
                self.syncStatus = .synced
            }
        } catch {
            await MainActor.run {
                self.syncStatus = .error(self.mapError(error))
            }
        }
    }
    
    private func performFullSync() async throws {
        // Sync all entity types
        try await syncUserProgress()
        try await syncLessons()
        try await syncCourses()
        try await syncScoreResults()
        try await syncDailyProgress()
        
        // Resolve any conflicts
        try await performConflictResolution()
    }
    
    private func performIncrementalSync() async throws {
        // Only sync entities that have been modified recently
        let lastSyncDate = UserDefaults.standard.object(forKey: "lastCloudKitSync") as? Date ?? Date.distantPast
        
        try await syncModifiedEntities(since: lastSyncDate)
        
        // Update last sync timestamp
        UserDefaults.standard.set(Date(), forKey: "lastCloudKitSync")
    }
    
    // MARK: - Entity-Specific Sync Methods
    
    private func syncUserProgress() async throws {
        let request: NSFetchRequest<UserProgress> = UserProgress.fetchRequest()
        let localProgress = try coreDataManager.context.fetch(request)
        
        for progress in localProgress {
            try await syncUserProgressEntity(progress)
        }
        
        // Fetch remote changes
        try await fetchRemoteUserProgress()
    }
    
    private func syncUserProgressEntity(_ progress: UserProgress) async throws {
        let recordID = CKRecord.ID(recordName: progress.id)
        
        do {
            // Try to fetch existing record
            let existingRecord = try await privateDatabase.record(for: recordID)
            updateUserProgressRecord(existingRecord, with: progress)
            _ = try await privateDatabase.save(existingRecord)
        } catch CKError.unknownItem {
            // Create new record
            let newRecord = createUserProgressRecord(from: progress)
            _ = try await privateDatabase.save(newRecord)
        }
    }
    
    private func fetchRemoteUserProgress() async throws {
        let query = CKQuery(recordType: "UserProgress", predicate: NSPredicate(value: true))
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                try await updateLocalUserProgress(from: record)
            case .failure(let error):
                print("Error fetching UserProgress record: \(error)")
            }
        }
    }
    
    private func syncLessons() async throws {
        let request: NSFetchRequest<Lesson> = Lesson.fetchRequest()
        let localLessons = try coreDataManager.context.fetch(request)
        
        for lesson in localLessons {
            try await syncLessonEntity(lesson)
        }
        
        try await fetchRemoteLessons()
    }
    
    private func syncLessonEntity(_ lesson: Lesson) async throws {
        let recordID = CKRecord.ID(recordName: lesson.id)
        
        do {
            let existingRecord = try await privateDatabase.record(for: recordID)
            updateLessonRecord(existingRecord, with: lesson)
            _ = try await privateDatabase.save(existingRecord)
        } catch CKError.unknownItem {
            let newRecord = createLessonRecord(from: lesson)
            _ = try await privateDatabase.save(newRecord)
        }
    }
    
    private func fetchRemoteLessons() async throws {
        let query = CKQuery(recordType: "Lesson", predicate: NSPredicate(value: true))
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                try await updateLocalLesson(from: record)
            case .failure(let error):
                print("Error fetching Lesson record: \(error)")
            }
        }
    }
    
    private func syncCourses() async throws {
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        let localCourses = try coreDataManager.context.fetch(request)
        
        for course in localCourses {
            try await syncCourseEntity(course)
        }
        
        try await fetchRemoteCourses()
    }
    
    private func syncCourseEntity(_ course: Course) async throws {
        let recordID = CKRecord.ID(recordName: course.id)
        
        do {
            let existingRecord = try await privateDatabase.record(for: recordID)
            updateCourseRecord(existingRecord, with: course)
            _ = try await privateDatabase.save(existingRecord)
        } catch CKError.unknownItem {
            let newRecord = createCourseRecord(from: course)
            _ = try await privateDatabase.save(newRecord)
        }
    }
    
    private func fetchRemoteCourses() async throws {
        let query = CKQuery(recordType: "Course", predicate: NSPredicate(value: true))
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                try await updateLocalCourse(from: record)
            case .failure(let error):
                print("Error fetching Course record: \(error)")
            }
        }
    }
    
    private func syncScoreResults() async throws {
        let request: NSFetchRequest<ScoreResultEntity> = ScoreResultEntity.fetchRequest()
        let localScores = try coreDataManager.context.fetch(request)
        
        for score in localScores {
            try await syncScoreResultEntity(score)
        }
        
        try await fetchRemoteScoreResults()
    }
    
    private func syncScoreResultEntity(_ score: ScoreResultEntity) async throws {
        let recordID = CKRecord.ID(recordName: score.id)
        
        do {
            let existingRecord = try await privateDatabase.record(for: recordID)
            updateScoreResultRecord(existingRecord, with: score)
            _ = try await privateDatabase.save(existingRecord)
        } catch CKError.unknownItem {
            let newRecord = createScoreResultRecord(from: score)
            _ = try await privateDatabase.save(newRecord)
        }
    }
    
    private func fetchRemoteScoreResults() async throws {
        let query = CKQuery(recordType: "ScoreResult", predicate: NSPredicate(value: true))
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                try await updateLocalScoreResult(from: record)
            case .failure(let error):
                print("Error fetching ScoreResult record: \(error)")
            }
        }
    }
    
    private func syncDailyProgress() async throws {
        let request: NSFetchRequest<DailyProgress> = DailyProgress.fetchRequest()
        let localProgress = try coreDataManager.context.fetch(request)
        
        for progress in localProgress {
            try await syncDailyProgressEntity(progress)
        }
        
        try await fetchRemoteDailyProgress()
    }
    
    private func syncDailyProgressEntity(_ progress: DailyProgress) async throws {
        let recordID = CKRecord.ID(recordName: progress.id)
        
        do {
            let existingRecord = try await privateDatabase.record(for: recordID)
            updateDailyProgressRecord(existingRecord, with: progress)
            _ = try await privateDatabase.save(existingRecord)
        } catch CKError.unknownItem {
            let newRecord = createDailyProgressRecord(from: progress)
            _ = try await privateDatabase.save(newRecord)
        }
    }
    
    private func fetchRemoteDailyProgress() async throws {
        let query = CKQuery(recordType: "DailyProgress", predicate: NSPredicate(value: true))
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                try await updateLocalDailyProgress(from: record)
            case .failure(let error):
                print("Error fetching DailyProgress record: \(error)")
            }
        }
    }
    
    // MARK: - Record Creation Methods
    
    private func createUserProgressRecord(from progress: UserProgress) -> CKRecord {
        let record = CKRecord(recordType: "UserProgress", recordID: CKRecord.ID(recordName: progress.id))
        updateUserProgressRecord(record, with: progress)
        return record
    }
    
    private func updateUserProgressRecord(_ record: CKRecord, with progress: UserProgress) {
        record["userId"] = progress.userId
        record["currentLevel"] = progress.currentLevel
        record["totalStars"] = progress.totalStars
        record["currentStreak"] = progress.currentStreak
        record["maxStreak"] = progress.maxStreak
        record["totalTrophies"] = progress.totalTrophies
        record["dailyGoalMinutes"] = progress.dailyGoalMinutes
        record["lastPracticeDate"] = progress.lastPracticeDate
        record["totalPracticeTime"] = progress.totalPracticeTime
        record["createdAt"] = progress.createdAt
        record["updatedAt"] = progress.updatedAt
    }
    
    private func createLessonRecord(from lesson: Lesson) -> CKRecord {
        let record = CKRecord(recordType: "Lesson", recordID: CKRecord.ID(recordName: lesson.id))
        updateLessonRecord(record, with: lesson)
        return record
    }
    
    private func updateLessonRecord(_ record: CKRecord, with lesson: Lesson) {
        record["title"] = lesson.title
        record["courseId"] = lesson.courseId
        record["instrument"] = lesson.instrument
        record["defaultBPM"] = lesson.defaultBPM
        record["timeSignatureNumerator"] = lesson.timeSignatureNumerator
        record["timeSignatureDenominator"] = lesson.timeSignatureDenominator
        record["duration"] = lesson.duration
        record["tags"] = lesson.tags
        record["difficulty"] = lesson.difficulty
        record["createdAt"] = lesson.createdAt
        record["updatedAt"] = lesson.updatedAt
    }
    
    private func createCourseRecord(from course: Course) -> CKRecord {
        let record = CKRecord(recordType: "Course", recordID: CKRecord.ID(recordName: course.id))
        updateCourseRecord(record, with: course)
        return record
    }
    
    private func updateCourseRecord(_ record: CKRecord, with course: Course) {
        record["title"] = course.title
        record["courseDescription"] = course.courseDescription
        record["difficulty"] = course.difficulty
        record["tags"] = course.tags
        record["estimatedDuration"] = course.estimatedDuration
        record["createdAt"] = course.createdAt
        record["updatedAt"] = course.updatedAt
        record["isPublished"] = course.isPublished ? 1 : 0
    }
    
    private func createScoreResultRecord(from score: ScoreResultEntity) -> CKRecord {
        let record = CKRecord(recordType: "ScoreResult", recordID: CKRecord.ID(recordName: score.id))
        updateScoreResultRecord(record, with: score)
        return record
    }
    
    private func updateScoreResultRecord(_ record: CKRecord, with score: ScoreResultEntity) {
        record["lessonId"] = score.lessonId
        record["totalScore"] = score.totalScore
        record["starRating"] = score.starRating
        record["isPlatinum"] = score.isPlatinum ? 1 : 0
        record["isBlackStar"] = score.isBlackStar ? 1 : 0
        record["streakCount"] = score.streakCount
        record["maxStreak"] = score.maxStreak
        record["missCount"] = score.missCount
        record["extraCount"] = score.extraCount
        record["perfectCount"] = score.perfectCount
        record["earlyCount"] = score.earlyCount
        record["lateCount"] = score.lateCount
        record["completionTime"] = score.completionTime
        record["completedAt"] = score.completedAt
        record["playbackMode"] = score.playbackMode
        record["timingResultsData"] = score.timingResultsData
    }
    
    private func createDailyProgressRecord(from progress: DailyProgress) -> CKRecord {
        let record = CKRecord(recordType: "DailyProgress", recordID: CKRecord.ID(recordName: progress.id))
        updateDailyProgressRecord(record, with: progress)
        return record
    }
    
    private func updateDailyProgressRecord(_ record: CKRecord, with progress: DailyProgress) {
        record["userId"] = progress.userId
        record["date"] = progress.date
        record["practiceTimeMinutes"] = progress.practiceTimeMinutes
        record["goalAchieved"] = progress.goalAchieved ? 1 : 0
        record["lessonsCompleted"] = progress.lessonsCompleted
        record["starsEarned"] = progress.starsEarned
        record["createdAt"] = progress.createdAt
    }
    
    // MARK: - Local Update Methods
    
    private func updateLocalUserProgress(from record: CKRecord) async throws {
        let context = coreDataManager.context
        
        await context.perform {
            let request: NSFetchRequest<UserProgress> = UserProgress.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", record.recordID.recordName)
            request.fetchLimit = 1
            
            do {
                let progress: UserProgress
                if let existing = try context.fetch(request).first {
                    progress = existing
                } else {
                    progress = UserProgress(context: context)
                    progress.id = record.recordID.recordName
                }
                
                progress.userId = record["userId"] as? String ?? ""
                progress.currentLevel = record["currentLevel"] as? Int16 ?? 1
                progress.totalStars = record["totalStars"] as? Int16 ?? 0
                progress.currentStreak = record["currentStreak"] as? Int16 ?? 0
                progress.maxStreak = record["maxStreak"] as? Int16 ?? 0
                progress.totalTrophies = record["totalTrophies"] as? Int16 ?? 0
                progress.dailyGoalMinutes = record["dailyGoalMinutes"] as? Int16 ?? 5
                progress.lastPracticeDate = record["lastPracticeDate"] as? Date
                progress.totalPracticeTime = record["totalPracticeTime"] as? TimeInterval ?? 0
                progress.createdAt = record["createdAt"] as? Date ?? Date()
                progress.updatedAt = record["updatedAt"] as? Date ?? Date()
                
                try context.save()
            } catch {
                print("Error updating local UserProgress: \(error)")
            }
        }
    }
    
    private func updateLocalLesson(from record: CKRecord) async throws {
        let context = coreDataManager.context
        
        await context.perform {
            let request: NSFetchRequest<Lesson> = Lesson.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", record.recordID.recordName)
            request.fetchLimit = 1
            
            do {
                let lesson: Lesson
                if let existing = try context.fetch(request).first {
                    lesson = existing
                } else {
                    lesson = Lesson(context: context)
                    lesson.id = record.recordID.recordName
                }
                
                lesson.title = record["title"] as? String ?? ""
                lesson.courseId = record["courseId"] as? String
                lesson.instrument = record["instrument"] as? String ?? "drums"
                lesson.defaultBPM = record["defaultBPM"] as? Float ?? 120.0
                lesson.timeSignatureNumerator = record["timeSignatureNumerator"] as? Int16 ?? 4
                lesson.timeSignatureDenominator = record["timeSignatureDenominator"] as? Int16 ?? 4
                lesson.duration = record["duration"] as? TimeInterval ?? 0
                lesson.tags = record["tags"] as? String ?? "[]"
                lesson.difficulty = record["difficulty"] as? Int16 ?? 1
                lesson.createdAt = record["createdAt"] as? Date ?? Date()
                lesson.updatedAt = record["updatedAt"] as? Date ?? Date()
                
                try context.save()
            } catch {
                print("Error updating local Lesson: \(error)")
            }
        }
    }
    
    private func updateLocalCourse(from record: CKRecord) async throws {
        let context = coreDataManager.context
        
        await context.perform {
            let request: NSFetchRequest<Course> = Course.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", record.recordID.recordName)
            request.fetchLimit = 1
            
            do {
                let course: Course
                if let existing = try context.fetch(request).first {
                    course = existing
                } else {
                    course = Course(context: context)
                    course.id = record.recordID.recordName
                }
                
                course.title = record["title"] as? String ?? ""
                course.courseDescription = record["courseDescription"] as? String ?? ""
                course.difficulty = record["difficulty"] as? Int16 ?? 1
                course.tags = record["tags"] as? String ?? "[]"
                course.estimatedDuration = record["estimatedDuration"] as? TimeInterval ?? 0
                course.createdAt = record["createdAt"] as? Date ?? Date()
                course.updatedAt = record["updatedAt"] as? Date ?? Date()
                course.isPublished = (record["isPublished"] as? Int ?? 0) == 1
                
                try context.save()
            } catch {
                print("Error updating local Course: \(error)")
            }
        }
    }
    
    private func updateLocalScoreResult(from record: CKRecord) async throws {
        let context = coreDataManager.context
        
        await context.perform {
            let request: NSFetchRequest<ScoreResultEntity> = ScoreResultEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", record.recordID.recordName)
            request.fetchLimit = 1
            
            do {
                let score: ScoreResultEntity
                if let existing = try context.fetch(request).first {
                    score = existing
                } else {
                    score = ScoreResultEntity(context: context)
                    score.id = record.recordID.recordName
                }
                
                score.lessonId = record["lessonId"] as? String ?? ""
                score.totalScore = record["totalScore"] as? Float ?? 0
                score.starRating = record["starRating"] as? Int16 ?? 0
                score.isPlatinum = (record["isPlatinum"] as? Int ?? 0) == 1
                score.isBlackStar = (record["isBlackStar"] as? Int ?? 0) == 1
                score.streakCount = record["streakCount"] as? Int16 ?? 0
                score.maxStreak = record["maxStreak"] as? Int16 ?? 0
                score.missCount = record["missCount"] as? Int16 ?? 0
                score.extraCount = record["extraCount"] as? Int16 ?? 0
                score.perfectCount = record["perfectCount"] as? Int16 ?? 0
                score.earlyCount = record["earlyCount"] as? Int16 ?? 0
                score.lateCount = record["lateCount"] as? Int16 ?? 0
                score.completionTime = record["completionTime"] as? TimeInterval ?? 0
                score.completedAt = record["completedAt"] as? Date ?? Date()
                score.playbackMode = record["playbackMode"] as? String ?? "performance"
                score.timingResultsData = record["timingResultsData"] as? Data ?? Data()
                
                try context.save()
            } catch {
                print("Error updating local ScoreResult: \(error)")
            }
        }
    }
    
    private func updateLocalDailyProgress(from record: CKRecord) async throws {
        let context = coreDataManager.context
        
        await context.perform {
            let request: NSFetchRequest<DailyProgress> = DailyProgress.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", record.recordID.recordName)
            request.fetchLimit = 1
            
            do {
                let progress: DailyProgress
                if let existing = try context.fetch(request).first {
                    progress = existing
                } else {
                    progress = DailyProgress(context: context)
                    progress.id = record.recordID.recordName
                }
                
                progress.userId = record["userId"] as? String ?? ""
                progress.date = record["date"] as? Date ?? Date()
                progress.practiceTimeMinutes = record["practiceTimeMinutes"] as? Int16 ?? 0
                progress.goalAchieved = (record["goalAchieved"] as? Int ?? 0) == 1
                progress.lessonsCompleted = record["lessonsCompleted"] as? Int16 ?? 0
                progress.starsEarned = record["starsEarned"] as? Int16 ?? 0
                progress.createdAt = record["createdAt"] as? Date ?? Date()
                
                try context.save()
            } catch {
                print("Error updating local DailyProgress: \(error)")
            }
        }
    }
    
    // MARK: - Conflict Resolution
    
    private func performConflictResolution() async throws {
        // Implement conflict resolution strategy
        // For this implementation, we'll use "last writer wins" strategy
        // In a production app, you might want more sophisticated conflict resolution
        
        let conflictedRecords = try await findConflictedRecords()
        
        for record in conflictedRecords {
            try await resolveConflict(for: record)
        }
    }
    
    private func findConflictedRecords() async throws -> [CKRecord] {
        // This is a simplified implementation
        // In practice, you'd track modification dates and detect conflicts
        return []
    }
    
    private func resolveConflict(for record: CKRecord) async throws {
        // Implement conflict resolution logic
        // For now, we'll just use the remote version
        switch record.recordType {
        case "UserProgress":
            try await updateLocalUserProgress(from: record)
        case "Lesson":
            try await updateLocalLesson(from: record)
        case "Course":
            try await updateLocalCourse(from: record)
        case "ScoreResult":
            try await updateLocalScoreResult(from: record)
        case "DailyProgress":
            try await updateLocalDailyProgress(from: record)
        default:
            throw CloudKitSyncError.invalidRecordType
        }
    }
    
    // MARK: - Modified Entities Sync
    
    private func syncModifiedEntities(since date: Date) async throws {
        // Sync UserProgress modified since date
        let userProgressRequest: NSFetchRequest<UserProgress> = UserProgress.fetchRequest()
        userProgressRequest.predicate = NSPredicate(format: "updatedAt > %@", date as NSDate)
        let modifiedUserProgress = try coreDataManager.context.fetch(userProgressRequest)
        
        for progress in modifiedUserProgress {
            try await syncUserProgressEntity(progress)
        }
        
        // Sync Lessons modified since date
        let lessonsRequest: NSFetchRequest<Lesson> = Lesson.fetchRequest()
        lessonsRequest.predicate = NSPredicate(format: "updatedAt > %@", date as NSDate)
        let modifiedLessons = try coreDataManager.context.fetch(lessonsRequest)
        
        for lesson in modifiedLessons {
            try await syncLessonEntity(lesson)
        }
        
        // Sync Courses modified since date
        let coursesRequest: NSFetchRequest<Course> = Course.fetchRequest()
        coursesRequest.predicate = NSPredicate(format: "updatedAt > %@", date as NSDate)
        let modifiedCourses = try coreDataManager.context.fetch(coursesRequest)
        
        for course in modifiedCourses {
            try await syncCourseEntity(course)
        }
        
        // ScoreResults and DailyProgress are typically only created, not modified
        // But we can sync recent ones
        let scoreResultsRequest: NSFetchRequest<ScoreResultEntity> = ScoreResultEntity.fetchRequest()
        scoreResultsRequest.predicate = NSPredicate(format: "completedAt > %@", date as NSDate)
        let recentScores = try coreDataManager.context.fetch(scoreResultsRequest)
        
        for score in recentScores {
            try await syncScoreResultEntity(score)
        }
        
        let dailyProgressRequest: NSFetchRequest<DailyProgress> = DailyProgress.fetchRequest()
        dailyProgressRequest.predicate = NSPredicate(format: "createdAt > %@", date as NSDate)
        let recentDailyProgress = try coreDataManager.context.fetch(dailyProgressRequest)
        
        for progress in recentDailyProgress {
            try await syncDailyProgressEntity(progress)
        }
    }
    
    // MARK: - Notification Setup
    
    private func setupNotifications() {
        // Listen for Core Data remote change notifications
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .sink { [weak self] _ in
                Task {
                    await self?.handleRemoteChange()
                }
            }
            .store(in: &cancellables)
        
        // Listen for network reachability changes
        NotificationCenter.default.publisher(for: .networkReachabilityChanged)
            .sink { [weak self] _ in
                Task {
                    await self?.handleNetworkChange()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleRemoteChange() async {
        // Handle remote changes from CloudKit
        if syncStatus == .synced {
            await MainActor.run {
                self.syncStatus = .syncing
            }
            
            do {
                try await performIncrementalSync()
                await MainActor.run {
                    self.syncStatus = .synced
                }
            } catch {
                await MainActor.run {
                    self.syncStatus = .error(self.mapError(error))
                }
            }
        }
    }
    
    private func handleNetworkChange() async {
        // Restart sync when network becomes available
        if syncStatus == .networkUnavailable {
            await checkAndStartSync()
        }
    }
    
    // MARK: - Error Mapping
    
    private func mapError(_ error: Error) -> CloudKitSyncError {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                return .accountNotAvailable
            case .networkUnavailable, .networkFailure:
                return .networkUnavailable
            case .quotaExceeded:
                return .quotaExceeded
            case .unknownItem:
                return .recordNotFound
            case .permissionFailure:
                return .permissionFailure
            default:
                return .unknownError(error)
            }
        }
        
        return .unknownError(error)
    }
}

// MARK: - Network Reachability Notification

extension Notification.Name {
    static let networkReachabilityChanged = Notification.Name("networkReachabilityChanged")
}

// MARK: - CloudKit Sync Manager Extensions

extension CloudKitSyncManager {
    
    // MARK: - Convenience Methods
    
    func syncStatusDescription() -> String {
        return syncStatus.displayMessage
    }
    
    func isSyncEnabled() -> Bool {
        return syncTimer != nil
    }
    
    func getLastSyncDate() -> Date? {
        return UserDefaults.standard.object(forKey: "lastCloudKitSync") as? Date
    }
    
    // MARK: - Manual Sync Triggers
    
    func syncSpecificEntity<T: NSManagedObject>(_ entity: T) async throws {
        switch entity {
        case let progress as UserProgress:
            try await syncUserProgressEntity(progress)
        case let lesson as Lesson:
            try await syncLessonEntity(lesson)
        case let course as Course:
            try await syncCourseEntity(course)
        case let score as ScoreResultEntity:
            try await syncScoreResultEntity(score)
        case let dailyProgress as DailyProgress:
            try await syncDailyProgressEntity(dailyProgress)
        default:
            throw CloudKitSyncError.invalidRecordType
        }
    }
    
    // MARK: - Batch Operations
    
    func batchSyncRecords<T: NSManagedObject>(_ entities: [T]) async throws {
        for entity in entities {
            try await syncSpecificEntity(entity)
        }
    }
    
    // MARK: - Data Cleanup
    
    func cleanupOrphanedRecords() async throws {
        // Remove CloudKit records that no longer have local counterparts
        let recordTypes = ["UserProgress", "Lesson", "Course", "ScoreResult", "DailyProgress"]
        
        for recordType in recordTypes {
            try await cleanupOrphanedRecords(ofType: recordType)
        }
    }
    
    private func cleanupOrphanedRecords(ofType recordType: String) async throws {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        for (recordID, result) in matchResults {
            switch result {
            case .success(_):
                // Check if local record exists
                let localExists = try await checkLocalRecordExists(recordID: recordID.recordName, recordType: recordType)
                if !localExists {
                    // Delete orphaned CloudKit record
                    try await privateDatabase.deleteRecord(withID: recordID)
                }
            case .failure(let error):
                print("Error checking record \(recordID): \(error)")
            }
        }
    }
    
    private func checkLocalRecordExists(recordID: String, recordType: String) async throws -> Bool {
        let context = coreDataManager.context
        
        return try await context.perform {
            let request: NSFetchRequest<NSManagedObject>
            
            switch recordType {
            case "UserProgress":
                request = UserProgress.fetchRequest() as! NSFetchRequest<NSManagedObject>
            case "Lesson":
                request = Lesson.fetchRequest() as! NSFetchRequest<NSManagedObject>
            case "Course":
                request = Course.fetchRequest() as! NSFetchRequest<NSManagedObject>
            case "ScoreResult":
                request = ScoreResultEntity.fetchRequest() as! NSFetchRequest<NSManagedObject>
            case "DailyProgress":
                request = DailyProgress.fetchRequest() as! NSFetchRequest<NSManagedObject>
            default:
                return false
            }
            
            request.predicate = NSPredicate(format: "id == %@", recordID)
            request.fetchLimit = 1
            
            let results = try context.fetch(request)
            return !results.isEmpty
        }
    }
}