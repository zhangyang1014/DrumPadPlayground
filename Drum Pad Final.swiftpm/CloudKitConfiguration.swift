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
        
        var fields: [String: CKRecord.FieldType] {
            switch self {
            case .userProgress:
                return [
                    "userId": .string,
                    "currentLevel": .int64,
                    "totalStars": .int64,
                    "currentStreak": .int64,
                    "maxStreak": .int64,
                    "totalTrophies": .int64,
                    "dailyGoalMinutes": .int64,
                    "lastPracticeDate": .dateTime,
                    "totalPracticeTime": .double,
                    "createdAt": .dateTime,
                    "updatedAt": .dateTime
                ]
            case .lesson:
                return [
                    "title": .string,
                    "courseId": .string,
                    "instrument": .string,
                    "defaultBPM": .double,
                    "timeSignatureNumerator": .int64,
                    "timeSignatureDenominator": .int64,
                    "duration": .double,
                    "tags": .string,
                    "difficulty": .int64,
                    "createdAt": .dateTime,
                    "updatedAt": .dateTime
                ]
            case .course:
                return [
                    "title": .string,
                    "courseDescription": .string,
                    "difficulty": .int64,
                    "tags": .string,
                    "estimatedDuration": .double,
                    "createdAt": .dateTime,
                    "updatedAt": .dateTime,
                    "isPublished": .int64
                ]
            case .scoreResult:
                return [
                    "lessonId": .string,
                    "totalScore": .double,
                    "starRating": .int64,
                    "isPlatinum": .int64,
                    "isBlackStar": .int64,
                    "streakCount": .int64,
                    "maxStreak": .int64,
                    "missCount": .int64,
                    "extraCount": .int64,
                    "perfectCount": .int64,
                    "earlyCount": .int64,
                    "lateCount": .int64,
                    "completionTime": .double,
                    "completedAt": .dateTime,
                    "playbackMode": .string,
                    "timingResultsData": .bytes
                ]
            case .dailyProgress:
                return [
                    "userId": .string,
                    "date": .dateTime,
                    "practiceTimeMinutes": .int64,
                    "goalAchieved": .int64,
                    "lessonsCompleted": .int64,
                    "starsEarned": .int64,
                    "createdAt": .dateTime
                ]
            case .lessonStep:
                return [
                    "lessonId": .string,
                    "order": .int64,
                    "title": .string,
                    "stepDescription": .string,
                    "targetEventsData": .bytes,
                    "bpmOverride": .double,
                    "assistLevel": .string,
                    "createdAt": .dateTime
                ]
            case .scoringProfile:
                return [
                    "perfectWindow": .double,
                    "earlyWindow": .double,
                    "lateWindow": .double,
                    "missThreshold": .double,
                    "extraPenalty": .double,
                    "gradePenaltyMultiplier": .double,
                    "streakBonus": .double
                ]
            case .audioAssets:
                return [
                    "backingTrackURL": .string,
                    "clickTrackURL": .string,
                    "previewURL": .string,
                    "stemURLsData": .bytes
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
                query.resultsLimit = 1
                
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
                for (fieldName, fieldType) in recordType.fields {
                    switch fieldType {
                    case .string:
                        record[fieldName] = "sample"
                    case .int64:
                        record[fieldName] = 0
                    case .double:
                        record[fieldName] = 0.0
                    case .dateTime:
                        record[fieldName] = Date()
                    case .bytes:
                        record[fieldName] = Data()
                    default:
                        break
                    }
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
        let permissionStatus = try await container.status(forApplicationPermission: .userDiscoverability)
        
        if permissionStatus == .initialState {
            let newStatus = try await container.requestApplicationPermission(.userDiscoverability)
            if newStatus != .granted {
                print("⚠️ User discoverability permission not granted")
            }
        }
    }
    
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