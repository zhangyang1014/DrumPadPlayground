import Foundation
import AudioKit
import AVFoundation
import CoreData
import CloudKit

// MARK: - Error Handling System

/// Comprehensive error handling system for the drum trainer application
/// Provides audio system error recovery, data integrity checks, and user-friendly error messages

// MARK: - Validation Error Type
// 定义本地 ValidationError 类型，避免与其他模块的类型冲突
public struct ContentValidationError: Error, LocalizedError {
    public let field: String
    public let reason: String
    
    public var errorDescription: String? {
        return "\(field): \(reason)"
    }
}

// MARK: - Error Types

public enum DrumTrainerError: Error, LocalizedError {
    // Audio System Errors
    case audioEngineFailure(underlying: Error)
    case midiConnectionFailure(deviceName: String, underlying: Error?)
    case audioLatencyTooHigh(latency: TimeInterval)
    case audioDeviceNotFound(deviceName: String)
    case audioSessionInterrupted
    case audioBufferUnderrun
    
    // Data Integrity Errors
    case dataCorruption(entity: String, id: String)
    case syncConflict(entity: String, localVersion: Date, remoteVersion: Date)
    case invalidLessonData(lessonId: String, reason: String)
    case missingRequiredData(entity: String, field: String)
    case cloudKitSyncFailure(underlying: Error)
    
    // Content Management Errors
    case invalidMIDIFile(fileName: String, reason: String)
    case contentValidationFailure(errors: [ContentValidationError])
    case unsupportedFileFormat(fileName: String, expectedFormat: String)
    case contentImportFailure(fileName: String, underlying: Error)
    
    // Scoring System Errors
    case scoringEngineFailure(reason: String)
    case invalidScoringProfile(reason: String)
    case timingCalculationError(underlying: Error)
    
    // User Interface Errors
    case memoryModeNotUnlocked(lessonId: String)
    case invalidPlaybackMode(mode: String)
    case uiStateInconsistency(component: String, expectedState: String, actualState: String)
    
    public var errorDescription: String? {
        switch self {
        // Audio System Errors
        case .audioEngineFailure(let underlying):
            return "Audio engine failed to start: \(underlying.localizedDescription)"
        case .midiConnectionFailure(let deviceName, let underlying):
            let underlyingMsg = underlying?.localizedDescription ?? "Unknown error"
            return "Failed to connect to MIDI device '\(deviceName)': \(underlyingMsg)"
        case .audioLatencyTooHigh(let latency):
            return "Audio latency is too high (\(Int(latency * 1000))ms). Consider using wired headphones."
        case .audioDeviceNotFound(let deviceName):
            return "Audio device '\(deviceName)' not found. Please check your audio settings."
        case .audioSessionInterrupted:
            return "Audio session was interrupted. Please restart the lesson."
        case .audioBufferUnderrun:
            return "Audio buffer underrun detected. Try closing other apps or restarting the device."
            
        // Data Integrity Errors
        case .dataCorruption(let entity, let id):
            return "Data corruption detected in \(entity) with ID: \(id). Please try reloading the content."
        case .syncConflict(let entity, let localVersion, let remoteVersion):
            return "Sync conflict in \(entity). Local version: \(localVersion), Remote version: \(remoteVersion)"
        case .invalidLessonData(let lessonId, let reason):
            return "Invalid lesson data for lesson \(lessonId): \(reason)"
        case .missingRequiredData(let entity, let field):
            return "Missing required data in \(entity): \(field)"
        case .cloudKitSyncFailure(let underlying):
            return "CloudKit sync failed: \(underlying.localizedDescription)"
            
        // Content Management Errors
        case .invalidMIDIFile(let fileName, let reason):
            return "Invalid MIDI file '\(fileName)': \(reason)"
        case .contentValidationFailure(let errors):
            let errorMessages = errors.map { $0.localizedDescription }.joined(separator: ", ")
            return "Content validation failed: \(errorMessages)"
        case .unsupportedFileFormat(let fileName, let expectedFormat):
            return "Unsupported file format for '\(fileName)'. Expected: \(expectedFormat)"
        case .contentImportFailure(let fileName, let underlying):
            return "Failed to import '\(fileName)': \(underlying.localizedDescription)"
            
        // Scoring System Errors
        case .scoringEngineFailure(let reason):
            return "Scoring engine error: \(reason)"
        case .invalidScoringProfile(let reason):
            return "Invalid scoring profile: \(reason)"
        case .timingCalculationError(let underlying):
            return "Timing calculation error: \(underlying.localizedDescription)"
            
        // User Interface Errors
        case .memoryModeNotUnlocked(let lessonId):
            return "Memory mode not unlocked for lesson \(lessonId). Complete the lesson with 100% score in Performance mode first."
        case .invalidPlaybackMode(let mode):
            return "Invalid playback mode: \(mode)"
        case .uiStateInconsistency(let component, let expectedState, let actualState):
            return "UI state inconsistency in \(component). Expected: \(expectedState), Actual: \(actualState)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .audioEngineFailure:
            return "Try restarting the app or checking your audio settings."
        case .midiConnectionFailure:
            return "Check MIDI device connection and try reconnecting."
        case .audioLatencyTooHigh:
            return "Use wired headphones or adjust audio buffer settings."
        case .audioDeviceNotFound:
            return "Check audio device connections and system audio settings."
        case .audioSessionInterrupted:
            return "Restart the lesson or check for other apps using audio."
        case .audioBufferUnderrun:
            return "Close other apps, restart the device, or adjust audio buffer size."
        case .dataCorruption:
            return "Try reloading the content or contact support if the issue persists."
        case .syncConflict:
            return "Choose which version to keep or merge the changes manually."
        case .invalidLessonData:
            return "Try redownloading the lesson or contact support."
        case .missingRequiredData:
            return "Reload the content or check your internet connection."
        case .cloudKitSyncFailure:
            return "Check your internet connection and iCloud settings."
        case .invalidMIDIFile:
            return "Use a valid MIDI file or check the file format."
        case .contentValidationFailure:
            return "Fix the validation errors and try again."
        case .unsupportedFileFormat:
            return "Convert the file to the supported format."
        case .contentImportFailure:
            return "Check the file and try importing again."
        case .scoringEngineFailure:
            return "Restart the lesson or contact support."
        case .invalidScoringProfile:
            return "Reset scoring settings to default values."
        case .timingCalculationError:
            return "Restart the lesson or check system performance."
        case .memoryModeNotUnlocked:
            return "Complete the lesson with 100% score in Performance mode first."
        case .invalidPlaybackMode:
            return "Select a valid playback mode."
        case .uiStateInconsistency:
            return "Restart the app or refresh the current view."
        }
    }
    
    public var severity: ErrorSeverity {
        switch self {
        case .audioEngineFailure, .dataCorruption, .cloudKitSyncFailure:
            return .critical
        case .midiConnectionFailure, .audioLatencyTooHigh, .invalidLessonData, .scoringEngineFailure:
            return .high
        case .audioDeviceNotFound, .syncConflict, .contentValidationFailure, .invalidScoringProfile:
            return .medium
        case .audioSessionInterrupted, .audioBufferUnderrun, .invalidMIDIFile, .memoryModeNotUnlocked:
            return .low
        case .unsupportedFileFormat, .contentImportFailure, .timingCalculationError, .invalidPlaybackMode, .uiStateInconsistency, .missingRequiredData:
            return .low
        }
    }
}

public enum ErrorSeverity: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var requiresUserAction: Bool {
        return self.rawValue >= ErrorSeverity.medium.rawValue
    }
}

// MARK: - Error Recovery System

public protocol ErrorRecoveryProtocol {
    func canRecover(from error: DrumTrainerError) -> Bool
    func recover(from error: DrumTrainerError) async throws
}

public class ErrorRecoveryManager: ErrorRecoveryProtocol {
    private let conductor: Conductor
    private let coreDataManager: CoreDataManager
    private let cloudKitManager: CloudKitSyncManager
    
    // 使用 internal 访问级别，因为 CloudKitSyncManager 是 internal 类型
    init(conductor: Conductor, coreDataManager: CoreDataManager, cloudKitManager: CloudKitSyncManager) {
        self.conductor = conductor
        self.coreDataManager = coreDataManager
        self.cloudKitManager = cloudKitManager
    }
    
    public func canRecover(from error: DrumTrainerError) -> Bool {
        switch error {
        case .audioEngineFailure, .audioSessionInterrupted:
            return true
        case .midiConnectionFailure:
            return true
        case .audioLatencyTooHigh:
            return false // Requires user action
        case .dataCorruption:
            return true
        case .syncConflict:
            return false // Requires user decision
        case .invalidLessonData:
            return true
        case .cloudKitSyncFailure:
            return true
        case .scoringEngineFailure:
            return true
        default:
            return false
        }
    }
    
    public func recover(from error: DrumTrainerError) async throws {
        switch error {
        case .audioEngineFailure:
            try await recoverAudioEngine()
            
        case .audioSessionInterrupted:
            try await recoverAudioSession()
            
        case .midiConnectionFailure(let deviceName, _):
            try await recoverMIDIConnection(deviceName: deviceName)
            
        case .dataCorruption(let entity, let id):
            try await recoverCorruptedData(entity: entity, id: id)
            
        case .invalidLessonData(let lessonId, _):
            try await recoverLessonData(lessonId: lessonId)
            
        case .cloudKitSyncFailure:
            try await recoverCloudKitSync()
            
        case .scoringEngineFailure:
            try await recoverScoringEngine()
            
        default:
            throw DrumTrainerError.scoringEngineFailure(reason: "Cannot automatically recover from this error type")
        }
    }
    
    // MARK: - Specific Recovery Methods
    
    private func recoverAudioEngine() async throws {
        // Stop current engine
        conductor.engine.stop()
        
        // Wait a moment for cleanup
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Restart engine
        do {
            try conductor.engine.start()
            conductor.start() // Reload samples and setup
        } catch {
            throw DrumTrainerError.audioEngineFailure(underlying: error)
        }
    }
    
    private func recoverAudioSession() async throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Reactivate audio session
            try audioSession.setActive(true)
            
            // Restart conductor
            conductor.start()
        } catch {
            throw DrumTrainerError.audioSessionInterrupted
        }
    }
    
    private func recoverMIDIConnection(deviceName: String) async throws {
        // Rescan for MIDI devices
        conductor.scanForMIDIDevices()
        
        // Wait for scan to complete
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Try to reconnect to the device
        if let device = conductor.detectedDevices.first(where: { $0.name == deviceName }) {
            conductor.connectToDevice(device)
        } else {
            throw DrumTrainerError.audioDeviceNotFound(deviceName: deviceName)
        }
    }
    
    private func recoverCorruptedData(entity: String, id: String) async throws {
        switch entity.lowercased() {
        case "lesson":
            // Try to reload lesson from CloudKit
            try await cloudKitManager.fetchLesson(id: id)
            
        case "course":
            // Try to reload course from CloudKit
            try await cloudKitManager.fetchCourse(id: id)
            
        case "userprogress":
            // Reset user progress to last known good state
            try await resetUserProgress(id: id)
            
        default:
            // Generic data recovery - delete corrupted entity
            try coreDataManager.deleteEntity(entityName: entity, id: id)
        }
    }
    
    private func recoverLessonData(lessonId: String) async throws {
        // Try to fetch fresh lesson data from CloudKit
        do {
            try await cloudKitManager.fetchLesson(id: lessonId)
        } catch {
            // If CloudKit fails, try to regenerate from MIDI file
            if let lesson = coreDataManager.fetchLesson(by: lessonId),
               let midiURL = lesson.audioAssets?.backingTrackURL {
                try await regenerateLessonFromMIDI(lessonId: lessonId, midiURL: midiURL)
            } else {
                throw DrumTrainerError.invalidLessonData(lessonId: lessonId, reason: "Cannot recover lesson data")
            }
        }
    }
    
    private func recoverCloudKitSync() async throws {
        // Reset CloudKit sync state and retry
        cloudKitManager.resetSyncState()
        
        do {
            try await cloudKitManager.performFullSync()
        } catch {
            throw DrumTrainerError.cloudKitSyncFailure(underlying: error)
        }
    }
    
    private func recoverScoringEngine() async throws {
        // Reset scoring engine to default state
        conductor.resetScoring()
        
        // Reload scoring profile
        if let lesson = conductor.scoreEngine.currentLesson {
            let profile = lesson.scoringProfile?.toScoringProfile() ?? ScoringProfile.defaultProfile()
            conductor.scoreEngine.setScoringProfile(profile)
        }
    }
    
    private func resetUserProgress(id: String) async throws {
        // Implementation would reset user progress to last backup
        // This is a placeholder for the actual implementation
        print("Resetting user progress for ID: \(id)")
    }
    
    private func regenerateLessonFromMIDI(lessonId: String, midiURL: String) async throws {
        // Implementation would regenerate lesson data from MIDI file
        // This is a placeholder for the actual implementation
        print("Regenerating lesson \(lessonId) from MIDI: \(midiURL)")
    }
}

// MARK: - Data Integrity Checker

public class DataIntegrityChecker {
    private let coreDataManager: CoreDataManager
    
    public init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
    }
    
    public func performIntegrityCheck() async -> [DataIntegrityIssue] {
        var issues: [DataIntegrityIssue] = []
        
        // Check lessons
        issues.append(contentsOf: await checkLessonsIntegrity())
        
        // Check courses
        issues.append(contentsOf: await checkCoursesIntegrity())
        
        // Check user progress
        issues.append(contentsOf: await checkUserProgressIntegrity())
        
        // Check relationships
        issues.append(contentsOf: await checkRelationshipsIntegrity())
        
        return issues
    }
    
    private func checkLessonsIntegrity() async -> [DataIntegrityIssue] {
        var issues: [DataIntegrityIssue] = []
        
        let lessons = coreDataManager.fetchAllLessons()
        
        for lesson in lessons {
            do {
                try lesson.validate()
            } catch {
                issues.append(DataIntegrityIssue(
                    type: .validation,
                    entity: "Lesson",
                    entityId: lesson.id,
                    description: error.localizedDescription,
                    severity: .medium
                ))
            }
            
            // Check for missing steps
            if lesson.stepsArray.isEmpty {
                issues.append(DataIntegrityIssue(
                    type: .missingData,
                    entity: "Lesson",
                    entityId: lesson.id,
                    description: "Lesson has no steps",
                    severity: .high
                ))
            }
            
            // Check for invalid target events
            for step in lesson.stepsArray {
                if step.targetEvents.isEmpty {
                    issues.append(DataIntegrityIssue(
                        type: .missingData,
                        entity: "LessonStep",
                        entityId: step.id,
                        description: "Step has no target events",
                        severity: .medium
                    ))
                }
            }
        }
        
        return issues
    }
    
    private func checkCoursesIntegrity() async -> [DataIntegrityIssue] {
        var issues: [DataIntegrityIssue] = []
        
        let courses = coreDataManager.fetchAllCourses()
        
        for course in courses {
            do {
                try course.validate()
            } catch {
                issues.append(DataIntegrityIssue(
                    type: .validation,
                    entity: "Course",
                    entityId: course.id,
                    description: error.localizedDescription,
                    severity: .medium
                ))
            }
            
            // Check for orphaned courses (no lessons)
            if course.lessonsArray.isEmpty {
                issues.append(DataIntegrityIssue(
                    type: .missingData,
                    entity: "Course",
                    entityId: course.id,
                    description: "Course has no lessons",
                    severity: .low
                ))
            }
        }
        
        return issues
    }
    
    private func checkUserProgressIntegrity() async -> [DataIntegrityIssue] {
        var issues: [DataIntegrityIssue] = []
        
        let userProgress = coreDataManager.fetchUserProgress()
        
        // UserProgressData 没有 id 属性，使用默认标识符
        let progressId = "user_progress"
        
        // Check for negative values
        if userProgress.currentLevel < 0 {
            issues.append(DataIntegrityIssue(
                type: .invalidData,
                entity: "UserProgress",
                entityId: progressId,
                description: "Negative current level",
                severity: .medium
            ))
        }
        
        if userProgress.totalStars < 0 {
            issues.append(DataIntegrityIssue(
                type: .invalidData,
                entity: "UserProgress",
                entityId: progressId,
                description: "Negative total stars",
                severity: .medium
            ))
        }
        
        // Check for inconsistent streak data
        if userProgress.currentStreak > userProgress.maxStreak {
            issues.append(DataIntegrityIssue(
                type: .inconsistentData,
                entity: "UserProgress",
                entityId: progressId,
                description: "Current streak exceeds max streak",
                severity: .low
            ))
        }
        
        return issues
    }
    
    private func checkRelationshipsIntegrity() async -> [DataIntegrityIssue] {
        var issues: [DataIntegrityIssue] = []
        
        // Check for orphaned lesson steps
        let allSteps = coreDataManager.fetchAllLessonSteps()
        for step in allSteps {
            if step.lesson == nil {
                issues.append(DataIntegrityIssue(
                    type: .brokenRelationship,
                    entity: "LessonStep",
                    entityId: step.id,
                    description: "Step has no parent lesson",
                    severity: .high
                ))
            }
        }
        
        // Check for orphaned score results
        let allScoreResults = coreDataManager.fetchAllScoreResults()
        for result in allScoreResults {
            if result.lesson == nil {
                issues.append(DataIntegrityIssue(
                    type: .brokenRelationship,
                    entity: "ScoreResult",
                    entityId: result.id,
                    description: "Score result has no parent lesson",
                    severity: .medium
                ))
            }
        }
        
        return issues
    }
    
    public func repairIntegrityIssues(_ issues: [DataIntegrityIssue]) async throws {
        for issue in issues {
            try await repairIssue(issue)
        }
    }
    
    private func repairIssue(_ issue: DataIntegrityIssue) async throws {
        switch issue.type {
        case .validation:
            // Try to fix validation issues by resetting to default values
            try await repairValidationIssue(issue)
            
        case .missingData:
            // Try to restore missing data from defaults or CloudKit
            try await repairMissingData(issue)
            
        case .invalidData:
            // Fix invalid data by resetting to valid values
            try await repairInvalidData(issue)
            
        case .inconsistentData:
            // Fix inconsistent data by choosing the most logical value
            try await repairInconsistentData(issue)
            
        case .brokenRelationship:
            // Fix broken relationships by either restoring or removing orphaned entities
            try await repairBrokenRelationship(issue)
        }
    }
    
    private func repairValidationIssue(_ issue: DataIntegrityIssue) async throws {
        // Implementation would fix specific validation issues
        print("Repairing validation issue: \(issue.description)")
    }
    
    private func repairMissingData(_ issue: DataIntegrityIssue) async throws {
        // Implementation would restore missing data
        print("Repairing missing data: \(issue.description)")
    }
    
    private func repairInvalidData(_ issue: DataIntegrityIssue) async throws {
        // Implementation would fix invalid data
        print("Repairing invalid data: \(issue.description)")
    }
    
    private func repairInconsistentData(_ issue: DataIntegrityIssue) async throws {
        // Implementation would fix inconsistent data
        print("Repairing inconsistent data: \(issue.description)")
    }
    
    private func repairBrokenRelationship(_ issue: DataIntegrityIssue) async throws {
        // Implementation would fix broken relationships
        print("Repairing broken relationship: \(issue.description)")
    }
}

// MARK: - Data Integrity Issue Types

public struct DataIntegrityIssue {
    public let type: IssueType
    public let entity: String
    public let entityId: String
    public let description: String
    public let severity: ErrorSeverity
    
    public enum IssueType {
        case validation
        case missingData
        case invalidData
        case inconsistentData
        case brokenRelationship
    }
}

// MARK: - User-Friendly Error Presenter

public class ErrorPresenter: ObservableObject {
    @Published public var currentError: DrumTrainerError?
    @Published public var isShowingError: Bool = false
    @Published public var errorHistory: [ErrorLogEntry] = []
    
    private let recoveryManager: ErrorRecoveryManager
    
    public init(recoveryManager: ErrorRecoveryManager) {
        self.recoveryManager = recoveryManager
    }
    
    public func presentError(_ error: DrumTrainerError) {
        // Log the error
        let logEntry = ErrorLogEntry(
            error: error,
            timestamp: Date(),
            context: getCurrentContext()
        )
        errorHistory.append(logEntry)
        
        // Show error to user based on severity
        if error.severity.requiresUserAction {
            currentError = error
            isShowingError = true
        } else {
            // For low severity errors, just log them
            print("Low severity error: \(error.localizedDescription)")
        }
    }
    
    public func dismissError() {
        currentError = nil
        isShowingError = false
    }
    
    public func attemptRecovery() async {
        guard let error = currentError else { return }
        
        if recoveryManager.canRecover(from: error) {
            do {
                try await recoveryManager.recover(from: error)
                dismissError()
            } catch let recoveryError {
                // Recovery failed, present the recovery error
                if let drumTrainerError = recoveryError as? DrumTrainerError {
                    presentError(drumTrainerError)
                } else {
                    presentError(.scoringEngineFailure(reason: "Recovery failed: \(recoveryError.localizedDescription)"))
                }
            }
        }
    }
    
    private func getCurrentContext() -> String {
        // Return current app context (which screen, what operation, etc.)
        return "Unknown context" // Placeholder
    }
    
    public func exportErrorLog() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        
        var log = "Drum Trainer Error Log\n"
        log += "Generated: \(formatter.string(from: Date()))\n\n"
        
        for entry in errorHistory {
            log += "[\(formatter.string(from: entry.timestamp))] "
            log += "\(entry.error.severity.displayName): "
            log += "\(entry.error.localizedDescription)\n"
            log += "Context: \(entry.context)\n"
            if let suggestion = entry.error.recoverySuggestion {
                log += "Suggestion: \(suggestion)\n"
            }
            log += "\n"
        }
        
        return log
    }
}

public struct ErrorLogEntry {
    public let error: DrumTrainerError
    public let timestamp: Date
    public let context: String
}

// MARK: - Extensions for Core Data Manager

extension CoreDataManager {
    func deleteEntity(entityName: String, id: String) throws {
        // Implementation would delete the specified entity
        print("Deleting \(entityName) with ID: \(id)")
    }
    
    func fetchAllLessons() -> [Lesson] {
        // Implementation would fetch all lessons
        return []
    }
    
    func fetchAllCourses() -> [Course] {
        // Implementation would fetch all courses
        return []
    }
    
    func fetchAllLessonSteps() -> [LessonStep] {
        // Implementation would fetch all lesson steps
        return []
    }
    
    func fetchAllScoreResults() -> [ScoreResultEntity] {
        // Implementation would fetch all score results
        return []
    }
    
    func fetchUserProgress() -> UserProgressData {
        // 返回用户进度数据的默认实例
        // 使用 ProgressManager.swift 中定义的 UserProgressData（有默认参数）
        return UserProgressData()
    }
}

// MARK: - Extensions for CloudKit Manager

extension CloudKitSyncManager {
    func fetchLesson(id: String) async throws {
        // Implementation would fetch lesson from CloudKit
        print("Fetching lesson \(id) from CloudKit")
    }
    
    func fetchCourse(id: String) async throws {
        // Implementation would fetch course from CloudKit
        print("Fetching course \(id) from CloudKit")
    }
    
    func resetSyncState() {
        // 重置同步状态并清理定时器
        stopSync()
        Task { @MainActor in
            self.syncStatus = .notStarted
        }
    }
}

// MARK: - Extensions for Score Engine

extension ScoreEngine {
    var currentLesson: Lesson? {
        // Implementation would return current lesson
        return nil
    }
}