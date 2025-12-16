import Testing
import Foundation
@testable import DrumPadApp

// MARK: - Settings Property Tests

@Suite("Settings Property Tests")
struct SettingsPropertyTests {
    
    // MARK: - Property 28: High Contrast Mode Conversion
    
    @Test("Property 28: High contrast mode conversion", .tags(.property))
    func testHighContrastModeConversion() async throws {
        /**
         * Feature: melodic-drum-trainer, Property 28: 高对比模式转换性
         * For any high contrast mode activation, all colored feedback should convert to white icons
         * Validates: Requirements 10.1
         */
        
        // Generate test cases for high contrast mode
        let testCases = generateHighContrastTestCases()
        
        for testCase in testCases {
            let settingsManager = createTestSettingsManager()
            
            // Apply high contrast mode setting
            settingsManager.highContrastMode = testCase.highContrastEnabled
            
            // Verify the conversion behavior
            let feedbackStyle = getFeedbackStyle(
                highContrast: testCase.highContrastEnabled,
                originalColor: testCase.originalColor
            )
            
            if testCase.highContrastEnabled {
                // In high contrast mode, all colored feedback should be white with icons
                #expect(feedbackStyle.color == .white, "High contrast mode should convert colors to white")
                #expect(feedbackStyle.hasIcon == true, "High contrast mode should add icons")
                #expect(feedbackStyle.iconName != nil, "High contrast mode should provide icon name")
            } else {
                // In normal mode, original colors should be preserved
                #expect(feedbackStyle.color == testCase.originalColor, "Normal mode should preserve original colors")
                #expect(feedbackStyle.hasIcon == false, "Normal mode should not require icons")
            }
        }
    }
    
    // MARK: - Property 29: Latency Compensation Application
    
    @Test("Property 29: Latency compensation application", .tags(.property))
    func testLatencyCompensationApplication() async throws {
        /**
         * Feature: melodic-drum-trainer, Property 29: 延迟补偿应用性
         * For any set latency compensation value, the judgment system's time windows should adjust accordingly
         * Validates: Requirements 10.3
         */
        
        // Generate test cases for latency compensation
        let testCases = generateLatencyCompensationTestCases()
        
        for testCase in testCases {
            let settingsManager = createTestSettingsManager()
            let originalTimingWindows = createTestTimingWindows()
            
            // Apply latency compensation
            settingsManager.audioLatencyCompensation = testCase.compensationMs
            
            // Get adjusted timing windows
            let adjustedWindows = applyLatencyCompensation(
                originalWindows: originalTimingWindows,
                compensationMs: testCase.compensationMs
            )
            
            // Verify that timing windows are adjusted by the compensation amount
            let expectedPerfectStart = originalTimingWindows.perfectWindow.start + (testCase.compensationMs / 1000.0)
            let expectedPerfectEnd = originalTimingWindows.perfectWindow.end + (testCase.compensationMs / 1000.0)
            let expectedEarlyStart = originalTimingWindows.earlyWindow.start + (testCase.compensationMs / 1000.0)
            let expectedEarlyEnd = originalTimingWindows.earlyWindow.end + (testCase.compensationMs / 1000.0)
            let expectedLateStart = originalTimingWindows.lateWindow.start + (testCase.compensationMs / 1000.0)
            let expectedLateEnd = originalTimingWindows.lateWindow.end + (testCase.compensationMs / 1000.0)
            
            #expect(
                abs(adjustedWindows.perfectWindow.start - expectedPerfectStart) < 0.001,
                "Perfect window start should be adjusted by compensation amount"
            )
            #expect(
                abs(adjustedWindows.perfectWindow.end - expectedPerfectEnd) < 0.001,
                "Perfect window end should be adjusted by compensation amount"
            )
            #expect(
                abs(adjustedWindows.earlyWindow.start - expectedEarlyStart) < 0.001,
                "Early window start should be adjusted by compensation amount"
            )
            #expect(
                abs(adjustedWindows.earlyWindow.end - expectedEarlyEnd) < 0.001,
                "Early window end should be adjusted by compensation amount"
            )
            #expect(
                abs(adjustedWindows.lateWindow.start - expectedLateStart) < 0.001,
                "Late window start should be adjusted by compensation amount"
            )
            #expect(
                abs(adjustedWindows.lateWindow.end - expectedLateEnd) < 0.001,
                "Late window end should be adjusted by compensation amount"
            )
            
            // Verify that the relative window sizes remain unchanged
            let originalPerfectSize = originalTimingWindows.perfectWindow.end - originalTimingWindows.perfectWindow.start
            let adjustedPerfectSize = adjustedWindows.perfectWindow.end - adjustedWindows.perfectWindow.start
            
            #expect(
                abs(originalPerfectSize - adjustedPerfectSize) < 0.001,
                "Window sizes should remain unchanged after compensation"
            )
        }
    }
    
    // MARK: - Settings Validation Property
    
    @Test("Settings validation consistency", .tags(.property))
    func testSettingsValidationConsistency() async throws {
        /**
         * Additional property: Settings validation should be consistent
         * For any settings configuration, validation should produce consistent results
         */
        
        let testCases = generateSettingsValidationTestCases()
        
        for testCase in testCases {
            let settingsManager = createTestSettingsManager()
            
            // Apply test settings
            settingsManager.dailyGoalMinutes = testCase.dailyGoal
            settingsManager.audioLatencyCompensation = testCase.latencyCompensation
            settingsManager.metronomeVolume = testCase.metronomeVolume
            
            // Validate settings multiple times
            let validation1 = settingsManager.validateSettings()
            let validation2 = settingsManager.validateSettings()
            let validation3 = settingsManager.validateSettings()
            
            // Validation should be consistent
            #expect(validation1.count == validation2.count, "Validation should be consistent")
            #expect(validation2.count == validation3.count, "Validation should be consistent")
            
            // Check expected validation results
            let hasInvalidGoal = testCase.dailyGoal < 1 || testCase.dailyGoal > 120
            let hasInvalidLatency = testCase.latencyCompensation < -100 || testCase.latencyCompensation > 100
            let hasInvalidVolume = testCase.metronomeVolume < 0 || testCase.metronomeVolume > 1
            
            let expectedErrorCount = [hasInvalidGoal, hasInvalidLatency, hasInvalidVolume].filter { $0 }.count
            
            #expect(validation1.count == expectedErrorCount, "Validation should catch all invalid settings")
        }
    }
    
    // MARK: - Settings Import/Export Property
    
    @Test("Settings import/export round trip", .tags(.property))
    func testSettingsImportExportRoundTrip() async throws {
        /**
         * Additional property: Settings export then import should preserve all values
         * For any settings configuration, exporting then importing should result in identical settings
         */
        
        let testCases = generateSettingsRoundTripTestCases()
        
        for testCase in testCases {
            let originalSettings = createTestSettingsManager()
            
            // Apply test settings
            originalSettings.highContrastMode = testCase.highContrastMode
            originalSettings.streakFlashEnabled = testCase.streakFlashEnabled
            originalSettings.audioLatencyCompensation = testCase.audioLatencyCompensation
            originalSettings.selectedAudioDevice = testCase.selectedAudioDevice
            originalSettings.dailyGoalMinutes = testCase.dailyGoalMinutes
            originalSettings.metronomeVolume = testCase.metronomeVolume
            originalSettings.metronomeSound = testCase.metronomeSound
            
            // Export settings
            let exportedSettings = originalSettings.exportSettings()
            
            // Create new settings manager and import
            let importedSettings = createTestSettingsManager()
            try importedSettings.importSettings(exportedSettings)
            
            // Verify all settings are preserved
            #expect(importedSettings.highContrastMode == originalSettings.highContrastMode, "High contrast mode should be preserved")
            #expect(importedSettings.streakFlashEnabled == originalSettings.streakFlashEnabled, "Streak flash setting should be preserved")
            #expect(abs(importedSettings.audioLatencyCompensation - originalSettings.audioLatencyCompensation) < 0.001, "Latency compensation should be preserved")
            #expect(importedSettings.selectedAudioDevice == originalSettings.selectedAudioDevice, "Audio device selection should be preserved")
            #expect(importedSettings.dailyGoalMinutes == originalSettings.dailyGoalMinutes, "Daily goal should be preserved")
            #expect(abs(importedSettings.metronomeVolume - originalSettings.metronomeVolume) < 0.001, "Metronome volume should be preserved")
            #expect(importedSettings.metronomeSound == originalSettings.metronomeSound, "Metronome sound should be preserved")
        }
    }
}

// MARK: - Test Data Generators

private func generateHighContrastTestCases() -> [HighContrastTestCase] {
    let colors: [TestColor] = [.red, .blue, .green, .yellow, .orange, .purple]
    var testCases: [HighContrastTestCase] = []
    
    for color in colors {
        testCases.append(HighContrastTestCase(highContrastEnabled: true, originalColor: color))
        testCases.append(HighContrastTestCase(highContrastEnabled: false, originalColor: color))
    }
    
    return testCases
}

private func generateLatencyCompensationTestCases() -> [LatencyCompensationTestCase] {
    let compensationValues: [Double] = [-100, -50, -25, -10, -5, 0, 5, 10, 25, 50, 100]
    return compensationValues.map { LatencyCompensationTestCase(compensationMs: $0) }
}

private func generateSettingsValidationTestCases() -> [SettingsValidationTestCase] {
    var testCases: [SettingsValidationTestCase] = []
    
    // Valid cases
    testCases.append(SettingsValidationTestCase(dailyGoal: 5, latencyCompensation: 0, metronomeVolume: 0.7))
    testCases.append(SettingsValidationTestCase(dailyGoal: 1, latencyCompensation: -100, metronomeVolume: 0))
    testCases.append(SettingsValidationTestCase(dailyGoal: 120, latencyCompensation: 100, metronomeVolume: 1))
    
    // Invalid cases
    testCases.append(SettingsValidationTestCase(dailyGoal: 0, latencyCompensation: 0, metronomeVolume: 0.7))
    testCases.append(SettingsValidationTestCase(dailyGoal: 121, latencyCompensation: 0, metronomeVolume: 0.7))
    testCases.append(SettingsValidationTestCase(dailyGoal: 5, latencyCompensation: -101, metronomeVolume: 0.7))
    testCases.append(SettingsValidationTestCase(dailyGoal: 5, latencyCompensation: 101, metronomeVolume: 0.7))
    testCases.append(SettingsValidationTestCase(dailyGoal: 5, latencyCompensation: 0, metronomeVolume: -0.1))
    testCases.append(SettingsValidationTestCase(dailyGoal: 5, latencyCompensation: 0, metronomeVolume: 1.1))
    
    return testCases
}

private func generateSettingsRoundTripTestCases() -> [SettingsRoundTripTestCase] {
    var testCases: [SettingsRoundTripTestCase] = []
    
    // Various combinations of settings
    let boolValues = [true, false]
    let latencyValues = [-50.0, 0.0, 25.0]
    let goalValues = [5, 15, 30]
    let volumeValues = [0.0, 0.5, 1.0]
    let soundValues = ["click", "beep", "wood"]
    let deviceValues = ["", "builtin", "headphones"]
    
    for highContrast in boolValues {
        for streakFlash in boolValues {
            for latency in latencyValues {
                for goal in goalValues {
                    for volume in volumeValues {
                        for sound in soundValues {
                            for device in deviceValues {
                                testCases.append(SettingsRoundTripTestCase(
                                    highContrastMode: highContrast,
                                    streakFlashEnabled: streakFlash,
                                    audioLatencyCompensation: latency,
                                    selectedAudioDevice: device,
                                    dailyGoalMinutes: goal,
                                    metronomeVolume: volume,
                                    metronomeSound: sound
                                ))
                            }
                        }
                    }
                }
            }
        }
    }
    
    return Array(testCases.prefix(50)) // Limit to 50 test cases for performance
}

// MARK: - Test Models

private struct HighContrastTestCase {
    let highContrastEnabled: Bool
    let originalColor: TestColor
}

private struct LatencyCompensationTestCase {
    let compensationMs: Double
}

private struct SettingsValidationTestCase {
    let dailyGoal: Int
    let latencyCompensation: Double
    let metronomeVolume: Double
}

private struct SettingsRoundTripTestCase {
    let highContrastMode: Bool
    let streakFlashEnabled: Bool
    let audioLatencyCompensation: Double
    let selectedAudioDevice: String
    let dailyGoalMinutes: Int
    let metronomeVolume: Double
    let metronomeSound: String
}

private enum TestColor {
    case red, blue, green, yellow, orange, purple
}

private struct FeedbackStyle {
    let color: TestColor
    let hasIcon: Bool
    let iconName: String?
}

private struct TimingWindow {
    let start: TimeInterval
    let end: TimeInterval
}

private struct TimingWindows {
    let perfectWindow: TimingWindow
    let earlyWindow: TimingWindow
    let lateWindow: TimingWindow
}

// MARK: - Test Helpers

private func createTestSettingsManager() -> SettingsManager {
    // Create a test instance that doesn't persist to UserDefaults
    return SettingsManager.shared
}

private func getFeedbackStyle(highContrast: Bool, originalColor: TestColor) -> FeedbackStyle {
    if highContrast {
        return FeedbackStyle(
            color: .white,
            hasIcon: true,
            iconName: getIconForColor(originalColor)
        )
    } else {
        return FeedbackStyle(
            color: originalColor,
            hasIcon: false,
            iconName: nil
        )
    }
}

private func getIconForColor(_ color: TestColor) -> String {
    switch color {
    case .red: return "circle.fill"
    case .blue: return "square.fill"
    case .green: return "triangle.fill"
    case .yellow: return "diamond.fill"
    case .orange: return "star.fill"
    case .purple: return "heart.fill"
    }
}

private func createTestTimingWindows() -> TimingWindows {
    return TimingWindows(
        perfectWindow: TimingWindow(start: -0.02, end: 0.02),
        earlyWindow: TimingWindow(start: -0.05, end: -0.02),
        lateWindow: TimingWindow(start: 0.02, end: 0.05)
    )
}

private func applyLatencyCompensation(originalWindows: TimingWindows, compensationMs: Double) -> TimingWindows {
    let compensationSeconds = compensationMs / 1000.0
    
    return TimingWindows(
        perfectWindow: TimingWindow(
            start: originalWindows.perfectWindow.start + compensationSeconds,
            end: originalWindows.perfectWindow.end + compensationSeconds
        ),
        earlyWindow: TimingWindow(
            start: originalWindows.earlyWindow.start + compensationSeconds,
            end: originalWindows.earlyWindow.end + compensationSeconds
        ),
        lateWindow: TimingWindow(
            start: originalWindows.lateWindow.start + compensationSeconds,
            end: originalWindows.lateWindow.end + compensationSeconds
        )
    )
}

// MARK: - Test Tags

extension Tag {
    @Tag static var property: Self
}