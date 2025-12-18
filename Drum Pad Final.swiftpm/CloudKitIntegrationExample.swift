import SwiftUI
import CloudKit

// MARK: - CloudKit Integration Example

/// This file demonstrates how to integrate CloudKit sync functionality
/// into the drum trainer application.

struct CloudKitIntegrationExample: View {
    @ObservedObject private var coreDataManager = CoreDataManager.shared
    @State private var showingSyncSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Sync Status Display
                CloudKitSyncStatusView()
                
                // Sample Data Operations
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sample Operations")
                        .font(.headline)
                    
                    Button("Create Sample Lesson") {
                        createSampleLesson()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Create Sample Score") {
                        createSampleScore()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Update User Progress") {
                        updateUserProgress()
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                // Detailed Status
                DetailedCloudKitStatusView()
            }
            .padding()
            .navigationTitle("CloudKit Integration")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        showingSyncSettings = true
                    }
                }
            }
            .sheet(isPresented: $showingSyncSettings) {
                NavigationView {
                    CloudKitSyncSettingsView()
                }
            }
        }
    }
    
    // MARK: - Sample Operations
    
    private func createSampleLesson() {
        let lesson = coreDataManager.createLesson(
            title: "Sample CloudKit Lesson",
            defaultBPM: 120.0,
            duration: 90.0,
            tags: ["sample", "cloudkit", "sync"],
            difficulty: 2
        )
        
        print("Created lesson: \(lesson.title) with ID: \(lesson.id)")
        
        // The save() method in CoreDataManager will automatically trigger CloudKit sync
    }
    
    private func createSampleScore() {
        // First, get or create a lesson
        let lessons = coreDataManager.fetchLessons()
        guard let lesson = lessons.first else {
            createSampleLesson()
            return
        }
        
        let scoreResult = ScoreResult(
            totalScore: 87.5,
            starRating: 3,
            isPlatinum: false,
            isBlackStar: false,
            timingResults: [],
            streakCount: 12,
            maxStreak: 15,
            missCount: 3,
            extraCount: 1,
            perfectCount: 25,
            earlyCount: 4,
            lateCount: 2,
            completionTime: 85.0
        )
        
        let scoreEntity = coreDataManager.saveScoreResult(scoreResult, for: lesson.id, mode: .performance)
        
        print("Created score result: \(scoreEntity.totalScore)% for lesson: \(lesson.title)")
    }
    
    private func updateUserProgress() {
        let userProgress = coreDataManager.getUserProgress(for: "demo_user")
        
        userProgress.currentLevel += 1
        userProgress.totalStars += 3
        userProgress.currentStreak += 1
        userProgress.maxStreak = max(userProgress.maxStreak, userProgress.currentStreak)
        userProgress.totalPracticeTime += 300 // 5 minutes
        userProgress.updatedAt = Date()
        
        coreDataManager.save()
        
        print("Updated user progress: Level \(userProgress.currentLevel), Stars: \(userProgress.totalStars)")
    }
}

// MARK: - CloudKit Setup Guide

struct CloudKitSetupGuide: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("CloudKit Setup Guide")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                setupSection(
                    title: "1. CloudKit Container Configuration",
                    content: """
                    The app is configured to use the CloudKit container:
                    'iCloud.com.drumtrainer.data'
                    
                    This container should be set up in your Apple Developer account
                    with the appropriate record types and fields.
                    """
                )
                
                setupSection(
                    title: "2. Core Data + CloudKit Integration",
                    content: """
                    The app uses NSPersistentCloudKitContainer to automatically
                    sync Core Data entities with CloudKit. The following entities
                    are synced:
                    
                    • UserProgress - User level, stars, streaks
                    • Lesson - Practice lessons and content
                    • Course - Lesson collections
                    • ScoreResult - Practice session results
                    • DailyProgress - Daily practice tracking
                    """
                )
                
                setupSection(
                    title: "3. Automatic Sync Features",
                    content: """
                    • Automatic background sync every 5 minutes
                    • Real-time conflict resolution
                    • Network status monitoring
                    • Account status checking
                    • Error handling and recovery
                    """
                )
                
                setupSection(
                    title: "4. User Experience",
                    content: """
                    • Sync status indicator in UI
                    • Manual sync trigger
                    • Offline mode support
                    • Data export/import capabilities
                    • Settings for sync preferences
                    """
                )
                
                setupSection(
                    title: "5. Privacy and Security",
                    content: """
                    • All data is stored in the user's private CloudKit database
                    • No data is shared between users
                    • User must be signed in to iCloud
                    • Respects iCloud storage quotas
                    """
                )
            }
            .padding()
        }
        .navigationTitle("Setup Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func setupSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - CloudKit Debugging View

struct CloudKitDebuggingView: View {
    @State private var debugOutput = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("CloudKit Debugging")
                .font(.headline)
            
            HStack {
                Button("Check Account") {
                    checkAccount()
                }
                .buttonStyle(.bordered)
                
                Button("Validate Schema") {
                    validateSchema()
                }
                .buttonStyle(.bordered)
                
                Button("Force Sync") {
                    forceSync()
                }
                .buttonStyle(.bordered)
            }
            
            if isLoading {
                SwiftUI.ProgressView("Processing...")
                    .padding()
            }
            
            ScrollView {
                Text(debugOutput)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private func checkAccount() {
        isLoading = true
        debugOutput = "Checking CloudKit account status...\n"
        
        Task {
            let status = await CoreDataManager.shared.checkCloudKitAccountStatus()
            
            await MainActor.run {
                debugOutput += "Account Status: \(status)\n"
                
                switch status {
                case .available:
                    debugOutput += "✅ CloudKit account is available\n"
                case .temporarilyUnavailable:
                    debugOutput += "⏳ iCloud temporarily unavailable\n"
                case .noAccount:
                    debugOutput += "❌ No iCloud account configured\n"
                case .restricted:
                    debugOutput += "⚠️ iCloud account is restricted\n"
                case .couldNotDetermine:
                    debugOutput += "❓ Could not determine account status\n"
                @unknown default:
                    debugOutput += "❓ Unknown account status\n"
                }
                
                isLoading = false
            }
        }
    }
    
    private func validateSchema() {
        isLoading = true
        debugOutput += "\nValidating CloudKit schema...\n"
        
        Task {
            do {
                try await CloudKitConfiguration.validateCloudKitSchema()
                await MainActor.run {
                    debugOutput += "✅ Schema validation completed successfully\n"
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    debugOutput += "❌ Schema validation failed: \(error.localizedDescription)\n"
                    isLoading = false
                }
            }
        }
    }
    
    private func forceSync() {
        isLoading = true
        debugOutput += "\nForcing CloudKit sync...\n"
        
        Task {
            do {
                try await CoreDataManager.shared.forceSyncNow()
                await MainActor.run {
                    debugOutput += "✅ Sync completed successfully\n"
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    debugOutput += "❌ Sync failed: \(error.localizedDescription)\n"
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CloudKitIntegrationExample_Previews: PreviewProvider {
    static var previews: some View {
        CloudKitIntegrationExample()
    }
}
#endif