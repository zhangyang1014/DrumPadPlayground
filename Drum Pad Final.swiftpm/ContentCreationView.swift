import SwiftUI
import UniformTypeIdentifiers

// MARK: - Content Creation View

struct ContentCreationView: View {
    @StateObject private var contentManager = ContentManager(coreDataManager: CoreDataManager.shared)
    @State private var showingFilePicker = false
    @State private var showingCourseCreator = false
    @State private var showingContentValidation = false
    @State private var selectedLessons: Set<String> = []
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Create Content")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Import MIDI files or create courses")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Import Section
                VStack(spacing: 16) {
                    // MIDI Import Button
                    Button {
                        showingFilePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Import MIDI Files")
                                    .font(.headline)
                                
                                Text("Convert MIDI files into interactive lessons")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Course Creation Button
                    Button {
                        showingCourseCreator = true
                    } label: {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Create Course")
                                    .font(.headline)
                                
                                Text("Group lessons into structured courses")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Content Validation Button
                    Button {
                        showingContentValidation = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.shield")
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Validate Content")
                                    .font(.headline)
                                
                                Text("Check lessons and courses for issues")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                
                // Import Status
                if contentManager.isImporting {
                    ImportProgressView(
                        progress: contentManager.importProgress,
                        contentManager: contentManager
                    )
                    .padding(.horizontal)
                }
                
                // Recent Import Results
                if let importResult = contentManager.lastImportResult {
                    ImportResultView(result: importResult)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Content Creation")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.midi],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showingCourseCreator) {
            CourseCreationView(contentManager: contentManager)
        }
        .sheet(isPresented: $showingContentValidation) {
            ContentValidationView(contentManager: contentManager)
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                do {
                    _ = try await contentManager.importMultipleMIDIFiles(urls)
                } catch {
                    print("Import failed: \(error)")
                }
            }
        case .failure(let error):
            print("File selection failed: \(error)")
        }
    }
}

// MARK: - Import Progress View

struct ImportProgressView: View {
    let progress: Float
    let contentManager: ContentManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.blue)
                
                Text("Importing MIDI Files...")
                    .font(.headline)
                
                Spacer()
            }
            
            SwiftUI.ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text("\(Int(progress * 100))% Complete")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Import Result View

struct ImportResultView: View {
    let result: ContentImportResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(result.success ? .green : .orange)
                
                Text(result.success ? "Import Successful" : "Import Completed with Issues")
                    .font(.headline)
                
                Spacer()
            }
            
            if !result.importedContent.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Imported \(result.importedContent.count) lesson(s):")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(result.importedContent.prefix(3), id: \.id) { content in
                        HStack {
                            Image(systemName: "music.note")
                                .foregroundColor(.blue)
                                .font(.caption)
                            
                            Text(content.title)
                                .font(.caption)
                            
                            Spacer()
                        }
                    }
                    
                    if result.importedContent.count > 3 {
                        Text("... and \(result.importedContent.count - 3) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !result.errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Errors:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                    
                    ForEach(result.errors.prefix(3), id: \.localizedDescription) { error in
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.red)
                                .font(.caption)
                            
                            Text(error.localizedDescription)
                                .font(.caption)
                            
                            Spacer()
                        }
                    }
                }
            }
            
            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Warnings:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    ForEach(result.warnings.prefix(2), id: \.localizedDescription) { warning in
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.caption)
                            
                            Text(warning.localizedDescription)
                                .font(.caption)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(result.success ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Course Creation View

struct CourseCreationView: View {
    let contentManager: ContentManager
    @State private var courseTitle = ""
    @State private var courseDescription = ""
    @State private var selectedDifficulty: DifficultyLevel = .beginner
    @State private var selectedLessons: Set<String> = []
    @State private var availableLessons: [Lesson] = []
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section("Course Information") {
                    TextField("Course Title", text: $courseTitle)
                    
                    TextField("Description", text: $courseDescription, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Difficulty", selection: $selectedDifficulty) {
                        ForEach(DifficultyLevel.allCases, id: \.self) { difficulty in
                            Text(difficulty.description).tag(difficulty)
                        }
                    }
                }
                
                Section("Select Lessons") {
                    if availableLessons.isEmpty {
                        Text("No lessons available. Import some MIDI files first.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(availableLessons, id: \.id) { lesson in
                            LessonSelectionRow(
                                lesson: lesson,
                                isSelected: selectedLessons.contains(lesson.id)
                            ) { isSelected in
                                if isSelected {
                                    selectedLessons.insert(lesson.id)
                                } else {
                                    selectedLessons.remove(lesson.id)
                                }
                            }
                        }
                    }
                }
                
                if !selectedLessons.isEmpty {
                    Section("Course Preview") {
                        let selectedLessonObjects = availableLessons.filter { selectedLessons.contains($0.id) }
                        let totalDuration = selectedLessonObjects.reduce(0) { $0 + $1.duration }
                        
                        HStack {
                            Text("Lessons:")
                            Spacer()
                            Text("\(selectedLessons.count)")
                        }
                        
                        HStack {
                            Text("Total Duration:")
                            Spacer()
                            Text(formatDuration(totalDuration))
                        }
                        
                        HStack {
                            Text("Estimated Difficulty:")
                            Spacer()
                            DifficultyBadge(level: calculateCourseDifficulty(selectedLessonObjects))
                        }
                    }
                }
            }
            .navigationTitle("Create Course")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Create") {
                    createCourse()
                }
                .disabled(courseTitle.isEmpty || selectedLessons.isEmpty)
            )
        }
        .onAppear {
            loadAvailableLessons()
        }
    }
    
    private func loadAvailableLessons() {
        availableLessons = CoreDataManager.shared.fetchLessons()
    }
    
    private func createCourse() {
        let selectedLessonObjects = availableLessons.filter { selectedLessons.contains($0.id) }
        
        let course = contentManager.createCourse(
            title: courseTitle,
            lessons: selectedLessonObjects
        )
        
        // Update course description
        course.courseDescription = courseDescription.isEmpty ? 
            "Course containing \(selectedLessons.count) lessons" : 
            courseDescription
        
        CoreDataManager.shared.save()
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func calculateCourseDifficulty(_ lessons: [Lesson]) -> DifficultyLevel {
        guard !lessons.isEmpty else { return .beginner }
        
        let averageDifficulty = lessons.reduce(0) { $0 + Int($1.difficulty) } / lessons.count
        return DifficultyLevel(rawValue: averageDifficulty) ?? .beginner
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Lesson Selection Row

struct LessonSelectionRow: View {
    let lesson: Lesson
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    
    var body: some View {
        HStack {
            Button {
                onSelectionChanged(!isSelected)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(.headline)
                
                HStack {
                    DifficultyBadge(level: DifficultyLevel(rawValue: Int(lesson.difficulty)) ?? .beginner)
                    
                    Text(formatDuration(lesson.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !lesson.tagsArray.isEmpty {
                        Text("• \(lesson.tagsArray.prefix(2).joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectionChanged(!isSelected)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Content Validation View

struct ContentValidationView: View {
    let contentManager: ContentManager
    @State private var validationResults: [String: ContentValidationResult] = [:]
    @State private var isValidating = false
    
    var body: some View {
        NavigationView {
            List {
                if isValidating {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Validating content...")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if validationResults.isEmpty {
                    Text("No validation results available")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(Array(validationResults.keys), id: \.self) { contentId in
                        if let result = validationResults[contentId] {
                            ValidationResultRow(contentId: contentId, result: result)
                        }
                    }
                }
            }
            .navigationTitle("Content Validation")
            .navigationBarItems(
                trailing: Button("Validate All") {
                    validateAllContent()
                }
            )
        }
        .onAppear {
            validationResults = contentManager.validationResults
        }
    }
    
    private func validateAllContent() {
        isValidating = true
        
        Task {
            let results = await contentManager.validateAllContent()
            
            DispatchQueue.main.async {
                self.validationResults = results
                self.isValidating = false
            }
        }
    }
}

// MARK: - Validation Result Row

struct ValidationResultRow: View {
    let contentId: String
    let result: ContentValidationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(result.isValid ? .green : .red)
                
                Text(contentId)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text(result.isValid ? "Valid" : "Issues")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(result.isValid ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .cornerRadius(8)
            }
            
            if !result.errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Errors:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                    
                    ForEach(result.errors, id: \.localizedDescription) { error in
                        Text("• \(error.localizedDescription)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Warnings:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    ForEach(result.warnings, id: \.localizedDescription) { warning in
                        Text("• \(warning.localizedDescription)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

struct ContentCreationView_Previews: PreviewProvider {
    static var previews: some View {
        ContentCreationView()
    }
}