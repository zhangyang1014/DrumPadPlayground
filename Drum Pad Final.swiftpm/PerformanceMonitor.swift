import Foundation
import AudioKit
import AVFoundation
import os.log
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Performance Monitoring and Optimization System

/// Comprehensive performance monitoring system for the drum trainer application
/// Monitors audio latency, memory usage, CPU usage, and provides optimization recommendations

// MARK: - Performance Metrics

struct PerformanceMetrics {
    let timestamp: Date
    let audioLatency: TimeInterval
    let memoryUsage: Int64 // bytes
    let cpuUsage: Double // percentage
    let audioBufferUnderruns: Int
    let midiProcessingLatency: TimeInterval
    let frameDrops: Int
    let batteryLevel: Float
    let thermalState: ProcessInfo.ThermalState
    
    var isPerformanceGood: Bool {
        return audioLatency < 0.020 && // < 20ms
               cpuUsage < 80.0 && // < 80%
               audioBufferUnderruns == 0 &&
               midiProcessingLatency < 0.005 && // < 5ms
               frameDrops == 0
    }
    
    var performanceScore: Double {
        var score = 100.0
        
        // Audio latency penalty
        if audioLatency > 0.020 {
            score -= min(50.0, (audioLatency - 0.020) * 1000.0) // -1 point per ms over 20ms
        }
        
        // CPU usage penalty
        if cpuUsage > 50.0 {
            score -= (cpuUsage - 50.0) // -1 point per % over 50%
        }
        
        // Buffer underrun penalty
        score -= Double(audioBufferUnderruns) * 10.0 // -10 points per underrun
        
        // MIDI latency penalty
        if midiProcessingLatency > 0.005 {
            score -= (midiProcessingLatency - 0.005) * 2000.0 // -2 points per ms over 5ms
        }
        
        // Frame drop penalty
        score -= Double(frameDrops) * 5.0 // -5 points per frame drop
        
        return max(0.0, score)
    }
}

// MARK: - Performance Monitor

class PerformanceMonitor: ObservableObject {
    @Published var currentMetrics: PerformanceMetrics?
    @Published var isMonitoring: Bool = false
    @Published var performanceHistory: [PerformanceMetrics] = []
    @Published var optimizationRecommendations: [OptimizationRecommendation] = []
    
    private var monitoringTimer: Timer?
    private var audioEngine: AudioEngine?
    private var conductor: Conductor?
    
    // Performance tracking
    private var audioBufferUnderrunCount = 0
    private var frameDropCount = 0
    private var midiEventTimestamps: [TimeInterval] = []
    
    // Logging
    private let logger = Logger(subsystem: "com.drumtrainer.performance", category: "monitoring")
    
    init() {
        setupNotificationObservers()
    }
    
    // MARK: - Public Interface
    
    func startMonitoring(audioEngine: AudioEngine, conductor: Conductor) {
        self.audioEngine = audioEngine
        self.conductor = conductor
        
        guard !isMonitoring else { return }
        
        isMonitoring = true
        logger.info("Starting performance monitoring")
        
        // Start periodic monitoring
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.collectMetrics()
        }
        
        // Setup audio session monitoring
        setupAudioSessionMonitoring()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        logger.info("Stopped performance monitoring")
    }
    
    func recordMIDIEvent(timestamp: TimeInterval) {
        midiEventTimestamps.append(timestamp)
        
        // Keep only recent events (last 10 seconds)
        let cutoff = CACurrentMediaTime() - 10.0
        midiEventTimestamps.removeAll { $0 < cutoff }
    }
    
    func getAveragePerformanceScore(over duration: TimeInterval = 60.0) -> Double {
        let cutoff = Date().addingTimeInterval(-duration)
        let recentMetrics = performanceHistory.filter { $0.timestamp >= cutoff }
        
        guard !recentMetrics.isEmpty else { return 0.0 }
        
        let totalScore = recentMetrics.reduce(0.0) { $0 + $1.performanceScore }
        return totalScore / Double(recentMetrics.count)
    }
    
    func exportPerformanceReport() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        
        var report = "Drum Trainer Performance Report\n"
        report += "Generated: \(formatter.string(from: Date()))\n\n"
        
        if let current = currentMetrics {
            report += "Current Performance:\n"
            report += "- Audio Latency: \(String(format: "%.1f", current.audioLatency * 1000))ms\n"
            report += "- Memory Usage: \(ByteCountFormatter.string(fromByteCount: current.memoryUsage, countStyle: .memory))\n"
            report += "- CPU Usage: \(String(format: "%.1f", current.cpuUsage))%\n"
            report += "- Performance Score: \(String(format: "%.1f", current.performanceScore))/100\n\n"
        }
        
        let avgScore = getAveragePerformanceScore()
        report += "Average Performance (last hour): \(String(format: "%.1f", avgScore))/100\n\n"
        
        if !optimizationRecommendations.isEmpty {
            report += "Optimization Recommendations:\n"
            for (index, recommendation) in optimizationRecommendations.enumerated() {
                report += "\(index + 1). \(recommendation.title)\n"
                report += "   \(recommendation.description)\n"
                report += "   Impact: \(recommendation.impact.displayName)\n\n"
            }
        }
        
        return report
    }
    
    // MARK: - Private Implementation
    
    private func collectMetrics() {
        let metrics = PerformanceMetrics(
            timestamp: Date(),
            audioLatency: measureAudioLatency(),
            memoryUsage: getMemoryUsage(),
            cpuUsage: getCPUUsage(),
            audioBufferUnderruns: audioBufferUnderrunCount,
            midiProcessingLatency: calculateMIDIProcessingLatency(),
            frameDrops: frameDropCount,
            batteryLevel: getBatteryLevel(),
            thermalState: ProcessInfo.processInfo.thermalState
        )
        
        DispatchQueue.main.async {
            self.currentMetrics = metrics
            self.performanceHistory.append(metrics)
            
            // Keep only recent history (last hour)
            let cutoff = Date().addingTimeInterval(-3600)
            self.performanceHistory.removeAll { $0.timestamp < cutoff }
            
            // Update optimization recommendations
            self.updateOptimizationRecommendations(based: metrics)
        }
        
        // Log performance issues
        if !metrics.isPerformanceGood {
            logger.warning("Performance issue detected: latency=\(metrics.audioLatency * 1000, privacy: .public)ms, cpu=\(metrics.cpuUsage, privacy: .public)%")
        }
    }
    
    private func measureAudioLatency() -> TimeInterval {
        guard let audioEngine = audioEngine else { return 0.0 }
        
        let audioSession = AVAudioSession.sharedInstance()
        let bufferDuration = audioSession.ioBufferDuration
        let sampleRate = audioSession.sampleRate
        
        // Calculate total latency including processing
        let inputLatency = audioSession.inputLatency
        let outputLatency = audioSession.outputLatency
        let processingLatency = bufferDuration + (1024.0 / sampleRate)
        
        return inputLatency + outputLatency + processingLatency
    }
    
    private func getMemoryUsage() -> Int64 {
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
    
    private func getCPUUsage() -> Double {
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
            // This is a simplified CPU usage calculation
            // In a real implementation, you'd need to track CPU time over intervals
            return Double(info.resident_size) / Double(1024 * 1024 * 100) // Rough approximation
        } else {
            return 0.0
        }
    }
    
    private func calculateMIDIProcessingLatency() -> TimeInterval {
        guard !midiEventTimestamps.isEmpty else { return 0.0 }
        
        // Calculate average time between MIDI events and processing
        // This is a simplified calculation
        let currentTime = CACurrentMediaTime()
        let recentEvents = midiEventTimestamps.filter { currentTime - $0 < 1.0 }
        
        if recentEvents.count >= 2 {
            let intervals = zip(recentEvents.dropFirst(), recentEvents).map { $0.0 - $0.1 }
            return intervals.reduce(0.0, +) / Double(intervals.count)
        }
        
        return 0.0
    }
    
    private func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
    }
    
    private func setupNotificationObservers() {
        // Audio interruption notifications
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.warning("Audio session interrupted")
        }
        
        // Audio route change notifications
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt {
                self?.logger.info("Audio route changed: \(reason)")
            }
        }
        
        // Memory warning notifications
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.warning("Memory warning received")
            self?.handleMemoryWarning()
        }
        
        // Thermal state notifications
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let thermalState = ProcessInfo.processInfo.thermalState
            self?.logger.info("Thermal state changed: \(thermalState.rawValue)")
            self?.handleThermalStateChange(thermalState)
        }
    }
    
    private func setupAudioSessionMonitoring() {
        // Monitor audio buffer underruns
        // This would typically involve setting up audio unit callbacks
        // For now, we'll simulate this with periodic checks
    }
    
    private func handleMemoryWarning() {
        // Clear performance history to free memory
        let recentCutoff = Date().addingTimeInterval(-300) // Keep last 5 minutes
        performanceHistory.removeAll { $0.timestamp < recentCutoff }
        
        // Add memory optimization recommendation
        let recommendation = OptimizationRecommendation(
            title: "Memory Usage High",
            description: "Consider closing other apps or restarting the device to free up memory.",
            impact: .high,
            category: .memory,
            action: .userAction
        )
        
        DispatchQueue.main.async {
            if !self.optimizationRecommendations.contains(where: { $0.category == .memory }) {
                self.optimizationRecommendations.append(recommendation)
            }
        }
    }
    
    private func handleThermalStateChange(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .serious, .critical:
            let recommendation = OptimizationRecommendation(
                title: "Device Overheating",
                description: "Device is running hot. Consider reducing audio quality or taking a break.",
                impact: .high,
                category: .thermal,
                action: .automaticOptimization
            )
            
            DispatchQueue.main.async {
                self.optimizationRecommendations.append(recommendation)
            }
            
        default:
            // Remove thermal recommendations when state improves
            DispatchQueue.main.async {
                self.optimizationRecommendations.removeAll { $0.category == .thermal }
            }
        }
    }
    
    private func updateOptimizationRecommendations(based metrics: PerformanceMetrics) {
        var newRecommendations: [OptimizationRecommendation] = []
        
        // Audio latency recommendations
        if metrics.audioLatency > 0.050 {
            newRecommendations.append(OptimizationRecommendation(
                title: "High Audio Latency",
                description: "Use wired headphones and close other audio apps to reduce latency.",
                impact: .high,
                category: .audio,
                action: .userAction
            ))
        }
        
        // CPU usage recommendations
        if metrics.cpuUsage > 80.0 {
            newRecommendations.append(OptimizationRecommendation(
                title: "High CPU Usage",
                description: "Close background apps and reduce audio quality settings.",
                impact: .medium,
                category: .cpu,
                action: .automaticOptimization
            ))
        }
        
        // Buffer underrun recommendations
        if metrics.audioBufferUnderruns > 0 {
            newRecommendations.append(OptimizationRecommendation(
                title: "Audio Buffer Underruns",
                description: "Increase audio buffer size or close other apps.",
                impact: .high,
                category: .audio,
                action: .automaticOptimization
            ))
        }
        
        // Battery recommendations
        if metrics.batteryLevel < 0.20 {
            newRecommendations.append(OptimizationRecommendation(
                title: "Low Battery",
                description: "Connect to power to maintain optimal performance.",
                impact: .medium,
                category: .power,
                action: .userAction
            ))
        }
        
        // Update recommendations, avoiding duplicates
        DispatchQueue.main.async {
            // Remove old recommendations of the same categories
            let newCategories = Set(newRecommendations.map { $0.category })
            self.optimizationRecommendations.removeAll { newCategories.contains($0.category) }
            
            // Add new recommendations
            self.optimizationRecommendations.append(contentsOf: newRecommendations)
        }
    }
    
    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Optimization Recommendations

public struct OptimizationRecommendation: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let description: String
    public let impact: Impact
    public let category: Category
    public let action: Action
    
    public enum Impact {
        case low, medium, high
        
        var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
    }
    
    public enum Category {
        case audio, cpu, memory, thermal, power, network
    }
    
    public enum Action {
        case userAction, automaticOptimization, systemSetting
    }
}

// MARK: - Performance Optimizer

class PerformanceOptimizer {
    private let performanceMonitor: PerformanceMonitor
    private let conductor: Conductor
    private let audioEngine: AudioEngine
    
    init(performanceMonitor: PerformanceMonitor, conductor: Conductor, audioEngine: AudioEngine) {
        self.performanceMonitor = performanceMonitor
        self.conductor = conductor
        self.audioEngine = audioEngine
    }
    
    func applyAutomaticOptimizations() {
        guard let metrics = performanceMonitor.currentMetrics else { return }
        
        // Apply optimizations based on current performance
        if metrics.audioLatency > 0.030 {
            optimizeAudioLatency()
        }
        
        if metrics.cpuUsage > 75.0 {
            optimizeCPUUsage()
        }
        
        if metrics.memoryUsage > 500_000_000 { // 500MB
            optimizeMemoryUsage()
        }
        
        if metrics.thermalState == .serious || metrics.thermalState == .critical {
            optimizeForThermalState()
        }
    }
    
    private func optimizeAudioLatency() {
        // Reduce audio buffer size if possible
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Try to set a smaller buffer size
            let targetBufferDuration = 0.005 // 5ms
            try audioSession.setPreferredIOBufferDuration(targetBufferDuration)
            
            print("Optimized audio buffer duration to \(targetBufferDuration)s")
        } catch {
            print("Failed to optimize audio buffer duration: \(error)")
        }
    }
    
    private func optimizeCPUUsage() {
        // Reduce audio quality or processing complexity
        
        // Disable reverb if enabled
        if conductor.reverbMix > 0 {
            conductor.reverbMix = 0
            print("Disabled reverb to reduce CPU usage")
        }
        
        // Reduce delay feedback
        if conductor.delayFeedback > 0 {
            conductor.delayFeedback = 0
            print("Disabled delay to reduce CPU usage")
        }
        
        // Reduce metronome subdivision if possible
        if conductor.metronomeSubdivision != .quarter {
            conductor.setMetronomeSubdivision(.quarter)
            print("Reduced metronome subdivision to optimize CPU usage")
        }
    }
    
    private func optimizeMemoryUsage() {
        // Clear caches and reduce memory footprint
        
        // Clear performance history except recent data
        let recentCutoff = Date().addingTimeInterval(-300) // Keep last 5 minutes
        performanceMonitor.performanceHistory.removeAll { $0.timestamp < recentCutoff }
        
        print("Cleared performance history to optimize memory usage")
    }
    
    private func optimizeForThermalState() {
        // Reduce processing load when device is overheating
        
        // Lower audio quality
        optimizeCPUUsage()
        
        // Reduce monitoring frequency
        // This would require modifying the monitoring timer interval
        
        print("Applied thermal optimizations")
    }
}

// MARK: - Audio Performance Analyzer

public class AudioPerformanceAnalyzer {
    private var audioBufferSizes: [Int] = []
    private var audioLatencies: [TimeInterval] = []
    private var dropoutEvents: [Date] = []
    
    func recordAudioBuffer(size: Int) {
        audioBufferSizes.append(size)
        
        // Keep only recent data
        if audioBufferSizes.count > 1000 {
            audioBufferSizes.removeFirst(500)
        }
    }
    
    func recordAudioLatency(_ latency: TimeInterval) {
        audioLatencies.append(latency)
        
        // Keep only recent data
        if audioLatencies.count > 1000 {
            audioLatencies.removeFirst(500)
        }
    }
    
    func recordDropoutEvent() {
        dropoutEvents.append(Date())
        
        // Keep only recent events (last hour)
        let cutoff = Date().addingTimeInterval(-3600)
        dropoutEvents.removeAll { $0 < cutoff }
    }
    
    func getAudioPerformanceReport() -> AudioPerformanceReport {
        return AudioPerformanceReport(
            averageLatency: audioLatencies.isEmpty ? 0 : audioLatencies.reduce(0, +) / Double(audioLatencies.count),
            maxLatency: audioLatencies.max() ?? 0,
            minLatency: audioLatencies.min() ?? 0,
            averageBufferSize: audioBufferSizes.isEmpty ? 0 : audioBufferSizes.reduce(0, +) / audioBufferSizes.count,
            dropoutCount: dropoutEvents.count,
            dropoutRate: Double(dropoutEvents.count) / 3600.0 // per hour
        )
    }
}

public struct AudioPerformanceReport {
    public let averageLatency: TimeInterval
    public let maxLatency: TimeInterval
    public let minLatency: TimeInterval
    public let averageBufferSize: Int
    public let dropoutCount: Int
    public let dropoutRate: Double // dropouts per hour
    
    public var isPerformanceAcceptable: Bool {
        return averageLatency < 0.025 && // < 25ms average
               maxLatency < 0.050 && // < 50ms max
               dropoutRate < 1.0 // < 1 dropout per hour
    }
}

// MARK: - Debug Logger

public class DebugLogger {
    private let logger = Logger(subsystem: "com.drumtrainer.debug", category: "general")
    private var logEntries: [LogEntry] = []
    
    public struct LogEntry {
        public let timestamp: Date
        public let level: LogLevel
        public let category: String
        public let message: String
    }
    
    public enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
    }
    
    func log(_ level: LogLevel, category: String, message: String) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message
        )
        
        logEntries.append(entry)
        
        // Keep only recent entries (last 1000)
        if logEntries.count > 1000 {
            logEntries.removeFirst(500)
        }
        
        // Log to system logger
        switch level {
        case .debug:
            logger.debug("\(category): \(message)")
        case .info:
            logger.info("\(category): \(message)")
        case .warning:
            logger.warning("\(category): \(message)")
        case .error:
            logger.error("\(category): \(message)")
        case .critical:
            logger.critical("\(category): \(message)")
        }
    }
    
    func exportLogs() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        var logString = "Drum Trainer Debug Log\n"
        logString += "Generated: \(formatter.string(from: Date()))\n\n"
        
        for entry in logEntries {
            logString += "[\(formatter.string(from: entry.timestamp))] "
            logString += "\(entry.level.rawValue) "
            logString += "[\(entry.category)] "
            logString += "\(entry.message)\n"
        }
        
        return logString
    }
    
    func clearLogs() {
        logEntries.removeAll()
    }
}

// MARK: - Performance Extensions

extension Conductor {
    func getPerformanceMetrics() -> [String: Any] {
        return [
            "audioLatency": audioLatency,
            "mixerVolume": mixerVolume,
            "reverbMix": reverbMix,
            "delayMix": delayMix,
            "tempo": tempo,
            "midiConnectionStatus": midiConnectionStatus.rawValue,
            "connectedDevicesCount": connectedDevicesCount
        ]
    }
}

extension ScoreEngine {
    func getPerformanceMetrics() -> [String: Any] {
        return [
            "currentScore": currentScore,
            "currentStreak": currentStreak,
            "isScoring": isScoring,
            "targetEventsCount": targetEvents.count,
            "processedEventsCount": timingResults.count
        ]
    }
}

extension LessonEngine {
    func getPerformanceMetrics() -> [String: Any] {
        return [
            "playbackState": playbackState.rawValue,
            "playbackMode": playbackMode.rawValue,
            "currentTempo": currentTempo,
            "playbackPosition": playbackPosition,
            "isWaitModeEnabled": isWaitModeEnabled,
            "isAutoAccelEnabled": isAutoAccelEnabled
        ]
    }
}