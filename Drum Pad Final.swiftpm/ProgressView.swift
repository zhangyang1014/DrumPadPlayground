import SwiftUI
import CoreData

// MARK: - Progress View

struct ProgressView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var progressManager = ProgressManager()
    
    @State private var selectedTimeframe: ProgressTimeframe = .week
    @State private var showingAchievements = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // User level and overview
                    UserLevelOverviewView(progressManager: progressManager)
                    
                    // Daily goal and streak
                    DailyGoalStreakView(progressManager: progressManager)
                    
                    // Progress charts
                    ProgressChartsView(
                        progressManager: progressManager,
                        selectedTimeframe: $selectedTimeframe
                    )
                    
                    // Recent achievements
                    RecentAchievementsView(progressManager: progressManager) {
                        showingAchievements = true
                    }
                    
                    // Statistics summary
                    StatisticsSummaryView(progressManager: progressManager)
                    
                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                progressManager.loadUserProgress(context: viewContext)
            }
            .refreshable {
                progressManager.loadUserProgress(context: viewContext)
            }
        }
        .sheet(isPresented: $showingAchievements) {
            AchievementsView(progressManager: progressManager)
        }
    }
}

// MARK: - Progress Timeframe

enum ProgressTimeframe: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All Time"
}

// MARK: - User Level Overview View

struct UserLevelOverviewView: View {
    @ObservedObject var progressManager: ProgressManager
    
    var body: some View {
        VStack(spacing: 16) {
            // User avatar and level
            HStack {
                // Avatar placeholder
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text("L\(progressManager.currentLevel)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level \(progressManager.currentLevel)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("textColor1"))
                    
                    Text("Drum Apprentice")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Progress to next level
                    ProgressBar(
                        progress: progressManager.progressToNextLevel,
                        color: .blue,
                        height: 8
                    )
                    
                    Text("\(Int(progressManager.progressToNextLevel * 100))% to Level \(progressManager.currentLevel + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Quick stats
            HStack(spacing: 20) {
                QuickStatView(
                    title: "Total Stars",
                    value: "\(progressManager.totalStars)",
                    icon: "star.fill",
                    color: .yellow
                )
                
                QuickStatView(
                    title: "Trophies",
                    value: "\(progressManager.totalTrophies)",
                    icon: "trophy.fill",
                    color: .orange
                )
                
                QuickStatView(
                    title: "Practice Time",
                    value: formatPracticeTime(progressManager.totalPracticeTime),
                    icon: "clock.fill",
                    color: .green
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("controlsBackground"))
        )
    }
    
    private func formatPracticeTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        if hours > 0 {
            return "\(hours)h"
        } else {
            let minutes = Int(time) / 60
            return "\(minutes)m"
        }
    }
}

// MARK: - Quick Stat View

struct QuickStatView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color("textColor1"))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Daily Goal Streak View

struct DailyGoalStreakView: View {
    @ObservedObject var progressManager: ProgressManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Daily Goal & Streak")
                    .font(.headline)
                    .foregroundColor(Color("textColor1"))
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                // Daily goal progress
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "target")
                            .foregroundColor(.blue)
                        Text("Today's Goal")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(Int(progressManager.todaysPracticeTime / 60)) / \(progressManager.dailyGoalMinutes) min")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("textColor1"))
                    
                    ProgressBar(
                        progress: min(1.0, progressManager.todaysPracticeTime / (Double(progressManager.dailyGoalMinutes) * 60)),
                        color: .blue,
                        height: 8
                    )
                }
                
                Divider()
                    .frame(height: 60)
                
                // Current streak
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("Current Streak")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(progressManager.currentStreak) days")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("textColor1"))
                    
                    Text("Best: \(progressManager.maxStreak) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("controlsBackground"))
        )
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let progress: Double
    let color: Color
    let height: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: height)
                
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geometry.size.width * progress, height: height)
                    .animation(.easeInOut(duration: 0.5), value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Progress Charts View

struct ProgressChartsView: View {
    @ObservedObject var progressManager: ProgressManager
    @Binding var selectedTimeframe: ProgressTimeframe
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Practice History")
                    .font(.headline)
                    .foregroundColor(Color("textColor1"))
                
                Spacer()
                
                // Timeframe picker
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(ProgressTimeframe.allCases, id: \.self) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            // Practice time chart
            PracticeTimeChartView(
                progressManager: progressManager,
                timeframe: selectedTimeframe
            )
            
            // Weekly calendar view for current week
            if selectedTimeframe == .week {
                WeeklyCalendarView(progressManager: progressManager)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("controlsBackground"))
        )
    }
}

// MARK: - Practice Time Chart View

struct PracticeTimeChartView: View {
    @ObservedObject var progressManager: ProgressManager
    let timeframe: ProgressTimeframe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Minutes Practiced")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Simple bar chart
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(progressManager.getChartData(for: timeframe), id: \.date) { dataPoint in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(dataPoint.minutes > 0 ? Color.blue : Color.secondary.opacity(0.3))
                            .frame(width: 20, height: max(4, CGFloat(dataPoint.minutes) * 2))
                        
                        Text(formatChartLabel(dataPoint.date, timeframe: timeframe))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(-45))
                    }
                }
            }
            .frame(height: 120)
        }
    }
    
    private func formatChartLabel(_ date: Date, timeframe: ProgressTimeframe) -> String {
        let formatter = DateFormatter()
        switch timeframe {
        case .week:
            formatter.dateFormat = "E"
        case .month:
            formatter.dateFormat = "d"
        case .year:
            formatter.dateFormat = "MMM"
        case .all:
            formatter.dateFormat = "yyyy"
        }
        return formatter.string(from: date)
    }
}

// MARK: - Weekly Calendar View

struct WeeklyCalendarView: View {
    @ObservedObject var progressManager: ProgressManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Week")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ForEach(progressManager.getCurrentWeekData(), id: \.date) { dayData in
                    VStack(spacing: 4) {
                        Text(formatDayName(dayData.date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Circle()
                            .fill(dayData.goalMet ? Color.green : (dayData.practiced ? Color.orange : Color.secondary.opacity(0.3)))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Group {
                                    if dayData.goalMet {
                                        Image(systemName: "checkmark")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                    } else if dayData.practiced {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 8, height: 8)
                                    }
                                }
                            )
                        
                        Text("\(dayData.minutes)m")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private func formatDayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

// MARK: - Recent Achievements View

struct RecentAchievementsView: View {
    @ObservedObject var progressManager: ProgressManager
    let onViewAll: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Achievements")
                    .font(.headline)
                    .foregroundColor(Color("textColor1"))
                
                Spacer()
                
                Button("View All") {
                    onViewAll()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if progressManager.recentAchievements.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("No achievements yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Complete lessons to earn your first achievement!")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(progressManager.recentAchievements.prefix(4), id: \.id) { achievement in
                        AchievementBadgeView(achievement: achievement)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("controlsBackground"))
        )
    }
}

// MARK: - Achievement Badge View

struct AchievementBadgeView: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: achievement.iconName)
                .font(.title2)
                .foregroundColor(achievement.color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(achievement.color.opacity(0.2))
                )
            
            Text(achievement.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color("textColor1"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("background"))
        )
    }
}

// MARK: - Statistics Summary View

struct StatisticsSummaryView: View {
    @ObservedObject var progressManager: ProgressManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Statistics")
                    .font(.headline)
                    .foregroundColor(Color("textColor1"))
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatisticCardView(
                    title: "Lessons Completed",
                    value: "\(progressManager.totalLessonsCompleted)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatisticCardView(
                    title: "Average Score",
                    value: "\(Int(progressManager.averageScore))%",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                )
                
                StatisticCardView(
                    title: "Perfect Notes",
                    value: "\(progressManager.totalPerfectNotes)",
                    icon: "star.fill",
                    color: .yellow
                )
                
                StatisticCardView(
                    title: "Days Practiced",
                    value: "\(progressManager.totalDaysPracticed)",
                    icon: "calendar.badge.checkmark",
                    color: .purple
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("controlsBackground"))
        )
    }
}

// MARK: - Statistic Card View

struct StatisticCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color("textColor1"))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("background"))
        )
    }
}

// MARK: - Achievements View

struct AchievementsView: View {
    @ObservedObject var progressManager: ProgressManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(progressManager.allAchievements, id: \.id) { achievement in
                        DetailedAchievementView(achievement: achievement)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// MARK: - Detailed Achievement View

struct DetailedAchievementView: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: achievement.iconName)
                .font(.system(size: 32))
                .foregroundColor(achievement.isUnlocked ? achievement.color : .secondary)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(achievement.isUnlocked ? achievement.color.opacity(0.2) : Color.secondary.opacity(0.1))
                )
            
            VStack(spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(achievement.isUnlocked ? Color("textColor1") : .secondary)
                    .multilineTextAlignment(.center)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            if achievement.isUnlocked {
                if let unlockedDate = achievement.unlockedDate {
                    Text("Unlocked \(formatDate(unlockedDate))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Locked")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("controlsBackground"))
        )
        .opacity(achievement.isUnlocked ? 1.0 : 0.6)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

struct ChartDataPoint {
    let date: Date
    let minutes: Int
}

struct WeekDayData {
    let date: Date
    let minutes: Int
    let practiced: Bool
    let goalMet: Bool
}

// 注意：Achievement 类型已在 ProgressManager.swift 中定义，这里不再重复定义
// 如果需要使用 Achievement，请直接使用 ProgressManager.swift 中的定义

// MARK: - Preview

struct ProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
    }
}