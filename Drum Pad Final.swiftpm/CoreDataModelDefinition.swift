import Foundation
import CoreData

// MARK: - Core Data Model Definition (Pure Code)
// 替代 DrumTrainerModel.xcdatamodeld 文件，解决 Swift Playgrounds 兼容性警告

/// 使用纯代码定义 Core Data 模型，避免 Swift Playgrounds 资源不可用警告
struct CoreDataModelDefinition {
    
    /// 创建并返回完整的 Core Data 模型
    static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // 创建所有实体
        let audioAssetsEntity = createAudioAssetsEntity()
        let courseEntity = createCourseEntity()
        let dailyProgressEntity = createDailyProgressEntity()
        let lessonEntity = createLessonEntity()
        let lessonStepEntity = createLessonStepEntity()
        let scoreResultEntity = createScoreResultEntity()
        let scoringProfileEntity = createScoringProfileEntity()
        let userProgressEntity = createUserProgressEntity()
        
        // 设置关系
        setupRelationships(
            audioAssets: audioAssetsEntity,
            course: courseEntity,
            dailyProgress: dailyProgressEntity,
            lesson: lessonEntity,
            lessonStep: lessonStepEntity,
            scoreResult: scoreResultEntity,
            scoringProfile: scoringProfileEntity,
            userProgress: userProgressEntity
        )
        
        model.entities = [
            audioAssetsEntity,
            courseEntity,
            dailyProgressEntity,
            lessonEntity,
            lessonStepEntity,
            scoreResultEntity,
            scoringProfileEntity,
            userProgressEntity
        ]
        
        return model
    }
    
    // MARK: - Entity Definitions
    
    private static func createAudioAssetsEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "AudioAssetsEntity"
        entity.managedObjectClassName = "AudioAssetsEntity"
        
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .stringAttributeType
        idAttr.isOptional = false
        
        let backingTrackURLAttr = NSAttributeDescription()
        backingTrackURLAttr.name = "backingTrackURL"
        backingTrackURLAttr.attributeType = .stringAttributeType
        backingTrackURLAttr.isOptional = true
        
        let clickTrackURLAttr = NSAttributeDescription()
        clickTrackURLAttr.name = "clickTrackURL"
        clickTrackURLAttr.attributeType = .stringAttributeType
        clickTrackURLAttr.isOptional = true
        
        let previewURLAttr = NSAttributeDescription()
        previewURLAttr.name = "previewURL"
        previewURLAttr.attributeType = .stringAttributeType
        previewURLAttr.isOptional = true
        
        let stemURLsDataAttr = NSAttributeDescription()
        stemURLsDataAttr.name = "stemURLsData"
        stemURLsDataAttr.attributeType = .binaryDataAttributeType
        stemURLsDataAttr.isOptional = false
        
        entity.properties = [idAttr, backingTrackURLAttr, clickTrackURLAttr, previewURLAttr, stemURLsDataAttr]
        
        return entity
    }
    
    private static func createCourseEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "Course"
        entity.managedObjectClassName = "Course"
        
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .stringAttributeType
        idAttr.isOptional = false
        
        let titleAttr = NSAttributeDescription()
        titleAttr.name = "title"
        titleAttr.attributeType = .stringAttributeType
        titleAttr.isOptional = false
        
        let descAttr = NSAttributeDescription()
        descAttr.name = "courseDescription"
        descAttr.attributeType = .stringAttributeType
        descAttr.isOptional = false
        
        let difficultyAttr = NSAttributeDescription()
        difficultyAttr.name = "difficulty"
        difficultyAttr.attributeType = .integer16AttributeType
        difficultyAttr.defaultValue = 1
        
        let estimatedDurationAttr = NSAttributeDescription()
        estimatedDurationAttr.name = "estimatedDuration"
        estimatedDurationAttr.attributeType = .doubleAttributeType
        estimatedDurationAttr.defaultValue = 0.0
        
        let isPublishedAttr = NSAttributeDescription()
        isPublishedAttr.name = "isPublished"
        isPublishedAttr.attributeType = .booleanAttributeType
        isPublishedAttr.defaultValue = false
        
        let tagsAttr = NSAttributeDescription()
        tagsAttr.name = "tags"
        tagsAttr.attributeType = .stringAttributeType
        tagsAttr.isOptional = false
        
        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false
        
        let updatedAtAttr = NSAttributeDescription()
        updatedAtAttr.name = "updatedAt"
        updatedAtAttr.attributeType = .dateAttributeType
        updatedAtAttr.isOptional = false
        
        entity.properties = [idAttr, titleAttr, descAttr, difficultyAttr, estimatedDurationAttr, isPublishedAttr, tagsAttr, createdAtAttr, updatedAtAttr]
        
        return entity
    }
    
    private static func createDailyProgressEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "DailyProgress"
        entity.managedObjectClassName = "DailyProgress"
        
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .stringAttributeType
        idAttr.isOptional = false
        
        let userIdAttr = NSAttributeDescription()
        userIdAttr.name = "userId"
        userIdAttr.attributeType = .stringAttributeType
        userIdAttr.isOptional = false
        
        let dateAttr = NSAttributeDescription()
        dateAttr.name = "date"
        dateAttr.attributeType = .dateAttributeType
        dateAttr.isOptional = false
        
        let practiceTimeAttr = NSAttributeDescription()
        practiceTimeAttr.name = "practiceTimeMinutes"
        practiceTimeAttr.attributeType = .integer16AttributeType
        practiceTimeAttr.defaultValue = 0
        
        let lessonsCompletedAttr = NSAttributeDescription()
        lessonsCompletedAttr.name = "lessonsCompleted"
        lessonsCompletedAttr.attributeType = .integer16AttributeType
        lessonsCompletedAttr.defaultValue = 0
        
        let starsEarnedAttr = NSAttributeDescription()
        starsEarnedAttr.name = "starsEarned"
        starsEarnedAttr.attributeType = .integer16AttributeType
        starsEarnedAttr.defaultValue = 0
        
        let goalAchievedAttr = NSAttributeDescription()
        goalAchievedAttr.name = "goalAchieved"
        goalAchievedAttr.attributeType = .booleanAttributeType
        goalAchievedAttr.defaultValue = false
        
        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false
        
        entity.properties = [idAttr, userIdAttr, dateAttr, practiceTimeAttr, lessonsCompletedAttr, starsEarnedAttr, goalAchievedAttr, createdAtAttr]
        
        return entity
    }
    
    private static func createLessonEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "Lesson"
        entity.managedObjectClassName = "Lesson"
        
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .stringAttributeType
        idAttr.isOptional = false
        
        let courseIdAttr = NSAttributeDescription()
        courseIdAttr.name = "courseId"
        courseIdAttr.attributeType = .stringAttributeType
        courseIdAttr.isOptional = true
        
        let titleAttr = NSAttributeDescription()
        titleAttr.name = "title"
        titleAttr.attributeType = .stringAttributeType
        titleAttr.isOptional = false
        
        let instrumentAttr = NSAttributeDescription()
        instrumentAttr.name = "instrument"
        instrumentAttr.attributeType = .stringAttributeType
        instrumentAttr.isOptional = false
        
        let difficultyAttr = NSAttributeDescription()
        difficultyAttr.name = "difficulty"
        difficultyAttr.attributeType = .integer16AttributeType
        difficultyAttr.defaultValue = 1
        
        let durationAttr = NSAttributeDescription()
        durationAttr.name = "duration"
        durationAttr.attributeType = .doubleAttributeType
        durationAttr.defaultValue = 0.0
        
        let defaultBPMAttr = NSAttributeDescription()
        defaultBPMAttr.name = "defaultBPM"
        defaultBPMAttr.attributeType = .floatAttributeType
        defaultBPMAttr.defaultValue = 120.0
        
        let timeSignatureNumeratorAttr = NSAttributeDescription()
        timeSignatureNumeratorAttr.name = "timeSignatureNumerator"
        timeSignatureNumeratorAttr.attributeType = .integer16AttributeType
        timeSignatureNumeratorAttr.defaultValue = 4
        
        let timeSignatureDenominatorAttr = NSAttributeDescription()
        timeSignatureDenominatorAttr.name = "timeSignatureDenominator"
        timeSignatureDenominatorAttr.attributeType = .integer16AttributeType
        timeSignatureDenominatorAttr.defaultValue = 4
        
        let tagsAttr = NSAttributeDescription()
        tagsAttr.name = "tags"
        tagsAttr.attributeType = .stringAttributeType
        tagsAttr.isOptional = false
        
        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false
        
        let updatedAtAttr = NSAttributeDescription()
        updatedAtAttr.name = "updatedAt"
        updatedAtAttr.attributeType = .dateAttributeType
        updatedAtAttr.isOptional = false
        
        entity.properties = [idAttr, courseIdAttr, titleAttr, instrumentAttr, difficultyAttr, durationAttr, defaultBPMAttr, timeSignatureNumeratorAttr, timeSignatureDenominatorAttr, tagsAttr, createdAtAttr, updatedAtAttr]
        
        return entity
    }
    
    private static func createLessonStepEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "LessonStep"
        entity.managedObjectClassName = "LessonStep"
        
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .stringAttributeType
        idAttr.isOptional = false
        
        let lessonIdAttr = NSAttributeDescription()
        lessonIdAttr.name = "lessonId"
        lessonIdAttr.attributeType = .stringAttributeType
        lessonIdAttr.isOptional = false
        
        let titleAttr = NSAttributeDescription()
        titleAttr.name = "title"
        titleAttr.attributeType = .stringAttributeType
        titleAttr.isOptional = false
        
        let descAttr = NSAttributeDescription()
        descAttr.name = "stepDescription"
        descAttr.attributeType = .stringAttributeType
        descAttr.isOptional = false
        
        let orderAttr = NSAttributeDescription()
        orderAttr.name = "order"
        orderAttr.attributeType = .integer16AttributeType
        orderAttr.defaultValue = 0
        
        let bpmOverrideAttr = NSAttributeDescription()
        bpmOverrideAttr.name = "bpmOverride"
        bpmOverrideAttr.attributeType = .floatAttributeType
        bpmOverrideAttr.defaultValue = 0.0
        
        let assistLevelAttr = NSAttributeDescription()
        assistLevelAttr.name = "assistLevel"
        assistLevelAttr.attributeType = .stringAttributeType
        assistLevelAttr.isOptional = false
        
        let targetEventsDataAttr = NSAttributeDescription()
        targetEventsDataAttr.name = "targetEventsData"
        targetEventsDataAttr.attributeType = .binaryDataAttributeType
        targetEventsDataAttr.isOptional = false
        
        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false
        
        entity.properties = [idAttr, lessonIdAttr, titleAttr, descAttr, orderAttr, bpmOverrideAttr, assistLevelAttr, targetEventsDataAttr, createdAtAttr]
        
        return entity
    }
    
    private static func createScoreResultEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "ScoreResultEntity"
        entity.managedObjectClassName = "ScoreResultEntity"
        
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .stringAttributeType
        idAttr.isOptional = false
        
        let lessonIdAttr = NSAttributeDescription()
        lessonIdAttr.name = "lessonId"
        lessonIdAttr.attributeType = .stringAttributeType
        lessonIdAttr.isOptional = false
        
        let totalScoreAttr = NSAttributeDescription()
        totalScoreAttr.name = "totalScore"
        totalScoreAttr.attributeType = .floatAttributeType
        totalScoreAttr.defaultValue = 0.0
        
        let starRatingAttr = NSAttributeDescription()
        starRatingAttr.name = "starRating"
        starRatingAttr.attributeType = .integer16AttributeType
        starRatingAttr.defaultValue = 0
        
        let isPlatinumAttr = NSAttributeDescription()
        isPlatinumAttr.name = "isPlatinum"
        isPlatinumAttr.attributeType = .booleanAttributeType
        isPlatinumAttr.defaultValue = false
        
        let isBlackStarAttr = NSAttributeDescription()
        isBlackStarAttr.name = "isBlackStar"
        isBlackStarAttr.attributeType = .booleanAttributeType
        isBlackStarAttr.defaultValue = false
        
        let streakCountAttr = NSAttributeDescription()
        streakCountAttr.name = "streakCount"
        streakCountAttr.attributeType = .integer16AttributeType
        streakCountAttr.defaultValue = 0
        
        let maxStreakAttr = NSAttributeDescription()
        maxStreakAttr.name = "maxStreak"
        maxStreakAttr.attributeType = .integer16AttributeType
        maxStreakAttr.defaultValue = 0
        
        let perfectCountAttr = NSAttributeDescription()
        perfectCountAttr.name = "perfectCount"
        perfectCountAttr.attributeType = .integer16AttributeType
        perfectCountAttr.defaultValue = 0
        
        let earlyCountAttr = NSAttributeDescription()
        earlyCountAttr.name = "earlyCount"
        earlyCountAttr.attributeType = .integer16AttributeType
        earlyCountAttr.defaultValue = 0
        
        let lateCountAttr = NSAttributeDescription()
        lateCountAttr.name = "lateCount"
        lateCountAttr.attributeType = .integer16AttributeType
        lateCountAttr.defaultValue = 0
        
        let missCountAttr = NSAttributeDescription()
        missCountAttr.name = "missCount"
        missCountAttr.attributeType = .integer16AttributeType
        missCountAttr.defaultValue = 0
        
        let extraCountAttr = NSAttributeDescription()
        extraCountAttr.name = "extraCount"
        extraCountAttr.attributeType = .integer16AttributeType
        extraCountAttr.defaultValue = 0
        
        let completionTimeAttr = NSAttributeDescription()
        completionTimeAttr.name = "completionTime"
        completionTimeAttr.attributeType = .doubleAttributeType
        completionTimeAttr.defaultValue = 0.0
        
        let playbackModeAttr = NSAttributeDescription()
        playbackModeAttr.name = "playbackMode"
        playbackModeAttr.attributeType = .stringAttributeType
        playbackModeAttr.isOptional = false
        
        let timingResultsDataAttr = NSAttributeDescription()
        timingResultsDataAttr.name = "timingResultsData"
        timingResultsDataAttr.attributeType = .binaryDataAttributeType
        timingResultsDataAttr.isOptional = false
        
        let completedAtAttr = NSAttributeDescription()
        completedAtAttr.name = "completedAt"
        completedAtAttr.attributeType = .dateAttributeType
        completedAtAttr.isOptional = false
        
        entity.properties = [idAttr, lessonIdAttr, totalScoreAttr, starRatingAttr, isPlatinumAttr, isBlackStarAttr, streakCountAttr, maxStreakAttr, perfectCountAttr, earlyCountAttr, lateCountAttr, missCountAttr, extraCountAttr, completionTimeAttr, playbackModeAttr, timingResultsDataAttr, completedAtAttr]
        
        return entity
    }
    
    private static func createScoringProfileEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "ScoringProfileEntity"
        entity.managedObjectClassName = "ScoringProfileEntity"
        
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .stringAttributeType
        idAttr.isOptional = false
        
        let perfectWindowAttr = NSAttributeDescription()
        perfectWindowAttr.name = "perfectWindow"
        perfectWindowAttr.attributeType = .doubleAttributeType
        perfectWindowAttr.defaultValue = 0.02
        
        let earlyWindowAttr = NSAttributeDescription()
        earlyWindowAttr.name = "earlyWindow"
        earlyWindowAttr.attributeType = .doubleAttributeType
        earlyWindowAttr.defaultValue = 0.05
        
        let lateWindowAttr = NSAttributeDescription()
        lateWindowAttr.name = "lateWindow"
        lateWindowAttr.attributeType = .doubleAttributeType
        lateWindowAttr.defaultValue = 0.05
        
        let missThresholdAttr = NSAttributeDescription()
        missThresholdAttr.name = "missThreshold"
        missThresholdAttr.attributeType = .doubleAttributeType
        missThresholdAttr.defaultValue = 0.1
        
        let extraPenaltyAttr = NSAttributeDescription()
        extraPenaltyAttr.name = "extraPenalty"
        extraPenaltyAttr.attributeType = .floatAttributeType
        extraPenaltyAttr.defaultValue = 0.05
        
        let gradePenaltyMultiplierAttr = NSAttributeDescription()
        gradePenaltyMultiplierAttr.name = "gradePenaltyMultiplier"
        gradePenaltyMultiplierAttr.attributeType = .floatAttributeType
        gradePenaltyMultiplierAttr.defaultValue = 1.0
        
        let streakBonusAttr = NSAttributeDescription()
        streakBonusAttr.name = "streakBonus"
        streakBonusAttr.attributeType = .floatAttributeType
        streakBonusAttr.defaultValue = 0.01
        
        entity.properties = [idAttr, perfectWindowAttr, earlyWindowAttr, lateWindowAttr, missThresholdAttr, extraPenaltyAttr, gradePenaltyMultiplierAttr, streakBonusAttr]
        
        return entity
    }
    
    private static func createUserProgressEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "UserProgress"
        entity.managedObjectClassName = "UserProgress"
        
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .stringAttributeType
        idAttr.isOptional = false
        
        let userIdAttr = NSAttributeDescription()
        userIdAttr.name = "userId"
        userIdAttr.attributeType = .stringAttributeType
        userIdAttr.isOptional = false
        
        let currentLevelAttr = NSAttributeDescription()
        currentLevelAttr.name = "currentLevel"
        currentLevelAttr.attributeType = .integer16AttributeType
        currentLevelAttr.defaultValue = 1
        
        let totalPracticeTimeAttr = NSAttributeDescription()
        totalPracticeTimeAttr.name = "totalPracticeTime"
        totalPracticeTimeAttr.attributeType = .doubleAttributeType
        totalPracticeTimeAttr.defaultValue = 0.0
        
        let totalStarsAttr = NSAttributeDescription()
        totalStarsAttr.name = "totalStars"
        totalStarsAttr.attributeType = .integer16AttributeType
        totalStarsAttr.defaultValue = 0
        
        let totalTrophiesAttr = NSAttributeDescription()
        totalTrophiesAttr.name = "totalTrophies"
        totalTrophiesAttr.attributeType = .integer16AttributeType
        totalTrophiesAttr.defaultValue = 0
        
        let currentStreakAttr = NSAttributeDescription()
        currentStreakAttr.name = "currentStreak"
        currentStreakAttr.attributeType = .integer16AttributeType
        currentStreakAttr.defaultValue = 0
        
        let maxStreakAttr = NSAttributeDescription()
        maxStreakAttr.name = "maxStreak"
        maxStreakAttr.attributeType = .integer16AttributeType
        maxStreakAttr.defaultValue = 0
        
        let dailyGoalMinutesAttr = NSAttributeDescription()
        dailyGoalMinutesAttr.name = "dailyGoalMinutes"
        dailyGoalMinutesAttr.attributeType = .integer16AttributeType
        dailyGoalMinutesAttr.defaultValue = 5
        
        let lastPracticeDateAttr = NSAttributeDescription()
        lastPracticeDateAttr.name = "lastPracticeDate"
        lastPracticeDateAttr.attributeType = .dateAttributeType
        lastPracticeDateAttr.isOptional = true
        
        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false
        
        let updatedAtAttr = NSAttributeDescription()
        updatedAtAttr.name = "updatedAt"
        updatedAtAttr.attributeType = .dateAttributeType
        updatedAtAttr.isOptional = false
        
        entity.properties = [idAttr, userIdAttr, currentLevelAttr, totalPracticeTimeAttr, totalStarsAttr, totalTrophiesAttr, currentStreakAttr, maxStreakAttr, dailyGoalMinutesAttr, lastPracticeDateAttr, createdAtAttr, updatedAtAttr]
        
        return entity
    }
    
    // MARK: - Relationships Setup
    
    private static func setupRelationships(
        audioAssets: NSEntityDescription,
        course: NSEntityDescription,
        dailyProgress: NSEntityDescription,
        lesson: NSEntityDescription,
        lessonStep: NSEntityDescription,
        scoreResult: NSEntityDescription,
        scoringProfile: NSEntityDescription,
        userProgress: NSEntityDescription
    ) {
        // AudioAssets <-> Lesson (one-to-many)
        let audioAssetsToLessons = NSRelationshipDescription()
        audioAssetsToLessons.name = "lessons"
        audioAssetsToLessons.destinationEntity = lesson
        audioAssetsToLessons.isOptional = true
        audioAssetsToLessons.deleteRule = .nullifyDeleteRule
        
        let lessonToAudioAssets = NSRelationshipDescription()
        lessonToAudioAssets.name = "audioAssets"
        lessonToAudioAssets.destinationEntity = audioAssets
        lessonToAudioAssets.maxCount = 1
        lessonToAudioAssets.isOptional = true
        lessonToAudioAssets.deleteRule = .cascadeDeleteRule
        
        audioAssetsToLessons.inverseRelationship = lessonToAudioAssets
        lessonToAudioAssets.inverseRelationship = audioAssetsToLessons
        
        // Course <-> Lesson (one-to-many)
        let courseToLessons = NSRelationshipDescription()
        courseToLessons.name = "lessons"
        courseToLessons.destinationEntity = lesson
        courseToLessons.isOptional = true
        courseToLessons.deleteRule = .cascadeDeleteRule
        
        let lessonToCourse = NSRelationshipDescription()
        lessonToCourse.name = "course"
        lessonToCourse.destinationEntity = course
        lessonToCourse.maxCount = 1
        lessonToCourse.isOptional = true
        lessonToCourse.deleteRule = .nullifyDeleteRule
        
        courseToLessons.inverseRelationship = lessonToCourse
        lessonToCourse.inverseRelationship = courseToLessons
        
        // Lesson <-> LessonStep (one-to-many)
        let lessonToSteps = NSRelationshipDescription()
        lessonToSteps.name = "steps"
        lessonToSteps.destinationEntity = lessonStep
        lessonToSteps.isOptional = true
        lessonToSteps.deleteRule = .cascadeDeleteRule
        
        let stepToLesson = NSRelationshipDescription()
        stepToLesson.name = "lesson"
        stepToLesson.destinationEntity = lesson
        stepToLesson.maxCount = 1
        stepToLesson.isOptional = true
        stepToLesson.deleteRule = .nullifyDeleteRule
        
        lessonToSteps.inverseRelationship = stepToLesson
        stepToLesson.inverseRelationship = lessonToSteps
        
        // Lesson <-> ScoreResult (one-to-many)
        let lessonToScoreResults = NSRelationshipDescription()
        lessonToScoreResults.name = "scoreResults"
        lessonToScoreResults.destinationEntity = scoreResult
        lessonToScoreResults.isOptional = true
        lessonToScoreResults.deleteRule = .cascadeDeleteRule
        
        let scoreResultToLesson = NSRelationshipDescription()
        scoreResultToLesson.name = "lesson"
        scoreResultToLesson.destinationEntity = lesson
        scoreResultToLesson.maxCount = 1
        scoreResultToLesson.isOptional = true
        scoreResultToLesson.deleteRule = .nullifyDeleteRule
        
        lessonToScoreResults.inverseRelationship = scoreResultToLesson
        scoreResultToLesson.inverseRelationship = lessonToScoreResults
        
        // Lesson <-> ScoringProfile (one-to-many)
        let lessonToScoringProfile = NSRelationshipDescription()
        lessonToScoringProfile.name = "scoringProfile"
        lessonToScoringProfile.destinationEntity = scoringProfile
        lessonToScoringProfile.maxCount = 1
        lessonToScoringProfile.isOptional = true
        lessonToScoringProfile.deleteRule = .cascadeDeleteRule
        
        let scoringProfileToLessons = NSRelationshipDescription()
        scoringProfileToLessons.name = "lessons"
        scoringProfileToLessons.destinationEntity = lesson
        scoringProfileToLessons.isOptional = true
        scoringProfileToLessons.deleteRule = .nullifyDeleteRule
        
        lessonToScoringProfile.inverseRelationship = scoringProfileToLessons
        scoringProfileToLessons.inverseRelationship = lessonToScoringProfile
        
        // UserProgress <-> DailyProgress (one-to-many)
        let userProgressToDailyProgress = NSRelationshipDescription()
        userProgressToDailyProgress.name = "dailyProgress"
        userProgressToDailyProgress.destinationEntity = dailyProgress
        userProgressToDailyProgress.isOptional = true
        userProgressToDailyProgress.deleteRule = .cascadeDeleteRule
        
        let dailyProgressToUserProgress = NSRelationshipDescription()
        dailyProgressToUserProgress.name = "userProgress"
        dailyProgressToUserProgress.destinationEntity = userProgress
        dailyProgressToUserProgress.maxCount = 1
        dailyProgressToUserProgress.isOptional = true
        dailyProgressToUserProgress.deleteRule = .nullifyDeleteRule
        
        userProgressToDailyProgress.inverseRelationship = dailyProgressToUserProgress
        dailyProgressToUserProgress.inverseRelationship = userProgressToDailyProgress
        
        // UserProgress <-> ScoreResult (one-to-many)
        let userProgressToScoreResults = NSRelationshipDescription()
        userProgressToScoreResults.name = "scoreResults"
        userProgressToScoreResults.destinationEntity = scoreResult
        userProgressToScoreResults.isOptional = true
        userProgressToScoreResults.deleteRule = .cascadeDeleteRule
        
        let scoreResultToUserProgress = NSRelationshipDescription()
        scoreResultToUserProgress.name = "userProgress"
        scoreResultToUserProgress.destinationEntity = userProgress
        scoreResultToUserProgress.maxCount = 1
        scoreResultToUserProgress.isOptional = true
        scoreResultToUserProgress.deleteRule = .nullifyDeleteRule
        
        userProgressToScoreResults.inverseRelationship = scoreResultToUserProgress
        scoreResultToUserProgress.inverseRelationship = userProgressToScoreResults
        
        // 添加关系到实体
        audioAssets.properties.append(audioAssetsToLessons)
        
        course.properties.append(courseToLessons)
        
        dailyProgress.properties.append(dailyProgressToUserProgress)
        
        lesson.properties.append(contentsOf: [lessonToAudioAssets, lessonToCourse, lessonToSteps, lessonToScoreResults, lessonToScoringProfile])
        
        lessonStep.properties.append(stepToLesson)
        
        scoreResult.properties.append(contentsOf: [scoreResultToLesson, scoreResultToUserProgress])
        
        scoringProfile.properties.append(scoringProfileToLessons)
        
        userProgress.properties.append(contentsOf: [userProgressToDailyProgress, userProgressToScoreResults])
    }
}
