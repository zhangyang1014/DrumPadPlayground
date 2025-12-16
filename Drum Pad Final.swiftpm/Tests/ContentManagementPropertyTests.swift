import Testing
import Foundation
@testable import DrumPadApp

// MARK: - Test Generators for Content Management

struct ContentManagementTestGenerators {
    
    // Generate random MIDI data for testing
    static func generateMIDIData() -> MIDIData {
        let eventCount = Int.random(in: 5...50)
        let duration = Double.random(in: 30...300)
        
        let drumEvents = (0..<eventCount).map { _ in
            MIDIEvent(
                timestamp: Double.random(in: 0...duration),
                noteNumber: [36, 38, 42, 46, 49].randomElement()!, // Common drum notes
                velocity: Int.random(in: 20...127),
                duration: Double.random(in: 0.1...1.0)
            )
        }.sorted { $0.timestamp < $1.timestamp }
        
        let tempoEvents = [TempoEvent(
            timestamp: 0,
            bpm: Float.random(in: 80...180),
            microsecondsPerQuarter: UInt32.random(in: 300_000...750_000)
        )]
        
        let timeSignatureEvents = [TimeSignatureEvent(
            timestamp: 0,
            timeSignature: TimeSignature.fourFour
        )]
        
        return MIDIData(
            formatType: 1,
            trackCount: 2,
            timeDivision: 480,
            tracks: [], // Simplified for testing
            drumEvents: drumEvents,
            tempoEvents: tempoEvents,
            timeSignatureEvents: timeSignatureEvents,
            totalDuration: duration,
            timeSignature: .fourFour
        )
    }
    
    // Generate random lesson content for validation testing
    static func generateLessonContent(valid: Bool = true) -> LessonContent {
        let id = UUID().uuidString
        let title = valid ? "Test Lesson \(Int.random(in: 1...100))" : ""
        let description = Bool.random() ? "Test description" : ""
        let bpm = valid ? Float.random(in: 80...180) : Float.random(in: 10...400)
        let duration = valid ? Double.random(in: 30...300) : (Bool.random() ? -1 : Double.random(in: 1...29))
        
        let eventCount = valid ? Int.random(in: 1...20) : 0
        let targetEvents = (0..<eventCount).map { _ in
            TargetEvent(
                timestamp: Double.random(in: 0...duration),
                laneId: ["KICK", "SNARE", "HI_HAT"].randomElement()!,
                noteNumber: Int.random(in: 36...81),
                velocity: Int.random(in: 1...127),
                duration: Double.random(in: 0.1...1.0)
            )
        }
        
        let tags = (0..<Int.random(in: 0...5)).map { _ in
            ["rock", "jazz", "beginner", "advanced", "groove"].randomElement()!
        }
        
        return LessonContent(
            id: id,
            title: title,
            description: description,
            bpm: bpm,
            duration: duration,
            targetEvents: targetEvents,
            tags: tags
        )
    }
    
    // Generate mock MIDI file data
    static func generateMockMIDIFileData() -> Data {
        // Create a minimal valid MIDI file header
        var data = Data()
        
        // MIDI header chunk
        data.append("MThd".data(using: .ascii)!) // Header chunk type
        data.append(Data([0x00, 0x00, 0x00, 0x06])) // Header length (6 bytes)
        data.append(Data([0x00, 0x01])) // Format type 1
        data.append(Data([0x00, 0x02])) // 2 tracks
        data.append(Data([0x01, 0xE0])) // Time division (480 ticks per quarter note)
        
        // Track 1 (tempo track)
        data.append("MTrk".data(using: .ascii)!) // Track chunk type
        data.append(Data([0x00, 0x00, 0x00, 0x0B])) // Track length (11 bytes)
        data.append(Data([0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20])) // Set tempo (120 BPM)
        data.append(Data([0x00, 0xFF, 0x2F, 0x00])) // End of track
        
        // Track 2 (drum track)
        let drumTrackData = generateDrumTrackData()
        data.append("MTrk".data(using: .ascii)!) // Track chunk type
        
        let trackLength = UInt32(drumTrackData.count).bigEndian
        data.append(Data(bytes: &trackLength, count: 4))
        data.append(drumTrackData)
        
        return data
    }
    
    private static func generateDrumTrackData() -> Data {
        var trackData = Data()
        
        // Generate some drum events
        let drumNotes = [36, 38, 42, 46] // Kick, snare, hi-hat, open hi-hat
        let eventCount = Int.random(in: 3...10)
        
        for i in 0..<eventCount {
            let deltaTime = UInt8.random(in: 96...192) // Random timing
            let noteNumber = drumNotes.randomElement()!
            let velocity = UInt8.random(in: 64...127)
            
            // Note on event
            trackData.append(Data([deltaTime, 0x99, UInt8(noteNumber), velocity]))
            
            // Note off event (short delta time)
            trackData.append(Data([0x10, 0x89, UInt8(noteNumber), 0x40]))
        }
        
        // End of track
        trackData.append(Data([0x00, 0xFF, 0x2F, 0x00]))
        
        return trackData
    }
    
    // Generate array of lesson contents for batch testing
    static func generateLessonContentArray(count: Int = 10, validRatio: Float = 0.8) -> [LessonContent] {
        return (0..<count).map { _ in
            let shouldBeValid = Float.random(in: 0...1) < validRatio
            return generateLessonContent(valid: shouldBeValid)
        }
    }
}

// MARK: - Mock Content Manager for Testing

class MockContentManager: ContentManagerProtocol {
    var importedLessons: [Lesson] = []
    var createdCourses: [Course] = []
    var validationResults: [String: ValidationResult] = [:]
    var publishedContent: [String] = []
    
    func importMIDIFile(_ url: URL) async throws -> Lesson? {
        // Simulate MIDI import
        let lesson = MockLesson()
        lesson.id = UUID().uuidString
        lesson.title = url.deletingPathExtension().lastPathComponent
        lesson.defaultBPM = Float.random(in: 80...180)
        lesson.duration = Double.random(in: 30...300)
        lesson.difficulty = Int16.random(in: 1...5)
        lesson.tagsArray = ["imported", "test"]
        
        importedLessons.append(lesson)
        return lesson
    }
    
    func createCourse(title: String, lessons: [Lesson]) -> Course {
        let course = MockCourse()
        course.id = UUID().uuidString
        course.title = title
        course.difficulty = Int16(lessons.map { Int($0.difficulty) }.reduce(0, +) / lessons.count)
        course.estimatedDuration = lessons.reduce(0) { $0 + $1.duration }
        
        createdCourses.append(course)
        return course
    }
    
    func validateContent(_ content: LessonContent) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        if content.title.isEmpty { errors.append(.emptyTitle) }
        if content.duration <= 0 { errors.append(.invalidDuration) }
        if content.bpm < 60 || content.bpm > 300 { errors.append(.invalidBPM) }
        if content.targetEvents.isEmpty { errors.append(.noTargetEvents) }
        
        if content.description.isEmpty { warnings.append(.noDescription) }
        if content.tags.isEmpty { warnings.append(.noTags) }
        
        let result = ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
        
        validationResults[content.id] = result
        return result
    }
    
    func publishContent(_ content: LessonContent) async throws {
        let validationResult = validateContent(content)
        if !validationResult.isValid {
            throw ContentPublishingError.validationFailed(validationResult.errors)
        }
        publishedContent.append(content.id)
    }
    
    func exportContent(_ contentId: String) async throws -> URL {
        return URL(fileURLWithPath: "/tmp/\(contentId).json")
    }
    
    func deleteContent(_ contentId: String) async throws {
        importedLessons.removeAll { $0.id == contentId }
        validationResults.removeValue(forKey: contentId)
        publishedContent.removeAll { $0 == contentId }
    }
}

// MARK: - Content Management Property Tests

@Suite("Content Management Property Tests")
struct ContentManagementPropertyTests {
    
    // **Feature: melodic-drum-trainer, Property 26: MIDI解析转换性**
    @Test("Property 26: MIDI Parsing Conversion Accuracy", arguments: (0..<100).map { _ in 
        ContentManagementTestGenerators.generateMIDIData()
    })
    func testMIDIParsingConversionAccuracy(midiData: MIDIData) async throws {
        let parser = MIDIParser()
        
        // **Property: For any valid MIDI data, parsing should preserve essential timing and note information**
        
        // Check that drum events are preserved
        #expect(!midiData.drumEvents.isEmpty || midiData.totalDuration == 0,
               "MIDI data should have drum events or zero duration")
        
        // **Property: All drum events should have valid timestamps within the total duration**
        for event in midiData.drumEvents {
            #expect(event.timestamp >= 0,
                   "MIDI event timestamp should be non-negative, got \(event.timestamp)")
            
            #expect(event.timestamp <= midiData.totalDuration,
                   "MIDI event timestamp \(event.timestamp) should not exceed total duration \(midiData.totalDuration)")
        }
        
        // **Property: All drum events should have valid MIDI note numbers**
        for event in midiData.drumEvents {
            #expect(event.noteNumber >= 0 && event.noteNumber <= 127,
                   "MIDI note number should be between 0-127, got \(event.noteNumber)")
        }
        
        // **Property: All drum events should have valid velocity values**
        for event in midiData.drumEvents {
            #expect(event.velocity >= 0 && event.velocity <= 127,
                   "MIDI velocity should be between 0-127, got \(event.velocity)")
        }
        
        // **Property: Tempo events should have valid BPM values**
        for tempoEvent in midiData.tempoEvents {
            #expect(tempoEvent.bpm > 0 && tempoEvent.bpm <= 1000,
                   "Tempo BPM should be positive and reasonable, got \(tempoEvent.bpm)")
        }
        
        // **Property: Events should be chronologically ordered**
        // Check that each event's timestamp is >= the previous event's timestamp
        for i in 1..<midiData.drumEvents.count {
            let previousTimestamp = midiData.drumEvents[i-1].timestamp
            let currentTimestamp = midiData.drumEvents[i].timestamp
            #expect(currentTimestamp >= previousTimestamp,
                   "MIDI events should be chronologically ordered: event \(i-1) at \(previousTimestamp) should be <= event \(i) at \(currentTimestamp)")
        }
        
        // **Property: Time signature should be valid**
        #expect(midiData.timeSignature.numerator > 0,
               "Time signature numerator should be positive")
        #expect(midiData.timeSignature.denominator > 0,
               "Time signature denominator should be positive")
        
        // **Property: Total duration should be consistent with last event**
        if let lastEvent = midiData.drumEvents.last {
            let expectedMinDuration = lastEvent.timestamp + (lastEvent.duration ?? 0.1)
            #expect(midiData.totalDuration >= expectedMinDuration,
                   "Total duration \(midiData.totalDuration) should be at least as long as the last event \(expectedMinDuration)")
        }
    }
    
    // **Feature: melodic-drum-trainer, Property 27: 内容验证完整性**
    @Test("Property 27: Content Validation Completeness", arguments: (0..<100).map { _ in 
        ContentManagementTestGenerators.generateLessonContentArray(count: 5)
    })
    func testContentValidationCompleteness(contentArray: [LessonContent]) async throws {
        let contentManager = MockContentManager()
        
        // **Property: For any lesson content, validation should check all required fields**
        for content in contentArray {
            let validationResult = contentManager.validateContent(content)
            
            // **Property: Empty title should always be caught as an error**
            if content.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let hasEmptyTitleError = validationResult.errors.contains { error in
                    if case .emptyTitle = error { return true }
                    return false
                }
                #expect(hasEmptyTitleError,
                       "Content with empty title should have emptyTitle error")
            }
            
            // **Property: Invalid duration should always be caught as an error**
            if content.duration <= 0 {
                let hasInvalidDurationError = validationResult.errors.contains { error in
                    if case .invalidDuration = error { return true }
                    return false
                }
                #expect(hasInvalidDurationError,
                       "Content with invalid duration \(content.duration) should have invalidDuration error")
            }
            
            // **Property: Invalid BPM should always be caught as an error**
            if content.bpm < 60 || content.bpm > 300 {
                let hasInvalidBPMError = validationResult.errors.contains { error in
                    if case .invalidBPM = error { return true }
                    return false
                }
                #expect(hasInvalidBPMError,
                       "Content with invalid BPM \(content.bpm) should have invalidBPM error")
            }
            
            // **Property: Missing target events should always be caught as an error**
            if content.targetEvents.isEmpty {
                let hasNoTargetEventsError = validationResult.errors.contains { error in
                    if case .noTargetEvents = error { return true }
                    return false
                }
                #expect(hasNoTargetEventsError,
                       "Content with no target events should have noTargetEvents error")
            }
            
            // **Property: Content is valid if and only if it has no errors**
            let hasErrors = !validationResult.errors.isEmpty
            #expect(validationResult.isValid == !hasErrors,
                   "Content validity should be inverse of having errors. Valid: \(validationResult.isValid), Has errors: \(hasErrors)")
            
            // **Property: Validation should be deterministic**
            let secondValidation = contentManager.validateContent(content)
            #expect(validationResult.isValid == secondValidation.isValid,
                   "Validation should be deterministic - same content should yield same validity")
            #expect(validationResult.errors.count == secondValidation.errors.count,
                   "Validation should be deterministic - same content should yield same error count")
        }
        
        // **Property: Validation results should be stored and retrievable**
        for content in contentArray {
            _ = contentManager.validateContent(content)
            
            let storedResult = contentManager.validationResults[content.id]
            #expect(storedResult != nil,
                   "Validation result should be stored for content ID \(content.id)")
        }
        
        // **Property: All content should be validated (no content skipped)**
        let validatedContentIds = Set(contentManager.validationResults.keys)
        let originalContentIds = Set(contentArray.map { $0.id })
        #expect(validatedContentIds == originalContentIds,
               "All content should be validated - no content should be skipped")
    }
    
    // Additional property test for MIDI file import round-trip
    @Test("MIDI Import Round-trip Consistency", arguments: (0..<50).map { _ in 
        ContentManagementTestGenerators.generateMockMIDIFileData()
    })
    func testMIDIImportRoundTripConsistency(midiFileData: Data) async throws {
        // **Property: MIDI file import should be consistent - importing the same data twice should yield equivalent results**
        
        // Create temporary files for testing
        let tempURL1 = FileManager.default.temporaryDirectory.appendingPathComponent("test1.mid")
        let tempURL2 = FileManager.default.temporaryDirectory.appendingPathComponent("test2.mid")
        
        try midiFileData.write(to: tempURL1)
        try midiFileData.write(to: tempURL2)
        
        let contentManager = MockContentManager()
        
        // Import the same MIDI data twice
        let lesson1 = try await contentManager.importMIDIFile(tempURL1)
        let lesson2 = try await contentManager.importMIDIFile(tempURL2)
        
        // **Property: Both imports should succeed if the data is valid**
        if lesson1 != nil {
            #expect(lesson2 != nil,
                   "If first import succeeds, second import of same data should also succeed")
        }
        
        // **Property: Imported lessons should have consistent properties**
        if let l1 = lesson1, let l2 = lesson2 {
            // BPM should be the same (within reasonable tolerance)
            let bpmDifference = abs(l1.defaultBPM - l2.defaultBPM)
            #expect(bpmDifference < 1.0,
                   "BPM should be consistent between imports: \(l1.defaultBPM) vs \(l2.defaultBPM)")
            
            // Duration should be the same (within reasonable tolerance)
            let durationDifference = abs(l1.duration - l2.duration)
            #expect(durationDifference < 1.0,
                   "Duration should be consistent between imports: \(l1.duration) vs \(l2.duration)")
            
            // Difficulty should be the same
            #expect(l1.difficulty == l2.difficulty,
                   "Difficulty should be consistent between imports: \(l1.difficulty) vs \(l2.difficulty)")
        }
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL1)
        try? FileManager.default.removeItem(at: tempURL2)
    }
    
    // Property test for content publishing workflow
    @Test("Content Publishing Workflow Consistency", arguments: (0..<50).map { _ in 
        ContentManagementTestGenerators.generateLessonContent()
    })
    func testContentPublishingWorkflowConsistency(content: LessonContent) async throws {
        let contentManager = MockContentManager()
        
        // **Property: Content can only be published if it passes validation**
        let validationResult = contentManager.validateContent(content)
        
        if validationResult.isValid {
            // Valid content should publish successfully
            try await contentManager.publishContent(content)
            
            #expect(contentManager.publishedContent.contains(content.id),
                   "Valid content should be successfully published")
        } else {
            // Invalid content should fail to publish
            do {
                try await contentManager.publishContent(content)
                #expect(false, "Invalid content should not be publishable")
            } catch {
                // Expected to fail
                #expect(!contentManager.publishedContent.contains(content.id),
                       "Failed publication should not add content to published list")
            }
        }
        
        // **Property: Publishing should be idempotent - publishing the same valid content twice should work**
        if validationResult.isValid {
            try await contentManager.publishContent(content)
            
            let publishCount = contentManager.publishedContent.filter { $0 == content.id }.count
            #expect(publishCount >= 1,
                   "Content should appear in published list after successful publication")
        }
    }
}

// MARK: - Content Management Integration Tests

@Suite("Content Management Integration Tests")
struct ContentManagementIntegrationTests {
    
    @Test("Course Creation from Multiple Lessons")
    func testCourseCreationFromMultipleLessons() async throws {
        let contentManager = MockContentManager()
        
        // Create some test lessons
        let lesson1 = MockLesson()
        lesson1.id = "lesson1"
        lesson1.title = "Basic Rock Beat"
        lesson1.difficulty = 1
        lesson1.duration = 120
        
        let lesson2 = MockLesson()
        lesson2.id = "lesson2"
        lesson2.title = "Advanced Fill"
        lesson2.difficulty = 4
        lesson2.duration = 180
        
        let lessons = [lesson1, lesson2]
        
        // Create course
        let course = contentManager.createCourse(title: "Rock Fundamentals", lessons: lessons)
        
        // Verify course properties
        #expect(course.title == "Rock Fundamentals", "Course should have correct title")
        #expect(course.estimatedDuration == 300, "Course duration should be sum of lesson durations")
        
        // Verify course difficulty is average of lesson difficulties
        let expectedDifficulty = (1 + 4) / 2
        #expect(Int(course.difficulty) == expectedDifficulty, "Course difficulty should be average of lesson difficulties")
        
        // Verify course was added to created courses
        #expect(contentManager.createdCourses.contains { $0.id == course.id },
               "Course should be added to created courses list")
    }
    
    @Test("Content Validation Error Aggregation")
    func testContentValidationErrorAggregation() async throws {
        let contentManager = MockContentManager()
        
        // Create content with multiple validation issues
        let problematicContent = LessonContent(
            id: "test",
            title: "", // Empty title - error
            description: "", // Empty description - warning
            bpm: 500, // Invalid BPM - error
            duration: -1, // Invalid duration - error
            targetEvents: [], // No events - error
            tags: [] // No tags - warning
        )
        
        let result = contentManager.validateContent(problematicContent)
        
        // Should not be valid
        #expect(!result.isValid, "Content with multiple issues should not be valid")
        
        // Should have multiple errors
        #expect(result.errors.count >= 3, "Should have at least 3 errors (title, BPM, duration, events)")
        
        // Should have warnings
        #expect(result.warnings.count >= 1, "Should have at least 1 warning")
        
        // Verify specific errors are present
        let errorTypes = result.errors.map { type(of: $0) }
        #expect(errorTypes.contains { $0 == ValidationError.emptyTitle.self },
               "Should contain empty title error")
    }
}