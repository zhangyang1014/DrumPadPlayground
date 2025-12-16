import SwiftUI
import Charts

struct AdvancedAnalyticsView: View {
    @StateObject private var progressManager = ProgressManager()
    @StateObject private var socialManager = SocialSharingManager()
    @State private var selectedTimeframe: AnalyticsTimeframe = .month
    @State private var selectedMetric: AnalyticsMetric = .performance
    @State private var showingSharingSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with timeframe selector
                    headerSection
                    
                    // Key metrics overview
                    keyMetricsSection
                    
                    // Performance charts
                    performanceChartsSection
                    
                    // Practice patterns
                    practicePatternsSection
                    
                    // Skill progression
                    skillProgressionSection
                    
                    // Comparative analysis
                    comparativeAnalysisSection
                    
                    // Personalized recommendations
                    recommendationsSection
                    
                    // Social sharing
                    socialSharingSection
                }
                .padding()
            }
            .navigationTitle("Advanced Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        showingSharingSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingSharingSheet) {
            SocialSharingView(socialManager: socialManager)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analytics Dashboard")
                .font(.title2)
                .fontWeight(.bold)
            
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(AnalyticsTimeframe.allCases, id: \.self) { timeframe in
                    Text(timeframe.displayName).tag(timeframe)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private var keyMetricsSection: some View {
        let analytics = progressManager.getAdvancedAnalytics()
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Key Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                MetricCard(
                    title: "Average Score",
                    value: String(format: "%.1f%%", analytics.performanceMetrics.averageScore),
                    trend: analytics.performanceMetrics.improvementRate > 0 ? .up : .down,
                    color: .blue
                )
                
                MetricCard(
                    title: "Consistency",
                    value: String(format: "%.1f%%", analytics.performanceMetrics.consistencyScore * 100),
                    trend: .stable,
                    color: .green
                )
                
                MetricCard(
                    title: "Practice Frequency",
                    value: String(format: "%.1f%%", analytics.practicePatterns.practiceFrequency * 100),
                    trend: .up,
                    color: .orange
                )
                
                MetricCard(
                    title: "Perfect Scores",
                    value: "\(analytics.performanceMetrics.perfectScoreCount)",
                    trend: .up,
                    color: .purple
                )
            }
        }
    }
    
    private var performanceChartsSection: some View {
        let analytics = progressManager.getAdvancedAnalytics()
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Performance Trends")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Score progression chart
            Chart {
                ForEach(0..<30, id: \.self) { day in
                    LineMark(
                        x: .value("Day", day),
                        y: .value("Score", Double.random(in: 60...100))
                    )
                    .foregroundStyle(.blue)
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(position: .bottom)
            }
            
            // Accuracy breakdown
            HStack {
                VStack(alignment: .leading) {
                    Text("Accuracy Breakdown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        AccuracyBar(label: "Perfect", percentage: 0.4, color: .green)
                        AccuracyBar(label: "Early", percentage: 0.25, color: .yellow)
                        AccuracyBar(label: "Late", percentage: 0.25, color: .orange)
                        AccuracyBar(label: "Miss", percentage: 0.1, color: .red)
                    }
                }
                Spacer()
            }
        }
    }
    
    private var practicePatternsSection: some View {
        let analytics = progressManager.getAdvancedAnalytics()
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Practice Patterns")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                PracticePatternRow(
                    icon: "clock",
                    title: "Preferred Practice Time",
                    value: formatHour(analytics.practicePatterns.preferredPracticeTime)
                )
                
                PracticePatternRow(
                    icon: "timer",
                    title: "Average Session Length",
                    value: formatDuration(analytics.practicePatterns.averageSessionLength)
                )
                
                PracticePatternRow(
                    icon: "calendar",
                    title: "Most Productive Day",
                    value: analytics.practicePatterns.mostProductiveDay
                )
                
                PracticePatternRow(
                    icon: "flame",
                    title: "Longest Streak",
                    value: "\(analytics.practicePatterns.longestStreak) days"
                )
            }
        }
    }
    
    private var skillProgressionSection: some View {
        let analytics = progressManager.getAdvancedAnalytics()
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Skill Progression")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Difficulty progression
            VStack(alignment: .leading, spacing: 8) {
                Text("Difficulty Mastery")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(1...5, id: \.self) { difficulty in
                    HStack {
                        Text("Level \(difficulty)")
                            .font(.caption)
                            .frame(width: 60, alignment: .leading)
                        
                        ProgressView(value: Double.random(in: 0...1))
                            .progressViewStyle(LinearProgressViewStyle(tint: difficultyColor(difficulty)))
                        
                        Text("\(Int(Double.random(in: 0...100)))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Weak and strong areas
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Areas to Improve")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                    
                    ForEach(analytics.skillProgression.weakAreas.prefix(3), id: \.name) { area in
                        Text("• \(area.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Strong Areas")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    
                    ForEach(analytics.skillProgression.strongAreas.prefix(3), id: \.name) { area in
                        Text("• \(area.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var comparativeAnalysisSection: some View {
        let analytics = progressManager.getAdvancedAnalytics()
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("How You Compare")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ComparisonRow(
                    title: "vs Global Average",
                    scoreComparison: analytics.comparativeAnalysis.vsGlobalAverage.scoreComparison,
                    practiceComparison: analytics.comparativeAnalysis.vsGlobalAverage.practiceTimeComparison
                )
                
                ComparisonRow(
                    title: "vs Similar Level Players",
                    scoreComparison: analytics.comparativeAnalysis.vsPeers.scoreComparison,
                    practiceComparison: analytics.comparativeAnalysis.vsPeers.practiceTimeComparison
                )
                
                HStack {
                    Text("Your Percentile Rank")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(analytics.comparativeAnalysis.percentileRank)th percentile")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var recommendationsSection: some View {
        let analytics = progressManager.getAdvancedAnalytics()
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Personalized Recommendations")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(analytics.recommendations.prefix(3), id: \.title) { recommendation in
                RecommendationCard(recommendation: recommendation)
            }
        }
    }
    
    private var socialSharingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Share Your Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                ShareButton(platform: .twitter, action: shareProgress)
                ShareButton(platform: .facebook, action: shareProgress)
                ShareButton(platform: .instagram, action: shareProgress)
                ShareButton(platform: .discord, action: shareProgress)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
    
    private func difficultyColor(_ difficulty: Int) -> Color {
        switch difficulty {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        default: return .gray
        }
    }
    
    private func shareProgress() {
        let progress = progressManager.getProgressSummary()
        let shareableContent = socialManager.createShareableProgress(progress)
        socialManager.shareToSocialMedia(shareableContent, platform: .twitter)
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let trend: TrendDirection
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: trend.iconName)
                    .foregroundColor(trend.color)
                    .font(.caption)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AccuracyBar: View {
    let label: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(height: 60 * percentage)
                .frame(maxHeight: 60)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct PracticePatternRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
}

struct ComparisonRow: View {
    let title: String
    let scoreComparison: ComparisonResult
    let practiceComparison: ComparisonResult
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            HStack(spacing: 8) {
                ComparisonIndicator(result: scoreComparison, label: "Score")
                ComparisonIndicator(result: practiceComparison, label: "Practice")
            }
        }
    }
}

struct ComparisonIndicator: View {
    let result: ComparisonResult
    let label: String
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: result.iconName)
                .foregroundColor(result.color)
                .font(.caption)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct RecommendationCard: View {
    let recommendation: Recommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(recommendation.priority.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(recommendation.priority.color.opacity(0.2))
                    .foregroundColor(recommendation.priority.color)
                    .cornerRadius(4)
            }
            
            Text(recommendation.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ShareButton: View {
    let platform: SocialPlatform
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: platform.iconName)
                    .font(.title2)
                
                Text(platform.displayName)
                    .font(.caption2)
            }
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

// MARK: - Supporting Types

enum AnalyticsTimeframe: CaseIterable {
    case week, month, quarter, year
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        case .year: return "Year"
        }
    }
}

enum AnalyticsMetric: CaseIterable {
    case performance, practice, skills, social
    
    var displayName: String {
        switch self {
        case .performance: return "Performance"
        case .practice: return "Practice"
        case .skills: return "Skills"
        case .social: return "Social"
        }
    }
}

enum TrendDirection {
    case up, down, stable
    
    var iconName: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .stable: return .gray
        }
    }
}

// MARK: - Extensions

extension ComparisonResult {
    var iconName: String {
        switch self {
        case .above: return "arrow.up"
        case .below: return "arrow.down"
        case .equal: return "equal"
        }
    }
    
    var color: Color {
        switch self {
        case .above: return .green
        case .below: return .red
        case .equal: return .gray
        }
    }
}

extension RecommendationPriority {
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .orange
        case .high: return .red
        }
    }
}

extension SocialPlatform {
    var iconName: String {
        switch self {
        case .twitter: return "message"
        case .facebook: return "person.2"
        case .instagram: return "camera"
        case .discord: return "gamecontroller"
        }
    }
}