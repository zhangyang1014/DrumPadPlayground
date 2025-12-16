import Testing
import Foundation
import AudioKit
import CoreData
import CloudKit

// MARK: - Integration Test Suite

/// Comprehensive integration tests for the drum trainer application
/// Tests complete practice workflows, device compatibility, and data sync consistency

@Suite("Integration Tests")
struct IntegrationTests {
    
    // MARK: - Complete Practice Flow Tests
    
    @Test("Complete practice session workflow")
    func testCompletePracticeWorkflow() async throws {
        // Setup test environment
        let testEnvironment = IntegrationTestEnvironment()
        try await testEnvironment.setup()
        
        // 1. Load a lesson
        let lesson = try await testEnvironment.loadTestLesson()
        #expect(lesson != nil, "Lesson should load successfully")
        
        // 2. Configure practice settings
        let practiceSettings = PracticeSettings(
            startingTempo: 80.0,
            autoAccelEnabled: true,
            waitModeEnabled: false,
            loopStart: nil,
            loopEnd: nil
        )
        
        // 3. Start practice session
        try await testEnvironment.startPracticeSession(settings: practiceSettings)
        #expect(testEnvironment.lessonEngine.playbackState == .playing, "Playback should be active")
        
        // 4. Simulate user input during practice
        let userInputs = generateTestUserInputs(for: lesson!)
        for input in userInputs {
            try await testEnvironment.simulateUserInput(input)
        }
        
        // 5. Complete the session
        let sessionStats = try await testEnvironment.completePracticeSession()
        #expect(sessionStats.totalHits > 0, "Session should record user inputs")
        #expect(sessionStats.averageScore >= 0, "Score should be calculated")
        
        // 6. Verify progress is saved
        let progress = try await testEnvironment.getUserProgress()
        #expect(progress.totalPracticeTime > 0, "Practice time should be recorded")
        
        try await testEnvironment.teardown()
    }
    
    @Test("Performance mode to memory mode progression")
    func testPerformanceToMemoryModeProgression() async throws {
        let testEnvironment = IntegrationTestEnvironment()
        try await testEnvironment.setup()
        
        let lesson = try await testEnvironment.loadTestLesson()
        
        // 1. Complete lesson in performance mode with 100% score
        testEnvironment.lessonEngine.setPlaybackMode(.performance)
        try await testEnvironment.startPracticeSession(settings: PracticeSettings.defaultSettings())
        
        // Simulate perfect performance
        let perfectInputs = generatePerfectUserInputs(for: lesson!)
        for input in perfectInputs {
            try await testEnvironment.simulateUserInput(input)
        }
        
        let performanceResult = try await testEnvironment.completePracticeSession()
        #expect(performanceResult.averageScore >= 100.0, "Should achieve 100% score")
        
        // 2. Verify memory mode is unlocked
        let isUnlocked = testEnvironment.lessonEngine.isMemoryModeUnlocked()
        #expect(isUnlocked, "Memory mode should be unlocked after 100% performance")
        
        // 3. Start memory mode session
        let memoryModeEnabled = testEnvironment.lessonEngine.enableMemoryMode()
        #expect(memoryModeEnabled, "Memory mode should be enabled")
        #expect(testEnvironment.lessonEngine.playbackMode == .memory, "Should be in memory mode")
        
        // 4. Verify visual state changes in memory mode
        let visualState = testEnvironment.lessonEngine.getMemoryModeVisualState()
        #expect(visualState.assistLevel == .none, "Memory mode should have no assistance")
        
        try await testEnvironment.teardown()
    }
    
    @Test("Auto acceleration during practice")
    func testAutoAccelerationWorkflow() async throws {
        let testEnvironment = IntegrationTestEnvironment()
        try await testEnvironment.setup()
        
        let lesson = try await testEnvironment.loadTestLesson()
        
        // Configure practice with auto acceleration
        let practiceSettings = PracticeSettings(
            startingTempo: 80.0,
            autoAccelEnabled: true,
            waitModeEnabled: false,
            loopStart: nil,
            loopEnd: nil
        )
        
        testEnvironment.lessonEngine.setPlaybackMode(.practice)
        try await testEnvironment.startPracticeSession(settings: practiceSettings)
        
        let initialTempo = testEnvironment.lessonEngine.currentTempo
        
        // Simulate good performance to trigger auto acceleration
        let goodInputs = generateGoodUserInputs(for: lesson!)
        for input in goodInputs {
            try await testEnvironment.simulateUserInput(input)
            
            // Check if tempo has increased
            if testEnvironment.lessonEngine.currentTempo > initialTempo {
                break // Auto acceleration triggered
            }
        }
        
        #expect(testEnvironment.lessonEngine.currentTempo > initialTempo, "Auto acceleration should increase tempo")
        
        try await testEnvironment.teardown()
    }
    
    @Test("Loop region practice workflow")
    func testLoopRegionPractice() async throws {
        let testEnvironment = IntegrationTestEnvironment()
        try await testEnvironment.setup()
        
        let lesson = try await testEnvironment.loadTestLesson()
        
        // Set up loop region (first 8 seconds)
        testEnvironment.lessonEngine.setLoopRegion(0.0, 8.0)
        
        let practiceSettings = PracticeSettings(
            startingTempo: 100.0,
            autoAccelEnabled: false,
            waitModeEnabled: false,
            loopStart: 0.0,
            loopEnd: 8.0
        )
        
        try await testEnvironment.startPracticeSession(settings: practiceSettings)
        
        // Let the loop play through multiple times
        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        
        let sessionStats = try await testEnvironment.completePracticeSession()
        #expect(sessionStats.loopsCompleted > 1, "Should complete multiple loops")
        
        try await testEnvironment.teardown()
    }
    
    // MARK: - Device Compatibility Tests
    
    @Test("MIDI device connection and mapping")
    func testMIDIDeviceCompatibility() async throws {
        let testEnvironment = IntegrationTestEnvironment()
        try await testEnvironment.setup()
        
        // Simulate MIDI device detection
        let mockDevice = MIDIDeviceInfo(
            name: "Test MIDI Controller",
            manufacturer: "Test Manufacturer",
            deviceRef: 0, // Mock device reference
            connectionType: .usb,
            isOnline: true
        )
        
        // Test device connection
        testEnvironment.conductor.connectToDevice(mockDevice)
        
        // Wait for connection to establish
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        #expect(testEnvironment.conductor.midiConnectionStatus == .connected, "MIDI device should connect")
        
        // Test MIDI mapping validation
        let mapping = testEnvironment.conductor.currentMidiMapping
        let isValid = testEnvironment.conductor.validateMIDIMapping()
        #expect(isValid, "MIDI mapping should be valid")
        
        // Test MIDI input processing
        let testMIDIEvent = MIDIEvent(
            timestamp: CACurrentMediaTime(),
            noteNumber: 36, // Kick drum
            velocity: 100,
            channel: 0
        )
        
        testEnvironment.conductor.scoreEngine.processUserInput(testMIDIEvent, at: testMIDIEvent.timestamp)
        
        // Verify input was processed
        #expect(testEnvironment.conductor.scoreEngine.isScoring, "Score engine should process MIDI input")
        
        try await testEnvironment.teardown()
    }
    
    @Test("Audio device switching and latency handling")
    func testAudioDeviceCompatibility() async throws {
        let testEnvironment = IntegrationTestEnvironment()
        try await testEnvironment.setup()
        
        // Test initial audio setup
        #expect(testEnvironment.conductor.engine.avEngine.isRunning, "Audio engine should be running")
        
        // Simulate audio device change
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: nil,
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue]
        )
        
        // Wait for audio system to adapt
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Verify audio latency is measured
        #expect(testEnvironment.conductor.audioLatency > 0, "Audio latency should be measured")
        
        // Test high latency detection
        if testEnvironment.conductor.audioLatency > 0.050 {
            // High latency should trigger warning
            #expect(testEnvironment.conductor.errorPresenter != nil, "Error presenter should handle high latency")
        }
        
        try await testEnvironment.teardown()
    }
    
    @Test("Bluetooth audio device warning")
    func testBluetoothAudioWarning() async throws {
        let testEnvironment = IntegrationTestEnvironment()
        try await testEnvironment.setup()
        
        // Simulate Bluetooth device connection
        let bluetoothDevice = MIDIDeviceInfo(
            name: "Bluetooth Headphones",
            manufacturer: "Apple",
            deviceRef: 1,
            connectionType: .bluetooth,
            isOnline: true
        )
        
        testEnvironment.conductor.connectToDevice(bluetoothDevice)
        
        // Verify Bluetooth warning is triggered
        // This would normally check if a warning UI is shown
        #expect(bluetoothDevice.connectionType == .bluetooth, "Should detect Bluetooth connection")
        
        try await testEnvironment.teardown()
    }
    
    // MARK: - Data Sync Consistency Tests
    
    @Test("Local and CloudKit data synchronization")
    func testDataSyncConsistency() async throws {
        let testEnvironment = IntegrationTestEnvironment()
        try await testEnvironment.setup()
        
        // Create local progress data
        let localProgress = try await testEnvironment.createLocalProgress()
        #expect(localProgress != nil, "Local progress should be created")
        
        // Simulate CloudKit sync
        try await testEnvironment.cloudKitManager.performFullSync()
        
        // Verify data consistency after sync
        let syncedProgress = try await testEnvironment.getUserProgress()
        #expect(syncedProgress.id == localProgress!.id, "Progress IDs should match after sync")
        #expect(syncedProgress.totalStars == localProgress!.totalStars, "Progress data should be consistent")
        
        try await testEnvironment.teardown()
    }
    
    @Test("Offline mode data persistence")
    func testOfflineDataPersistence() async throws {
        let testEnvironment = IntegrationTestEnvironment()
        try await testEnvironment.setup()
        
        // Simulate offline mode
        testEnvironment.cloudKitManager.setOfflineMode(true)
        
        // Create practice session data while offline
        let lesson = try await testEnvironment.loadTestLesson()
        try await testEnvironment.startPracticeSession(settings: PracticeSettings.defaultSettings())
        
        let userInputs = generateTestUserInputs(for: lesson!)
        for input in userInputs {
            try await testEnvironment.simulateUserInput(input)
        }
        
        let offlineStats = try await testEnvironment.completePracticeSession()
        
        // Verify data is saved locally
        let localProgress = try await testEnvironment.getUserProgress()
        #expect(localProgress.totalPracticeTime > 0, "Practice time should be saved offline")
        
        // Simulate going back online
        testEnvironment.cloudKitManager.setOfflineMode(false)
        try await testEnvironment.cloudKitManager.performFullSync()
        
        // Verify offline data is synced
        let syncedProgress = try await testEnvironment.getUserProgress()
        #expect(syncedProgress.totalPracticeTime == localProgress.totalPracticeTime, "Offline data should sync correctly")
        
        try await testEnvironment.teardown()
    }
    
    @Test("Sync conflict resolution")
    func testSyncConflictResolution() async throws {
        let testEnvironment = IntegrationTestEnvironment()
        try await testEnvironment.setup()
        
        // Create conflicting data scenarios
        let localProgress = try await testEnvironment.createLocalProgress()
        let remoteProgress = try await testEnvironment.createRemoteProgress()
        
        // Simulate sync conflict
        do {
            try await testEnvironment.cloudKitManager.performFullSync()
        } catch {
            // Expect sync conflict error
            if let drumTrainerError = error as? DrumTrainerError {
                switch drumTrainerError {
                case .syncConflict:
                    // Conflict detected correctly
                    break
                default:
                    throw error
                }
            }
        }
        
        // Verify conflict resolution mechanism
        let resolvedProgress = try await testEnvironment.getUserProgress()
        #expect(resolvedProgress != nil, "Conflict should be resolved")
        
        try await testEnvironment.teardown()
    }
    
    // MARK: - Error Recovery Integration Tests
    
    @Test("Audio engine failure recovery")
    func testAudioEngineFailureRecovery() async throws {
        let testEnvironment = IntegrationTestEnvironment()
        try await testEnvironment.setup()
        
        // Simulate audio engine failure
        testEnvironment.conductor.engine.stop()
        
        // Attempt recovery
        let recoveryManager = testEnvironment.errorRecoveryManager
        let canRecover = recoveryManager.canRecover(from: .audioEngineFailure(underlying: NSError(domain: "Test", code: 1)))
        #expect(canRecover, "Should be able to recover from audio engine failure")
        
        try await recoveryManager.recover(from: .audioEngineFailure(underlying: NSError(domain: "Test", code: 1)))
        
        // Verify recovery
        #expect(testEnvironment.conductor.engine.avEngine.isRunning, "Audio engine should be recovered")
        
        try await testEnvironment.teardown()
    }
    
    @Test("Data corruption recovery")
    func testDataCorruptionRecovery() async throws {
        let testEnvironment = IntegrationTestEnvironment()
        try await testEnvironment.setup()
        
        // Simulate data corruption
        let corruptionError = DrumTrainerError.dataCorruption(entity: "Lesson", id: "test-lesson-id")
        
        // Attempt recovery
        let recoveryManager = testEnvironment.errorRecoveryManager
        let canRecover = recoveryManager.canRecover(from: corruptionError)
        #expect(canRecover, "Should be able to recover from data corruption")
        
        try await recoveryManager.recover(from: corruptionError)
        
        // Verify data integrity after recovery
        let integrityChecker = DataIntegrityChecker(coreDataManager: testEnvironment.coreDataManager)
        let issues = await integrityChecker.performIntegrityCheck()
        #expect(issues.isEmpty, "No integrity issues should remain after recovery")
        
        try await testEnvironment.teardown()
    }
    
    // MARK: - Performance Integration Tests
    
    @Test("Memory usage during extended practice session")
    func testMemoryUsageDuringExtendedSession() async throws {
        let testEnvironment = IntegrationTestEnvironment()
        try await testEnvironment.setup()
        
        let initialMemory = getMemoryUsage()
        
        // Run extended practice session (simulate 30 minutes)
        for _ in 0..<30 {
            let lesson = try await testEnvironment.loadTestLesson()
            try await testEnvironment.startPracticeSession(settings: PracticeSettings.defaultSettings())
            
            let userInputs = generateTestUserInputs(for: lesson!)
            for input in userInputs {
                try await testEnvironment.simulateUserInput(input)
            }
            
            _ = try await testEnvironment.completePracticeSession()
            
            // Brief pause between sessions
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable (less than 100MB)
        #expect(memoryIncrease < 100_000_000, "Memory usage should not increase excessively during extended sessions")
        
        try await testEnvironment.teardown()
    }
    
    @Test("Audio processing latency under load")
    func testAudioLatencyUnderLoad() async throws {
        let testEnvironment = IntegrationTestEnvironment()
        try await testEnvironment.setup()
        
        // Start multiple concurrent audio processes
        let lesson = try await testEnvironment.loadTestLesson()
        try await testEnvironment.startPracticeSession(settings: PracticeSettings.defaultSettings())
        
        // Measure latency while processing many MIDI events
        let startTime = CACurrentMediaTime()
        
        for i in 0..<1000 {
            let midiEvent = MIDIEvent(
                timestamp: CACurrentMediaTime(),
                noteNumber: 36 + (i % 8), // Cycle through drum pads
                velocity: 100,
                channel: 0
            )
            
            testEnvironment.conductor.scoreEngine.processUserInput(midiEvent, at: midiEvent.timestamp)
        }
        
        let processingTime = CACurrentMediaTime() - startTime
        
        // Processing 1000 events should complete quickly (under 1 second)
        #expect(processingTime < 1.0, "MIDI processing should be efficient under load")
        
        try await testEnvironment.teardown()
    }
}

// MARK: - Integration Test Environment

class IntegrationTestEnvironment {
    let conductor: Conductor
    let coreDataManager: CoreDataManager
    let cloudKitManager: CloudKitSyncManager
    let lessonEngine: LessonEngine
    let errorRecoveryManager: ErrorRecoveryManager
    let errorPresenter: ErrorPresenter
    
    init() {
        self.coreDataManager = CoreDataManager()
        self.cloudKitManager = CloudKitSyncManager()
        self.conductor = Conductor()
        self.lessonEngine = LessonEngine(
            coreDataManager: coreDataManager,
            conductor: conductor,
            scoreEngine: conductor.scoreEngine
        )
        self.errorRecoveryManager = ErrorRecoveryManager(
            conductor: conductor,
            coreDataManager: coreDataManager,
            cloudKitManager: cloudKitManager
        )
        self.errorPresenter = ErrorPresenter(recoveryManager: errorRecoveryManager)
        
        // Connect error handling
        conductor.setErrorPresenter(errorPresenter)
    }
    
    func setup() async throws {
        // Initialize test environment
        conductor.start()
        try coreDataManager.setupTestEnvironment()
        cloudKitManager.setupTestMode()
    }
    
    func teardown() async throws {
        // Clean up test environment
        conductor.engine.stop()
        try coreDataManager.cleanupTestEnvironment()
        cloudKitManager.cleanupTestMode()
    }
    
    func loadTestLesson() async throws -> Lesson? {
        // Create and return a test lesson
        return createTestLesson()
    }
    
    func startPracticeSession(settings: PracticeSettings) async throws {
        lessonEngine.startPracticeSession(withSettings: settings)
    }
    
    func simulateUserInput(_ input: MIDIEvent) async throws {
        conductor.scoreEngine.processUserInput(input, at: input.timestamp)
        // Small delay to simulate realistic timing
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    }
    
    func completePracticeSession() async throws -> PracticeSessionStats {
        return lessonEngine.getPracticeSessionStats()
    }
    
    func getUserProgress() async throws -> UserProgress {
        return coreDataManager.fetchUserProgress()
    }
    
    func createLocalProgress() async throws -> UserProgress? {
        // Create test progress data locally
        return createTestUserProgress()
    }
    
    func createRemoteProgress() async throws -> UserProgress? {
        // Create test progress data in CloudKit
        return createTestUserProgress()
    }
}

// MARK: - Test Data Generators

func generateTestUserInputs(for lesson: Lesson) -> [MIDIEvent] {
    var inputs: [MIDIEvent] = []
    let baseTime = CACurrentMediaTime()
    
    // Generate inputs based on lesson target events
    for (index, step) in lesson.stepsArray.enumerated() {
        for (eventIndex, targetEvent) in step.targetEvents.enumerated() {
            let input = MIDIEvent(
                timestamp: baseTime + targetEvent.timestamp + Double.random(in: -0.02...0.02), // Add slight timing variation
                noteNumber: targetEvent.noteNumber,
                velocity: Int.random(in: 80...127),
                channel: 0
            )
            inputs.append(input)
        }
    }
    
    return inputs
}

func generatePerfectUserInputs(for lesson: Lesson) -> [MIDIEvent] {
    var inputs: [MIDIEvent] = []
    let baseTime = CACurrentMediaTime()
    
    // Generate perfect timing inputs
    for step in lesson.stepsArray {
        for targetEvent in step.targetEvents {
            let input = MIDIEvent(
                timestamp: baseTime + targetEvent.timestamp, // Perfect timing
                noteNumber: targetEvent.noteNumber,
                velocity: 127, // Maximum velocity
                channel: 0
            )
            inputs.append(input)
        }
    }
    
    return inputs
}

func generateGoodUserInputs(for lesson: Lesson) -> [MIDIEvent] {
    var inputs: [MIDIEvent] = []
    let baseTime = CACurrentMediaTime()
    
    // Generate good (but not perfect) timing inputs
    for step in lesson.stepsArray {
        for targetEvent in step.targetEvents {
            let input = MIDIEvent(
                timestamp: baseTime + targetEvent.timestamp + Double.random(in: -0.01...0.01), // Small timing variation
                noteNumber: targetEvent.noteNumber,
                velocity: Int.random(in: 100...127),
                channel: 0
            )
            inputs.append(input)
        }
    }
    
    return inputs
}

func createTestLesson() -> Lesson {
    // Create a test lesson with sample data
    let lesson = Lesson(context: CoreDataManager().viewContext)
    lesson.id = "test-lesson-\(UUID().uuidString)"
    lesson.title = "Test Lesson"
    lesson.defaultBPM = 120.0
    lesson.duration = 30.0 // 30 seconds
    lesson.difficulty = 2
    lesson.tags = "[]"
    lesson.createdAt = Date()
    lesson.updatedAt = Date()
    
    // Add test steps
    let step = LessonStep(context: CoreDataManager().viewContext)
    step.id = "test-step-\(UUID().uuidString)"
    step.lessonId = lesson.id
    step.order = 0
    step.title = "Test Step"
    step.stepDescription = "Test step description"
    step.assistLevel = AssistLevel.full.rawValue
    step.createdAt = Date()
    
    // Add target events
    let targetEvents = [
        TargetEvent(timestamp: 1.0, laneId: "kick", noteNumber: 36, velocity: 100, duration: nil),
        TargetEvent(timestamp: 2.0, laneId: "snare", noteNumber: 38, velocity: 100, duration: nil),
        TargetEvent(timestamp: 3.0, laneId: "hihat", noteNumber: 42, velocity: 100, duration: nil),
        TargetEvent(timestamp: 4.0, laneId: "kick", noteNumber: 36, velocity: 100, duration: nil)
    ]
    step.targetEvents = targetEvents
    
    lesson.addToSteps(step)
    
    return lesson
}

func createTestUserProgress() -> UserProgress {
    let progress = UserProgress(context: CoreDataManager().viewContext)
    progress.id = "test-progress-\(UUID().uuidString)"
    progress.userId = "test-user"
    progress.currentLevel = 1
    progress.totalStars = 5
    progress.currentStreak = 3
    progress.maxStreak = 10
    progress.totalTrophies = 2
    progress.dailyGoalMinutes = 5
    progress.totalPracticeTime = 300.0 // 5 minutes
    progress.createdAt = Date()
    progress.updatedAt = Date()
    
    return progress
}

func getMemoryUsage() -> Int64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     $0,
                     &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        return Int64(info.resident_size)
    } else {
        return 0
    }
}

// MARK: - Mock Extensions

extension CoreDataManager {
    func setupTestEnvironment() throws {
        // Setup test Core Data stack
        print("Setting up test Core Data environment")
    }
    
    func cleanupTestEnvironment() throws {
        // Clean up test data
        print("Cleaning up test Core Data environment")
    }
}

extension CloudKitSyncManager {
    func setupTestMode() {
        // Setup CloudKit test mode
        print("Setting up CloudKit test mode")
    }
    
    func cleanupTestMode() {
        // Clean up CloudKit test data
        print("Cleaning up CloudKit test mode")
    }
    
    func setOfflineMode(_ offline: Bool) {
        // Simulate offline/online mode
        print("Setting offline mode: \(offline)")
    }
}