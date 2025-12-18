import Foundation
import CoreData
import AVFoundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Content Manager Protocol

protocol ContentManagerProtocol {
    func importMIDIFile(_ url: URL) async throws -> Lesson?
    func createCourse(title: String, lessons: [Lesson]) -> Course
    func validateContent(_ content: LessonContent) -> CMValidationResult
    func publishContent(_ content: LessonContent) async throws
    func exportContent(_ contentId: String) async throws -> URL
    func deleteContent(_ contentId: String) async throws
}

// MARK: - Content Manager Implementation

class ContentManager: ObservableObject, ContentManagerProtocol {
    
    // MARK: - Published Properties
    @Published var isImporting: Bool = false
    @Published var importProgress: Float = 0.0
    @Published var lastImportResult: ContentImportResult?
    @Published var validationResults: [String: ContentValidationResult] = [:]
    
    // MARK: - Private Properties
    private let coreDataManager: CoreDataManager
    private let midiParser: MIDIParser
    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.midiParser = MIDIParser()
        
        setupObservers()
    }
    
    private func setupObservers() {
        // Listen for import progress updates
        midiParser.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.importProgress = progress
            }
            .store(in: &cancellables)
    }
    
    // MARK: - MIDI Import and Parsing
    
    func importMIDIFile(_ url: URL) async throws -> Lesson? {
        isImporting = true
        importProgress = 0.0
        
        defer {
            isImporting = false
            importProgress = 0.0
        }
        
        do {
            // Validate file format - now supports multiple formats
            let supportedExtensions = ["mid", "midi", "json", "xml", "gp5", "gp4", "ptb", "tux"]
            guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
                throw ContentImportError.invalidFileFormat
            }
            
            // Check file accessibility
            guard fileManager.fileExists(atPath: url.path) else {
                throw ContentImportError.fileNotFound
            }
            
            // Parse file based on format
            let midiData = try await parseFile(url)
            
            // Convert to lesson
            let lesson = try await convertMIDIDataToLesson(midiData, sourceURL: url)
            
            // Validate lesson
            let validationResult = ContentValidationResult.validate(
                ContentItem(
                    id: lesson.id,
                    title: lesson.title,
                    description: "",
                    type: .lesson,
                    difficulty: DifficultyLevel(rawValue: Int(lesson.difficulty)) ?? .beginner,
                    duration: lesson.duration,
                    tags: Set(lesson.tagsArray),
                    source: .lesson(lesson)
                )
            )
            
            validationResults[lesson.id] = validationResult
            
            if !validationResult.isValid {
                throw ContentImportError.validationFailed(validationResult.errors)
            }
            
            // Save to Core Data
            coreDataManager.save()
            
            // Create import result
            lastImportResult = ContentImportResult(
                success: true,
                importedContent: [ContentItem(
                    id: lesson.id,
                    title: lesson.title,
                    description: "",
                    type: .lesson,
                    difficulty: DifficultyLevel(rawValue: Int(lesson.difficulty)) ?? .beginner,
                    duration: lesson.duration,
                    tags: Set(lesson.tagsArray),
                    source: .lesson(lesson)
                )],
                errors: [],
                warnings: validationResult.warnings.map { _ in .dataLoss }
            )
            
            return lesson
            
        } catch {
            let importError: ContentImportResult.ImportError
            
            if let contentError = error as? ContentImportError {
                switch contentError {
                case .invalidFileFormat:
                    importError = .invalidFileFormat
                case .corruptedFile:
                    importError = .corruptedFile
                case .unsupportedVersion:
                    importError = .unsupportedVersion
                case .missingRequiredData:
                    importError = .missingRequiredData
                case .duplicateContent:
                    importError = .duplicateContent
                default:
                    importError = .corruptedFile
                }
            } else {
                importError = .corruptedFile
            }
            
            lastImportResult = ContentImportResult(
                success: false,
                importedContent: [],
                errors: [importError],
                warnings: []
            )
            
            throw error
        }
    }
    
    private func convertMIDIDataToLesson(_ midiData: MIDIData, sourceURL: URL) async throws -> Lesson {
        // Extract basic information
        let fileName = sourceURL.deletingPathExtension().lastPathComponent
        let title = fileName.replacingOccurrences(of: "_", with: " ").capitalized
        
        // Determine BPM from MIDI data
        let bpm = midiData.tempoEvents.first?.bpm ?? 120.0
        
        // Calculate duration
        let duration = midiData.totalDuration
        
        // Determine difficulty based on note density and complexity
        let difficulty = calculateDifficulty(from: midiData)
        
        // Generate tags based on content analysis
        let tags = generateTags(from: midiData, fileName: fileName)
        
        // Create lesson
        let lesson = coreDataManager.createLesson(
            title: title,
            instrument: "drums",
            defaultBPM: bpm,
            timeSignature: midiData.timeSignature,
            duration: duration,
            tags: tags,
            difficulty: difficulty
        )
        
        // Create lesson steps from MIDI tracks
        try await createLessonSteps(from: midiData, for: lesson)
        
        // Create audio assets if available
        createAudioAssets(for: lesson, sourceURL: sourceURL)
        
        return lesson
    }
    
    private func createLessonSteps(from midiData: MIDIData, for lesson: Lesson) async throws {
        // Group MIDI events by difficulty/complexity - 使用 ParsedMIDIEvent
        let eventGroups = groupEventsByComplexity(midiData.drumEvents)
        
        for (index, eventGroup) in eventGroups.enumerated() {
            let stepTitle = "Step \(index + 1)"
            let stepDescription = generateStepDescription(for: eventGroup, stepNumber: index + 1)
            
            // Convert ParsedMIDIEvent to target events
            let targetEvents = eventGroup.map { midiEvent in
                TargetEvent(
                    timestamp: midiEvent.timestamp,
                    laneId: mapMIDINoteToDrumLane(midiEvent.noteNumber),
                    noteNumber: midiEvent.noteNumber,
                    velocity: midiEvent.velocity,
                    duration: midiEvent.duration
                )
            }
            
            // Determine assist level based on step complexity
            let assistLevel: AssistLevel = index == 0 ? .full : (index < eventGroups.count - 1 ? .reduced : .minimal)
            
            _ = coreDataManager.createLessonStep(
                lessonId: lesson.id,
                order: index,
                title: stepTitle,
                description: stepDescription,
                targetEvents: targetEvents,
                bpmOverride: 0, // Use lesson default
                assistLevel: assistLevel
            )
        }
    }
    
    private func groupEventsByComplexity(_ events: [ParsedMIDIEvent]) -> [[ParsedMIDIEvent]] {
        // Sort events by timestamp
        let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }
        
        // Simple grouping: divide into 3 steps of increasing complexity
        let totalEvents = sortedEvents.count
        let step1Count = totalEvents / 3
        let step2Count = totalEvents / 2
        
        var groups: [[ParsedMIDIEvent]] = []
        
        // Step 1: First third of events (simplest)
        if step1Count > 0 {
            groups.append(Array(sortedEvents.prefix(step1Count)))
        }
        
        // Step 2: First half of events (medium complexity)
        if step2Count > step1Count {
            groups.append(Array(sortedEvents.prefix(step2Count)))
        }
        
        // Step 3: All events (full complexity)
        groups.append(sortedEvents)
        
        return groups
    }
    
    private func mapMIDINoteToDrumLane(_ noteNumber: Int) -> String {
        // Standard GM drum mapping
        switch noteNumber {
        case 36: return "KICK"           // Bass Drum 1
        case 35: return "KICK"           // Bass Drum 2
        case 38, 40: return "SNARE"      // Snare Drum
        case 42: return "HI_HAT"         // Closed Hi-Hat
        case 46: return "OPEN_HI_HAT"    // Open Hi-Hat
        case 39: return "CLAP"           // Hand Clap
        case 49: return "CRASH"          // Crash Cymbal
        case 41, 43: return "LO_TOM"     // Low Tom
        case 45, 47: return "MID_TOM"    // Mid Tom
        case 48, 50: return "HI_TOM"     // High Tom
        default: return "OTHER"
        }
    }
    
    private func calculateDifficulty(from midiData: MIDIData) -> Int {
        let events = midiData.drumEvents
        let duration = midiData.totalDuration
        
        // Calculate note density (notes per second)
        let noteDensity = Double(events.count) / duration
        
        // Calculate complexity factors
        let uniqueNotes = Set(events.map { $0.noteNumber }).count
        let hasPolyrhythm = checkForPolyrhythm(events)
        let hasFastPassages = checkForFastPassages(events)
        
        // Determine difficulty based on factors
        var difficulty = 1
        
        if noteDensity > 2.0 { difficulty += 1 }
        if noteDensity > 4.0 { difficulty += 1 }
        if uniqueNotes > 4 { difficulty += 1 }
        if hasPolyrhythm { difficulty += 1 }
        if hasFastPassages { difficulty += 1 }
        
        return min(5, max(1, difficulty))
    }
    
    private func checkForPolyrhythm(_ events: [ParsedMIDIEvent]) -> Bool {
        // Simple polyrhythm detection: check for overlapping notes
        let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }
        
        for i in 0..<sortedEvents.count - 1 {
            let current = sortedEvents[i]
            let next = sortedEvents[i + 1]
            
            if let currentDuration = current.duration,
               next.timestamp < current.timestamp + currentDuration {
                return true
            }
        }
        
        return false
    }
    
    private func checkForFastPassages(_ events: [ParsedMIDIEvent]) -> Bool {
        // Check for rapid note sequences (< 0.25 seconds apart)
        let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }
        
        for i in 0..<sortedEvents.count - 1 {
            let timeDiff = sortedEvents[i + 1].timestamp - sortedEvents[i].timestamp
            if timeDiff < 0.25 {
                return true
            }
        }
        
        return false
    }
    
    private func generateTags(from midiData: MIDIData, fileName: String) -> [String] {
        var tags: [String] = []
        
        // Add difficulty-based tags
        let difficulty = calculateDifficulty(from: midiData)
        switch difficulty {
        case 1: tags.append("beginner")
        case 2: tags.append("intermediate")
        case 3: tags.append("advanced")
        case 4: tags.append("expert")
        case 5: tags.append("master")
        default: break
        }
        
        // Add tempo-based tags
        let bpm = midiData.tempoEvents.first?.bpm ?? 120.0
        if bpm < 80 {
            tags.append("slow")
        } else if bpm > 140 {
            tags.append("fast")
        }
        
        // Add content-based tags from filename
        let lowerFileName = fileName.lowercased()
        if lowerFileName.contains("rock") { tags.append("rock") }
        if lowerFileName.contains("jazz") { tags.append("jazz") }
        if lowerFileName.contains("latin") { tags.append("latin") }
        if lowerFileName.contains("fill") { tags.append("fills") }
        if lowerFileName.contains("groove") { tags.append("grooves") }
        if lowerFileName.contains("rudiment") { tags.append("rudiments") }
        
        // Add instrument-based tags
        let uniqueNotes = Set(midiData.drumEvents.map { $0.noteNumber })
        if uniqueNotes.contains(36) || uniqueNotes.contains(35) { tags.append("kick") }
        if uniqueNotes.contains(38) || uniqueNotes.contains(40) { tags.append("snare") }
        if uniqueNotes.contains(42) || uniqueNotes.contains(46) { tags.append("hihat") }
        
        return tags
    }
    
    // MARK: - Enhanced File Format Support
    
    private func parseFile(_ url: URL) async throws -> MIDIData {
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "mid", "midi":
            return try await midiParser.parseMIDIFile(url)
        case "json":
            return try await parseJSONDrumFile(url)
        case "xml":
            return try await parseMusicXMLFile(url)
        case "gp5", "gp4":
            return try await parseGuitarProFile(url)
        case "ptb":
            return try await parsePowerTabFile(url)
        case "tux":
            return try await parseTuxGuitarFile(url)
        default:
            throw ContentImportError.invalidFileFormat
        }
    }
    
    private func parseJSONDrumFile(_ url: URL) async throws -> MIDIData {
        let data = try Data(contentsOf: url)
        let jsonDrumData = try JSONDecoder().decode(JSONDrumData.self, from: data)
        
        // Convert JSON drum data to MIDIData - 使用 ParsedMIDIEvent
        let events = jsonDrumData.events.map { event in
            ParsedMIDIEvent(
                timestamp: event.time,
                noteNumber: mapDrumNameToMIDINote(event.drum),
                velocity: event.velocity ?? 100,
                duration: event.duration
            )
        }
        
        // 计算 microsecondsPerQuarter: 60,000,000 / BPM
        let microsecondsPerQuarter = UInt32(60_000_000 / Double(jsonDrumData.bpm))
        
        return MIDIData(
            drumEvents: events,
            tempoEvents: [TempoEvent(timestamp: 0, bpm: jsonDrumData.bpm, microsecondsPerQuarter: microsecondsPerQuarter)],
            timeSignature: jsonDrumData.timeSignature,
            totalDuration: jsonDrumData.duration
        )
    }
    
    private func parseMusicXMLFile(_ url: URL) async throws -> MIDIData {
        let xmlData = try Data(contentsOf: url)
        let xmlString = String(data: xmlData, encoding: .utf8) ?? ""
        
        // Simple XML parsing for drum notation - 使用 ParsedMIDIEvent
        var events: [ParsedMIDIEvent] = []
        var currentTime: TimeInterval = 0
        let bpm: Float = 120 // Default, could be parsed from XML
        
        // Parse XML structure (simplified implementation)
        let lines = xmlString.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("<note>") {
                // Extract note information from XML
                if let noteEvent = parseXMLNoteParsed(line, currentTime: currentTime) {
                    events.append(noteEvent)
                }
            }
            if line.contains("<duration>") {
                // Update current time based on duration
                currentTime += parseDurationFromXML(line, bpm: bpm)
            }
        }
        
        let microsecondsPerQuarter = UInt32(60_000_000 / Double(bpm))
        
        return MIDIData(
            drumEvents: events,
            tempoEvents: [TempoEvent(timestamp: 0, bpm: bpm, microsecondsPerQuarter: microsecondsPerQuarter)],
            timeSignature: TimeSignature(numerator: 4, denominator: 4),
            totalDuration: currentTime
        )
    }
    
    private func parseGuitarProFile(_ url: URL) async throws -> MIDIData {
        // Guitar Pro files contain binary data - this is a simplified parser
        let data = try Data(contentsOf: url)
        
        // Guitar Pro files have a specific binary format
        // This is a basic implementation that would need to be expanded
        var events: [ParsedMIDIEvent] = []
        let bpm: Float = 120
        
        // Look for drum track data in the binary file
        // Guitar Pro stores drum data in specific sections
        if let drumTrackData = extractDrumTrackFromGuitarPro(data) {
            events = parseDrumTrackDataParsed(drumTrackData)
        }
        
        let microsecondsPerQuarter = UInt32(60_000_000 / Double(bpm))
        
        return MIDIData(
            drumEvents: events,
            tempoEvents: [TempoEvent(timestamp: 0, bpm: bpm, microsecondsPerQuarter: microsecondsPerQuarter)],
            timeSignature: TimeSignature(numerator: 4, denominator: 4),
            totalDuration: calculateDurationFromParsed(from: events)
        )
    }
    
    private func parsePowerTabFile(_ url: URL) async throws -> MIDIData {
        // PowerTab files are also binary format
        let data = try Data(contentsOf: url)
        
        var events: [ParsedMIDIEvent] = []
        let bpm: Float = 120
        
        // PowerTab has a different binary structure than Guitar Pro
        if let drumData = extractDrumDataFromPowerTab(data) {
            events = parsePowerTabDrumData(drumData)
        }
        
        let microsecondsPerQuarter = UInt32(60_000_000 / Double(bpm))
        
        return MIDIData(
            drumEvents: events,
            tempoEvents: [TempoEvent(timestamp: 0, bpm: bpm, microsecondsPerQuarter: microsecondsPerQuarter)],
            timeSignature: TimeSignature(numerator: 4, denominator: 4),
            totalDuration: calculateDuration(from: events)
        )
    }
    
    private func parseTuxGuitarFile(_ url: URL) async throws -> MIDIData {
        // TuxGuitar files are XML-based
        let xmlData = try Data(contentsOf: url)
        let xmlString = String(data: xmlData, encoding: .utf8) ?? ""
        
        var events: [ParsedMIDIEvent] = []
        let bpm: Float = 120
        
        // Parse TuxGuitar XML format for drum tracks
        if let drumTrackXML = extractDrumTrackFromTuxGuitar(xmlString) {
            events = parseTuxGuitarDrumTrack(drumTrackXML)
        }
        
        let microsecondsPerQuarter = UInt32(60_000_000 / Double(bpm))
        
        return MIDIData(
            drumEvents: events,
            tempoEvents: [TempoEvent(timestamp: 0, bpm: bpm, microsecondsPerQuarter: microsecondsPerQuarter)],
            timeSignature: TimeSignature(numerator: 4, denominator: 4),
            totalDuration: calculateDuration(from: events)
        )
    }
    
    // MARK: - Helper Methods for File Parsing
    
    private func mapDrumNameToMIDINote(_ drumName: String) -> Int {
        switch drumName.lowercased() {
        case "kick", "bass", "bd": return 36
        case "snare", "sd": return 38
        case "hihat", "hh", "closed_hihat": return 42
        case "open_hihat", "oh": return 46
        case "crash", "cc": return 49
        case "ride", "rd": return 51
        case "hi_tom", "ht": return 50
        case "mid_tom", "mt": return 47
        case "lo_tom", "lt": return 43
        case "clap", "cp": return 39
        default: return 38 // Default to snare
        }
    }
    
    private func parseXMLNote(_ line: String, currentTime: TimeInterval) -> ParsedMIDIEvent? {
        // Simplified XML note parsing
        // In a real implementation, you'd use a proper XML parser
        guard line.contains("drum") else { return nil }
        
        let noteNumber = 38 // Default snare
        let velocity = 100
        
        return ParsedMIDIEvent(
            timestamp: currentTime,
            noteNumber: noteNumber,
            velocity: velocity,
            duration: 0.1
        )
    }
    
    // 别名函数用于兼容
    private func parseXMLNoteParsed(_ line: String, currentTime: TimeInterval) -> ParsedMIDIEvent? {
        return parseXMLNote(line, currentTime: currentTime)
    }
    
    private func parseDurationFromXML(_ line: String, bpm: Float) -> TimeInterval {
        // Parse duration from XML and convert to time
        // Simplified implementation
        return 60.0 / Double(bpm) / 4.0 // Quarter note duration
    }
    
    private func extractDrumTrackFromGuitarPro(_ data: Data) -> Data? {
        // Guitar Pro binary format parsing
        // This would need to implement the actual GP format specification
        return nil // Placeholder
    }
    
    private func parseDrumTrackData(_ data: Data) -> [ParsedMIDIEvent] {
        // Parse drum track data from Guitar Pro format
        return [] // Placeholder
    }
    
    // 别名函数用于兼容
    private func parseDrumTrackDataParsed(_ data: Data) -> [ParsedMIDIEvent] {
        return parseDrumTrackData(data)
    }
    
    private func extractDrumDataFromPowerTab(_ data: Data) -> Data? {
        // PowerTab binary format parsing
        return nil // Placeholder
    }
    
    private func parsePowerTabDrumData(_ data: Data) -> [ParsedMIDIEvent] {
        // Parse PowerTab drum data
        return [] // Placeholder
    }
    
    private func extractDrumTrackFromTuxGuitar(_ xmlString: String) -> String? {
        // Extract drum track XML from TuxGuitar file
        return nil // Placeholder
    }
    
    private func parseTuxGuitarDrumTrack(_ xmlString: String) -> [ParsedMIDIEvent] {
        // Parse TuxGuitar drum track XML
        return [] // Placeholder
    }
    
    private func calculateDuration(from events: [ParsedMIDIEvent]) -> TimeInterval {
        guard let lastEvent = events.max(by: { $0.timestamp < $1.timestamp }) else {
            return 0
        }
        return lastEvent.timestamp + (lastEvent.duration ?? 0.1)
    }
    
    // 别名函数用于兼容
    private func calculateDurationFromParsed(from events: [ParsedMIDIEvent]) -> TimeInterval {
        return calculateDuration(from: events)
    }
    
    private func generateStepDescription(for events: [ParsedMIDIEvent], stepNumber: Int) -> String {
        let noteCount = events.count
        let uniqueNotes = Set(events.map { $0.noteNumber }).count
        
        switch stepNumber {
        case 1:
            return "Basic pattern with \(noteCount) notes focusing on fundamental timing"
        case 2:
            return "Intermediate pattern with \(noteCount) notes and \(uniqueNotes) different drums"
        default:
            return "Complete pattern with all \(noteCount) notes and full complexity"
        }
    }
    
    private func createAudioAssets(for lesson: Lesson, sourceURL: URL) {
        // Create audio assets entity
        let audioAssets = AudioAssetsEntity(context: coreDataManager.context)
        audioAssets.id = UUID().uuidString
        
        // Try to find associated audio files
        let baseURL = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        
        // Look for common audio file extensions
        let audioExtensions = ["wav", "mp3", "aiff", "m4a"]
        
        for ext in audioExtensions {
            let audioURL = baseURL.appendingPathComponent(baseName).appendingPathExtension(ext)
            if fileManager.fileExists(atPath: audioURL.path) {
                audioAssets.backingTrackURL = audioURL.absoluteString
                break
            }
        }
        
        // Look for preview audio
        for ext in audioExtensions {
            let previewURL = baseURL.appendingPathComponent("\(baseName)_preview").appendingPathExtension(ext)
            if fileManager.fileExists(atPath: previewURL.path) {
                audioAssets.previewURL = previewURL.absoluteString
                break
            }
        }
        
        lesson.audioAssets = audioAssets
    }
    
    // MARK: - Course Management
    
    func createCourse(title: String, lessons: [Lesson]) -> Course {
        let course = coreDataManager.createCourse(
            title: title,
            description: "Course containing \(lessons.count) lessons",
            difficulty: calculateCourseDifficulty(lessons),
            tags: generateCourseTags(lessons)
        )
        
        // Link lessons to course
        for lesson in lessons {
            lesson.course = course
            lesson.courseId = course.id
        }
        
        // Calculate estimated duration
        let totalDuration = lessons.reduce(0) { $0 + $1.duration }
        course.estimatedDuration = totalDuration
        
        coreDataManager.save()
        return course
    }
    
    private func calculateCourseDifficulty(_ lessons: [Lesson]) -> Int {
        guard !lessons.isEmpty else { return 1 }
        
        let averageDifficulty = lessons.reduce(0) { $0 + Int($1.difficulty) } / lessons.count
        return max(1, min(5, averageDifficulty))
    }
    
    private func generateCourseTags(_ lessons: [Lesson]) -> [String] {
        var tagCounts: [String: Int] = [:]
        
        for lesson in lessons {
            for tag in lesson.tagsArray {
                tagCounts[tag, default: 0] += 1
            }
        }
        
        // Return tags that appear in at least 50% of lessons
        let threshold = lessons.count / 2
        return tagCounts.compactMap { tag, count in
            count >= threshold ? tag : nil
        }
    }
    
    // MARK: - Content Validation
    
    func validateContent(_ content: LessonContent) -> CMValidationResult {
        var errors: [CMValidationError] = []
        var warnings: [CMValidationWarning] = []
        
        // Validate basic properties
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
        
        // Validate target events
        for event in content.targetEvents {
            if event.timestamp < 0 || event.timestamp > content.duration {
                errors.append(.invalidEventTiming)
            }
            
            if event.noteNumber < 0 || event.noteNumber > 127 {
                errors.append(.invalidNoteNumber)
            }
        }
        
        // Generate warnings
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
        
        return CMValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    // MARK: - Content Publishing
    
    func publishContent(_ content: LessonContent) async throws {
        // Validate content before publishing
        let validationResult = validateContent(content)
        
        if !validationResult.isValid {
            throw ContentPublishingError.validationFailed(validationResult.errors)
        }
        
        // Mark as published in database
        if let lesson = coreDataManager.fetchLesson(by: content.id) {
            lesson.updatedAt = Date()
            coreDataManager.save()
        }
        
        // Could add cloud publishing logic here
        // For now, just mark as published locally
    }
    
    // MARK: - Content Export
    
    func exportContent(_ contentId: String) async throws -> URL {
        guard let lesson = coreDataManager.fetchLesson(by: contentId) else {
            throw ContentExportError.contentNotFound
        }
        
        // Create export data
        let exportData = createExportData(for: lesson)
        
        // Write to temporary file
        let tempURL = fileManager.temporaryDirectory
            .appendingPathComponent("\(lesson.title)_export")
            .appendingPathExtension("json")
        
        let jsonData = try JSONEncoder().encode(exportData)
        try jsonData.write(to: tempURL)
        
        return tempURL
    }
    
    private func createExportData(for lesson: Lesson) -> LessonExportData {
        return LessonExportData(
            id: lesson.id,
            title: lesson.title,
            instrument: lesson.instrument,
            defaultBPM: lesson.defaultBPM,
            timeSignature: lesson.timeSignature,
            duration: lesson.duration,
            difficulty: Int(lesson.difficulty),
            tags: lesson.tagsArray,
            steps: lesson.stepsArray.map { step in
                LessonStepExportData(
                    id: step.id,
                    order: Int(step.order),
                    title: step.title,
                    description: step.stepDescription,
                    targetEvents: step.targetEvents,
                    bpmOverride: step.bpmOverride,
                    assistLevel: step.assistLevelEnum
                )
            },
            createdAt: lesson.createdAt,
            updatedAt: lesson.updatedAt
        )
    }
    
    // MARK: - Content Deletion
    
    func deleteContent(_ contentId: String) async throws {
        guard let lesson = coreDataManager.fetchLesson(by: contentId) else {
            throw ContentDeletionError.contentNotFound
        }
        
        // Delete associated files
        if let audioAssets = lesson.audioAssets {
            try deleteAssociatedFiles(audioAssets)
        }
        
        // Delete from database
        coreDataManager.delete(lesson)
        
        // Remove from validation results
        validationResults.removeValue(forKey: contentId)
    }
    
    private func deleteAssociatedFiles(_ audioAssets: AudioAssetsEntity) throws {
        // Delete backing track
        if let backingTrackURL = audioAssets.backingTrackURL,
           let url = URL(string: backingTrackURL) {
            try? fileManager.removeItem(at: url)
        }
        
        // Delete preview
        if let previewURL = audioAssets.previewURL,
           let url = URL(string: previewURL) {
            try? fileManager.removeItem(at: url)
        }
        
        // Delete stems
        for (_, urlString) in audioAssets.stemURLs {
            try? fileManager.removeItem(at: urlString)
        }
    }
    
    // MARK: - Batch Operations
    
    func importMultipleMIDIFiles(_ urls: [URL]) async throws -> [Lesson] {
        var importedLessons: [Lesson] = []
        var errors: [ContentImportResult.ImportError] = []
        
        for url in urls {
            do {
                if let lesson = try await importMIDIFile(url) {
                    importedLessons.append(lesson)
                }
            } catch {
                errors.append(.corruptedFile)
            }
        }
        
        // Update import result
        lastImportResult = ContentImportResult(
            success: errors.isEmpty,
            importedContent: importedLessons.map { lesson in
                ContentItem(
                    id: lesson.id,
                    title: lesson.title,
                    description: "",
                    type: .lesson,
                    difficulty: DifficultyLevel(rawValue: Int(lesson.difficulty)) ?? .beginner,
                    duration: lesson.duration,
                    tags: Set(lesson.tagsArray),
                    source: .lesson(lesson)
                )
            },
            errors: errors,
            warnings: []
        )
        
        return importedLessons
    }
    
    func validateAllContent() async -> [String: ContentValidationResult] {
        let lessons = coreDataManager.fetchLessons()
        var results: [String: ContentValidationResult] = [:]
        
        for lesson in lessons {
            // 使用与 importMIDIFile 相同的验证方法
            let validationResult = ContentValidationResult.validate(
                ContentItem(
                    id: lesson.id,
                    title: lesson.title,
                    description: "",
                    type: .lesson,
                    difficulty: DifficultyLevel(rawValue: Int(lesson.difficulty)) ?? .beginner,
                    duration: lesson.duration,
                    tags: Set(lesson.tagsArray),
                    source: .lesson(lesson)
                )
            )
            
            results[lesson.id] = validationResult
        }
        
        validationResults = results
        return results
    }
}

// MARK: - Supporting Types

struct LessonContent {
    let id: String
    let title: String
    let description: String
    let bpm: Float
    let duration: TimeInterval
    let targetEvents: [TargetEvent]
    let tags: [String]
}

// 重命名为 CMValidationResult 避免与其他模块冲突
struct CMValidationResult {
    let isValid: Bool
    let errors: [CMValidationError]
    let warnings: [CMValidationWarning]
}

// 重命名为 CMValidationError 避免与 DataModels.swift 中的 ValidationError 冲突
enum CMValidationError: LocalizedError {
    case emptyTitle
    case invalidDuration
    case invalidBPM
    case noTargetEvents
    case invalidEventTiming
    case invalidNoteNumber
    
    var errorDescription: String? {
        switch self {
        case .emptyTitle: return "Title cannot be empty"
        case .invalidDuration: return "Duration must be greater than 0"
        case .invalidBPM: return "BPM must be between 60 and 300"
        case .noTargetEvents: return "Lesson must have target events"
        case .invalidEventTiming: return "Event timing is outside lesson duration"
        case .invalidNoteNumber: return "Invalid MIDI note number"
        }
    }
}

// 重命名为 CMValidationWarning 避免冲突
enum CMValidationWarning: LocalizedError {
    case noDescription
    case noTags
    case shortDuration
    case longDuration
    
    var errorDescription: String? {
        switch self {
        case .noDescription: return "Consider adding a description"
        case .noTags: return "Consider adding tags for better discoverability"
        case .shortDuration: return "Lesson is very short (< 30 seconds)"
        case .longDuration: return "Lesson is very long (> 10 minutes)"
        }
    }
}

// MARK: - Error Types

enum ContentImportError: LocalizedError {
    case invalidFileFormat
    case fileNotFound
    case corruptedFile
    case unsupportedVersion
    case missingRequiredData
    case duplicateContent
    case validationFailed([ContentValidationResult.ValidationError])
    
    var errorDescription: String? {
        switch self {
        case .invalidFileFormat: return "Invalid file format"
        case .fileNotFound: return "File not found"
        case .corruptedFile: return "File appears to be corrupted"
        case .unsupportedVersion: return "Unsupported file version"
        case .missingRequiredData: return "Missing required data"
        case .duplicateContent: return "Content already exists"
        case .validationFailed(let errors): return "Validation failed: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        }
    }
}

enum ContentPublishingError: LocalizedError {
    case validationFailed([CMValidationError])
    case networkError
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let errors): return "Validation failed: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        case .networkError: return "Network error occurred"
        case .permissionDenied: return "Permission denied"
        }
    }
}

enum ContentExportError: LocalizedError {
    case contentNotFound
    case exportFailed
    case insufficientSpace
    
    var errorDescription: String? {
        switch self {
        case .contentNotFound: return "Content not found"
        case .exportFailed: return "Export failed"
        case .insufficientSpace: return "Insufficient disk space"
        }
    }
}

enum ContentDeletionError: LocalizedError {
    case contentNotFound
    case deletionFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .contentNotFound: return "Content not found"
        case .deletionFailed: return "Deletion failed"
        case .permissionDenied: return "Permission denied"
        }
    }
}

// MARK: - JSON Drum Data Format

struct JSONDrumData: Codable {
    let title: String
    let bpm: Float
    let timeSignature: TimeSignature
    let duration: TimeInterval
    let events: [JSONDrumEvent]
    
    struct JSONDrumEvent: Codable {
        let time: TimeInterval
        let drum: String
        let velocity: Int?
        let duration: TimeInterval?
    }
}

// MARK: - Social Sharing Features

class SocialSharingManager: ObservableObject {
    @Published var shareableContent: [ShareableContent] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var friendsProgress: [FriendProgress] = []
    
    func createShareableProgress(_ progress: ProgressSummary) -> ShareableContent {
        return ShareableContent(
            id: UUID().uuidString,
            type: .progress,
            title: "Level \(progress.currentLevel) Drummer!",
            description: "I've reached level \(progress.currentLevel) with \(progress.totalStars) stars and a \(progress.currentStreak) day streak!",
            imageData: generateProgressImage(progress),
            data: try? JSONEncoder().encode(progress),
            createdAt: Date()
        )
    }
    
    func createShareableAchievement(_ achievement: Achievement) -> ShareableContent {
        return ShareableContent(
            id: UUID().uuidString,
            type: .achievement,
            title: "New Achievement Unlocked!",
            description: "\(achievement.title): \(achievement.description)",
            imageData: generateAchievementImage(achievement),
            data: try? JSONEncoder().encode(achievement),
            createdAt: Date()
        )
    }
    
    func createShareableScore(_ score: ScoreResult, lessonTitle: String) -> ShareableContent {
        return ShareableContent(
            id: UUID().uuidString,
            type: .score,
            title: "Perfect Performance!",
            description: "I scored \(Int(score.totalScore))% on '\(lessonTitle)' with \(score.starRating) stars!",
            imageData: generateScoreImage(score, lessonTitle: lessonTitle),
            data: try? JSONEncoder().encode(score),
            createdAt: Date()
        )
    }
    
    private func generateProgressImage(_ progress: ProgressSummary) -> Data? {
        // Generate a visual representation of progress
        // This would create an image showing level, stars, streak, etc.
        return nil // Placeholder - would implement actual image generation
    }
    
    private func generateAchievementImage(_ achievement: Achievement) -> Data? {
        // Generate achievement badge image
        return nil // Placeholder
    }
    
    private func generateScoreImage(_ score: ScoreResult, lessonTitle: String) -> Data? {
        // Generate score card image
        return nil // Placeholder
    }
    
    func shareToSocialMedia(_ content: ShareableContent, platform: SocialPlatform) {
        // Implement sharing to various platforms
        switch platform {
        case .twitter:
            shareToTwitter(content)
        case .facebook:
            shareToFacebook(content)
        case .instagram:
            shareToInstagram(content)
        case .discord:
            shareToDiscord(content)
        }
    }
    
    private func shareToTwitter(_ content: ShareableContent) {
        let text = "\(content.title) \(content.description) #DrumTrainer #Music"
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let twitterURL = "https://twitter.com/intent/tweet?text=\(encodedText)"
        
        if let url = URL(string: twitterURL) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #endif
        }
    }
    
    private func shareToFacebook(_ content: ShareableContent) {
        // Facebook sharing implementation
    }
    
    private func shareToInstagram(_ content: ShareableContent) {
        // Instagram sharing implementation
    }
    
    private func shareToDiscord(_ content: ShareableContent) {
        // Discord sharing implementation
    }
}

struct ShareableContent: Identifiable, Codable {
    let id: String
    let type: ShareType
    let title: String
    let description: String
    let imageData: Data?
    let data: Data?
    let createdAt: Date
}

enum ShareType: String, Codable {
    case progress = "progress"
    case achievement = "achievement"
    case score = "score"
    case lesson = "lesson"
}

enum SocialPlatform: String, CaseIterable {
    case twitter = "twitter"
    case facebook = "facebook"
    case instagram = "instagram"
    case discord = "discord"
    
    var displayName: String {
        switch self {
        case .twitter: return "Twitter"
        case .facebook: return "Facebook"
        case .instagram: return "Instagram"
        case .discord: return "Discord"
        }
    }
}

struct LeaderboardEntry: Identifiable, Codable {
    let id: String
    let username: String
    let level: Int
    let totalStars: Int
    let currentStreak: Int
    let rank: Int
}

struct FriendProgress: Identifiable, Codable {
    let id: String
    let username: String
    let level: Int
    let recentAchievements: [Achievement]
    let lastActive: Date
}

// MARK: - Export Data Types

struct LessonExportData: Codable {
    let id: String
    let title: String
    let instrument: String
    let defaultBPM: Float
    let timeSignature: TimeSignature
    let duration: TimeInterval
    let difficulty: Int
    let tags: [String]
    let steps: [LessonStepExportData]
    let createdAt: Date
    let updatedAt: Date
}

struct LessonStepExportData: Codable {
    let id: String
    let order: Int
    let title: String
    let description: String
    let targetEvents: [TargetEvent]
    let bpmOverride: Float
    let assistLevel: AssistLevel
}
