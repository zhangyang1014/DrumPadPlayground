import Foundation
import SwiftUI
import AVFoundation
import Combine

// MARK: - Settings Manager

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // MARK: - Published Properties
    
    @Published var highContrastMode: Bool {
        didSet {
            UserDefaults.standard.set(highContrastMode, forKey: "highContrastMode")
            applyHighContrastMode()
        }
    }
    
    @Published var streakFlashEnabled: Bool {
        didSet {
            UserDefaults.standard.set(streakFlashEnabled, forKey: "streakFlashEnabled")
        }
    }
    
    @Published var audioLatencyCompensation: Double {
        didSet {
            UserDefaults.standard.set(audioLatencyCompensation, forKey: "audioLatencyCompensation")
            applyLatencyCompensation()
        }
    }
    
    @Published var selectedAudioDevice: String {
        didSet {
            UserDefaults.standard.set(selectedAudioDevice, forKey: "selectedAudioDevice")
            selectAudioDevice(selectedAudioDevice)
        }
    }
    
    @Published var dailyGoalMinutes: Int {
        didSet {
            UserDefaults.standard.set(dailyGoalMinutes, forKey: "dailyGoalMinutes")
        }
    }
    
    @Published var metronomeVolume: Double {
        didSet {
            UserDefaults.standard.set(metronomeVolume, forKey: "metronomeVolume")
        }
    }
    
    @Published var metronomeSound: String {
        didSet {
            UserDefaults.standard.set(metronomeSound, forKey: "metronomeSound")
        }
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        // Load settings from UserDefaults
        self.highContrastMode = UserDefaults.standard.bool(forKey: "highContrastMode")
        self.streakFlashEnabled = UserDefaults.standard.object(forKey: "streakFlashEnabled") as? Bool ?? true
        self.audioLatencyCompensation = UserDefaults.standard.double(forKey: "audioLatencyCompensation")
        self.selectedAudioDevice = UserDefaults.standard.string(forKey: "selectedAudioDevice") ?? ""
        self.dailyGoalMinutes = UserDefaults.standard.object(forKey: "dailyGoalMinutes") as? Int ?? 5
        self.metronomeVolume = UserDefaults.standard.object(forKey: "metronomeVolume") as? Double ?? 0.7
        self.metronomeSound = UserDefaults.standard.string(forKey: "metronomeSound") ?? "click"
        
        // Apply initial settings
        applyHighContrastMode()
        applyLatencyCompensation()
    }
    
    // MARK: - Settings Application
    
    private func applyHighContrastMode() {
        NotificationCenter.default.post(
            name: .highContrastModeChanged,
            object: highContrastMode
        )
    }
    
    private func selectAudioDevice(_ deviceId: String) {
        AudioDeviceManager.shared.selectDevice(deviceId)
    }
    
    private func applyLatencyCompensation() {
        AudioLatencyManager.shared.setCompensation(audioLatencyCompensation)
    }
    
    // MARK: - Validation
    
    func validateSettings() -> [SettingsValidationError] {
        var errors: [SettingsValidationError] = []
        
        if dailyGoalMinutes < 1 || dailyGoalMinutes > 120 {
            errors.append(.invalidDailyGoal)
        }
        
        if audioLatencyCompensation < -100 || audioLatencyCompensation > 100 {
            errors.append(.invalidLatencyCompensation)
        }
        
        if metronomeVolume < 0 || metronomeVolume > 1 {
            errors.append(.invalidMetronomeVolume)
        }
        
        return errors
    }
    
    // MARK: - Reset Settings
    
    func resetToDefaults() {
        highContrastMode = false
        streakFlashEnabled = true
        audioLatencyCompensation = 0.0
        selectedAudioDevice = ""
        dailyGoalMinutes = 5
        metronomeVolume = 0.7
        metronomeSound = "click"
    }
    
    // MARK: - Export/Import Settings
    
    func exportSettings() -> SettingsExport {
        return SettingsExport(
            highContrastMode: highContrastMode,
            streakFlashEnabled: streakFlashEnabled,
            audioLatencyCompensation: audioLatencyCompensation,
            selectedAudioDevice: selectedAudioDevice,
            dailyGoalMinutes: dailyGoalMinutes,
            metronomeVolume: metronomeVolume,
            metronomeSound: metronomeSound,
            exportDate: Date()
        )
    }
    
    func importSettings(_ settingsExport: SettingsExport) throws {
        // Validate imported settings
        let tempManager = SettingsManager()
        tempManager.highContrastMode = settingsExport.highContrastMode
        tempManager.streakFlashEnabled = settingsExport.streakFlashEnabled
        tempManager.audioLatencyCompensation = settingsExport.audioLatencyCompensation
        tempManager.selectedAudioDevice = settingsExport.selectedAudioDevice
        tempManager.dailyGoalMinutes = settingsExport.dailyGoalMinutes
        tempManager.metronomeVolume = settingsExport.metronomeVolume
        tempManager.metronomeSound = settingsExport.metronomeSound
        
        let validationErrors = tempManager.validateSettings()
        if !validationErrors.isEmpty {
            throw SettingsImportError.validationFailed(validationErrors)
        }
        
        // Apply validated settings
        self.highContrastMode = settingsExport.highContrastMode
        self.streakFlashEnabled = settingsExport.streakFlashEnabled
        self.audioLatencyCompensation = settingsExport.audioLatencyCompensation
        self.selectedAudioDevice = settingsExport.selectedAudioDevice
        self.dailyGoalMinutes = settingsExport.dailyGoalMinutes
        self.metronomeVolume = settingsExport.metronomeVolume
        self.metronomeSound = settingsExport.metronomeSound
    }
}

// MARK: - Settings Models

struct SettingsExport: Codable {
    let highContrastMode: Bool
    let streakFlashEnabled: Bool
    let audioLatencyCompensation: Double
    let selectedAudioDevice: String
    let dailyGoalMinutes: Int
    let metronomeVolume: Double
    let metronomeSound: String
    let exportDate: Date
}

enum SettingsValidationError: Error, LocalizedError {
    case invalidDailyGoal
    case invalidLatencyCompensation
    case invalidMetronomeVolume
    case invalidAudioDevice
    
    var errorDescription: String? {
        switch self {
        case .invalidDailyGoal:
            return "Daily goal must be between 1 and 120 minutes"
        case .invalidLatencyCompensation:
            return "Latency compensation must be between -100ms and +100ms"
        case .invalidMetronomeVolume:
            return "Metronome volume must be between 0% and 100%"
        case .invalidAudioDevice:
            return "Selected audio device is not available"
        }
    }
}

enum SettingsImportError: Error, LocalizedError {
    case validationFailed([SettingsValidationError])
    case corruptedData
    case incompatibleVersion
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let errors):
            return "Settings validation failed: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        case .corruptedData:
            return "Settings data is corrupted or invalid"
        case .incompatibleVersion:
            return "Settings were exported from an incompatible version"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let highContrastModeChanged = Notification.Name("highContrastModeChanged")
    static let latencyCompensationChanged = Notification.Name("latencyCompensationChanged")
    static let audioDeviceChanged = Notification.Name("audioDeviceChanged")
    static let metronomeSettingsChanged = Notification.Name("metronomeSettingsChanged")
}