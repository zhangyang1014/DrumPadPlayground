import SwiftUI
import AudioKit
// 注意：已移除 AudioKitUI 依赖，使用 CustomAudioKitViews.swift 中的自定义组件

// MARK: - Main Navigation Tabs

enum NavigationTab: String, CaseIterable {
    case browse = "Browse"
    case play = "Play"
    case progress = "Progress"
    case analytics = "Analytics"
    case settings = "Settings"
    
    var iconName: String {
        switch self {
        case .browse: return "music.note.list"
        case .play: return "play.circle"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .analytics: return "chart.bar.xaxis"
        case .settings: return "gear"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var conductor: Conductor
    @Environment(\.openURL) var openURL
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var selectedTab: NavigationTab = .browse
    @State private var selectedLesson: Lesson?
    @State private var isPlayingLesson = false
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                // Landscape layout - side navigation
                HStack(spacing: 0) {
                    // Side navigation
                    SideNavigationView(selectedTab: $selectedTab)
                        .frame(width: 200)
                    
                    Divider()
                    
                    // Main content
                    MainContentView(
                        selectedTab: $selectedTab,
                        selectedLesson: $selectedLesson,
                        isPlayingLesson: $isPlayingLesson,
                        conductor: conductor
                    )
                }
            } else {
                // Portrait layout - tab navigation
                TabView(selection: $selectedTab) {
                    ForEach(NavigationTab.allCases, id: \.self) { tab in
                        MainContentView(
                            selectedTab: $selectedTab,
                            selectedLesson: $selectedLesson,
                            isPlayingLesson: $isPlayingLesson,
                            conductor: conductor
                        )
                        .tabItem {
                            Image(systemName: tab.iconName)
                            Text(tab.rawValue)
                        }
                        .tag(tab)
                    }
                }
            }
        }
        .background(Color("background"))
        .sheet(item: $selectedLesson) { lesson in
            LessonPlayerView(lesson: lesson, conductor: conductor)
        }
    }
}

// MARK: - Side Navigation View

struct SideNavigationView: View {
    @Binding var selectedTab: NavigationTab
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // App header
            VStack(alignment: .leading, spacing: 4) {
                Image("header")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                
                Text("Drum Trainer")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Navigation items
            VStack(spacing: 4) {
                ForEach(NavigationTab.allCases, id: \.self) { tab in
                    NavigationItemView(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 8)
            
            Spacer()
        }
        .background(Color("controlsBackground"))
    }
}

// MARK: - Navigation Item View

struct NavigationItemView: View {
    let tab: NavigationTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20)
                
                Text(tab.rawValue)
                    .font(.system(size: 15, weight: .medium))
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
            )
            .foregroundColor(isSelected ? .blue : Color("textColor1"))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Main Content View

struct MainContentView: View {
    @Binding var selectedTab: NavigationTab
    @Binding var selectedLesson: Lesson?
    @Binding var isPlayingLesson: Bool
    let conductor: Conductor
    
    var body: some View {
        Group {
            switch selectedTab {
            case .browse:
                ContentBrowserView()
                    .onReceive(NotificationCenter.default.publisher(for: .lessonSelected)) { notification in
                        if let lesson = notification.object as? Lesson {
                            selectedLesson = lesson
                        }
                    }
                
            case .play:
                if let lesson = selectedLesson {
                    LessonPlayerView(lesson: lesson, conductor: conductor)
                } else {
                    LessonSelectionPromptView {
                        // Switch to browse tab to select a lesson
                        selectedTab = .browse
                    }
                }
                
            case .progress:
                ProgressView()
                
            case .analytics:
                AdvancedAnalyticsView()
                
            case .settings:
                SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Lesson Selection Prompt View

struct LessonSelectionPromptView: View {
    let onBrowseLessons: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "music.note")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Lesson Selected")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Choose a lesson to start practicing")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Button("Browse Lessons") {
                onBrowseLessons()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("background"))
    }
}

#if false
// Legacy inline demo (disabled)
private struct LegacyDrumPadInlineView: View {
    var body: some View {
        EmptyView()
    }
}
#endif

// MARK: - Notification Extensions

extension Notification.Name {
    static let lessonSelected = Notification.Name("lessonSelected")
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .preferredColorScheme(.dark)
                .previewInterfaceOrientation(.landscapeLeft)
                .environmentObject(Conductor())
                .environment(\.managedObjectContext, CoreDataManager.shared.context)
            ContentView()
                .preferredColorScheme(.light)
                .previewInterfaceOrientation(.landscapeLeft)
                .environmentObject(Conductor())
                .environment(\.managedObjectContext, CoreDataManager.shared.context)
        }
    }
}
