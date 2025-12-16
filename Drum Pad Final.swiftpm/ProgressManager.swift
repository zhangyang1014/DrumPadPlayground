import Foundation
import CoreData
import Combine

// MARK: - Progress Manager Protocol

protocol ProgressManagerProtocol {
    func updateProgress(lessonId: String, score: ScoreResult)
    func getDailyProgress() -> DailyProgressData
    func updateStreak()
    func unlockAchievement(_ achievement: Achievement)
    func calculateLevel(from totalStars: Int) -> Int
    func calculateTrophies(from practiceTime: TimeInterval) -> Int
}

// MARK: - Progress Manager Implementation

public class ProgressManager: ObservableObject, ProgressManagerProtocol {
    
    // MARK: - Published Properties
    @Published var currentProgress: UserProgressData = UserProgressData()
    @Published var dailyProgress: DailyProgressData = DailyProgressData()
    @Published var achievements: [Achievement] = []
    @Published var recentScores: [ScoreResult] = []
    
    // MARK: - Private Properties
    private let coreDataManager: CoreDataManager
    private let userId: String
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    private let starsPerLevel = 10
    private let minutesPerTrophy = 60 // 1 hour = 1 trophy
    private let maxLevel = 100
    
    // MARK: - Initialization
    
    init(userId: String = "default_user", coreDataManager: CoreDataManager = .shared) {
        self.userId = userId
        self.coreDataManager = coreDataManager
        
        loadUserProgress()
        loadDailyProgress()
        setupNotifications()
    }
    
    // MARK: - Public Interface
    
    func updateProgress(lessonId: String, score: ScoreResult) {
        let userProgress = coreDataManager.getUserProgress(for: userId)
        
        // Create score result entity
        let scoreEntity = coreDataManager.saveScoreResult(score, for: lessonId, mode: .performance)
        
        // Update user progress
        let oldLevel = Int(userProgress.currentLevel)
        let oldTrophies = Int(userProgress.totalTrophies)
        
        userProgress.totalStars += Int16(score.starRating)
        userProgress.totalPracticeTime += score.completionTime
        userProgress.updatedAt = Date()
        
        // Calculate new level and trophies
        let newLevel = calculateLevel(from: Int(userProgress.totalStars))
        let newTrophies = calculateTrophies(from: userProgress.totalPracticeTime)
        
        userProgress.currentLevel = Int16(newLevel)
        userProgress.totalTrophies = Int16(newTrophies)
        
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
        
        // Save changes
        coreDataManager.save()
        
        // Refresh published properties
        loadUserProgress()
        loadDailyProgress()
        
        // Add to recent scores
        recentScores.insert(score, at: 0)
        if recentScores.count > 10 {
            recentScores.removeLast()
        }
    }
    
    func getDailyProgress() -> DailyProgressData {
        return dailyProgress
    }
    
    func updateStreak() {
        let userProgress = coreDataManager.getUserProgress(for: userId)
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        // Check if user practiced today
        let todayProgress = getDailyProgressEntity(for: today)
        let yesterdayProgress = getDailyProgressEntity(for: yesterday)
        
        if todayProgress?.goalAchieved == true {
            if yesterdayProgress?.goalAchieved == true || userProgress.currentStreak == 0 {
                // Continue or start streak
                userProgress.currentStreak += 1
                userProgress.maxStreak = max(userProgress.maxStreak, userProgress.currentStreak)
            }
        } else {
            // Check if streak should be broken (if it's past midnight and no practice today)
            let now = Date()
            let calendar = Calendar.current
            if calendar.component(.hour, from: now) >= 1 { // Give 1 hour grace period
                userProgress.currentStreak = 0
            }
        }
        
        userProgress.lastPracticeDate = Date()
        coreDataManager.save()
    }
    
    func unlockAchievement(_ achievement: Achievement) {
        if !achievements.contains(where: { $0.id == achievement.id }) {
            achievements.append(achievement)
            
            // Post notification for UI
            NotificationCenter.default.post(
                name: .achievementUnlocked,
                object: achievement
            )
        }
    }
    
    func calculateLevel(from totalStars: Int) -> Int {
        return min(maxLevel, max(1, (totalStars / starsPerLevel) + 1))
    }
    
    func calculateTrophies(from practiceTime: TimeInterval) -> Int {
        return Int(practiceTime / 60.0 / Double(minutesPerTrophy))
    }
    
    // MARK: - Progress Queries
    
    func getProgressSummary() -> ProgressSummary {
        let userProgress = coreDataManager.getUserProgress(for: userId)
        
        return ProgressSummary(
            currentLevel: Int(userProgress.currentLevel),
            totalStars: Int(userProgress.totalStars),
            currentStreak: Int(userProgress.currentStreak),
            maxStreak: Int(userProgress.maxStreak),
            totalTrophies: Int(userProgress.totalTrophies),
            totalPracticeTime: userProgress.totalPracticeTime,
            starsToNextLevel: starsToNextLevel(),
            progressToNextLevel: progressToNextLevel(),
            dailyGoalProgress: dailyGoalProgress(),
            recentAchievements: Array(achievements.suffix(3))
        )
    }
    
    func getWeeklyProgress() -> [DailyProgressData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var weeklyData: [DailyProgressData] = []
        
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let progress = getDailyProgressEntity(for: date)
            
            weeklyData.append(DailyProgressData(
                date: date,
                practiceTimeMinutes: Int(progress?.practiceTimeMinutes ?? 0),
                goalAchieved: progress?.goalAchieved ?? false,
                lessonsCompleted: Int(progress?.lessonsCompleted ?? 0),
                starsEarned: Int(progress?.starsEarned ?? 0)
            ))
        }
        
        return weeklyData.reversed()
    }
    
    func getMonthlyStats() -> MonthlyStats {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        let request: NSFetchRequest<DailyProgress> = DailyProgress.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND date >= %@", userId, startOfMonth as NSDate)
        
        do {
            let monthlyProgress = try coreDataManager.context.fetch(request)
            
            let totalPracticeTime = monthlyProgress.reduce(0) { $0 + Int($1.practiceTimeMinutes) }
            let daysWithGoalMet = monthlyProgress.filter { $0.goalAchieved }.count
            let totalLessons = monthlyProgress.reduce(0) { $0 + Int($1.lessonsCompleted) }
            let totalStars = monthlyProgress.reduce(0) { $0 + Int($1.starsEarned) }
            
            return MonthlyStats(
                totalPracticeMinutes: totalPracticeTime,
                daysWithGoalMet: daysWithGoalMet,
                totalLessonsCompleted: totalLessons,
                totalStarsEarned: totalStars,
                averageDailyPractice: totalPracticeTime / max(1, monthlyProgress.count)
            )
        } catch {
            print("Error fetching monthly stats: \(error)")
            return MonthlyStats()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadUserProgress() {
        let userProgress = coreDataManager.getUserProgress(for: userId)
        
        currentProgress = UserProgressData(
            currentLevel: Int(userProgress.currentLevel),
            totalStars: Int(userProgress.totalStars),
            currentStreak: Int(userProgress.currentStreak),
            maxStreak: Int(userProgress.maxStreak),
            totalTrophies: Int(userProgress.totalTrophies),
            dailyGoalMinutes: Int(userProgress.dailyGoalMinutes),
            totalPracticeTime: userProgress.totalPracticeTime,
            lastPracticeDate: userProgress.lastPracticeDate
        )
    }
    
    private func loadDailyProgress() {
        let today = Calendar.current.startOfDay(for: Date())
        let todayProgress = getDailyProgressEntity(for: today)
        
        dailyProgress = DailyProgressData(
            date: today,
            practiceTimeMinutes: Int(todayProgress?.practiceTimeMinutes ?? 0),
            goalAchieved: todayProgress?.goalAchieved ?? false,
            lessonsCompleted: Int(todayProgress?.lessonsCompleted ?? 0),
            starsEarned: Int(todayProgress?.starsEarned ?? 0)
        )
    }
    
    private func getDailyProgressEntity(for date: Date) -> DailyProgress? {
        let request: NSFetchRequest<DailyProgress> = DailyProgress.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND date == %@", userId, date as NSDate)
        request.fetchLimit = 1
        
        do {
            return try coreDataManager.context.fetch(request).first
        } catch {
            print("Error fetching daily progress: \(error)")
            return nil
        }
    }
    
    private func updateDailyProgress(practiceTime: TimeInterval, starsEarned: Int) {
        coreDataManager.updateDailyProgress(for: userId, practiceTime: practiceTime)
        
        // Update stars earned for today
        let today = Calendar.current.startOfDay(for: Date())
        if let todayProgress = getDailyProgressEntity(for: today) {
            todayProgress.starsEarned += Int16(starsEarned)
            coreDataManager.save()
        }
    }
    
    private func checkForAchievements(oldLevel: Int, newLevel: Int, oldTrophies: Int, newTrophies: Int, score: ScoreResult) {
        // Level up achievement
        if newLevel > oldLevel {
            unlockAchievement(Achievement.levelUp(level: newLevel))
        }
        
        // Trophy milestones
        let trophyMilestones = [1, 5, 10, 25, 50, 100]
        for milestone in trophyMilestones {
            if newTrophies >= milestone && oldTrophies < milestone {
                unlockAchievement(Achievement.trophyMilestone(count: milestone))
            }
        }
        
        // Perfect score achievement
        if score.totalScore >= 100.0 {
            unlockAchievement(Achievement.perfectScore)
        }
        
        // Streak achievements
        let streakMilestones = [3, 7, 14, 30, 100]
        for milestone in streakMilestones {
            if currentProgress.currentStreak >= milestone {
                unlockAchievement(Achievement.streakMilestone(days: milestone))
            }
        }
        
        // Star achievements
        let starMilestones = [10, 50, 100, 500, 1000]
        for milestone in starMilestones {
            if currentProgress.totalStars >= milestone {
                unlockAchievement(Achievement.starMilestone(count: milestone))
            }
        }
    }
    
    private func setupNotifications() {
        // Listen for day changes to update streaks
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .sink { [weak self] _ in
                self?.updateStreak()
                self?.loadDailyProgress()
            }
            .store(in: &cancellables)
    }
    
    private func starsToNextLevel() -> Int {
        let currentLevel = currentProgress.currentLevel
        let nextLevelStars = currentLevel * starsPerLevel
        return max(0, nextLevelStars - currentProgress.totalStars)
    }
    
    private func progressToNextLevel() -> Float {
        let currentLevelStars = (currentProgress.currentLevel - 1) * starsPerLevel
        let nextLevelStars = currentProgress.currentLevel * starsPerLevel
        let progressStars = currentProgress.totalStars - currentLevelStars
        let totalStarsNeeded = nextLevelStars - currentLevelStars
        
        return Float(progressStars) / Float(totalStarsNeeded)
    }
    
    private func dailyGoalProgress() -> Float {
        return Float(dailyProgress.practiceTimeMinutes) / Float(currentProgress.dailyGoalMinutes)
    }
}

// MARK: - Data Structures

public struct UserProgressData {
    let currentLevel: Int
    let totalStars: Int
    let currentStreak: Int
    let maxStreak: Int
    let totalTrophies: Int
    let dailyGoalMinutes: Int
    let totalPracticeTime: TimeInterval
    let lastPracticeDate: Date?
    
    init(
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

public struct DailyProgressData {
    let date: Date
    let practiceTimeMinutes: Int
    let goalAchieved: Bool
    let lessonsCompleted: Int
    let starsEarned: Int
    
    init(
        date: Date = Date(),
        practiceTimeMinutes: Int = 0,
        goalAchieved: Bool = false,
        lessonsCompleted: Int = 0,
        starsEarned: Int = 0
    ) {
        self.date = date
        self.practiceTimeMinutes = practiceTimeMinutes
        self.goalAchieved = goalAchieved
        self.lessonsCompleted = lessonsCompleted
        self.starsEarned = starsEarned
    }
}

public struct ProgressSummary {
    let currentLevel: Int
    let totalStars: Int
    let currentStreak: Int
    let maxStreak: Int
    let totalTrophies: Int
    let totalPracticeTime: TimeInterval
    let starsToNextLevel: Int
    let progressToNextLevel: Float
    let dailyGoalProgress: Float
    let recentAchievements: [Achievement]
}

public struct MonthlyStats {
    let totalPracticeMinutes: Int
    let daysWithGoalMet: Int
    let totalLessonsCompleted: Int
    let totalStarsEarned: Int
    let averageDailyPractice: Int
    
    init(
        totalPracticeMinutes: Int = 0,
        daysWithGoalMet: Int = 0,
        totalLessonsCompleted: Int = 0,
        totalStarsEarned: Int = 0,
        averageDailyPractice: Int = 0
    ) {
        self.totalPracticeMinutes = totalPracticeMinutes
        self.daysWithGoalMet = daysWithGoalMet
        self.totalLessonsCompleted = totalLessonsCompleted
        self.totalStarsEarned = totalStarsEarned
        self.averageDailyPractice = averageDailyPractice
    }
}

// MARK: - Achievement System

public struct Achievement: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let description: String
    public let iconName: String
    public let unlockedAt: Date
    public let category: AchievementCategory
    
    public init(id: String, title: String, description: String, iconName: String, category: AchievementCategory) {
        self.id = id
        self.title = title
        self.description = description
        self.iconName = iconName
        self.unlockedAt = Date()
        self.category = category
    }
    
    // MARK: - Predefined Achievements
    
    static func levelUp(level: Int) -> Achievement {
        return Achievement(
            id: "level_\(level)",
            title: "Level \(level) Reached!",
            description: "You've reached level \(level)!",
            iconName: "star.fill",
            category: .level
        )
    }
    
    static func trophyMilestone(count: Int) -> Achievement {
        return Achievement(
            id: "trophy_\(count)",
            title: "\(count) Trophies",
            description: "You've earned \(count) trophies!",
            iconName: "trophy.fill",
            category: .trophy
        )
    }
    
    static let perfectScore = Achievement(
        id: "perfect_score",
        title: "Perfect Performance",
        description: "You achieved a perfect 100% score!",
        iconName: "star.circle.fill",
        category: .performance
    )
    
    static func streakMilestone(days: Int) -> Achievement {
        return Achievement(
            id: "streak_\(days)",
            title: "\(days) Day Streak",
            description: "You've practiced for \(days) days in a row!",
            iconName: "flame.fill",
            category: .streak
        )
    }
    
    static func starMilestone(count: Int) -> Achievement {
        return Achievement(
            id: "stars_\(count)",
            title: "\(count) Stars",
            description: "You've earned \(count) stars!",
            iconName: "star.fill",
            category: .stars
        )
    }
}

public enum AchievementCategory: String, CaseIterable {
    case level = "level"
    case trophy = "trophy"
    case performance = "performance"
    case streak = "streak"
    case stars = "stars"
    
    public var displayName: String {
        switch self {
        case .level: return "Level"
        case .trophy: return "Trophy"
        case .performance: return "Performance"
        case .streak: return "Streak"
        case .stars: return "Stars"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
    static let levelUp = Notification.Name("levelUp")
    static let streakUpdated = Notification.Name("streakUpdated")
    static let dailyGoalAchieved = Notification.Name("dailyGoalAchieved")
    static let coreDataError = Notification.Name("coreDataError")
}