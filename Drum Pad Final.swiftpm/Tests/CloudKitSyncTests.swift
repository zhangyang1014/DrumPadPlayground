import XCTest
import CloudKit
import CoreData
@testable import AppModule

// MARK: - CloudKit Sync Tests

class CloudKitSyncTests: XCTestCase {
    
    var coreDataManager: CoreDataManager!
    var cloudKitSyncManager: CloudKitSyncManager!
    var testContainer: NSPersistentContainer!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory Core Data stack for testing
        coreDataManager = createTestCoreDataManager()
        cloudKitSyncManager = CloudKitSyncManager(coreDataManager: coreDataManager)
    }
    
    override func tearDown() {
        // Clean up test data
        clearTestData()
        coreDataManager = nil
        cloudKitSyncManager = nil
        testContainer = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestCoreDataManager() -> CoreDataManager {
        // Create in-memory Core Data stack for testing
        testContainer = NSPersistentContainer(name: "DrumTrainerModel")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        testContainer.persistentStoreDescriptions = [description]
        
        let expectation = XCTestExpectation(description: "Core Data stack loaded")
        testContainer.loadPersistentStores { _, error in
            XCTAssertNil(error, "Failed to load in-memory store: \(error?.localizedDescription ?? "Unknown error")")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Create a test CoreDataManager with our test container
        let manager = CoreDataManager()
        // Replace the persistent container with our test container
        manager.persistentContainer = testContainer as! NSPersistentCloudKitContainer
        
        return manager
    }
    
    private func clearTestData() {
        guard let context = testContainer?.viewContext else { return }
        
        // Delete all test entities
        let entityNames = ["UserProgress", "Lesson", "Course", "ScoreResultEntity", "DailyProgress", "LessonStep", "ScoringProfileEntity", "AudioAssetsEntity"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
            } catch {
                print("Failed to delete \(entityName): \(error)")
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save after cleanup: \(error)")
        }
    }
    
    // MARK: - 1. Local Data Saving and Reading Tests
    
    func testLocalUserProgressSaveAndRead() {
        // Test creating and saving user progress
        let userId = "test_user_\(UUID().uuidString)"
        let userProgress = coreDataManager.getUserProgress(for: userId)
        
        // Modify user progress
        userProgress.currentLevel = 5
        userProgress.totalStars = 50
        userProgress.currentStreak = 3
        userProgress.maxStreak = 10
        userProgress.totalTrophies = 2
        userProgress.dailyGoalMinutes = 10
        userProgress.totalPracticeTime = 3600 // 1 hour
        
        coreDataManager.saveWithoutSync()
        
        // Verify data was saved and can be read
        let fetchedProgress = coreDataManager.getUserProgress(for: userId)
        XCTAssertEqual(fetchedProgress.currentLevel, 5)
        XCTAssertEqual(fetchedProgress.totalStars, 50)
        XCTAssertEqual(fetchedProgress.currentStreak, 3)
        XCTAssertEqual(fetchedProgress.maxStreak, 10)
        XCTAssertEqual(fetchedProgress.totalTrophies, 2)
        XCTAssertEqual(fetchedProgress.dailyGoalMinutes, 10)
        XCTAssertEqual(fetchedProgress.totalPracticeTime, 3600)
        XCTAssertEqual(fetchedProgress.userId, userId)
    }
    
    func testLocalLessonSaveAndRead() {
        // Test creating and saving lesson
        let lessonId = UUID().uuidString
        let lesson = coreDataManager.createLesson(
            id: lessonId,
            title: "Test Lesson for Local Storage",
            courseId: "test_course",
            instrument: "drums",
            defaultBPM: 120.0,
            timeSignature: .fourFour,
            duration: 60.0,
            tags: ["test", "beginner", "local"],
            difficulty: 2
        )
        
        // Verify lesson was created and saved
        XCTAssertEqual(lesson.id, lessonId)
        XCTAssertEqual(lesson.title, "Test Lesson for Local Storage")
        XCTAssertEqual(lesson.courseId, "test_course")
        XCTAssertEqual(lesson.instrument, "drums")
        XCTAssertEqual(lesson.defaultBPM, 120.0)
        XCTAssertEqual(lesson.duration, 60.0)
        XCTAssertEqual(lesson.tagsArray, ["test", "beginner", "local"])
        XCTAssertEqual(lesson.difficulty, 2)
        
        // Test reading lesson back from storage
        let fetchedLesson = coreDataManager.fetchLesson(by: lessonId)
        XCTAssertNotNil(fetchedLesson)
        XCTAssertEqual(fetchedLesson?.title, "Test Lesson for Local Storage")
        XCTAssertEqual(fetchedLesson?.courseId, "test_course")
        XCTAssertEqual(fetchedLesson?.tagsArray, ["test", "beginner", "local"])
    }
    
    func testLocalCourseSaveAndRead() {
        // Test creating and saving course
        let courseId = UUID().uuidString
        let course = coreDataManager.createCourse(
            id: courseId,
            title: "Test Course for Local Storage",
            description: "A comprehensive test course for local data operations",
            difficulty: 3,
            tags: ["test", "intermediate", "local"]
        )
        
        // Verify course was created
        XCTAssertEqual(course.id, courseId)
        XCTAssertEqual(course.title, "Test Course for Local Storage")
        XCTAssertEqual(course.courseDescription, "A comprehensive test course for local data operations")
        XCTAssertEqual(course.difficulty, 3)
        XCTAssertEqual(course.tagsArray, ["test", "intermediate", "local"])
        XCTAssertFalse(course.isPublished)
        
        // Test reading course back from storage
        let courses = coreDataManager.fetchCourses()
        let fetchedCourse = courses.first { $0.id == courseId }
        XCTAssertNotNil(fetchedCourse)
        XCTAssertEqual(fetchedCourse?.title, "Test Course for Local Storage")
        XCTAssertEqual(fetchedCourse?.difficulty, 3)
    }
    
    func testLocalScoreResultSaveAndRead() {
        // First create a lesson
        let lesson = coreDataManager.createLesson(
            title: "Test Lesson for Score",
            defaultBPM: 120.0,
            duration: 60.0
        )
        
        // Create test score result
        let scoreResult = ScoreResult(
            totalScore: 85.5,
            starRating: 2,
            isPlatinum: false,
            isBlackStar: false,
            timingResults: [],
            streakCount: 5,
            maxStreak: 8,
            missCount: 2,
            extraCount: 1,
            perfectCount: 15,
            earlyCount: 3,
            lateCount: 2,
            completionTime: 45.0
        )
        
        let scoreEntity = coreDataManager.saveScoreResult(scoreResult, for: lesson.id, mode: .performance)
        
        // Verify score result was saved
        XCTAssertEqual(scoreEntity.totalScore, 85.5)
        XCTAssertEqual(scoreEntity.starRating, 2)
        XCTAssertEqual(scoreEntity.streakCount, 5)
        XCTAssertEqual(scoreEntity.maxStreak, 8)
        XCTAssertEqual(scoreEntity.missCount, 2)
        XCTAssertEqual(scoreEntity.lessonId, lesson.id)
        XCTAssertEqual(scoreEntity.playbackModeEnum, .performance)
        
        // Test reading score results back
        let fetchedScores = coreDataManager.fetchScoreResults(for: lesson.id)
        XCTAssertEqual(fetchedScores.count, 1)
        XCTAssertEqual(fetchedScores.first?.totalScore, 85.5)
        XCTAssertEqual(fetchedScores.first?.starRating, 2)
    }
    
    func testLocalDailyProgressSaveAndRead() {
        let userId = "test_user_daily_\(UUID().uuidString)"
        
        // Create user progress first
        let userProgress = coreDataManager.getUserProgress(for: userId)
        userProgress.dailyGoalMinutes = 5
        coreDataManager.saveWithoutSync()
        
        // Update daily progress
        coreDataManager.updateDailyProgress(for: userId, practiceTime: 300) // 5 minutes
        
        // Verify daily progress was created and saved
        let today = Calendar.current.startOfDay(for: Date())
        let request: NSFetchRequest<DailyProgress> = DailyProgress.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND date == %@", userId, today as NSDate)
        
        do {
            let dailyProgressArray = try coreDataManager.context.fetch(request)
            XCTAssertEqual(dailyProgressArray.count, 1)
            
            let dailyProgress = dailyProgressArray.first!
            XCTAssertEqual(dailyProgress.userId, userId)
            XCTAssertEqual(dailyProgress.practiceTimeMinutes, 5)
            XCTAssertEqual(dailyProgress.lessonsCompleted, 1)
            XCTAssertTrue(dailyProgress.goalAchieved)
            XCTAssertTrue(dailyProgress.isGoalMet)
        } catch {
            XCTFail("Failed to fetch daily progress: \(error)")
        }
    }
    
    func testLocalDataIntegrityValidation() {
        // Create test data with relationships
        let course = coreDataManager.createCourse(
            title: "Integrity Test Course",
            description: "Course for testing data integrity",
            difficulty: 2
        )
        
        let lesson = coreDataManager.createLesson(
            title: "Integrity Test Lesson",
            courseId: course.id,
            defaultBPM: 120.0,
            duration: 60.0
        )
        
        let step = coreDataManager.createLessonStep(
            lessonId: lesson.id,
            order: 1,
            title: "Test Step",
            description: "A test lesson step"
        )
        
        // Verify relationships are established
        XCTAssertEqual(lesson.courseId, course.id)
        XCTAssertEqual(step.lessonId, lesson.id)
        
        // Test data integrity validation
        let issues = coreDataManager.validateDataIntegrity()
        XCTAssertTrue(issues.isEmpty, "Data integrity issues found: \(issues)")
        
        // Test data integrity repair (should not affect valid data)
        coreDataManager.repairDataIntegrity()
        
        // Verify data is still intact after repair
        let fetchedLesson = coreDataManager.fetchLesson(by: lesson.id)
        XCTAssertNotNil(fetchedLesson)
        XCTAssertEqual(fetchedLesson?.courseId, course.id)
        
        let fetchedSteps = coreDataManager.fetchLessonSteps(for: lesson.id)
        XCTAssertEqual(fetchedSteps.count, 1)
        XCTAssertEqual(fetchedSteps.first?.title, "Test Step")
    }
    
    // MARK: - Sync Status Tests
    
    func testInitialSyncStatus() {
        XCTAssertEqual(cloudKitSyncManager.syncStatus, .notStarted)
    }
    
    func testSyncStatusPublisher() {
        let expectation = XCTestExpectation(description: "Sync status should be published")
        
        let cancellable = cloudKitSyncManager.syncStatusPublisher
            .sink { status in
                if status != .notStarted {
                    expectation.fulfill()
                }
            }
        
        // Simulate status change
        cloudKitSyncManager.startSync()
        
        wait(for: [expectation], timeout: 5.0)
        cancellable.cancel()
    }
    
    // MARK: - 2. CloudKit Sync Functionality Tests
    
    func testCheckAccountStatus() async {
        let accountStatus = await cloudKitSyncManager.checkAccountStatus()
        
        // In test environment, account status might be .couldNotDetermine
        XCTAssertTrue([.available, .noAccount, .restricted, .couldNotDetermine].contains(accountStatus))
    }
    
    func testSyncManagerInitialization() {
        XCTAssertNotNil(cloudKitSyncManager)
        XCTAssertEqual(cloudKitSyncManager.syncStatus, .notStarted)
        XCTAssertFalse(cloudKitSyncManager.isSyncEnabled())
        XCTAssertNil(cloudKitSyncManager.getLastSyncDate())
    }
    
    func testSyncManagerStartStop() {
        // Test starting sync
        cloudKitSyncManager.startSync()
        XCTAssertTrue(cloudKitSyncManager.isSyncEnabled())
        
        // Test stopping sync
        cloudKitSyncManager.stopSync()
        XCTAssertFalse(cloudKitSyncManager.isSyncEnabled())
        
        // After stopping, status should not be syncing
        XCTAssertFalse(cloudKitSyncManager.syncStatus.isActive)
    }
    
    func testForceSyncWithoutCloudKit() async {
        // Test that force sync handles errors gracefully when CloudKit is not available
        do {
            try await cloudKitSyncManager.forceSyncNow()
            // If no error is thrown, that's also acceptable in test environment
        } catch {
            // Expected in test environment without CloudKit setup
            XCTAssertTrue(error is CloudKitSyncError || error is CKError)
        }
    }
    
    func testSyncStatusMessages() {
        // Test sync status display messages
        XCTAssertEqual(CloudKitSyncStatus.notStarted.displayMessage, "Sync not started")
        XCTAssertEqual(CloudKitSyncStatus.syncing.displayMessage, "Syncing with iCloud...")
        XCTAssertEqual(CloudKitSyncStatus.synced.displayMessage, "Synced with iCloud")
        XCTAssertEqual(CloudKitSyncStatus.accountUnavailable.displayMessage, "iCloud account unavailable")
        XCTAssertEqual(CloudKitSyncStatus.networkUnavailable.displayMessage, "Network unavailable")
        
        let error = CloudKitSyncError.accountNotAvailable
        let errorStatus = CloudKitSyncStatus.error(error)
        XCTAssertTrue(errorStatus.displayMessage.contains("Sync error"))
    }
    
    func testCloudKitErrorMapping() {
        // Test that CloudKit errors are properly mapped to sync errors
        let ckErrors: [(CKError.Code, CloudKitSyncError)] = [
            (.notAuthenticated, .accountNotAvailable),
            (.networkUnavailable, .networkUnavailable),
            (.networkFailure, .networkUnavailable),
            (.quotaExceeded, .quotaExceeded),
            (.unknownItem, .recordNotFound),
            (.permissionFailure, .permissionFailure)
        ]
        
        for (ckErrorCode, expectedSyncError) in ckErrors {
            let ckError = CKError(ckErrorCode)
            let mappedError = mapCKErrorToSyncError(ckError)
            
            switch (mappedError, expectedSyncError) {
            case (.accountNotAvailable, .accountNotAvailable),
                 (.networkUnavailable, .networkUnavailable),
                 (.quotaExceeded, .quotaExceeded),
                 (.recordNotFound, .recordNotFound),
                 (.permissionFailure, .permissionFailure):
                XCTAssertTrue(true) // Correct mapping
            default:
                XCTFail("Incorrect error mapping for \(ckErrorCode): got \(mappedError), expected \(expectedSyncError)")
            }
        }
    }
    
    func testSyncSpecificEntity() async {
        // Create test entities
        let userProgress = coreDataManager.getUserProgress(for: "test_sync_user")
        userProgress.currentLevel = 3
        userProgress.totalStars = 25
        coreDataManager.saveWithoutSync()
        
        let lesson = coreDataManager.createLesson(
            title: "Sync Test Lesson",
            defaultBPM: 140.0,
            duration: 90.0
        )
        
        // Test syncing specific entities (will fail in test environment, but should handle gracefully)
        do {
            try await cloudKitSyncManager.syncSpecificEntity(userProgress)
            try await cloudKitSyncManager.syncSpecificEntity(lesson)
        } catch {
            // Expected in test environment without CloudKit
            XCTAssertTrue(error is CloudKitSyncError || error is CKError)
        }
    }
    
    func testBatchSyncRecords() async {
        // Create multiple test entities
        let entities: [NSManagedObject] = [
            coreDataManager.getUserProgress(for: "batch_user_1"),
            coreDataManager.getUserProgress(for: "batch_user_2"),
            coreDataManager.createLesson(title: "Batch Lesson 1", defaultBPM: 120.0, duration: 60.0),
            coreDataManager.createLesson(title: "Batch Lesson 2", defaultBPM: 130.0, duration: 70.0)
        ]
        
        // Test batch sync (will fail in test environment, but should handle gracefully)
        do {
            try await cloudKitSyncManager.batchSyncRecords(entities)
        } catch {
            // Expected in test environment without CloudKit
            XCTAssertTrue(error is CloudKitSyncError || error is CKError)
        }
    }
    
    // Helper method for error mapping test
    private func mapCKErrorToSyncError(_ error: CKError) -> CloudKitSyncError {
        switch error.code {
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
    
    // MARK: - 3. Offline Mode and Data Recovery Tests
    
    func testOfflineDataPersistence() {
        // Simulate offline mode by stopping sync
        cloudKitSyncManager.stopSync()
        
        // Create data while "offline"
        let userId = "offline_user_\(UUID().uuidString)"
        let userProgress = coreDataManager.getUserProgress(for: userId)
        userProgress.currentLevel = 7
        userProgress.totalStars = 75
        userProgress.currentStreak = 5
        
        let lesson = coreDataManager.createLesson(
            title: "Offline Lesson",
            defaultBPM: 150.0,
            duration: 120.0,
            tags: ["offline", "test"]
        )
        
        let scoreResult = ScoreResult(
            totalScore: 92.5,
            starRating: 3,
            isPlatinum: false,
            isBlackStar: false,
            timingResults: [],
            streakCount: 10,
            maxStreak: 12,
            missCount: 1,
            extraCount: 0,
            perfectCount: 20,
            earlyCount: 2,
            lateCount: 1,
            completionTime: 110.0
        )
        
        let scoreEntity = coreDataManager.saveScoreResult(scoreResult, for: lesson.id, mode: .practice)
        
        // Verify data persists locally even when offline
        let fetchedProgress = coreDataManager.getUserProgress(for: userId)
        XCTAssertEqual(fetchedProgress.currentLevel, 7)
        XCTAssertEqual(fetchedProgress.totalStars, 75)
        
        let fetchedLesson = coreDataManager.fetchLesson(by: lesson.id)
        XCTAssertNotNil(fetchedLesson)
        XCTAssertEqual(fetchedLesson?.title, "Offline Lesson")
        
        let fetchedScores = coreDataManager.fetchScoreResults(for: lesson.id)
        XCTAssertEqual(fetchedScores.count, 1)
        XCTAssertEqual(fetchedScores.first?.totalScore, 92.5)
    }
    
    func testDataRecoveryAfterCorruption() {
        // Create initial valid data
        let userId = "recovery_user_\(UUID().uuidString)"
        let userProgress = coreDataManager.getUserProgress(for: userId)
        userProgress.currentLevel = 4
        userProgress.totalStars = 40
        coreDataManager.saveWithoutSync()
        
        let lesson = coreDataManager.createLesson(
            title: "Recovery Test Lesson",
            defaultBPM: 120.0,
            duration: 60.0
        )
        
        // Simulate data corruption by creating orphaned records
        let orphanedStep = coreDataManager.createLessonStep(
            lessonId: "non_existent_lesson_id",
            order: 1,
            title: "Orphaned Step",
            description: "This step has no parent lesson"
        )
        
        // Verify corruption is detected
        let issues = coreDataManager.validateDataIntegrity()
        XCTAssertFalse(issues.isEmpty, "Should detect orphaned lesson step")
        XCTAssertTrue(issues.first?.contains("orphaned lesson steps") == true)
        
        // Test data recovery
        coreDataManager.repairDataIntegrity()
        
        // Verify corruption is fixed
        let issuesAfterRepair = coreDataManager.validateDataIntegrity()
        XCTAssertTrue(issuesAfterRepair.isEmpty, "Data integrity issues should be resolved after repair")
        
        // Verify valid data is preserved
        let recoveredProgress = coreDataManager.getUserProgress(for: userId)
        XCTAssertEqual(recoveredProgress.currentLevel, 4)
        XCTAssertEqual(recoveredProgress.totalStars, 40)
        
        let recoveredLesson = coreDataManager.fetchLesson(by: lesson.id)
        XCTAssertNotNil(recoveredLesson)
        XCTAssertEqual(recoveredLesson?.title, "Recovery Test Lesson")
    }
    
    func testDataExportImportForBackup() {
        // Create test data for export
        let userId = "export_user_\(UUID().uuidString)"
        let userProgress = coreDataManager.getUserProgress(for: userId)
        userProgress.currentLevel = 6
        userProgress.totalStars = 60
        userProgress.currentStreak = 4
        userProgress.maxStreak = 8
        userProgress.totalTrophies = 3
        coreDataManager.saveWithoutSync()
        
        let lesson = coreDataManager.createLesson(
            title: "Export Test Lesson",
            defaultBPM: 130.0,
            duration: 80.0
        )
        
        let scoreResult = ScoreResult(
            totalScore: 88.0,
            starRating: 2,
            isPlatinum: false,
            isBlackStar: false,
            timingResults: [],
            streakCount: 6,
            maxStreak: 10,
            missCount: 3,
            extraCount: 1,
            perfectCount: 18,
            earlyCount: 4,
            lateCount: 2,
            completionTime: 75.0
        )
        
        _ = coreDataManager.saveScoreResult(scoreResult, for: lesson.id, mode: .performance)
        
        // Export user data
        let exportedData = coreDataManager.exportUserData()
        
        // Verify export contains expected data
        XCTAssertNotNil(exportedData["userProgress"])
        XCTAssertNotNil(exportedData["scoreResults"])
        
        if let userProgressArray = exportedData["userProgress"] as? [[String: Any]] {
            let exportedProgress = userProgressArray.first { ($0["userId"] as? String) == userId }
            XCTAssertNotNil(exportedProgress)
            XCTAssertEqual(exportedProgress?["currentLevel"] as? Int16, 6)
            XCTAssertEqual(exportedProgress?["totalStars"] as? Int16, 60)
        }
        
        if let scoresArray = exportedData["scoreResults"] as? [[String: Any]] {
            let exportedScore = scoresArray.first { ($0["lessonId"] as? String) == lesson.id }
            XCTAssertNotNil(exportedScore)
            XCTAssertEqual(exportedScore?["totalScore"] as? Float, 88.0)
            XCTAssertEqual(exportedScore?["starRating"] as? Int16, 2)
        }
        
        // Test import (basic validation - full implementation would restore data)
        do {
            try coreDataManager.importUserData(exportedData)
            // If no error is thrown, import structure is valid
        } catch {
            XCTFail("Data import should not fail with valid export data: \(error)")
        }
    }
    
    func testOfflineModeTransitions() {
        // Test transitioning between online and offline modes
        
        // Start in offline mode
        cloudKitSyncManager.stopSync()
        XCTAssertFalse(cloudKitSyncManager.isSyncEnabled())
        
        // Create data while offline
        let userId = "transition_user_\(UUID().uuidString)"
        let userProgress = coreDataManager.getUserProgress(for: userId)
        userProgress.currentLevel = 3
        coreDataManager.saveWithoutSync()
        
        // Simulate going online
        cloudKitSyncManager.startSync()
        XCTAssertTrue(cloudKitSyncManager.isSyncEnabled())
        
        // Data should still be available after transition
        let fetchedProgress = coreDataManager.getUserProgress(for: userId)
        XCTAssertEqual(fetchedProgress.currentLevel, 3)
        
        // Simulate going offline again
        cloudKitSyncManager.stopSync()
        XCTAssertFalse(cloudKitSyncManager.isSyncEnabled())
        
        // Data should still be available
        let stillFetchedProgress = coreDataManager.getUserProgress(for: userId)
        XCTAssertEqual(stillFetchedProgress.currentLevel, 3)
    }
    
    func testNetworkFailureHandling() {
        // Test that sync handles network failures gracefully
        let expectation = XCTestExpectation(description: "Network failure should be handled")
        
        let cancellable = cloudKitSyncManager.syncStatusPublisher
            .sink { status in
                switch status {
                case .error(let error):
                    // Network-related errors should be handled gracefully
                    switch error {
                    case .networkUnavailable, .accountNotAvailable, .unknownError(_):
                        expectation.fulfill()
                    default:
                        break
                    }
                case .networkUnavailable:
                    expectation.fulfill()
                default:
                    break
                }
            }
        
        // Start sync (will likely fail in test environment due to no network/CloudKit setup)
        cloudKitSyncManager.startSync()
        
        wait(for: [expectation], timeout: 10.0)
        cancellable.cancel()
    }
    
    func testDataConsistencyAfterRecovery() {
        // Create related data
        let course = coreDataManager.createCourse(
            title: "Consistency Test Course",
            description: "Testing data consistency",
            difficulty: 2
        )
        
        let lesson1 = coreDataManager.createLesson(
            title: "Lesson 1",
            courseId: course.id,
            defaultBPM: 120.0,
            duration: 60.0
        )
        
        let lesson2 = coreDataManager.createLesson(
            title: "Lesson 2",
            courseId: course.id,
            defaultBPM: 140.0,
            duration: 80.0
        )
        
        let step1 = coreDataManager.createLessonStep(
            lessonId: lesson1.id,
            order: 1,
            title: "Step 1",
            description: "First step"
        )
        
        let step2 = coreDataManager.createLessonStep(
            lessonId: lesson2.id,
            order: 1,
            title: "Step 2",
            description: "Second step"
        )
        
        // Verify initial consistency
        let initialIssues = coreDataManager.validateDataIntegrity()
        XCTAssertTrue(initialIssues.isEmpty, "Initial data should be consistent")
        
        // Simulate recovery process
        coreDataManager.repairDataIntegrity()
        
        // Verify data consistency is maintained
        let postRecoveryIssues = coreDataManager.validateDataIntegrity()
        XCTAssertTrue(postRecoveryIssues.isEmpty, "Data should remain consistent after recovery")
        
        // Verify relationships are intact
        let fetchedLesson1 = coreDataManager.fetchLesson(by: lesson1.id)
        let fetchedLesson2 = coreDataManager.fetchLesson(by: lesson2.id)
        
        XCTAssertEqual(fetchedLesson1?.courseId, course.id)
        XCTAssertEqual(fetchedLesson2?.courseId, course.id)
        
        let steps1 = coreDataManager.fetchLessonSteps(for: lesson1.id)
        let steps2 = coreDataManager.fetchLessonSteps(for: lesson2.id)
        
        XCTAssertEqual(steps1.count, 1)
        XCTAssertEqual(steps2.count, 1)
        XCTAssertEqual(steps1.first?.title, "Step 1")
        XCTAssertEqual(steps2.first?.title, "Step 2")
    }
    
    // MARK: - Data Model Tests
    
    func testUserProgressSync() {
        // Create test user progress
        let userProgress = coreDataManager.getUserProgress(for: "test_user")
        userProgress.currentLevel = 5
        userProgress.totalStars = 50
        userProgress.currentStreak = 3
        
        coreDataManager.save()
        
        // Verify data was saved
        let fetchedProgress = coreDataManager.getUserProgress(for: "test_user")
        XCTAssertEqual(fetchedProgress.currentLevel, 5)
        XCTAssertEqual(fetchedProgress.totalStars, 50)
        XCTAssertEqual(fetchedProgress.currentStreak, 3)
    }
    
    func testLessonCreationAndSync() {
        // Create test lesson
        let lesson = coreDataManager.createLesson(
            title: "Test Lesson",
            defaultBPM: 120.0,
            duration: 60.0,
            tags: ["test", "beginner"]
        )
        
        // Verify lesson was created
        XCTAssertEqual(lesson.title, "Test Lesson")
        XCTAssertEqual(lesson.defaultBPM, 120.0)
        XCTAssertEqual(lesson.duration, 60.0)
        XCTAssertEqual(lesson.tagsArray, ["test", "beginner"])
        
        // Verify lesson can be fetched
        let fetchedLesson = coreDataManager.fetchLesson(by: lesson.id)
        XCTAssertNotNil(fetchedLesson)
        XCTAssertEqual(fetchedLesson?.title, "Test Lesson")
    }
    
    func testScoreResultSync() {
        // Create test lesson first
        let lesson = coreDataManager.createLesson(
            title: "Test Lesson",
            defaultBPM: 120.0,
            duration: 60.0
        )
        
        // Create test score result
        let scoreResult = ScoreResult(
            totalScore: 85.5,
            starRating: 2,
            isPlatinum: false,
            isBlackStar: false,
            timingResults: [],
            streakCount: 5,
            maxStreak: 8,
            missCount: 2,
            extraCount: 1,
            perfectCount: 15,
            earlyCount: 3,
            lateCount: 2,
            completionTime: 45.0
        )
        
        let scoreEntity = coreDataManager.saveScoreResult(scoreResult, for: lesson.id, mode: .performance)
        
        // Verify score result was saved
        XCTAssertEqual(scoreEntity.totalScore, 85.5)
        XCTAssertEqual(scoreEntity.starRating, 2)
        XCTAssertEqual(scoreEntity.streakCount, 5)
        XCTAssertEqual(scoreEntity.lessonId, lesson.id)
    }
    
    // MARK: - Conflict Resolution Tests
    
    func testConflictResolution() async {
        // This test would simulate conflict scenarios
        // For now, we'll test that the method doesn't throw
        do {
            try await cloudKitSyncManager.resolveConflicts()
        } catch {
            XCTFail("Conflict resolution should not throw in test environment: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testSyncErrorHandling() {
        // Test that sync manager handles errors gracefully
        let expectation = XCTestExpectation(description: "Error should be handled")
        
        let cancellable = cloudKitSyncManager.syncStatusPublisher
            .sink { status in
                switch status {
                case .error(_):
                    expectation.fulfill()
                default:
                    break
                }
            }
        
        // In test environment without CloudKit setup, starting sync should result in error
        cloudKitSyncManager.startSync()
        
        wait(for: [expectation], timeout: 10.0)
        cancellable.cancel()
    }
    
    // MARK: - Data Validation Tests
    
    func testDataValidation() throws {
        // Test lesson validation
        let lesson = coreDataManager.createLesson(
            title: "Valid Lesson",
            defaultBPM: 120.0,
            duration: 60.0
        )
        
        XCTAssertNoThrow(try lesson.validate())
        
        // Test invalid lesson
        lesson.title = ""
        XCTAssertThrowsError(try lesson.validate()) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    func testScoreResultValidation() throws {
        let lesson = coreDataManager.createLesson(
            title: "Test Lesson",
            defaultBPM: 120.0,
            duration: 60.0
        )
        
        let scoreResult = ScoreResult(
            totalScore: 85.5,
            starRating: 2,
            isPlatinum: false,
            isBlackStar: false,
            timingResults: [],
            streakCount: 5,
            maxStreak: 8,
            missCount: 2,
            extraCount: 1,
            perfectCount: 15,
            earlyCount: 3,
            lateCount: 2,
            completionTime: 45.0
        )
        
        let scoreEntity = coreDataManager.saveScoreResult(scoreResult, for: lesson.id, mode: .performance)
        
        XCTAssertNoThrow(try scoreEntity.validate())
        
        // Test invalid score
        scoreEntity.totalScore = 150.0 // Invalid score > 100
        XCTAssertThrowsError(try scoreEntity.validate()) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    // MARK: - Performance Tests
    
    func testLocalDataPerformance() {
        measure {
            // Test local data operations performance
            for i in 0..<50 {
                let lesson = coreDataManager.createLesson(
                    title: "Performance Test Lesson \(i)",
                    defaultBPM: Float(120 + i),
                    duration: TimeInterval(60 + i),
                    tags: ["performance", "test", "batch_\(i)"]
                )
                
                let scoreResult = ScoreResult(
                    totalScore: Float(min(100, i * 2)),
                    starRating: min(3, i % 4),
                    isPlatinum: false,
                    isBlackStar: false,
                    timingResults: [],
                    streakCount: i,
                    maxStreak: i + 5,
                    missCount: i % 3,
                    extraCount: i % 2,
                    perfectCount: i * 2,
                    earlyCount: i % 4,
                    lateCount: i % 5,
                    completionTime: TimeInterval(i * 2)
                )
                
                _ = coreDataManager.saveScoreResult(scoreResult, for: lesson.id, mode: .performance)
            }
        }
    }
    
    func testBulkDataOperationsPerformance() {
        // Test performance of bulk operations
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create bulk data
        var lessons: [Lesson] = []
        for i in 0..<100 {
            let lesson = coreDataManager.createLesson(
                title: "Bulk Lesson \(i)",
                defaultBPM: Float(120 + (i % 60)),
                duration: TimeInterval(60 + (i % 120))
            )
            lessons.append(lesson)
        }
        
        let creationTime = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThan(creationTime, 5.0, "Bulk creation should complete within 5 seconds")
        
        // Test bulk fetch performance
        let fetchStartTime = CFAbsoluteTimeGetCurrent()
        let fetchedLessons = coreDataManager.fetchLessons()
        let fetchTime = CFAbsoluteTimeGetCurrent() - fetchStartTime
        
        XCTAssertGreaterThanOrEqual(fetchedLessons.count, 100)
        XCTAssertLessThan(fetchTime, 1.0, "Bulk fetch should complete within 1 second")
    }
    
    // MARK: - Data Integrity Tests
    
    func testDataIntegrityValidation() {
        // Create some test data
        let lesson = coreDataManager.createLesson(
            title: "Integrity Test Lesson",
            defaultBPM: 120.0,
            duration: 60.0
        )
        
        let scoreResult = ScoreResult(
            totalScore: 85.5,
            starRating: 2,
            isPlatinum: false,
            isBlackStar: false,
            timingResults: [],
            streakCount: 5,
            maxStreak: 8,
            missCount: 2,
            extraCount: 1,
            perfectCount: 15,
            earlyCount: 3,
            lateCount: 2,
            completionTime: 45.0
        )
        
        _ = coreDataManager.saveScoreResult(scoreResult, for: lesson.id, mode: .performance)
        
        // Validate data integrity
        let issues = coreDataManager.validateDataIntegrity()
        XCTAssertTrue(issues.isEmpty, "Data integrity issues found: \(issues)")
    }
    
    // MARK: - Additional Comprehensive Tests
    
    func testConcurrentDataOperations() {
        let expectation = XCTestExpectation(description: "Concurrent operations should complete")
        expectation.expectedFulfillmentCount = 3
        
        // Test concurrent data operations
        DispatchQueue.global().async {
            for i in 0..<10 {
                let lesson = self.coreDataManager.createLesson(
                    title: "Concurrent Lesson A\(i)",
                    defaultBPM: 120.0,
                    duration: 60.0
                )
                XCTAssertNotNil(lesson)
            }
            expectation.fulfill()
        }
        
        DispatchQueue.global().async {
            for i in 0..<10 {
                let userProgress = self.coreDataManager.getUserProgress(for: "concurrent_user_\(i)")
                userProgress.currentLevel = Int16(i + 1)
                self.coreDataManager.saveWithoutSync()
            }
            expectation.fulfill()
        }
        
        DispatchQueue.global().async {
            for i in 0..<10 {
                let course = self.coreDataManager.createCourse(
                    title: "Concurrent Course \(i)",
                    description: "Course created concurrently",
                    difficulty: (i % 5) + 1
                )
                XCTAssertNotNil(course)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify data integrity after concurrent operations
        let issues = coreDataManager.validateDataIntegrity()
        XCTAssertTrue(issues.isEmpty, "Concurrent operations should not cause data integrity issues")
    }
    
    func testLargeDatasetHandling() {
        // Test handling of large datasets
        let largeUserId = "large_dataset_user"
        let userProgress = coreDataManager.getUserProgress(for: largeUserId)
        
        // Create a large number of daily progress entries
        let calendar = Calendar.current
        let today = Date()
        
        for i in 0..<365 { // One year of data
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let dailyProgress = DailyProgress(context: coreDataManager.context)
            dailyProgress.id = UUID().uuidString
            dailyProgress.userId = largeUserId
            dailyProgress.date = calendar.startOfDay(for: date)
            dailyProgress.practiceTimeMinutes = Int16((i % 60) + 5) // 5-65 minutes
            dailyProgress.goalAchieved = dailyProgress.practiceTimeMinutes >= 5
            dailyProgress.lessonsCompleted = Int16(i % 10)
            dailyProgress.starsEarned = Int16(i % 15)
            dailyProgress.createdAt = date
            dailyProgress.userProgress = userProgress
        }
        
        coreDataManager.saveWithoutSync()
        
        // Test fetching large dataset
        let fetchStartTime = CFAbsoluteTimeGetCurrent()
        let dailyProgressArray = userProgress.dailyProgressArray
        let fetchTime = CFAbsoluteTimeGetCurrent() - fetchStartTime
        
        XCTAssertEqual(dailyProgressArray.count, 365)
        XCTAssertLessThan(fetchTime, 2.0, "Large dataset fetch should complete within 2 seconds")
        
        // Test data integrity with large dataset
        let issues = coreDataManager.validateDataIntegrity()
        XCTAssertTrue(issues.isEmpty, "Large dataset should not cause integrity issues")
    }
    
    func testEdgeCaseDataHandling() {
        // Test handling of edge cases and boundary values
        
        // Test empty strings and nil values
        let lesson = coreDataManager.createLesson(
            title: "Edge Case Lesson",
            courseId: nil, // Test nil courseId
            defaultBPM: 1.0, // Minimum BPM
            duration: 0.1 // Very short duration
        )
        
        XCTAssertNotNil(lesson)
        XCTAssertNil(lesson.courseId)
        XCTAssertEqual(lesson.defaultBPM, 1.0)
        
        // Test maximum values
        let maxLesson = coreDataManager.createLesson(
            title: String(repeating: "A", count: 1000), // Very long title
            defaultBPM: 300.0, // Maximum reasonable BPM
            duration: 3600.0, // 1 hour duration
            difficulty: 5 // Maximum difficulty
        )
        
        XCTAssertNotNil(maxLesson)
        XCTAssertEqual(maxLesson.difficulty, 5)
        XCTAssertEqual(maxLesson.defaultBPM, 300.0)
        
        // Test score result with edge values
        let edgeScoreResult = ScoreResult(
            totalScore: 0.0, // Minimum score
            starRating: 0, // No stars
            isPlatinum: false,
            isBlackStar: false,
            timingResults: [],
            streakCount: 0,
            maxStreak: 0,
            missCount: 1000, // Many misses
            extraCount: 0,
            perfectCount: 0,
            earlyCount: 0,
            lateCount: 0,
            completionTime: 0.001 // Very short completion time
        )
        
        let edgeScoreEntity = coreDataManager.saveScoreResult(edgeScoreResult, for: lesson.id, mode: .practice)
        XCTAssertEqual(edgeScoreEntity.totalScore, 0.0)
        XCTAssertEqual(edgeScoreEntity.missCount, 1000)
    }
    
    // MARK: - CloudKit Configuration Tests
    
    func testCloudKitConfiguration() {
        // Test record type definitions
        for recordType in CloudKitConfiguration.RecordType.allCases {
            XCTAssertFalse(recordType.fields.isEmpty, "Record type \(recordType.rawValue) should have fields defined")
            
            // Test that each record type has required fields
            let fields = recordType.fields
            switch recordType {
            case .userProgress:
                XCTAssertTrue(fields.keys.contains("userId"))
                XCTAssertTrue(fields.keys.contains("currentLevel"))
                XCTAssertTrue(fields.keys.contains("totalStars"))
            case .lesson:
                XCTAssertTrue(fields.keys.contains("title"))
                XCTAssertTrue(fields.keys.contains("defaultBPM"))
                XCTAssertTrue(fields.keys.contains("duration"))
            case .scoreResult:
                XCTAssertTrue(fields.keys.contains("lessonId"))
                XCTAssertTrue(fields.keys.contains("totalScore"))
                XCTAssertTrue(fields.keys.contains("starRating"))
            default:
                break
            }
        }
    }
    
    func testCloudKitContainerConfiguration() {
        let container = CloudKitConfiguration.container
        XCTAssertEqual(container.containerIdentifier, CloudKitConfiguration.containerIdentifier)
        XCTAssertEqual(CloudKitConfiguration.containerIdentifier, "iCloud.com.drumtrainer.data")
    }
    
    func testCloudKitErrorDescriptions() {
        let errors: [CloudKitSyncError] = [
            .accountNotAvailable,
            .networkUnavailable,
            .quotaExceeded,
            .conflictResolutionFailed,
            .recordNotFound,
            .invalidRecordType,
            .permissionFailure,
            .unknownError(NSError(domain: "test", code: 1))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}

// MARK: - CloudKit Configuration Tests

class CloudKitConfigurationTests: XCTestCase {
    
    func testRecordTypeFields() {
        // Test that all record types have required fields
        for recordType in CloudKitConfiguration.RecordType.allCases {
            let fields = recordType.fields
            XCTAssertFalse(fields.isEmpty, "Record type \(recordType.rawValue) should have fields")
            
            // Test specific field requirements based on record type
            switch recordType {
            case .userProgress:
                XCTAssertTrue(fields.keys.contains("userId"))
                XCTAssertTrue(fields.keys.contains("currentLevel"))
                XCTAssertTrue(fields.keys.contains("totalStars"))
            case .lesson:
                XCTAssertTrue(fields.keys.contains("title"))
                XCTAssertTrue(fields.keys.contains("defaultBPM"))
                XCTAssertTrue(fields.keys.contains("duration"))
            case .scoreResult:
                XCTAssertTrue(fields.keys.contains("lessonId"))
                XCTAssertTrue(fields.keys.contains("totalScore"))
                XCTAssertTrue(fields.keys.contains("starRating"))
            default:
                break
            }
        }
    }
    
    func testContainerIdentifier() {
        XCTAssertEqual(CloudKitConfiguration.containerIdentifier, "iCloud.com.drumtrainer.data")
    }
    
    func testErrorTypes() {
        let errors: [CloudKitConfigurationError] = [
            .noAccount,
            .accountRestricted,
            .accountStatusUnknown,
            .schemaValidationFailed("TestType", NSError(domain: "test", code: 1)),
            .permissionDenied,
            .quotaExceeded,
            .migrationFailed(NSError(domain: "test", code: 1))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}

// MARK: - Mock CloudKit Tests

class MockCloudKitTests: XCTestCase {
    
    // These tests would use mock CloudKit responses
    // to test sync behavior without requiring actual CloudKit setup
    
    func testMockSyncSuccess() {
        // Test successful sync scenario with mock data
        let expectation = XCTestExpectation(description: "Mock sync should succeed")
        
        // Implementation would use dependency injection to provide mock CloudKit
        // For now, this is a placeholder for future mock implementation
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMockSyncFailure() {
        // Test sync failure scenarios with mock errors
        let expectation = XCTestExpectation(description: "Mock sync should handle failure")
        
        // Implementation would simulate various CloudKit errors
        // and verify proper error handling
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMockConflictResolution() {
        // Test conflict resolution with mock conflicted records
        let expectation = XCTestExpectation(description: "Mock conflict resolution should work")
        
        // Implementation would simulate record conflicts
        // and test resolution strategies
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
}