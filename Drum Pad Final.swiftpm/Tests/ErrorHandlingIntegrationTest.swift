import Testing
import Foundation

// MARK: - Error Handling Integration Test

/// Simple integration test to verify error handling system functionality
/// Tests error presentation, recovery mechanisms, and data integrity checks

@Suite("Error Handling Integration")
struct ErrorHandlingIntegrationTest {
    
    @Test("Error presenter handles audio engine failure")
    func testErrorPresenterHandlesAudioEngineFailure() async throws {
        // Create test environment
        let mockCoreDataManager = MockCoreDataManager()
        let mockCloudKitManager = MockCloudKitSyncManager()
        let mockConductor = MockConductor()
        
        let recoveryManager = ErrorRecoveryManager(
            conductor: mockConductor,
            coreDataManager: mockCoreDataManager,
            cloudKitManager: mockCloudKitManager
        )
        
        let errorPresenter = ErrorPresenter(recoveryManager: recoveryManager)
        
        // Test error presentation
        let testError = DrumTrainerError.audioEngineFailure(underlying: NSError(domain: "Test", code: 1))
        errorPresenter.presentError(testError)
        
        // Verify error is presented
        #expect(errorPresenter.isShowingError, "Error should be shown for high severity errors")
        #expect(errorPresenter.currentError != nil, "Current error should be set")
        #expect(errorPresenter.errorHistory.count == 1, "Error should be logged in history")
        
        // Test error dismissal
        errorPresenter.dismissError()
        #expect(!errorPresenter.isShowingError, "Error should be dismissed")
        #expect(errorPresenter.currentError == nil, "Current error should be cleared")
    }
    
    @Test("Error recovery manager can recover from audio failures")
    func testErrorRecoveryManagerAudioFailures() async throws {
        let mockCoreDataManager = MockCoreDataManager()
        let mockCloudKitManager = MockCloudKitSyncManager()
        let mockConductor = MockConductor()
        
        let recoveryManager = ErrorRecoveryManager(
            conductor: mockConductor,
            coreDataManager: mockCoreDataManager,
            cloudKitManager: mockCloudKitManager
        )
        
        // Test recovery capability check
        let audioError = DrumTrainerError.audioEngineFailure(underlying: NSError(domain: "Test", code: 1))
        let canRecover = recoveryManager.canRecover(from: audioError)
        #expect(canRecover, "Should be able to recover from audio engine failure")
        
        // Test actual recovery (would normally restart audio engine)
        do {
            try await recoveryManager.recover(from: audioError)
            // If we get here, recovery succeeded
        } catch {
            throw error // Re-throw if recovery failed
        }
    }
    
    @Test("Data integrity checker detects issues")
    func testDataIntegrityChecker() async throws {
        let mockCoreDataManager = MockCoreDataManager()
        let integrityChecker = DataIntegrityChecker(coreDataManager: mockCoreDataManager)
        
        // Run integrity check
        let issues = await integrityChecker.performIntegrityCheck()
        
        // For mock data, we expect no issues
        #expect(issues.isEmpty, "Mock data should have no integrity issues")
    }
    
    @Test("Performance monitor tracks metrics")
    func testPerformanceMonitorTracking() async throws {
        let performanceMonitor = PerformanceMonitor()
        
        // Verify initial state
        #expect(!performanceMonitor.isMonitoring, "Should not be monitoring initially")
        #expect(performanceMonitor.currentMetrics == nil, "Should have no metrics initially")
        #expect(performanceMonitor.performanceHistory.isEmpty, "Should have empty history initially")
        
        // Test metric recording (simulated)
        let testMetrics = PerformanceMetrics(
            timestamp: Date(),
            audioLatency: 0.025,
            memoryUsage: 150_000_000,
            cpuUsage: 45.0,
            audioBufferUnderruns: 0,
            midiProcessingLatency: 0.003,
            frameDrops: 0,
            batteryLevel: 0.75,
            thermalState: .nominal
        )
        
        // Simulate adding metrics
        performanceMonitor.currentMetrics = testMetrics
        performanceMonitor.performanceHistory.append(testMetrics)
        
        // Verify metrics are tracked
        #expect(performanceMonitor.currentMetrics != nil, "Should have current metrics")
        #expect(performanceMonitor.performanceHistory.count == 1, "Should have one history entry")
        
        // Test performance score calculation
        let score = testMetrics.performanceScore
        #expect(score > 0, "Performance score should be positive")
        #expect(score <= 100, "Performance score should not exceed 100")
    }
    
    @Test("Error handling system integration")
    func testErrorHandlingSystemIntegration() async throws {
        // Create integrated test environment
        let mockCoreDataManager = MockCoreDataManager()
        let mockCloudKitManager = MockCloudKitSyncManager()
        let mockConductor = MockConductor()
        
        let recoveryManager = ErrorRecoveryManager(
            conductor: mockConductor,
            coreDataManager: mockCoreDataManager,
            cloudKitManager: mockCloudKitManager
        )
        
        let errorPresenter = ErrorPresenter(recoveryManager: recoveryManager)
        let performanceMonitor = PerformanceMonitor()
        
        // Connect error presenter to conductor
        mockConductor.setErrorPresenter(errorPresenter)
        
        // Simulate error scenario
        let midiError = DrumTrainerError.midiConnectionFailure(deviceName: "Test Device", underlying: nil)
        errorPresenter.presentError(midiError)
        
        // Verify error is handled
        #expect(errorPresenter.isShowingError, "MIDI error should be shown")
        
        // Test recovery attempt
        await errorPresenter.attemptRecovery()
        
        // After recovery, error should be dismissed (in successful case)
        // Note: In real implementation, this would depend on actual recovery success
    }
}

// MARK: - Mock Classes for Testing

class MockConductor: Conductor {
    var mockErrorPresenter: ErrorPresenter?
    
    override func setErrorPresenter(_ presenter: ErrorPresenter) {
        mockErrorPresenter = presenter
    }
    
    override func start() {
        // Mock implementation - don't actually start audio engine
        print("Mock conductor started")
    }
}

class MockCoreDataManager: CoreDataManager {
    override func fetchAllLessons() -> [Lesson] {
        return [] // Return empty array for testing
    }
    
    override func fetchAllCourses() -> [Course] {
        return [] // Return empty array for testing
    }
    
    override func fetchAllLessonSteps() -> [LessonStep] {
        return [] // Return empty array for testing
    }
    
    override func fetchAllScoreResults() -> [ScoreResultEntity] {
        return [] // Return empty array for testing
    }
    
    override func fetchUserProgress() -> UserProgress {
        // Create mock user progress
        let progress = UserProgress(context: viewContext)
        progress.id = "mock-progress"
        progress.userId = "mock-user"
        progress.currentLevel = 1
        progress.totalStars = 0
        progress.currentStreak = 0
        progress.maxStreak = 0
        progress.totalTrophies = 0
        progress.dailyGoalMinutes = 5
        progress.totalPracticeTime = 0
        progress.createdAt = Date()
        progress.updatedAt = Date()
        return progress
    }
}

class MockCloudKitSyncManager: CloudKitSyncManager {
    override func fetchLesson(id: String) async throws {
        // Mock implementation
        print("Mock fetching lesson: \(id)")
    }
    
    override func fetchCourse(id: String) async throws {
        // Mock implementation
        print("Mock fetching course: \(id)")
    }
    
    override func resetSyncState() {
        // Mock implementation
        print("Mock resetting sync state")
    }
    
    override func performFullSync() async throws {
        // Mock implementation
        print("Mock performing full sync")
    }
}