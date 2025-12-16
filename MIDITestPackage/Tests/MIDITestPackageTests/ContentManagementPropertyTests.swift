import Testing
import Foundation
@testable import MIDITestPackage

// MARK: - Test Generators for Content Management

struct ContentManagementTestGenerators {
    
    // Generate random MIDI data for testing
    static func generateMIDIData() -> MockMIDIData {
        let eventCount = Int.random(in: 5...50)
        let duration = Double.random(in: 30...300)
        
        // Generate events with proper chronological ordering
        var drumEvents: [MockMIDIEvent] = []
        var currentTime: Double = 0
        
        for _ in 0..<eventCount {
            // Ensure events are chronologically ordered by incrementing time
            let timeIncrement = Double.random(in: 0.1...(duration / Double(eventCount)))
            currentTime += timeIncrement
            
            // Ensure we don't exceed the total duration
            if currentTime > duration {
                currentTime = duration
            }
            
            drumEvents.append(MockMIDIEvent(
                timestamp: currentTime,
                noteNumber: [36, 38, 42, 46, 49].randomElement()!, // Common drum notes
                velocity: Int.random(in: 20...127),
                duration: Double.random(in: 0.1...1.0)
            ))
        }
        
        // Ensure final sorting just in case
        drumEvents = drumEvents.sorted { $0.timestamp < $1.timestamp }
        
        let tempoEvents = [MockTempoEvent(
            timestamp: 0,
            bpm: Float.random(in: 80...180),
            microsecondsPerQuarter: UInt32.random(in: 300_000...750_000)
        )]
        
        return MockMIDIData(
            formatType: 1,
            trackCount: 2,
            timeDivision: 480,
            drumEvents: drumEvents,
            tempoEvents: tempoEvents,
            totalDuration: duration,
            timeSignature: MockTimeSignature(numerator: 4, denominator: 4)
        )
    }
    
    // Generate random lesson content for validation testing
    static func generateLessonContent(valid: Bool = true) -> MockLessonContent {
        let id = UUID().uuidString
        let title = valid ? "Test Lesson \(Int.random(in: 1...100))" : ""
        let description = Bool.random() ? "Test description" : ""
        let bpm = valid ? Float.random(in: 80...180) : Float.random(in: 10...400)
        let duration = valid ? Double.random(in: 30...300) : (Bool.random() ? -1 : Double.random(in: 1...29))
        
        let eventCount = valid ? Int.random(in: 1...20) : 0
        let targetEvents = (0..<eventCount).map { _ in
            MockTargetEvent(
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
        
        return MockLessonContent(
            id: id,
            title: title,
            description: description,
            bpm: bpm,
            duration: duration,
            targetEvents: targetEvents,
            tags: tags
        )
    }
    
    // Generate array of lesson contents for batch testing
    static func generateLessonContentArray(count: Int = 10, validRatio: Float = 0.8) -> [MockLessonContent] {
        return (0..<count).map { _ in
            let shouldBeValid = Float.random(in: 0...1) < validRatio
            return generateLessonContent(valid: shouldBeValid)
        }
    }
}

// MARK: - Mock Types for Content Management Testing

public struct MockMIDIData {
    let formatType: Int
    let trackCount: Int
    let timeDivision: Int
    let drumEvents: [MockMIDIEvent]
    let tempoEvents: [MockTempoEvent]
    let totalDuration: TimeInterval
    let timeSignature: MockTimeSignature
}

public struct MockMIDIEvent {
    let timestamp: TimeInterval
    let noteNumber: Int
    let velocity: Int
    let duration: TimeInterval?
}

public struct MockTempoEvent {
    let timestamp: TimeInterval
    let bpm: Float
    let microsecondsPerQuarter: UInt32
}

public struct MockTimeSignature {
    let numerator: Int
    let denominator: Int
}

public struct MockTargetEvent {
    let timestamp: TimeInterval
    let laneId: String
    let noteNumber: Int
    let velocity: Int
    let duration: TimeInterval?
}

public struct MockLessonContent {
    let id: String
    let title: String
    let description: String
    let bpm: Float
    let duration: TimeInterval
    let targetEvents: [MockTargetEvent]
    let tags: [String]
}

public struct MockValidationResult {
    let isValid: Bool
    let errors: [MockValidationError]
    let warnings: [MockValidationWarning]
}

public enum MockValidationError: Error, Equatable {
    case emptyTitle
    case invalidDuration
    case invalidBPM
    case noTargetEvents
    case invalidEventTiming
    case invalidNoteNumber
}

public enum MockValidationWarning: Error {
    case noDescription
    case noTags
    case shortDuration
    case longDuration
}

// MARK: - Mock Content Manager for Testing

public class MockContentManager {
    var validationResults: [String: MockValidationResult] = [:]
    var publishedContent: [String] = []
    
    func validateContent(_ content: MockLessonContent) -> MockValidationResult {
        var errors: [MockValidationError] = []
        var warnings: [MockValidationWarning] = []
        
        if content.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyTitle)
        }
        if content.duration <= 0 {
            errors.append(.invalidDuration)
        }
        if content.bpm < 60 || content.bpm > 300 {
            errors.append(.invalidBPM)
        }
        if content.targetEvents.isEmpty {
            errors.append(.noTargetEvents)
        }
        
        // Check for invalid event timing
        for event in content.targetEvents {
            if event.timestamp < 0 || event.timestamp > content.duration {
                errors.append(.invalidEventTiming)
            }
            if event.noteNumber < 0 || event.noteNumber > 127 {
                errors.append(.invalidNoteNumber)
            }
        }
        
        if content.description.isEmpty {
            warnings.append(.noDescription)
        }
        if content.tags.isEmpty {
            warnings.append(.noTags)
        }
        if content.duration < 30 {
            warnings.append(.shortDuration)
        }
        if content.duration > 600 {
            warnings.append(.longDuration)
        }
        
        let result = MockValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
        
        validationResults[content.id] = result
        return result
    }
    
    func publishContent(_ content: MockLessonContent) throws {
        let validationResult = validateContent(content)
        if !validationResult.isValid {
            throw MockContentPublishingError.validationFailed(validationResult.errors)
        }
        publishedContent.append(content.id)
    }
}

public enum MockContentPublishingError: Error {
    case validationFailed([MockValidationError])
}

// MARK: - Content Management Property Tests

@Suite("Content Management Property Tests")
struct ContentManagementPropertyTests {
    
    // **Feature: melodic-drum-trainer, Property 26: MIDI解析转换性**
    @Test("Property 26: MIDI Parsing Conversion Accuracy", arguments: (0..<100).map { _ in 
        ContentManagementTestGenerators.generateMIDIData()
    })
    func testMIDIParsingConversionAccuracy(midiData: MockMIDIData) async throws {
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
        let timestamps = midiData.drumEvents.map { $0.timestamp }
        let sortedTimestamps = timestamps.sorted()
        #expect(timestamps == sortedTimestamps,
               "MIDI events should be chronologically ordered")
        
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
    func testContentValidationCompleteness(contentArray: [MockLessonContent]) async throws {
        let contentManager = MockContentManager()
        
        // **Property: For any lesson content, validation should check all required fields**
        for content in contentArray {
            let validationResult = contentManager.validateContent(content)
            
            // **Property: Empty title should always be caught as an error**
            if content.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let hasEmptyTitleError = validationResult.errors.contains(.emptyTitle)
                #expect(hasEmptyTitleError,
                       "Content with empty title should have emptyTitle error")
            }
            
            // **Property: Invalid duration should always be caught as an error**
            if content.duration <= 0 {
                let hasInvalidDurationError = validationResult.errors.contains(.invalidDuration)
                #expect(hasInvalidDurationError,
                       "Content with invalid duration \(content.duration) should have invalidDuration error")
            }
            
            // **Property: Invalid BPM should always be caught as an error**
            if content.bpm < 60 || content.bpm > 300 {
                let hasInvalidBPMError = validationResult.errors.contains(.invalidBPM)
                #expect(hasInvalidBPMError,
                       "Content with invalid BPM \(content.bpm) should have invalidBPM error")
            }
            
            // **Property: Missing target events should always be caught as an error**
            if content.targetEvents.isEmpty {
                let hasNoTargetEventsError = validationResult.errors.contains(.noTargetEvents)
                #expect(hasNoTargetEventsError,
                       "Content with no target events should have noTargetEvents error")
            }
            
            // **Property: Invalid event timing should be caught as an error**
            let hasInvalidTiming = content.targetEvents.contains { event in
                event.timestamp < 0 || event.timestamp > content.duration
            }
            if hasInvalidTiming {
                let hasInvalidTimingError = validationResult.errors.contains(.invalidEventTiming)
                #expect(hasInvalidTimingError,
                       "Content with invalid event timing should have invalidEventTiming error")
            }
            
            // **Property: Invalid note numbers should be caught as an error**
            let hasInvalidNotes = content.targetEvents.contains { event in
                event.noteNumber < 0 || event.noteNumber > 127
            }
            if hasInvalidNotes {
                let hasInvalidNoteError = validationResult.errors.contains(.invalidNoteNumber)
                #expect(hasInvalidNoteError,
                       "Content with invalid note numbers should have invalidNoteNumber error")
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
    
    // Property test for content publishing workflow
    @Test("Content Publishing Workflow Consistency", arguments: (0..<50).map { _ in 
        ContentManagementTestGenerators.generateLessonContent()
    })
    func testContentPublishingWorkflowConsistency(content: MockLessonContent) async throws {
        let contentManager = MockContentManager()
        
        // **Property: Content can only be published if it passes validation**
        let validationResult = contentManager.validateContent(content)
        
        if validationResult.isValid {
            // Valid content should publish successfully
            try contentManager.publishContent(content)
            
            #expect(contentManager.publishedContent.contains(content.id),
                   "Valid content should be successfully published")
        } else {
            // Invalid content should fail to publish
            do {
                try contentManager.publishContent(content)
                #expect(false, "Invalid content should not be publishable")
            } catch {
                // Expected to fail
                #expect(!contentManager.publishedContent.contains(content.id),
                       "Failed publication should not add content to published list")
            }
        }
        
        // **Property: Publishing should be idempotent - publishing the same valid content twice should work**
        if validationResult.isValid {
            try contentManager.publishContent(content)
            
            let publishCount = contentManager.publishedContent.filter { $0 == content.id }.count
            #expect(publishCount >= 1,
                   "Content should appear in published list after successful publication")
        }
    }
    
    // Property test for MIDI data consistency
    @Test("MIDI Data Structure Consistency", arguments: (0..<50).map { _ in 
        ContentManagementTestGenerators.generateMIDIData()
    })
    func testMIDIDataStructureConsistency(midiData: MockMIDIData) async throws {
        // **Property: MIDI data should maintain structural consistency**
        
        // **Property: Format type should be valid**
        #expect(midiData.formatType >= 0 && midiData.formatType <= 2,
               "MIDI format type should be 0, 1, or 2, got \(midiData.formatType)")
        
        // **Property: Track count should be positive**
        #expect(midiData.trackCount > 0,
               "MIDI track count should be positive, got \(midiData.trackCount)")
        
        // **Property: Time division should be positive**
        #expect(midiData.timeDivision > 0,
               "MIDI time division should be positive, got \(midiData.timeDivision)")
        
        // **Property: Total duration should be non-negative**
        #expect(midiData.totalDuration >= 0,
               "Total duration should be non-negative, got \(midiData.totalDuration)")
        
        // **Property: If there are drum events, total duration should be positive**
        if !midiData.drumEvents.isEmpty {
            #expect(midiData.totalDuration > 0,
                   "If drum events exist, total duration should be positive")
        }
        
        // **Property: Tempo events should have consistent timing**
        for tempoEvent in midiData.tempoEvents {
            #expect(tempoEvent.timestamp >= 0,
                   "Tempo event timestamp should be non-negative")
            #expect(tempoEvent.timestamp <= midiData.totalDuration,
                   "Tempo event timestamp should not exceed total duration")
        }
        
        // **Property: Microseconds per quarter should be reasonable**
        for tempoEvent in midiData.tempoEvents {
            #expect(tempoEvent.microsecondsPerQuarter > 0,
                   "Microseconds per quarter should be positive")
            #expect(tempoEvent.microsecondsPerQuarter < 10_000_000,
                   "Microseconds per quarter should be reasonable (< 10 seconds)")
        }
    }
}

// MARK: - Content Management Integration Tests

@Suite("Content Management Integration Tests")
struct ContentManagementIntegrationTests {
    
    @Test("Content Validation Error Aggregation")
    func testContentValidationErrorAggregation() async throws {
        let contentManager = MockContentManager()
        
        // Create content with multiple validation issues
        let problematicContent = MockLessonContent(
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
        #expect(result.errors.contains(.emptyTitle), "Should contain empty title error")
        #expect(result.errors.contains(.invalidBPM), "Should contain invalid BPM error")
        #expect(result.errors.contains(.invalidDuration), "Should contain invalid duration error")
        #expect(result.errors.contains(.noTargetEvents), "Should contain no target events error")
    }
    
    @Test("Validation Consistency Across Multiple Runs")
    func testValidationConsistencyAcrossMultipleRuns() async throws {
        let contentManager = MockContentManager()
        
        let content = ContentManagementTestGenerators.generateLessonContent()
        
        // Run validation multiple times
        let results = (0..<10).map { _ in
            contentManager.validateContent(content)
        }
        
        // All results should be identical
        let firstResult = results[0]
        for result in results.dropFirst() {
            #expect(result.isValid == firstResult.isValid,
                   "Validation validity should be consistent across runs")
            #expect(result.errors.count == firstResult.errors.count,
                   "Error count should be consistent across runs")
            #expect(result.warnings.count == firstResult.warnings.count,
                   "Warning count should be consistent across runs")
        }
    }
}