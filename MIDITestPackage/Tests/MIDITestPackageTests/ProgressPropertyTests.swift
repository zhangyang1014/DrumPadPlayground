import Testing
import Foundation
@testable import MIDITestPackage

// MARK: - Test Data Generators for Progress System

struct ProgressTestGenerators {
    
    static func generateScoreResult(
        scoreRange: ClosedRange<Float> = 0...100,
        starRange: ClosedRange<Int> = 0...3,
        timeRange: ClosedRange<TimeInterval> = 60...600
    ) -> ScoreResult {
        let score = Float.random(in: scoreRange)
        let stars = Int.random(in: starRange)
        
        return ScoreResult(
            totalScore: score,
            starRating: stars,
            isPlatinum: score >= 100.0,
            isBlackStar: false,
            timingResults: [],
            streakCount: Int.random(in: 0...10),
            maxStreak: Int.random(in: 0...20),
            missCount: Int.random(in: 0...10),
            extraCount: Int.random(in: 0...5),
            perfectCount: Int.random(in: 0...50),
            earlyCount: Int.random(in: 0...10),
            lateCount: Int.random(in: 0...10),
            completionTime: TimeInterval.random(in: timeRange)
        )
    }
    
    static func generateUserProgress(
        levelRange: ClosedRange<Int> = 1...50,
        starRange: ClosedRange<Int> = 0...500,
        streakRange: ClosedRange<Int> = 0...30
    ) -> MockUserProgress {
        return MockUserProgress(
            currentLevel: Int.random(in: levelRange),
            totalStars: Int.random(in: starRange),
            currentStreak: Int.random(in: streakRange),
            maxStreak: Int.random(in: streakRange),
            totalTrophies: Int.random(in: 0...20),
            dailyGoalMinutes: Int.random(in: 5...60),
            totalPracticeTime: TimeInterval.random(in: 0...36000), // 0-10 hours
            lastPracticeDate: Date()
        )
    }
    
    static func generateDailyProgressSequence(days: Int) -> [MockDailyProgress] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var sequence: [MockDailyProgress] = []
        
        for i in 0..<days {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let progress = MockDailyProgress(
                date: date,
                practiceTimeMinutes: Int.random(in: 0...60),
                goalAchieved: Bool.random(),
                lessonsCompleted: Int.random(in: 0...10),
                starsEarned: Int.random(in: 0...15)
            )
            sequence.append(progress)
        }
        
        return sequence.reversed()
    }
    
    static func generateConsecutiveGoalAchievements(days: Int) -> [MockDailyProgress] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var sequence: [MockDailyProgress] = []
        
        for i in 0..<days {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let progress = MockDailyProgress(
                date: date,
                practiceTimeMinutes: Int.random(in: 5...60), // Always meet goal
                goalAchieved: true,
                lessonsCompleted: Int.random(in: 1...5),
                starsEarned: Int.random(in: 1...10)
            )
            sequence.append(progress)
        }
        
        return sequence.reversed()
    }
}

// MARK: - Property Tests for Progress System

@Suite("Progress System Property Tests")
struct ProgressPropertyTests {
    
    // **Feature: melodic-drum-trainer, Property 21: 进度更新原子性**
    // *For any* 课程完成事件，用户等级和星级统计应该同时更新且保持一致
    @Test("Property 21: Progress Update Atomicity", .tags(.propertyBased))
    func testProgressUpdateAtomicity() async throws {
        for _ in 0..<100 {
            let initialProgress = ProgressTestGenerators.generateUserProgress()
            let progressManager = MockProgressManager(userProgress: initialProgress)
            let scoreResult = ProgressTestGenerators.generateScoreResult()
            
            let oldLevel = progressManager.userProgress.currentLevel
            let oldStars = progressManager.userProgress.totalStars
            let oldTrophies = progressManager.userProgress.totalTrophies
            let oldPracticeTime = progressManager.userProgress.totalPracticeTime
            
            // Update progress
            progressManager.updateProgress(lessonId: "test_lesson", score: scoreResult)
            
            // Verify atomic updates
            let newLevel = progressManager.userProgress.currentLevel
            let newStars = progressManager.userProgress.totalStars
            let newTrophies = progressManager.userProgress.totalTrophies
            let newPracticeTime = progressManager.userProgress.totalPracticeTime
            
            // Stars should increase by exactly the score's star rating
            #expect(newStars == oldStars + scoreResult.starRating, 
                   "Stars should increase atomically by score star rating")
            
            // Practice time should increase by exactly the completion time
            #expect(abs(newPracticeTime - (oldPracticeTime + scoreResult.completionTime)) < 0.001,
                   "Practice time should increase atomically by completion time")
            
            // Level should be consistent with total stars
            let expectedLevel = progressManager.calculateLevel(from: newStars)
            #expect(newLevel == expectedLevel,
                   "Level should be consistent with total stars after update")
            
            // Trophies should be consistent with total practice time
            let expectedTrophies = progressManager.calculateTrophies(from: newPracticeTime)
            #expect(newTrophies == expectedTrophies,
                   "Trophies should be consistent with total practice time after update")
        }
    }
    
    // **Feature: melodic-drum-trainer, Property 22: 每日目标累积性**
    // *For any* 练习会话，当累计时间达到5分钟时应该标记每日目标完成
    @Test("Property 22: Daily Goal Accumulation", .tags(.propertyBased))
    func testDailyGoalAccumulation() async throws {
        for _ in 0..<100 {
            let progressManager = MockProgressManager()
            let dailyGoalMinutes = 5
            
            // Generate multiple practice sessions for today
            let sessionCount = Int.random(in: 1...10)
            var expectedTotalSeconds = 0
            
            for _ in 0..<sessionCount {
                let sessionTime = TimeInterval.random(in: 30...300) // 30 seconds to 5 minutes
                let scoreResult = ScoreResult(
                    totalScore: Float.random(in: 0...100),
                    starRating: Int.random(in: 0...3),
                    isPlatinum: false,
                    isBlackStar: false,
                    timingResults: [],
                    streakCount: 0,
                    maxStreak: 0,
                    missCount: 0,
                    extraCount: 0,
                    perfectCount: 0,
                    earlyCount: 0,
                    lateCount: 0,
                    completionTime: sessionTime
                )
                
                progressManager.updateProgress(lessonId: "test_lesson_\(UUID().uuidString)", score: scoreResult)
                // Calculate expected total the same way the manager does - round each session individually
                expectedTotalSeconds += Int(round(sessionTime))
            }
            
            // Check daily progress
            let todayProgress = progressManager.getDailyProgress()
            // Calculate expected minutes the same way as the implementation
            let expectedMinutes = expectedTotalSeconds / 60
            
            #expect(todayProgress?.practiceTimeMinutes == expectedMinutes,
                   "Daily practice time should accumulate correctly: expected \(expectedMinutes), got \(todayProgress?.practiceTimeMinutes ?? 0)")
            
            // Check goal achievement
            if expectedMinutes >= dailyGoalMinutes {
                #expect(todayProgress?.goalAchieved == true,
                       "Daily goal should be achieved when practice time >= \(dailyGoalMinutes) minutes")
            } else {
                #expect(todayProgress?.goalAchieved == false,
                       "Daily goal should not be achieved when practice time < \(dailyGoalMinutes) minutes")
            }
        }
    }
    
    // **Feature: melodic-drum-trainer, Property 23: 连击重置保留性**
    // *For any* 连击中断事件，连击计数应该重置为0但奖杯进度应该保持不变
    @Test("Property 23: Streak Reset Preservation", .tags(.propertyBased))
    func testStreakResetPreservation() async throws {
        for _ in 0..<100 {
            // Start with a user who has some progress
            let initialProgress = ProgressTestGenerators.generateUserProgress(
                levelRange: 5...20,
                starRange: 50...200,
                streakRange: 5...15
            )
            let progressManager = MockProgressManager(userProgress: initialProgress)
            
            // Build up some consecutive days of goal achievement
            let streakDays = Int.random(in: 3...10)
            let consecutiveProgress = ProgressTestGenerators.generateConsecutiveGoalAchievements(days: streakDays)
            
            // Simulate the consecutive days
            for dayProgress in consecutiveProgress {
                progressManager.dailyProgress[dayProgress.date] = dayProgress
            }
            
            // Update streak based on consecutive achievements
            progressManager.updateStreak()
            
            let streakBeforeReset = progressManager.userProgress.currentStreak
            let trophiesBeforeReset = progressManager.userProgress.totalTrophies
            let levelBeforeReset = progressManager.userProgress.currentLevel
            let starsBeforeReset = progressManager.userProgress.totalStars
            
            #expect(streakBeforeReset > 0, "Should have a streak before reset")
            
            // Reset the streak (simulate missing a day)
            progressManager.resetStreak()
            
            let streakAfterReset = progressManager.userProgress.currentStreak
            let trophiesAfterReset = progressManager.userProgress.totalTrophies
            let levelAfterReset = progressManager.userProgress.currentLevel
            let starsAfterReset = progressManager.userProgress.totalStars
            
            // Verify streak is reset but other progress is preserved
            #expect(streakAfterReset == 0,
                   "Streak should be reset to 0 after interruption")
            
            #expect(trophiesAfterReset == trophiesBeforeReset,
                   "Trophies should be preserved after streak reset")
            
            #expect(levelAfterReset == levelBeforeReset,
                   "Level should be preserved after streak reset")
            
            #expect(starsAfterReset == starsBeforeReset,
                   "Stars should be preserved after streak reset")
        }
    }
    
    // Additional property test for level calculation consistency
    @Test("Level Calculation Consistency", .tags(.propertyBased))
    func testLevelCalculationConsistency() async throws {
        for _ in 0..<100 {
            let progressManager = MockProgressManager()
            let totalStars = Int.random(in: 0...1000)
            
            let calculatedLevel1 = progressManager.calculateLevel(from: totalStars)
            let calculatedLevel2 = progressManager.calculateLevel(from: totalStars)
            
            #expect(calculatedLevel1 == calculatedLevel2,
                   "Level calculation should be consistent for same input")
            
            // Test level progression
            if totalStars > 0 {
                let lowerLevel = progressManager.calculateLevel(from: totalStars - 1)
                #expect(calculatedLevel1 >= lowerLevel,
                       "Level should not decrease with more stars")
            }
            
            // Test level bounds
            #expect(calculatedLevel1 >= 1,
                   "Level should never be less than 1")
            #expect(calculatedLevel1 <= 100,
                   "Level should never exceed maximum level")
        }
    }
    
    // Additional property test for trophy calculation consistency
    @Test("Trophy Calculation Consistency", .tags(.propertyBased))
    func testTrophyCalculationConsistency() async throws {
        for _ in 0..<100 {
            let progressManager = MockProgressManager()
            let practiceTime = TimeInterval.random(in: 0...36000) // 0-10 hours
            
            let calculatedTrophies1 = progressManager.calculateTrophies(from: practiceTime)
            let calculatedTrophies2 = progressManager.calculateTrophies(from: practiceTime)
            
            #expect(calculatedTrophies1 == calculatedTrophies2,
                   "Trophy calculation should be consistent for same input")
            
            // Test trophy progression
            if practiceTime > 0 {
                let lowerTrophies = progressManager.calculateTrophies(from: practiceTime - 1)
                #expect(calculatedTrophies1 >= lowerTrophies,
                       "Trophies should not decrease with more practice time")
            }
            
            // Test trophy bounds
            #expect(calculatedTrophies1 >= 0,
                   "Trophies should never be negative")
        }
    }
    
    // Additional property test for streak logic
    @Test("Streak Logic Consistency", .tags(.propertyBased))
    func testStreakLogicConsistency() async throws {
        for _ in 0..<100 {
            let progressManager = MockProgressManager()
            let initialStreak = Int.random(in: 0...10)
            progressManager.userProgress.currentStreak = initialStreak
            // Ensure maxStreak is at least as large as currentStreak
            progressManager.userProgress.maxStreak = max(progressManager.userProgress.maxStreak, initialStreak)
            
            // Simulate achieving daily goal
            let practiceTime = TimeInterval.random(in: 300...3600) // 5 minutes to 1 hour
            let scoreResult = ScoreResult(
                totalScore: Float.random(in: 50...100),
                starRating: Int.random(in: 1...3),
                isPlatinum: false,
                isBlackStar: false,
                timingResults: [],
                streakCount: 0,
                maxStreak: 0,
                missCount: 0,
                extraCount: 0,
                perfectCount: 0,
                earlyCount: 0,
                lateCount: 0,
                completionTime: practiceTime
            )
            
            progressManager.updateProgress(lessonId: "test_lesson", score: scoreResult)
            
            let newStreak = progressManager.userProgress.currentStreak
            let maxStreak = progressManager.userProgress.maxStreak
            
            // Verify streak increment
            #expect(newStreak >= initialStreak,
                   "Streak should not decrease when goal is achieved")
            
            // Verify max streak tracking
            #expect(maxStreak >= newStreak,
                   "Max streak should always be >= current streak")
            #expect(maxStreak >= initialStreak,
                   "Max streak should never decrease")
        }
    }
}

