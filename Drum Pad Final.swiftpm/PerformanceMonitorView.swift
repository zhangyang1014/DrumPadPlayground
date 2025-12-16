import SwiftUI
import Charts

// MARK: - Performance Monitoring UI

/// User interface for displaying performance metrics and optimization recommendations
/// Provides real-time monitoring, historical charts, and actionable insights

struct PerformanceMonitorView: View {
    @ObservedObject var performanceMonitor: PerformanceMonitor
    @State private var selectedTimeRange: TimeRange = .lastHour
    @State private var isShowingDetailedMetrics = false
    @State private var isShowingOptimizations = false
    
    enum TimeRange: String, CaseIterable {
        case lastMinute = "1m"
        case last5Minutes = "5m"
        case lastHour = "1h"
        case lastSession = "Session"
        
        var displayName: String {
            switch self {
            case .lastMinute: return "Last Minute"
            case .last5Minutes: return "Last 5 Minutes"
            case .lastHour: return "Last Hour"
            case .lastSession: return "Current Session"
            }
        }
        
        var duration: TimeInterval {
            switch self {
            case .lastMinute: return 60
            case .last5Minutes: return 300
            case .lastHour: return 3600
            case .lastSession: return 0 // Special case
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Current Performance Overview
                    if let metrics = performanceMonitor.currentMetrics {
                        PerformanceOverviewCard(metrics: metrics)
                    }
                    
                    // Time Range Selector
                    TimeRangeSelector(selectedRange: $selectedTimeRange)
                    
                    // Performance Charts
                    PerformanceChartsSection(
                        performanceMonitor: performanceMonitor,
                        timeRange: selectedTimeRange
                    )
                    
                    // Optimization Recommendations
                    if !performanceMonitor.optimizationRecommendations.isEmpty {
                        OptimizationRecommendationsCard(
                            recommendations: performanceMonitor.optimizationRecommendations
                        )
                    }
                    
                    // Detailed Metrics (Expandable)
                    if isShowingDetailedMetrics {
                        DetailedMetricsSection(performanceMonitor: performanceMonitor)
                    }
                }
                .padding()
            }
            .navigationTitle("Performance Monitor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { isShowingDetailedMetrics.toggle() }) {
                            Label("Detailed Metrics", systemImage: "chart.bar.doc.horizontal")
                        }
                        
                        Button(action: { isShowingOptimizations.toggle() }) {
                            Label("Optimization Settings", systemImage: "gear")
                        }
                        
                        ShareLink(item: performanceMonitor.exportPerformanceReport()) {
                            Label("Export Report", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingOptimizations) {
            OptimizationSettingsView(performanceMonitor: performanceMonitor)
        }
    }
}

struct PerformanceOverviewCard: View {
    let metrics: PerformanceMetrics
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Performance Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                PerformanceScoreBadge(score: metrics.performanceScore)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MetricCard(
                    title: "Audio Latency",
                    value: "\(Int(metrics.audioLatency * 1000))ms",
                    status: metrics.audioLatency < 0.020 ? .good : (metrics.audioLatency < 0.050 ? .warning : .critical),
                    icon: "waveform"
                )
                
                MetricCard(
                    title: "CPU Usage",
                    value: "\(Int(metrics.cpuUsage))%",
                    status: metrics.cpuUsage < 50 ? .good : (metrics.cpuUsage < 80 ? .warning : .critical),
                    icon: "cpu"
                )
                
                MetricCard(
                    title: "Memory",
                    value: ByteCountFormatter.string(fromByteCount: metrics.memoryUsage, countStyle: .memory),
                    status: metrics.memoryUsage < 200_000_000 ? .good : (metrics.memoryUsage < 500_000_000 ? .warning : .critical),
                    icon: "memorychip"
                )
                
                MetricCard(
                    title: "MIDI Latency",
                    value: "\(Int(metrics.midiProcessingLatency * 1000))ms",
                    status: metrics.midiProcessingLatency < 0.005 ? .good : (metrics.midiProcessingLatency < 0.010 ? .warning : .critical),
                    icon: "pianokeys"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let status: MetricStatus
    let icon: String
    
    enum MetricStatus {
        case good, warning, critical
        
        var color: Color {
            switch self {
            case .good: return .green
            case .warning: return .orange
            case .critical: return .red
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .good: return .green.opacity(0.1)
            case .warning: return .orange.opacity(0.1)
            case .critical: return .red.opacity(0.1)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(status.color)
                    .font(.title3)
                
                Spacer()
                
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(status.backgroundColor)
        )
    }
}

struct PerformanceScoreBadge: View {
    let score: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: scoreIcon)
                .foregroundColor(scoreColor)
                .font(.caption)
            
            Text("\(Int(score))")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(scoreColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(scoreColor.opacity(0.1))
        )
    }
    
    private var scoreColor: Color {
        if score >= 90 {
            return .green
        } else if score >= 70 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var scoreIcon: String {
        if score >= 90 {
            return "checkmark.circle.fill"
        } else if score >= 70 {
            return "exclamationmark.triangle.fill"
        } else {
            return "xmark.circle.fill"
        }
    }
}

struct TimeRangeSelector: View {
    @Binding var selectedRange: PerformanceMonitorView.TimeRange
    
    var body: some View {
        Picker("Time Range", selection: $selectedRange) {
            ForEach(PerformanceMonitorView.TimeRange.allCases, id: \.self) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct PerformanceChartsSection: View {
    let performanceMonitor: PerformanceMonitor
    let timeRange: PerformanceMonitorView.TimeRange
    
    var filteredMetrics: [PerformanceMetrics] {
        let cutoff = Date().addingTimeInterval(-timeRange.duration)
        return performanceMonitor.performanceHistory.filter { $0.timestamp >= cutoff }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Performance Trends")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if !filteredMetrics.isEmpty {
                VStack(spacing: 20) {
                    // Audio Latency Chart
                    ChartCard(title: "Audio Latency", unit: "ms") {
                        Chart(filteredMetrics) { metrics in
                            LineMark(
                                x: .value("Time", metrics.timestamp),
                                y: .value("Latency", metrics.audioLatency * 1000)
                            )
                            .foregroundStyle(.blue)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 120)
                    }
                    
                    // CPU Usage Chart
                    ChartCard(title: "CPU Usage", unit: "%") {
                        Chart(filteredMetrics) { metrics in
                            LineMark(
                                x: .value("Time", metrics.timestamp),
                                y: .value("CPU", metrics.cpuUsage)
                            )
                            .foregroundStyle(.orange)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 120)
                    }
                    
                    // Performance Score Chart
                    ChartCard(title: "Performance Score", unit: "/100") {
                        Chart(filteredMetrics) { metrics in
                            LineMark(
                                x: .value("Time", metrics.timestamp),
                                y: .value("Score", metrics.performanceScore)
                            )
                            .foregroundStyle(.green)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 120)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Performance Data",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Performance monitoring data will appear here once monitoring is active.")
                )
            }
        }
    }
}

struct ChartCard<Content: View>: View {
    let title: String
    let unit: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

struct OptimizationRecommendationsCard: View {
    let recommendations: [OptimizationRecommendation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Optimization Recommendations")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(recommendations.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.orange.opacity(0.2))
                    )
                    .foregroundColor(.orange)
            }
            
            ForEach(recommendations) { recommendation in
                OptimizationRecommendationRow(recommendation: recommendation)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
}

struct OptimizationRecommendationRow: View {
    let recommendation: OptimizationRecommendation
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: impactIcon)
                .foregroundColor(impactColor)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Text("Impact: \(recommendation.impact.displayName)")
                        .font(.caption2)
                        .foregroundColor(impactColor)
                    
                    Spacer()
                    
                    if recommendation.action == .automaticOptimization {
                        Text("Auto-fixable")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(.blue.opacity(0.2))
                            )
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var impactIcon: String {
        switch recommendation.impact {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.triangle.fill"
        }
    }
    
    private var impactColor: Color {
        switch recommendation.impact {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}

struct DetailedMetricsSection: View {
    let performanceMonitor: PerformanceMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let metrics = performanceMonitor.currentMetrics {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 12) {
                    DetailedMetricRow(label: "Audio Buffer Underruns", value: "\(metrics.audioBufferUnderruns)")
                    DetailedMetricRow(label: "Frame Drops", value: "\(metrics.frameDrops)")
                    DetailedMetricRow(label: "Battery Level", value: "\(Int(metrics.batteryLevel * 100))%")
                    DetailedMetricRow(label: "Thermal State", value: thermalStateDescription(metrics.thermalState))
                    DetailedMetricRow(label: "Timestamp", value: DateFormatter.localizedString(from: metrics.timestamp, dateStyle: .none, timeStyle: .medium))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
    
    private func thermalStateDescription(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Normal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}

struct DetailedMetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

struct OptimizationSettingsView: View {
    @ObservedObject var performanceMonitor: PerformanceMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var autoOptimizationEnabled = true
    @State private var monitoringInterval: Double = 1.0
    
    var body: some View {
        NavigationView {
            Form {
                Section("Monitoring Settings") {
                    Toggle("Auto Optimization", isOn: $autoOptimizationEnabled)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monitoring Interval")
                        Slider(value: $monitoringInterval, in: 0.5...5.0, step: 0.5) {
                            Text("Interval")
                        } minimumValueLabel: {
                            Text("0.5s")
                        } maximumValueLabel: {
                            Text("5s")
                        }
                        Text("\(monitoringInterval, specifier: "%.1f") seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Performance Thresholds") {
                    HStack {
                        Text("Audio Latency Warning")
                        Spacer()
                        Text("20ms")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("CPU Usage Warning")
                        Spacer()
                        Text("80%")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Memory Usage Warning")
                        Spacer()
                        Text("500MB")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Actions") {
                    Button("Clear Performance History") {
                        performanceMonitor.performanceHistory.removeAll()
                    }
                    .foregroundColor(.red)
                    
                    Button("Reset Recommendations") {
                        performanceMonitor.optimizationRecommendations.removeAll()
                    }
                }
            }
            .navigationTitle("Optimization Settings")
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

// MARK: - Preview Helpers

#if DEBUG
struct PerformanceMonitorView_Previews: PreviewProvider {
    static var previews: some View {
        let monitor = PerformanceMonitor()
        
        // Add sample data
        let sampleMetrics = PerformanceMetrics(
            timestamp: Date(),
            audioLatency: 0.025,
            memoryUsage: 150_000_000,
            cpuUsage: 45.0,
            audioBufferUnderruns: 0,
            midiProcessingLatency: 0.003,
            frameDrops: 0,
            batteryLevel: 0.75,
            thermalState: .nominal
        )
        
        monitor.currentMetrics = sampleMetrics
        monitor.performanceHistory = [sampleMetrics]
        
        return PerformanceMonitorView(performanceMonitor: monitor)
    }
}
#endif