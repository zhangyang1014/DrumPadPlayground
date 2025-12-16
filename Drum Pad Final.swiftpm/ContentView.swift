import SwiftUI
import AudioKitUI

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
                        selectedTab: selectedTab,
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
                            selectedTab: tab,
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
    let selectedTab: NavigationTab
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

// MARK: - Legacy Drum Pad View (for settings/testing)

struct LegacyDrumPadView: View {
    @EnvironmentObject var conductor: Conductor
    @Environment(\.openURL) var openURL

    let padding: CGFloat = 30
    let cornerRadius: CGFloat = 15
    let spacing: CGFloat = 20
    let controlsHeight: CGFloat = 200
    let stepperHeight: CGFloat = 40

    var body: some View {
        ZStack {
            Color("background")

            VStack(spacing: spacing) {
                Image("header").resizable().scaledToFit().frame(height: 24)
                HStack(spacing: spacing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color("controlsBackground"))
                        HStack {
                            VStack {
                                HStack {
                                    ArcKnob(value: $conductor.delayMix, 
                                            range: 0...100, 
                                            title: "DELAY MIX", 
                                            textColor: Color("textColor1"), 
                                            arcColor: Color("knobFill"))
                                    ArcKnob(value: $conductor.delayFeedback,
                                            range: 0...100, title: "FEEDBACK",
                                            textColor: Color("textColor1"),
                                            arcColor: Color("knobFill"))
                                }
                                MusicalDurationStepper(musicalDuration: $conductor.delayDuration, time: conductor.delay.time)
                                    .padding(.leading, padding / 2)
                                    .frame(height: stepperHeight)
                                    .foregroundColor(Color("textColor2"))
                                    .frame(minWidth: 200)
                            }
                            Spacer()
                            VStack {
                                HStack {
                                    ArcKnob(value: $conductor.reverbMix,
                                            range: 0...100, title: "REVERB",
                                            textColor: Color("textColor1"),
                                            arcColor: Color("knobFill"))
                                    ArcKnob(value: $conductor.mixerVolume,
                                            range: 0...100, title: "VOLUME",
                                            textColor: Color("textColor1"),
                                            arcColor: Color("knobFill"))
                                }
                                ReverbPresetStepper(preset: $conductor.reverbPreset)
                                    .padding(.trailing, padding / 2)
                                    .frame(height: stepperHeight)
                                    .foregroundColor(Color("textColor2"))
                                    .frame(minWidth: 200)
                            }
                        }.padding(.bottom, padding / 2)
                    }.frame(minWidth: 450)
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius).fill(.black)
                        NodeOutputView(conductor.mixer).padding(padding)
                    }
                }.frame(height: controlsHeight)
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color("controlsBackground"))
                    HStack {
                        TempoDraggableStepper(tempo: $conductor.tempo)
                            .foregroundColor(Color("textColor1")).frame(width: 200)
                        Spacer()
                        if conductor.isDelayTimeMaxed {
                            Text("WARNING: DELAY TIME IS TOO LONG!")
                                .font(Font.system(size: 20, weight: .bold))
                                .foregroundColor(.red)
                        } else {
                            Text("MAKE THIS APP ON YOUR IPAD")
                                .foregroundColor( Color("textColor1"))
                                .font(Font.system(size: 18))
                            Button(action: {
                                openURL(URL(string: "https://audiokitpro.com/drumpadplayground/")!)
                            }) {
                                Text("WATCH TUTORIAL")
                                    .foregroundColor(Color("textColor1"))
                                    .fontWeight(.semibold)
                                    .font(Font.system(size: 18))
                            }.foregroundColor(.white)
                                .padding(.horizontal, 10.0)
                                .padding(.vertical, 5.0)
                                .background(Color("buttonBackground"))
                                .cornerRadius(10.0)
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.black.opacity(0.6), lineWidth: 1))
                }
                    }
                    .padding(8)
                }.frame(height: 30)

                TapCountingDrumPadGrid(names: conductor.drumSamples.map { $0.name }) { tapCounts in
                    conductor.drumPadTouchCounts = tapCounts
                }
                
            }.padding(padding)
        }
    }
}

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
