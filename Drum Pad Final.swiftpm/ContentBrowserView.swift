import SwiftUI
import CoreData

// MARK: - Content Browser View

struct ContentBrowserView: View {
    @StateObject private var viewModel = ContentBrowserViewModel()
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with search and filters
                ContentBrowserHeader(viewModel: viewModel)
                
                // Content list
                ContentListView(viewModel: viewModel)
            }
            .navigationTitle("Browse Content")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.loadContent(context: viewContext)
            }
        }
    }
}

// MARK: - Content Browser Header

struct ContentBrowserHeader: View {
    @ObservedObject var viewModel: ContentBrowserViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search lessons and courses...", text: $viewModel.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !viewModel.searchText.isEmpty {
                    Button("Clear") {
                        viewModel.searchText = ""
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Filter controls
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Content type filter
                    FilterPicker(
                        title: "Type",
                        selection: $viewModel.selectedContentType,
                        options: ContentType.self
                    )
                    
                    // Difficulty filter
                    FilterPicker(
                        title: "Difficulty",
                        selection: $viewModel.selectedDifficulty,
                        options: DifficultyLevel.self
                    )
                    
                    // Tag filter
                    if !viewModel.availableTags.isEmpty {
                        TagFilterView(
                            selectedTags: $viewModel.selectedTags,
                            availableTags: viewModel.availableTags
                        )
                    }
                    
                    // Clear filters button
                    if viewModel.hasActiveFilters {
                        Button("Clear Filters") {
                            viewModel.clearFilters()
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(radius: 1)
    }
}

// MARK: - Filter Picker

struct FilterPicker<T: CaseIterable & Hashable & CustomStringConvertible>: View {
    let title: String
    @Binding var selection: T?
    let options: T.Type
    
    var body: some View {
        Menu {
            Button("All \(title)s") {
                selection = nil
            }
            
            ForEach(Array(options.allCases), id: \.self) { option in
                Button(option.description) {
                    selection = option
                }
            }
        } label: {
            HStack {
                Text(title)
                Text(selection?.description ?? "All")
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

// MARK: - Tag Filter View

struct TagFilterView: View {
    @Binding var selectedTags: Set<String>
    let availableTags: [String]
    @State private var showingTagPicker = false
    
    var body: some View {
        Button {
            showingTagPicker = true
        } label: {
            HStack {
                Text("Tags")
                if selectedTags.isEmpty {
                    Text("All")
                        .foregroundColor(.secondary)
                } else {
                    Text("\(selectedTags.count)")
                        .foregroundColor(.blue)
                }
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .sheet(isPresented: $showingTagPicker) {
            TagPickerSheet(
                selectedTags: $selectedTags,
                availableTags: availableTags
            )
        }
    }
}

// MARK: - Tag Picker Sheet

struct TagPickerSheet: View {
    @Binding var selectedTags: Set<String>
    let availableTags: [String]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                ForEach(availableTags, id: \.self) { tag in
                    HStack {
                        Text(tag)
                        Spacer()
                        if selectedTags.contains(tag) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    }
                }
            }
            .navigationTitle("Select Tags")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Clear All") {
                    selectedTags.removeAll()
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// MARK: - Content List View

struct ContentListView: View {
    @ObservedObject var viewModel: ContentBrowserViewModel
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                SwiftUI.ProgressView("Loading content...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredContent.isEmpty {
                ContentEmptyState(
                    hasFilters: viewModel.hasActiveFilters,
                    onClearFilters: viewModel.clearFilters
                )
            } else {
                List {
                    // Beginner recommendations section
                    if viewModel.shouldShowBeginnerRecommendations {
                        Section("Recommended for Beginners") {
                            ForEach(viewModel.beginnerRecommendations, id: \.id) { item in
                                ContentRowView(item: item)
                                    .onTapGesture {
                                        viewModel.selectContent(item)
                                    }
                            }
                        }
                    }
                    
                    // Main content section
                    Section(viewModel.contentSectionTitle) {
                        ForEach(viewModel.filteredContent, id: \.id) { item in
                            ContentRowView(item: item)
                                .onTapGesture {
                                    viewModel.selectContent(item)
                                }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .sheet(item: $viewModel.selectedContent) { content in
            ContentDetailView(content: content)
        }
    }
}

// MARK: - Content Empty State

struct ContentEmptyState: View {
    let hasFilters: Bool
    let onClearFilters: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(hasFilters ? "No content matches your filters" : "No content available")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if hasFilters {
                Button("Clear Filters") {
                    onClearFilters()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Import some MIDI files or create lessons to get started")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Content Row View

struct ContentRowView: View {
    let item: ContentItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Content type icon
            ContentTypeIcon(type: item.type)
            
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                
                // Description
                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Metadata row
                HStack(spacing: 8) {
                    // Difficulty
                    DifficultyBadge(level: item.difficulty)
                    
                    // Duration
                    if item.duration > 0 {
                        Label(formatDuration(item.duration), systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Tags
                    if !item.tags.isEmpty {
                        TagsPreview(tags: Array(item.tags.prefix(2)))
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // Preview button
            Button {
                // Handle preview
            } label: {
                Image(systemName: "play.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Content Type Icon

struct ContentTypeIcon: View {
    let type: ContentType
    
    var body: some View {
        Image(systemName: type.iconName)
            .font(.title2)
            .foregroundColor(type.color)
            .frame(width: 32, height: 32)
            .background(type.color.opacity(0.1))
            .cornerRadius(8)
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let level: DifficultyLevel
    
    var body: some View {
        Text(level.description)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(level.color.opacity(0.2))
            .foregroundColor(level.color)
            .cornerRadius(4)
    }
}

// MARK: - Tags Preview

struct TagsPreview: View {
    let tags: [String]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(.systemGray5))
                    .cornerRadius(3)
            }
        }
    }
}

// MARK: - Content Detail View

struct ContentDetailView: View {
    let content: ContentItem
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ContentTypeIcon(type: content.type)
                            
                            VStack(alignment: .leading) {
                                Text(content.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                HStack {
                                    DifficultyBadge(level: content.difficulty)
                                    
                                    if content.duration > 0 {
                                        Label(formatDuration(content.duration), systemImage: "clock")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        
                        if !content.description.isEmpty {
                            Text(content.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Tags
                    if !content.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags")
                                .font(.headline)
                            
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 80))
                            ], spacing: 8) {
                                ForEach(Array(content.tags), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                    
                    // Steps (for lessons)
                    if case .lesson(let lesson) = content.source {
                        let steps = lesson.stepsArray
                        if !steps.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Steps (\(steps.count))")
                                    .font(.headline)
                                
                                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                                    HStack {
                                        Text("\(index + 1).")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 20, alignment: .leading)
                                        
                                        Text(step.title)
                                            .font(.body)
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                    
                    // Lessons (for courses)
                    if case .course(let course) = content.source {
                        let lessons = course.lessonsArray
                        if !lessons.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Lessons (\(lessons.count))")
                                    .font(.headline)
                                
                                ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                                    HStack {
                                        Text("\(index + 1).")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 20, alignment: .leading)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(lesson.title)
                                                .font(.body)
                                            
                                            HStack {
                                                DifficultyBadge(level: DifficultyLevel(rawValue: Int(lesson.difficulty)) ?? .beginner)
                                                
                                                if lesson.duration > 0 {
                                                    Label(formatDuration(lesson.duration), systemImage: "clock")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Content Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Start") {
                    // Handle start lesson/course
                    if case .lesson(let lesson) = content.source {
                        NotificationCenter.default.post(name: .lessonSelected, object: lesson)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
            )
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

struct ContentBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        ContentBrowserView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
    }
}