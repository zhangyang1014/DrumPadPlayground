import SwiftUI
import AudioKitUI

// MARK: - Lesson Player View

struct LessonPlayerView: View {
    let lesson: Lesson
    let conductor: Conductor
    
    @StateObject private var lessonEngine = LessonEngine()
    @StateObject private var scoreEngine = ScoreEngine()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentPlaybackMode: PlaybackMode = .performance
    @State private var isPlaying = false
    @State private var currentProgress: Double = 0.0
    @State private var showingResults = false
    @State private var currentScoreResult: ScoreResult?
    @State private var realtimeFeedback: [TimingFeedback] = []
    @State private var currentBPM: Float = 120
    @State private var isLoopEnabled = false
    @State private var loopStart: TimeInterval = 0
    @State private var loopEnd: TimeInterval = 0
    @State private var isWaitModeEnabled = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header with lesson info and controls
                LessonPlayerHeader(
                    lesson: lesson,
                    currentMode: $currentPlaybackMode,
                    isPlaying: $isPlaying,
                    onClose: {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
                
                if geometry.size.width > geometry.size.height {
                    // Landscape layout
                    HStack(spacing: 0) {
                        // Main play area
                        LessonPlayArea(
                            lesson: lesson,
                            lessonEngine: lessonEngine,
                            scoreEngine: scoreEngine,
                            currentProgress: $currentProgress,
                            realtimeFeedback: $realtimeFeedback,
                            currentMode: currentPlaybackMode
                        )
                        .frame(maxWidth: .infinity)
                        
                        Divider()
                        
                        // Side controls
                        LessonControlPanel(
                            lesson: lesson,
                            currentBPM: $currentBPM,
                            isLoopEnabled: $isLoopEnabled,
                            loopStart: $loopStart,
                            loopEnd: $loopEnd,
                            isWaitModeEnabled: $isWaitModeEnabled,
                            currentMode: currentPlaybackMode,
                            isPlaying: $isPlaying,
                            lessonEngine: lessonEngine
                        )
                        .frame(width: 300)
                    }
                } else {
                    // Portrait layout
                    VStack(spacing: 0) {
                        // Main play area
                        LessonPlayArea(
                            lesson: lesson,
                            lessonEngine: lessonEngine,
                            scoreEngine: scoreEngine,
                            currentProgress: $currentProgress,
                            realtimeFeedback: $realtimeFeedback,
                            currentMode: currentPlaybackMode
                        )
                        .frame(maxHeight: .infinity)
                        
                        Divider()
                        
                        // Bottom controls
                        LessonControlPanel(
                            lesson: lesson,
                            currentBPM: $currentBPM,
                            isLoopEnabled: $isLoopEnabled,
                            loopStart: $loopStart,
                            loopEnd: $loopEnd,
                            isWaitModeEnabled: $isWaitModeEnabled,
                            currentMode: currentPlaybackMode,
                            isPlaying: $isPlaying,
                            lessonEngine: lessonEngine
                        )
                        .frame(height: 200)
                    }
                }
            }
        }
        .background(Color("background"))
        .onAppear {
            setupLesson()
        }
        .sheet(isPresented: $showingResults) {
            if let result = currentScoreResult {
                LessonResultsView(
                    lesson: lesson,
                    scoreResult: result,
                    onRetry: {
                        showingResults = false
                        startLesson()
                    },
                    onClose: {
                        showingResults = false
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
    
    private func setupLesson() {
        lessonEngine.loadLesson(lesson)
        currentBPM = lesson.defaultBPM
        loopEnd = lesson.duration
        
        // Setup score engine callbacks
        scoreEngine.onRealtimeFeedback = { feedback in
            DispatchQueue.main.async {
                realtimeFeedback.append(feedback)
                // Keep only recent feedback (last 10 items)
                if realtimeFeedback.count > 10 {
                    realtimeFeedback.removeFirst()
                }
            }
        }
        
        scoreEngine.onLessonComplete = { result in
            DispatchQueue.main.async {
                currentScoreResult = result
                showingResults = true
                isPlaying = false
            }
        }
    }
    
    private func startLesson() {
        lessonEngine.startPlayback(
            mode: currentPlaybackMode,
            bpm: currentBPM,
            loopRegion: isLoopEnabled ? (loopStart, loopEnd) : nil,
            waitMode: isWaitModeEnabled
        )
        scoreEngine.startScoring(for: lesson, mode: currentPlaybackMode)
        isPlaying = true
    }
}

// MARK: - Lesson Player Header

struct LessonPlayerHeader: View {
    let lesson: Lesson
    @Binding var currentMode: PlaybackMode
    @Binding var isPlaying: Bool
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(.headline)
                    .foregroundColor(Color("textColor1"))
                
                HStack(spacing: 12) {
                    // Difficulty badge
                    DifficultyBadge(level: DifficultyLevel(rawValue: Int(lesson.difficulty)) ?? .beginner)
                    
                    // BPM info
                    Label("\(Int(lesson.defaultBPM)) BPM", systemImage: "metronome")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Duration info
                    Label(formatDuration(lesson.duration), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Mode selector
            PlaybackModeSelector(selectedMode: $currentMode, isPlaying: isPlaying)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color("controlsBackground"))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Playback Mode Selector

struct PlaybackModeSelector: View {
    @Binding var selectedMode: PlaybackMode
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(PlaybackMode.allCases, id: \.self) { mode in
                Button(mode.displayName) {
                    if !isPlaying {
                        selectedMode = mode
                    }
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedMode == mode ? Color.blue : Color.clear)
                )
                .foregroundColor(selectedMode == mode ? .white : Color("textColor1"))
                .disabled(isPlaying)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("background"))
        )
    }
}

// MARK: - Lesson Play Area

struct LessonPlayArea: View {
    let lesson: Lesson
    let lessonEngine: LessonEngine
    let scoreEngine: ScoreEngine
    @Binding var currentProgress: Double
    @Binding var realtimeFeedback: [TimingFeedback]
    let currentMode: PlaybackMode
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress bar and timeline
            LessonProgressView(
                lesson: lesson,
                currentProgress: $currentProgress,
                lessonEngine: lessonEngine
            )
            
            // Real-time feedback display
            RealtimeFeedbackView(
                feedback: realtimeFeedback,
                currentMode: currentMode
            )
            
            // Drum pad grid (if needed for practice)
            if currentMode == .practice {
                TapCountingDrumPadGrid(names: ["Kick", "Snare", "Hi-Hat", "Crash"]) { tapCounts in
                    // Handle drum pad taps
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(16)
    }
}

// MARK: - Lesson Progress View

struct LessonProgressView: View {
    let lesson: Lesson
    @Binding var currentProgress: Double
    let lessonEngine: LessonEngine
    
    var body: some View {
        VStack(spacing: 8) {
            // Time display
            HStack {
                Text(formatTime(currentProgress * lesson.duration))
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(Color("textColor1"))
                
                Spacer()
                
                Text(formatTime(lesson.duration))
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * currentProgress, height: 8)
                    
                    // Target events markers
                    ForEach(lessonEngine.currentTargetEvents.indices, id: \.self) { index in
                        let event = lessonEngine.currentTargetEvents[index]
                        let position = event.timestamp / lesson.duration
                        
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 12, height: 12)
                            .position(
                                x: geometry.size.width * position,
                                y: geometry.size.height / 2
                            )
                    }
                }
            }
            .frame(height: 20)
            .onTapGesture { location in
                // Allow seeking in practice mode
                if lessonEngine.currentMode == .practice {
                    let progress = location.x / UIScreen.main.bounds.width
                    lessonEngine.seekTo(progress: progress)
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Realtime Feedback View

struct RealtimeFeedbackView: View {
    let feedback: [TimingFeedback]
    let currentMode: PlaybackMode
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Real-time Feedback")
                .font(.headline)
                .foregroundColor(Color("textColor1"))
            
            if currentMode != .memory {
                HStack(spacing: 8) {
                    ForEach(Array(feedback.suffix(5).enumerated()), id: \.offset) { index, timing in
                        TimingFeedbackBadge(timing: timing)
                            .opacity(1.0 - Double(4 - index) * 0.2)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: feedback.count)
            } else {
                Text("Memory Mode - No Visual Feedback")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("controlsBackground"))
        )
    }
}

// MARK: - Timing Feedback Badge

struct TimingFeedbackBadge: View {
    let timing: TimingFeedback
    
    var body: some View {
        Text(timing.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(timing.color)
            )
            .foregroundColor(.white)
    }
}

// MARK: - Lesson Control Panel

struct LessonControlPanel: View {
    let lesson: Lesson
    @Binding var currentBPM: Float
    @Binding var isLoopEnabled: Bool
    @Binding var loopStart: TimeInterval
    @Binding var loopEnd: TimeInterval
    @Binding var isWaitModeEnabled: Bool
    let currentMode: PlaybackMode
    @Binding var isPlaying: Bool
    let lessonEngine: LessonEngine
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Play controls
                PlayControlsView(
                    isPlaying: $isPlaying,
                    onPlay: {
                        lessonEngine.startPlayback(
                            mode: currentMode,
                            bpm: currentBPM,
                            loopRegion: isLoopEnabled ? (loopStart, loopEnd) : nil,
                            waitMode: isWaitModeEnabled
                        )
                    },
                    onPause: {
                        lessonEngine.pausePlayback()
                    },
                    onStop: {
                        lessonEngine.stopPlayback()
                    }
                )
                
                Divider()
                
                // BPM control (practice mode only)
                if currentMode == .practice {
                    BPMControlView(
                        currentBPM: $currentBPM,
                        defaultBPM: lesson.defaultBPM,
                        onBPMChange: { newBPM in
                            lessonEngine.setBPM(newBPM)
                        }
                    )
                    
                    Divider()
                    
                    // Loop controls
                    LoopControlsView(
                        isLoopEnabled: $isLoopEnabled,
                        loopStart: $loopStart,
                        loopEnd: $loopEnd,
                        lessonDuration: lesson.duration,
                        onLoopChange: { start, end in
                            lessonEngine.setLoopRegion(start: start, end: end)
                        }
                    )
                    
                    Divider()
                    
                    // Wait mode toggle
                    WaitModeToggle(
                        isWaitModeEnabled: $isWaitModeEnabled,
                        onToggle: { enabled in
                            lessonEngine.setWaitMode(enabled)
                        }
                    )
                }
                
                Spacer()
            }
            .padding(16)
        }
        .background(Color("controlsBackground"))
    }
}

// MARK: - Play Controls View

struct PlayControlsView: View {
    @Binding var isPlaying: Bool
    let onPlay: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Playback")
                .font(.headline)
                .foregroundColor(Color("textColor1"))
            
            HStack(spacing: 16) {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                }
                .disabled(!isPlaying)
                
                Button(action: isPlaying ? onPause : onPlay) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}

// MARK: - BPM Control View

struct BPMControlView: View {
    @Binding var currentBPM: Float
    let defaultBPM: Float
    let onBPMChange: (Float) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("BPM")
                    .font(.headline)
                    .foregroundColor(Color("textColor1"))
                
                Spacer()
                
                Button("Reset") {
                    currentBPM = defaultBPM
                    onBPMChange(defaultBPM)
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                Text("\(Int(currentBPM))")
                    .font(.system(.title, design: .monospaced))
                    .foregroundColor(Color("textColor1"))
                
                Slider(
                    value: $currentBPM,
                    in: 60...200,
                    step: 5
                ) { _ in
                    onBPMChange(currentBPM)
                }
                .accentColor(.blue)
                
                HStack {
                    Text("60")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("200")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Loop Controls View

struct LoopControlsView: View {
    @Binding var isLoopEnabled: Bool
    @Binding var loopStart: TimeInterval
    @Binding var loopEnd: TimeInterval
    let lessonDuration: TimeInterval
    let onLoopChange: (TimeInterval, TimeInterval) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Loop")
                    .font(.headline)
                    .foregroundColor(Color("textColor1"))
                
                Spacer()
                
                Toggle("", isOn: $isLoopEnabled)
                    .onChange(of: isLoopEnabled) { enabled in
                        if enabled {
                            onLoopChange(loopStart, loopEnd)
                        }
                    }
            }
            
            if isLoopEnabled {
                VStack(spacing: 8) {
                    HStack {
                        Text("Start: \(formatTime(loopStart))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("End: \(formatTime(loopEnd))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Simplified loop range selector
                    HStack(spacing: 8) {
                        Button("-5s") {
                            loopStart = max(0, loopStart - 5)
                            onLoopChange(loopStart, loopEnd)
                        }
                        .font(.caption)
                        
                        Spacer()
                        
                        Button("+5s") {
                            loopEnd = min(lessonDuration, loopEnd + 5)
                            onLoopChange(loopStart, loopEnd)
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Wait Mode Toggle

struct WaitModeToggle: View {
    @Binding var isWaitModeEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Wait Mode")
                    .font(.headline)
                    .foregroundColor(Color("textColor1"))
                
                Spacer()
                
                Toggle("", isOn: $isWaitModeEnabled)
                    .onChange(of: isWaitModeEnabled) { enabled in
                        onToggle(enabled)
                    }
            }
            
            if isWaitModeEnabled {
                Text("Playback will pause at each target note until you play it correctly")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Extensions

extension TimingFeedback {
    var displayName: String {
        switch self {
        case .perfect: return "Perfect"
        case .early: return "Early"
        case .late: return "Late"
        case .miss: return "Miss"
        case .extra: return "Extra"
        }
    }
    
    var color: Color {
        switch self {
        case .perfect: return .green
        case .early: return .orange
        case .late: return .orange
        case .miss: return .red
        case .extra: return .purple
        }
    }
}

// MARK: - Preview

struct LessonPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample lesson for preview
        let context = CoreDataManager.shared.context
        let lesson = Lesson(context: context)
        lesson.id = "preview-lesson"
        lesson.title = "Basic Rock Beat"
        lesson.defaultBPM = 120
        lesson.duration = 60
        lesson.difficulty = 2
        
        return LessonPlayerView(lesson: lesson, conductor: Conductor())
            .environment(\.managedObjectContext, context)
    }
}