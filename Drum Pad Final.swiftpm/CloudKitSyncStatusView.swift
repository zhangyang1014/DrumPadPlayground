import SwiftUI
import CloudKit
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - CloudKit Sync Status View

public struct CloudKitSyncStatusView: View {
    @ObservedObject private var coreDataManager = CoreDataManager.shared
    @State private var showingAccountAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var accountStatus: CKAccountStatus = .couldNotDetermine
    
    public var body: some View {
        HStack(spacing: 8) {
            // Sync status indicator
            syncStatusIcon
            
            // Status text
            Text(coreDataManager.syncStatus)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Action button
            if !coreDataManager.isCloudKitEnabled {
                Button("Enable iCloud") {
                    Task {
                        await enableCloudKit()
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            } else {
                Button("Sync Now") {
                    Task {
                        await forceSyncNow()
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .disabled(coreDataManager.syncStatus.contains("Syncing"))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .alert("iCloud Account Required", isPresented: $showingAccountAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please sign in to iCloud in Settings to enable data synchronization across your devices.")
        }
        .alert("Sync Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await checkAccountStatus()
        }
    }
    
    @ViewBuilder
    private var syncStatusIcon: some View {
        if coreDataManager.syncStatus.contains("Syncing") {
            ProgressView()
                .scaleEffect(0.7)
        } else if coreDataManager.isCloudKitEnabled {
            Image(systemName: "icloud.fill")
                .foregroundColor(.blue)
        } else {
            Image(systemName: "icloud.slash")
                .foregroundColor(.gray)
        }
    }
    
    private func enableCloudKit() async {
        do {
            let status = await coreDataManager.checkCloudKitAccountStatus()
            
            await MainActor.run {
                self.accountStatus = status
                
                switch status {
                case .available:
                    coreDataManager.enableCloudKitSync()
                case .noAccount, .restricted:
                    showingAccountAlert = true
                case .couldNotDetermine:
                    errorMessage = "Unable to determine iCloud account status. Please check your internet connection."
                    showingErrorAlert = true
                @unknown default:
                    errorMessage = "Unknown iCloud account status."
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func forceSyncNow() async {
        do {
            try await coreDataManager.forceSyncNow()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }
    
    private func checkAccountStatus() async {
        let status = await coreDataManager.checkCloudKitAccountStatus()
        await MainActor.run {
            self.accountStatus = status
        }
    }
}

// MARK: - Detailed CloudKit Status View

public struct DetailedCloudKitStatusView: View {
    @ObservedObject private var coreDataManager = CoreDataManager.shared
    @State private var accountStatus: CKAccountStatus = .couldNotDetermine
    @State private var lastSyncDate: Date?
    @State private var isLoading = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "icloud")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("iCloud Sync")
                    .font(.headline)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Account Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Account Status")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    accountStatusIcon
                    Text(accountStatusText)
                        .font(.body)
                    Spacer()
                }
            }
            
            // Sync Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Sync Status")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    syncStatusIcon
                    Text(coreDataManager.syncStatus)
                        .font(.body)
                    Spacer()
                }
            }
            
            // Last Sync
            if let lastSync = lastSyncDate {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Sync")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(lastSync, style: .relative)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            // Actions
            VStack(spacing: 12) {
                if coreDataManager.isCloudKitEnabled {
                    Button(action: {
                        Task {
                            await forceSyncNow()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Sync Now")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(coreDataManager.syncStatus.contains("Syncing"))
                    
                    Button(action: {
                        Task {
                            await resolveConflicts()
                        }
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                            Text("Resolve Conflicts")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: {
                        Task {
                            await enableCloudKit()
                        }
                    }) {
                        HStack {
                            Image(systemName: "icloud")
                            Text("Enable iCloud Sync")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .task {
            await loadSyncInfo()
        }
    }
    
    @ViewBuilder
    private var accountStatusIcon: some View {
        switch accountStatus {
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .noAccount:
            Image(systemName: "person.crop.circle.badge.xmark")
                .foregroundColor(.red)
        case .restricted:
            Image(systemName: "lock.circle.fill")
                .foregroundColor(.orange)
        case .couldNotDetermine:
            Image(systemName: "questionmark.circle.fill")
                .foregroundColor(.gray)
        @unknown default:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
        }
    }
    
    private var accountStatusText: String {
        switch accountStatus {
        case .available:
            return "Signed in to iCloud"
        case .noAccount:
            return "Not signed in to iCloud"
        case .restricted:
            return "iCloud account restricted"
        case .couldNotDetermine:
            return "Unable to determine status"
        @unknown default:
            return "Unknown status"
        }
    }
    
    @ViewBuilder
    private var syncStatusIcon: some View {
        if coreDataManager.syncStatus.contains("Syncing") {
            ProgressView()
                .scaleEffect(0.7)
        } else if coreDataManager.syncStatus.contains("Synced") {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else if coreDataManager.syncStatus.contains("error") {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
        } else {
            Image(systemName: "circle")
                .foregroundColor(.gray)
        }
    }
    
    private func loadSyncInfo() async {
        isLoading = true
        
        let status = await coreDataManager.checkCloudKitAccountStatus()
        
        await MainActor.run {
            self.accountStatus = status
            self.lastSyncDate = UserDefaults.standard.object(forKey: "lastCloudKitSync") as? Date
            self.isLoading = false
        }
    }
    
    private func enableCloudKit() async {
        isLoading = true
        
        let status = await coreDataManager.checkCloudKitAccountStatus()
        
        await MainActor.run {
            self.accountStatus = status
            
            if status == .available {
                coreDataManager.enableCloudKitSync()
            }
            
            self.isLoading = false
        }
    }
    
    private func forceSyncNow() async {
        isLoading = true
        
        do {
            try await coreDataManager.forceSyncNow()
            await MainActor.run {
                self.lastSyncDate = Date()
            }
        } catch {
            print("Sync error: \(error)")
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    private func resolveConflicts() async {
        isLoading = true
        
        do {
            try await coreDataManager.resolveCloudKitConflicts()
        } catch {
            print("Conflict resolution error: \(error)")
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
}

// MARK: - CloudKit Sync Settings View

public struct CloudKitSyncSettingsView: View {
    @ObservedObject private var coreDataManager = CoreDataManager.shared
    @State private var autoSyncEnabled = true
    @State private var syncOnCellular = false
    @State private var showingDataExport = false
    @State private var exportedData: [String: Any] = [:]
    
    public var body: some View {
        Form {
            Section("Sync Settings") {
                Toggle("Automatic Sync", isOn: $autoSyncEnabled)
                    .onChange(of: autoSyncEnabled) { enabled in
                        if enabled {
                            coreDataManager.enableCloudKitSync()
                        } else {
                            coreDataManager.disableCloudKitSync()
                        }
                    }
                
                Toggle("Sync on Cellular", isOn: $syncOnCellular)
                    .disabled(!autoSyncEnabled)
            }
            
            Section("Data Management") {
                Button("Export Data") {
                    exportData()
                }
                
                Button("Clear Local Cache") {
                    clearLocalCache()
                }
                .foregroundColor(.orange)
            }
            
            Section("Status") {
                DetailedCloudKitStatusView()
            }
        }
        .navigationTitle("iCloud Sync")
        .sheet(isPresented: $showingDataExport) {
            CloudKitDataExportView(data: exportedData)
        }
    }
    
    private func exportData() {
        exportedData = coreDataManager.exportUserData()
        showingDataExport = true
    }
    
    private func clearLocalCache() {
        // Implementation for clearing local cache
        // This would remove local copies while keeping CloudKit data
    }
}

// MARK: - Data Export View

private struct CloudKitDataExportView: View {
    let data: [String: Any]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Exported Data")
                        .font(.headline)
                    
                    ForEach(Array(data.keys.sorted()), id: \.self) { key in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(key.capitalized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let arrayData = data[key] as? [Any] {
                                Text("\(arrayData.count) items")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Data Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CloudKitSyncStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CloudKitSyncStatusView()
            
            DetailedCloudKitStatusView()
        }
        .padding()
    }
}
#endif