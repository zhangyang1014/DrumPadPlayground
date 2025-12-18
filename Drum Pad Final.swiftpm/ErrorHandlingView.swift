import SwiftUI

// MARK: - Error Handling UI Components

/// User-friendly error presentation views
/// Provides clear error messages, recovery options, and user guidance

struct ErrorHandlingView: View {
    @ObservedObject var errorPresenter: ErrorPresenter
    @State private var isShowingErrorDetails = false
    @State private var isAttemptingRecovery = false
    
    var body: some View {
        ZStack {
            if errorPresenter.isShowingError, let error = errorPresenter.currentError {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Dismiss on background tap for low severity errors
                        if error.severity == .low {
                            errorPresenter.dismissError()
                        }
                    }
                
                ErrorAlertView(
                    error: error,
                    isShowingDetails: $isShowingErrorDetails,
                    isAttemptingRecovery: $isAttemptingRecovery,
                    onDismiss: {
                        errorPresenter.dismissError()
                    },
                    onRetry: {
                        Task {
                            isAttemptingRecovery = true
                            await errorPresenter.attemptRecovery()
                            isAttemptingRecovery = false
                        }
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: errorPresenter.isShowingError)
            }
        }
    }
}

struct ErrorAlertView: View {
    let error: DrumTrainerError
    @Binding var isShowingDetails: Bool
    @Binding var isAttemptingRecovery: Bool
    let onDismiss: () -> Void
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Error Icon and Severity
            HStack {
                Image(systemName: severityIcon)
                    .font(.title2)
                    .foregroundColor(severityColor)
                
                Text(error.severity.displayName)
                    .font(.headline)
                    .foregroundColor(severityColor)
                
                Spacer()
                
                Button(action: { isShowingDetails.toggle() }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
            }
            
            // Error Message
            VStack(alignment: .leading, spacing: 12) {
                Text("Something went wrong")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                if let suggestion = error.recoverySuggestion {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text(suggestion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            
            // Error Details (Expandable)
            if isShowingDetails {
                ErrorDetailsView(error: error)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                // Dismiss Button
                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                
                // Recovery Button (if available)
                if canAttemptRecovery {
                    Button(action: onRetry) {
                        HStack {
                            if isAttemptingRecovery {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isAttemptingRecovery ? "Recovering..." : "Try Again")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAttemptingRecovery)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 20)
        )
        .padding(.horizontal, 32)
        .animation(.easeInOut(duration: 0.2), value: isShowingDetails)
    }
    
    private var severityIcon: String {
        switch error.severity {
        case .low:
            return "info.circle"
        case .medium:
            return "exclamationmark.triangle"
        case .high:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "xmark.octagon.fill"
        }
    }
    
    private var severityColor: Color {
        switch error.severity {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .red
        }
    }
    
    private var canAttemptRecovery: Bool {
        // Check if this error type supports automatic recovery
        switch error {
        case .audioEngineFailure, .audioSessionInterrupted, .midiConnectionFailure,
             .dataCorruption, .invalidLessonData, .cloudKitSyncFailure, .scoringEngineFailure:
            return true
        default:
            return false
        }
    }
}

struct ErrorDetailsView: View {
    let error: DrumTrainerError
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Technical Details")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                DetailRow(label: "Error Type", value: errorType)
                DetailRow(label: "Severity", value: error.severity.displayName)
                DetailRow(label: "Timestamp", value: DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))
                
                if let additionalInfo = additionalErrorInfo {
                    DetailRow(label: "Details", value: additionalInfo)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
    
    private var errorType: String {
        switch error {
        case .audioEngineFailure:
            return "Audio Engine Failure"
        case .midiConnectionFailure:
            return "MIDI Connection Failure"
        case .audioLatencyTooHigh:
            return "High Audio Latency"
        case .dataCorruption:
            return "Data Corruption"
        case .syncConflict:
            return "Sync Conflict"
        case .invalidLessonData:
            return "Invalid Lesson Data"
        case .cloudKitSyncFailure:
            return "CloudKit Sync Failure"
        case .invalidMIDIFile:
            return "Invalid MIDI File"
        case .contentValidationFailure:
            return "Content Validation Failure"
        case .scoringEngineFailure:
            return "Scoring Engine Failure"
        case .memoryModeNotUnlocked:
            return "Memory Mode Not Unlocked"
        default:
            return "Unknown Error"
        }
    }
    
    private var additionalErrorInfo: String? {
        switch error {
        case .audioLatencyTooHigh(let latency):
            return "Latency: \(Int(latency * 1000))ms"
        case .midiConnectionFailure(let deviceName, _):
            return "Device: \(deviceName)"
        case .dataCorruption(let entity, let id):
            return "Entity: \(entity), ID: \(id)"
        case .invalidLessonData(let lessonId, let reason):
            return "Lesson: \(lessonId), Reason: \(reason)"
        case .memoryModeNotUnlocked(let lessonId):
            return "Lesson: \(lessonId)"
        default:
            return nil
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Error Toast View

struct ErrorToastView: View {
    let message: String
    let severity: ErrorSeverity
    @Binding var isShowing: Bool
    
    var body: some View {
        if isShowing {
            HStack(spacing: 12) {
                Image(systemName: toastIcon)
                    .foregroundColor(toastColor)
                
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Button(action: { isShowing = false }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .shadow(radius: 8)
            )
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                // Auto-dismiss after delay for low severity errors
                if severity == .low {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            isShowing = false
                        }
                    }
                }
            }
        }
    }
    
    private var toastIcon: String {
        switch severity {
        case .low:
            return "info.circle.fill"
        case .medium:
            return "exclamationmark.triangle.fill"
        case .high, .critical:
            return "xmark.circle.fill"
        }
    }
    
    private var toastColor: Color {
        switch severity {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high, .critical:
            return .red
        }
    }
}

// MARK: - Error Log View

struct ErrorLogView: View {
    @ObservedObject var errorPresenter: ErrorPresenter
    @State private var isShowingExportSheet = false
    @State private var exportedLog = ""
    
    var body: some View {
        NavigationView {
            List {
                if errorPresenter.errorHistory.isEmpty {
                    if #available(iOS 17, *) {
                        ContentUnavailableView(
                            "No Errors Logged",
                            systemImage: "checkmark.circle",
                            description: Text("Your app is running smoothly!")
                        )
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No Errors Logged")
                                .font(.headline)
                            Text("Your app is running smoothly!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                    }
                } else {
                    ForEach(errorPresenter.errorHistory.indices, id: \.self) { index in
                        let entry = errorPresenter.errorHistory[index]
                        ErrorLogEntryView(entry: entry)
                    }
                }
            }
            .navigationTitle("Error Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        exportedLog = errorPresenter.exportErrorLog()
                        isShowingExportSheet = true
                    }
                    .disabled(errorPresenter.errorHistory.isEmpty)
                }
            }
        }
        .sheet(isPresented: $isShowingExportSheet) {
            ErrorLogExportView(logContent: exportedLog)
        }
    }
}

struct ErrorLogEntryView: View {
    let entry: ErrorLogEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Severity indicator
                Circle()
                    .fill(severityColor)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(errorTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(DateFormatter.localizedString(from: entry.timestamp, dateStyle: .short, timeStyle: .short))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !entry.context.isEmpty {
                        Text("Context: \(entry.context)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let suggestion = entry.error.recoverySuggestion {
                        Text("Suggestion: \(suggestion)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.leading, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
    
    private var severityColor: Color {
        switch entry.error.severity {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .red
        }
    }
    
    private var errorTitle: String {
        switch entry.error {
        case .audioEngineFailure:
            return "Audio Engine Error"
        case .midiConnectionFailure(let deviceName, _):
            return "MIDI Connection Failed (\(deviceName))"
        case .audioLatencyTooHigh:
            return "High Audio Latency"
        case .dataCorruption:
            return "Data Corruption"
        case .syncConflict:
            return "Sync Conflict"
        case .invalidLessonData:
            return "Invalid Lesson Data"
        case .cloudKitSyncFailure:
            return "CloudKit Sync Failed"
        case .invalidMIDIFile:
            return "Invalid MIDI File"
        case .contentValidationFailure:
            return "Content Validation Failed"
        case .scoringEngineFailure:
            return "Scoring Engine Error"
        case .memoryModeNotUnlocked:
            return "Memory Mode Locked"
        default:
            return "Unknown Error"
        }
    }
}

struct ErrorLogExportView: View {
    let logContent: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(logContent)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Error Log Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: logContent) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct ErrorHandlingView_Previews: PreviewProvider {
    static var previews: some View {
        let mockRecoveryManager = ErrorRecoveryManager(
            conductor: Conductor(),
            coreDataManager: CoreDataManager(),
            cloudKitManager: CloudKitSyncManager()
        )
        let errorPresenter = ErrorPresenter(recoveryManager: mockRecoveryManager)
        
        // Simulate an error
        errorPresenter.presentError(.audioLatencyTooHigh(latency: 0.085))
        
        return ErrorHandlingView(errorPresenter: errorPresenter)
    }
}

struct ErrorToastView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ErrorToastView(
                message: "MIDI device disconnected",
                severity: .medium,
                isShowing: .constant(true)
            )
            
            Spacer()
        }
        .padding()
    }
}
#endif