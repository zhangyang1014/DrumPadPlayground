import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings Import/Export View

struct SettingsImportExportView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var settingsManager = SettingsManager.shared
    
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var exportedSettingsURL: URL?
    @State private var importError: SettingsImportError?
    @State private var showingImportError = false
    @State private var importSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "gear.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Settings Backup")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Export your settings to backup or share with other devices")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Export Section
                VStack(spacing: 16) {
                    Text("Export Settings")
                        .font(.headline)
                    
                    Text("Create a backup file containing all your current settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Export Settings") {
                        exportSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Import Section
                VStack(spacing: 16) {
                    Text("Import Settings")
                        .font(.headline)
                    
                    Text("Restore settings from a previously exported backup file")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Import Settings") {
                        showingImportSheet = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Current Settings Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Settings")
                        .font(.headline)
                    
                    SettingsPreviewRow(title: "High Contrast Mode", value: settingsManager.highContrastMode ? "On" : "Off")
                    SettingsPreviewRow(title: "Streak Flash", value: settingsManager.streakFlashEnabled ? "On" : "Off")
                    SettingsPreviewRow(title: "Latency Compensation", value: "\(Int(settingsManager.audioLatencyCompensation))ms")
                    SettingsPreviewRow(title: "Daily Goal", value: "\(settingsManager.dailyGoalMinutes) minutes")
                    SettingsPreviewRow(title: "Metronome Volume", value: "\(Int(settingsManager.metronomeVolume * 100))%")
                    SettingsPreviewRow(title: "Metronome Sound", value: settingsManager.metronomeSound.capitalized)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Settings Backup")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportedSettingsURL {
                ActivityViewController(activityItems: [url])
            }
        }
        .fileImporter(
            isPresented: $showingImportSheet,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert("Import Error", isPresented: $showingImportError) {
            Button("OK") { }
        } message: {
            if let error = importError {
                Text(error.localizedDescription)
            }
        }
        .alert("Import Successful", isPresented: $importSuccess) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Settings have been successfully imported and applied.")
        }
    }
    
    // MARK: - Private Methods
    
    private func exportSettings() {
        let settingsExport = settingsManager.exportSettings()
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(settingsExport)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "DrumTrainer_Settings_\(DateFormatter.fileNameFormatter.string(from: Date())).json"
            let fileURL = documentsPath.appendingPathComponent(fileName)
            
            try data.write(to: fileURL)
            
            exportedSettingsURL = fileURL
            showingExportSheet = true
            
        } catch {
            print("Export error: \(error)")
        }
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importSettings(from: url)
            
        case .failure(let error):
            importError = .corruptedData
            showingImportError = true
            print("File selection error: \(error)")
        }
    }
    
    private func importSettings(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let settingsExport = try decoder.decode(SettingsExport.self, from: data)
            try settingsManager.importSettings(settingsExport)
            
            importSuccess = true
            
        } catch let error as SettingsImportError {
            importError = error
            showingImportError = true
        } catch {
            importError = .corruptedData
            showingImportError = true
            print("Import error: \(error)")
        }
    }
}

// MARK: - Settings Preview Row

struct SettingsPreviewRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Activity View Controller

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}

// MARK: - Preview

struct SettingsImportExportView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsImportExportView()
    }
}