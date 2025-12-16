import Foundation

// MARK: - Progress System Types for Testing

public struct MockUserProgress {
    public var currentLevel: Int
    public var totalStars: Int
    public var currentStreak: Int
    public var maxStreak: Int
    public var totalTrophies: Int
    public var dailyGoalMinutes: Int
    public var totalPracticeTime: TimeInterval
    public var lastPracticeDate: Date?
    
    public init(
        currentLevel: Int = 1,
        totalStars: Int = 0,
        currentStreak: Int = 0,
        maxStreak: Int = 0,
        totalTrophies: Int = 0,
        dailyGoalMinutes: Int = 5,
        totalPracticeTime: TimeInterval = 0,
        lastPracticeDate: Date? = nil
    ) {
        self.currentLevel = currentLevel
        self.totalStars = totalStars
        self.currentStreak = currentStreak
        self.maxStreak = maxStreak
        self.totalTrophies = totalTrophies
        self.dailyGoalMinutes = dailyGoalMinutes
        self.totalPracticeTime = totalPracticeTime
        self.lastPracticeDate = lastPracticeDate
    }
}

public struct MockDailyProgress {
    public let date: Date
    public var practiceTimeMinutes: Int
    public var practiceTimeSeconds: Int // Track total seconds for accuracy
    public var goalAchieved: Bool
    public var lessonsCompleted: Int
    public var starsEarned: Int
    
    public init(
        date: Date = Date(),
        practiceTimeMinutes: Int = 0,
        practiceTimeSeconds: Int = 0,
        goalAchieved: Bool = false,
        lessonsCompleted: Int = 0,
        starsEarned: Int = 0
    ) {
        self.date = date
        self.practiceTimeMinutes = practiceTimeMinutes
        self.practiceTimeSeconds = practiceTimeSeconds
        self.goalAchieved = goalAchieved
        self.lessonsCompleted = lessonsCompleted
        self.starsEarned = starsEarned
    }
    
    public var isGoalMet: Bool {
        return practiceTimeMinutes >= 5 // Default daily goal
    }
}

public struct MockAchievement: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let description: String
    public let category: AchievementCategory
    public let unlockedAt: Date
    
    public init(id: String, title: String, description: String, category: AchievementCategory) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.unlockedAt = Date()
    }
    
    public static func == (lhs: MockAchievement, rhs: MockAchievement) -> Bool {
        return lhs.id == rhs.id
    }
}

public enum AchievementCategory: String, CaseIterable {
    case level = "level"
    case trophy = "trophy"
    case performance = "performance"
    case streak = "streak"
    case stars = "stars"
}

// MARK: - Mock Progress Manager

public class MockProgressManager {
    public var userProgress: MockUserProgress
    public var dailyProgress: [Date: MockDailyProgress] = [:]
    public var achievements: [MockAchievement] = []
    
    private let starsPerLevel = 10
    private let minutesPerTrophy = 60
    private let maxLevel = 100
    
    public init(userProgress: MockUserProgress = MockUserProgress()) {
        self.userProgress = userProgress
        // Ensure maxStreak is at least as large as currentStreak
        self.userProgress.maxStreak = max(self.userProgress.maxStreak, self.userProgress.currentStreak)
    }
    
    // MARK: - Progress Management
    
    public func updateProgress(lessonId: String, score: ScoreResult) {
        let oldLevel = userProgress.currentLevel
        let oldTrophies = userProgress.totalTrophies
        
        // Update user progress
        userProgress.totalStars += score.starRating
        userProgress.totalPracticeTime += score.completionTime
        
        // Calculate new level and trophies
        let newLevel = calculateLevel(from: userProgress.totalStars)
        let newTrophies = calculateTrophies(from: userProgress.totalPracticeTime)
        
        userProgress.currentLevel = newLevel
        userProgress.totalTrophies = newTrophies
        
        // Update daily progress
        updateDailyProgress(practiceTime: score.completionTime, starsEarned: score.starRating)
        
        // Check for achievements
        checkForAchievements(
            oldLevel: oldLevel,
            newLevel: newLevel,
            oldTrophies: oldTrophies,
            newTrophies: newTrophies,
            score: score
        )
        
        // Update streak
        updateStreak()
    }
    
    public func updateDailyProgress(practiceTime: TimeInterval, starsEarned: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        
        if var todayProgress = dailyProgress[today] {
            // Add to total seconds and recalculate minutes to avoid rounding issues
            todayProgress.practiceTimeSeconds += Int(round(practiceTime))
            todayProgress.practiceTimeMinutes = todayProgress.practiceTimeSeconds / 60
            todayProgress.starsEarned += starsEarned
            todayProgress.lessonsCompleted += 1
            todayProgress.goalAchieved = todayProgress.practiceTimeMinutes >= 5 // Update goal achievement based on new total
            dailyProgress[today] = todayProgress
        } else {
            let practiceSeconds = Int(round(practiceTime))
            let practiceMinutes = practiceSeconds / 60
            let newProgress = MockDailyProgress(
                date: today,
                practiceTimeMinutes: practiceMinutes,
                practiceTimeSeconds: practiceSeconds,
                goalAchieved: practiceMinutes >= 5, // Set goal achievement based on practice time
                lessonsCompleted: 1,
                starsEarned: starsEarned
            )
            dailyProgress[today] = newProgress
        }
    }
    
    public func updateStreak() {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        let todayProgress = dailyProgress[today]
        let yesterdayProgress = dailyProgress[yesterday]
        
        if todayProgress?.goalAchieved == true {
            if yesterdayProgress?.goalAchieved == true || userProgress.currentStreak == 0 {
                userProgress.currentStreak += 1
                userProgress.maxStreak = max(userProgress.maxStreak, userProgress.currentStreak)
            }
        } else {
            // Don't break streak immediately - give grace period
            // In real implementation, this would check time of day
        }
        
        userProgress.lastPracticeDate = Date()
    }
    
    public func resetStreak() {
        userProgress.currentStreak = 0
    }
    
    public func calculateLevel(from totalStars: Int) -> Int {
        return min(maxLevel, max(1, (totalStars / starsPerLevel) + 1))
    }
    
    public func calculateTrophies(from practiceTime: TimeInterval) -> Int {
        return Int(practiceTime / 60.0 / Double(minutesPerTrophy))
    }
    
    // MARK: - Achievement System
    
    private func checkForAchievements(oldLevel: Int, newLevel: Int, oldTrophies: Int, newTrophies: Int, score: ScoreResult) {
        // Level up achievement
        if newLevel > oldLevel {
            unlockAchievement(MockAchievement(
                id: "level_\(newLevel)",
                title: "Level \(newLevel) Reached!",
                description: "You've reached level \(newLevel)!",
                category: .level
            ))
        }
        
        // Trophy milestones
        let trophyMilestones = [1, 5, 10, 25, 50, 100]
        for milestone in trophyMilestones {
            if newTrophies >= milestone && oldTrophies < milestone {
                unlockAchievement(MockAchievement(
                    id: "trophy_\(milestone)",
                    title: "\(milestone) Trophies",
                    description: "You've earned \(milestone) trophies!",
                    category: .trophy
                ))
            }
        }
        
        // Perfect score achievement
        if score.totalScore >= 100.0 {
            unlockAchievement(MockAchievement(
                id: "perfect_score",
                title: "Perfect Performance",
                description: "You achieved a perfect 100% score!",
                category: .performance
            ))
        }
        
        // Streak achievements
        let streakMilestones = [3, 7, 14, 30]
        for milestone in streakMilestones {
            if userProgress.currentStreak >= milestone {
                unlockAchievement(MockAchievement(
                    id: "streak_\(milestone)",
                    title: "\(milestone) Day Streak",
                    description: "You've practiced for \(milestone) days in a row!",
                    category: .streak
                ))
            }
        }
    }
    
    private func unlockAchievement(_ achievement: MockAchievement) {
        if !achievements.contains(where: { $0.id == achievement.id }) {
            achievements.append(achievement)
        }
    }
    
    // MARK: - Progress Queries
    
    public func getDailyProgress(for date: Date = Date()) -> MockDailyProgress? {
        let dayStart = Calendar.current.startOfDay(for: date)
        return dailyProgress[dayStart]
    }
    
    public func getWeeklyProgress() -> [MockDailyProgress] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var weeklyData: [MockDailyProgress] = []
        
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let progress = dailyProgress[date] ?? MockDailyProgress(date: date)
            weeklyData.append(progress)
        }
        
        return weeklyData.reversed()
    }
    
    public func isStreakActive() -> Bool {
        guard let lastPractice = userProgress.lastPracticeDate else { return false }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastPracticeDay = calendar.startOfDay(for: lastPractice)
        
        let daysDifference = calendar.dateComponents([.day], from: lastPracticeDay, to: today).day ?? 0
        
        return daysDifference <= 1 // Allow for today or yesterday
    }
}