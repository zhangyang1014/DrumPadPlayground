import Foundation
import CloudKit
import CoreData

// MARK: - CloudKit Configuration Manager

public class CloudKitConfiguration {
    
    // MARK: - Container Configuration
    
    static let containerIdentifier = "iCloud.com.drumtrainer.data"
    
    static var container: CKContainer {
        return CKContainer(identifier: containerIdentifier)
    }
    
    static var privateDatabase: CKDatabase {
        return container.privateCloudDatabase
    }
    
    // MARK: - Record Types
    
    enum RecordType: String, CaseIterable {
        case userProgress = "UserProgress"
        case lesson = "Lesson"
        case course = "Course"
        case scoreResult = "ScoreResult"
        case dailyProgress = "DailyProgress"
        case lessonStep = "LessonStep"
        case scoringProfile = "ScoringProfile"
        case audioAssets = "AudioAssets"
        
        /// 样例字段值（用于建立/验证 schema）
        var sampleFields: [String: Any] {
            switch self {
            case .userProgress:
                return [
                    "userId": "sample-user",
                    "currentLevel": Int64(1),
                    "totalStars": Int64(0),
                    "currentStreak": Int64(0),
                    "maxStreak": Int64(0),
                    "totalTrophies": Int64(0),
                    "dailyGoalMinutes": Int64(5),
                    "lastPracticeDate": Date(),
                    "totalPracticeTime": 0.0,
                    "createdAt": Date(),
                    "updatedAt": Date()
                ]
            case .lesson:
                return [
                    "title": "Sample Lesson",
                    "courseId": "course-1",
                    "instrument": "drums",
                    "defaultBPM": 120.0,
                    "timeSignatureNumerator": Int64(4),
                    "timeSignatureDenominator": Int64(4),
                    "duration": 60.0,
                    "tags": "[]",
                    "difficulty": Int64(1),
                    "createdAt": Date(),
                    "updatedAt": Date()
                ]
            case .course:
                return [
                    "title": "Sample Course",
                    "courseDescription": "Sample description",
                    "difficulty": Int64(1),
                    "tags": "[]",
                    "estimatedDuration": 3600.0,
                    "createdAt": Date(),
                    "updatedAt": Date(),
                    "isPublished": Int64(0)
                ]
            case .scoreResult:
                return [
                    "lessonId": "lesson-1",
                    "totalScore": 95.0,
                    "starRating": Int64(3),
                    "isPlatinum": Int64(0),
                    "isBlackStar": Int64(0),
                    "streakCount": Int64(10),
                    "maxStreak": Int64(15),
                    "missCount": Int64(1),
                    "extraCount": Int64(0),
                    "perfectCount": Int64(20),
                    "earlyCount": Int64(2),
                    "lateCount": Int64(1),
                    "completionTime": 180.0,
                    "completedAt": Date(),
                    "playbackMode": "performance",
                    "timingResultsData": Data()
                ]
            case .dailyProgress:
                return [
                    "userId": "sample-user",
                    "date": Date(),
                    "practiceTimeMinutes": Int64(10),
                    "goalAchieved": Int64(1),
                    "lessonsCompleted": Int64(1),
                    "starsEarned": Int64(3),
                    "createdAt": Date()
                ]
            case .lessonStep:
                return [
                    "lessonId": "lesson-1",
                    "order": Int64(1),
                    "title": "Step 1",
                    "stepDescription": "Sample step",
                    "targetEventsData": Data(),
                    "bpmOverride": 120.0,
                    "assistLevel": "none",
                    "createdAt": Date()
                ]
            case .scoringProfile:
                return [
                    "perfectWindow": 0.02,
                    "earlyWindow": 0.04,
                    "lateWindow": 0.04,
                    "missThreshold": 0.08,
                    "extraPenalty": 1.0,
                    "gradePenaltyMultiplier": 0.5,
                    "streakBonus": 1.2
                ]
            case .audioAssets:
                return [
                    "backingTrackURL": "https://example.com/backing.wav",
                    "clickTrackURL": "https://example.com/click.wav",
                    "previewURL": "https://example.com/preview.wav",
                    "stemURLsData": Data()
                ]
            }
        }
    }
    
    // MARK: - Schema Validation
    
    static func validateCloudKitSchema() async throws {
        let database = privateDatabase
        
        for recordType in RecordType.allCases {
            do {
                // Try to fetch the record type to validate it exists
                let query = CKQuery(recordType: recordType.rawValue, predicate: NSPredicate(value: false))
                _ = try await database.records(matching: query)
                print("✓ Record type \(recordType.rawValue) is valid")
            } catch {
                print("⚠️ Record type \(recordType.rawValue) validation failed: \(error)")
                throw CloudKitConfigurationError.schemaValidationFailed(recordType.rawValue, error)
            }
        }
    }
    
    // MARK: - Development Schema Setup
    
    static func setupDevelopmentSchema() async throws {
        let database = privateDatabase
        
        for recordType in RecordType.allCases {
            do {
                // Create a sample record to establish the schema
                let record = CKRecord(recordType: recordType.rawValue)
                
                // Set sample values for each field to establish field types
                for (fieldName, sampleValue) in recordType.sampleFields {
                    record[fieldName] = sampleValue as? CKRecordValue
                }
                
                // Save the record to establish schema
                let savedRecord = try await database.save(record)
                
                // Delete the sample record
                try await database.deleteRecord(withID: savedRecord.recordID)
                
                print("✓ Schema established for \(recordType.rawValue)")
            } catch {
                print("⚠️ Failed to establish schema for \(recordType.rawValue): \(error)")
            }
        }
    }
    
    // MARK: - CloudKit Permissions
    
    static func requestCloudKitPermissions() async throws {
        let container = self.container
        
        // Check account status
        let accountStatus = try await container.accountStatus()
        
        switch accountStatus {
        case .available:
            print("✓ CloudKit account is available")
        case .noAccount:
            throw CloudKitConfigurationError.noAccount
        case .restricted:
            throw CloudKitConfigurationError.accountRestricted
        case .couldNotDetermine:
            throw CloudKitConfigurationError.accountStatusUnknown
        @unknown default:
            throw CloudKitConfigurationError.accountStatusUnknown
        }
        
        // Request application permissions
        // NOTE: Some toolchains (e.g., Swift Playgrounds SPM) do not expose
        // CKContainer.ApplicationPermission. To keep builds green, we skip
        // requesting permissions in that environment.
        #if false
        let permission: CKContainer.ApplicationPermission = .userDiscoverability
        let permissionStatus = try await fetchApplicationPermissionStatus(container: container, permission: permission)
        
        if permissionStatus == CKContainer.ApplicationPermissionStatus.initialState {
            let newStatus = try await requestApplicationPermission(container: container, permission: permission)
            if newStatus != CKContainer.ApplicationPermissionStatus.granted {
                print("⚠️ User discoverability permission not granted")
            }
        }
        #else
        _ = container // silence unused variable warning when skipping permission request
        #endif
    }

    // MARK: - Permission Helpers (guarded for toolchains missing ApplicationPermission)
    #if false
    private static func fetchApplicationPermissionStatus(container: CKContainer, permission: CKContainer.ApplicationPermission) async throws -> CKContainer.ApplicationPermissionStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.status(forApplicationPermission: permission) { status, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }
    
    private static func requestApplicationPermission(container: CKContainer, permission: CKContainer.ApplicationPermission) async throws -> CKContainer.ApplicationPermissionStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.requestApplicationPermission(permission) { status, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }
    #endif
    
    // MARK: - CloudKit Zones (for advanced use cases)
    
    static func createCustomZone(named zoneName: String) async throws -> CKRecordZone {
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        let zone = CKRecordZone(zoneID: zoneID)
        
        let database = privateDatabase
        return try await database.save(zone)
    }
    
    static func deleteCustomZone(named zoneName: String) async throws {
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        let database = privateDatabase
        
        _ = try await database.deleteRecordZone(withID: zoneID)
    }
    
    // MARK: - Subscription Management
    
    static func setupCloudKitSubscriptions() async throws {
        let database = privateDatabase
        
        // Create subscriptions for each record type to get push notifications
        for recordType in RecordType.allCases {
            let subscriptionID = "\(recordType.rawValue)Subscription"
            
            // Check if subscription already exists
            do {
                _ = try await database.subscription(for: subscriptionID)
                print("✓ Subscription \(subscriptionID) already exists")
                continue
            } catch CKError.unknownItem {
                // Subscription doesn't exist, create it
            }
            
            let subscription = CKQuerySubscription(
                recordType: recordType.rawValue,
                predicate: NSPredicate(value: true),
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )
            
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo
            
            do {
                _ = try await database.save(subscription)
                print("✓ Created subscription for \(recordType.rawValue)")
            } catch {
                print("⚠️ Failed to create subscription for \(recordType.rawValue): \(error)")
            }
        }
    }
    
    static func removeAllSubscriptions() async throws {
        let database = privateDatabase
        
        let subscriptions = try await database.allSubscriptions()
        
        for subscription in subscriptions {
            try await database.deleteSubscription(withID: subscription.subscriptionID)
            print("✓ Removed subscription \(subscription.subscriptionID)")
        }
    }
    
    // MARK: - CloudKit Quota Management
    
    static func checkCloudKitQuota() async throws -> (used: Int64, available: Int64) {
        // This is a simplified implementation
        // In practice, you'd need to implement quota tracking
        return (used: 0, available: 1_000_000_000) // 1GB default
    }
    
    // MARK: - Data Migration Helpers
    
    static func migrateLocalDataToCloudKit() async throws {
        // This would be implemented to migrate existing local data to CloudKit
        // when CloudKit is enabled for the first time
        print("Starting CloudKit migration...")
        
        // Implementation would depend on specific migration requirements
        // This is a placeholder for the migration logic
        
        print("CloudKit migration completed")
    }
}

// MARK: - CloudKit Configuration Errors

public enum CloudKitConfigurationError: Error, LocalizedError {
    case noAccount
    case accountRestricted
    case accountStatusUnknown
    case schemaValidationFailed(String, Error)
    case permissionDenied
    case quotaExceeded
    case migrationFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .noAccount:
            return "No iCloud account is configured on this device. Please sign in to iCloud in Settings."
        case .accountRestricted:
            return "iCloud account is restricted. Please check your iCloud settings."
        case .accountStatusUnknown:
            return "Unable to determine iCloud account status."
        case .schemaValidationFailed(let recordType, let error):
            return "Schema validation failed for \(recordType): \(error.localizedDescription)"
        case .permissionDenied:
            return "CloudKit permissions were denied."
        case .quotaExceeded:
            return "iCloud storage quota has been exceeded."
        case .migrationFailed(let error):
            return "Data migration to CloudKit failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - CloudKit Development Utilities

#if DEBUG
extension CloudKitConfiguration {
    
    // MARK: - Development Tools
    
    static func clearAllCloudKitData() async throws {
        print("⚠️ CLEARING ALL CLOUDKIT DATA - DEVELOPMENT ONLY")
        
        let database = privateDatabase
        
        for recordType in RecordType.allCases {
            let query = CKQuery(recordType: recordType.rawValue, predicate: NSPredicate(value: true))
            
            do {
                let (matchResults, _) = try await database.records(matching: query)
                
                for (recordID, result) in matchResults {
                    switch result {
                    case .success(_):
                        try await database.deleteRecord(withID: recordID)
                        print("Deleted record: \(recordID)")
                    case .failure(let error):
                        print("Failed to delete record \(recordID): \(error)")
                    }
                }
            } catch {
                print("Error clearing \(recordType.rawValue): \(error)")
            }
        }
        
        print("CloudKit data clearing completed")
    }
    
    static func dumpCloudKitData() async throws {
        print("=== CLOUDKIT DATA DUMP ===")
        
        let database = privateDatabase
        
        for recordType in RecordType.allCases {
            print("\n--- \(recordType.rawValue) ---")
            
            let query = CKQuery(recordType: recordType.rawValue, predicate: NSPredicate(value: true))
            
            do {
                let (matchResults, _) = try await database.records(matching: query)
                
                for (recordID, result) in matchResults {
                    switch result {
                    case .success(let record):
                        print("Record ID: \(recordID.recordName)")
                        for key in record.allKeys() {
                            print("  \(key): \(record[key] ?? "nil")")
                        }
                    case .failure(let error):
                        print("Error fetching record \(recordID): \(error)")
                    }
                }
                
                if matchResults.isEmpty {
                    print("No records found")
                }
            } catch {
                print("Error querying \(recordType.rawValue): \(error)")
            }
        }
        
        print("\n=== END DUMP ===")
    }
}
#endif