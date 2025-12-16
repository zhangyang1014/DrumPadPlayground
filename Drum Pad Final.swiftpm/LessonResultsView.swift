import SwiftUI

// MARK: - Lesson Results View

struct LessonResultsView: View {
    let lesson: Lesson
    let scoreResult: ScoreResult
    let onRetry: () -> Void
    let onClose: () -> Void
    
    @State private var showingDetailedResults = false
    @State private var animateStars = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with lesson info
                    LessonResultsHeader(lesson: lesson)
                    
                    // Score display
                    ScoreDisplayView(
                        scoreResult: scoreResult,
                        animateStars: $animateStars
                    )
                    
                    // Performance summary
                    PerformanceSummaryView(scoreResult: scoreResult)
                    
                    // Detailed breakdown button
                    Button("View Detailed Results") {
                        showingDetailedResults = true
                    }
                    .buttonStyle(.bordered)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button("Try Again") {
                            onRetry()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Button("Choose Another Lesson") {
                            onClose()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Lesson Complete")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    onClose()
                }
            )
        }
        .onAppear {
            // Animate stars after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animateStars = true
                }
            }
        }
        .sheet(isPresented: $showingDetailedResults) {
            DetailedResultsView(
                lesson: lesson,
                scoreResult: scoreResult
            )
        }
    }
}

// MARK: - Lesson Results Header

struct LessonResultsHeader: View {
    let lesson: Lesson
    
    var body: some View {
        VStack(spacing: 8) {
            Text(lesson.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color("textColor1"))
            
            HStack(spacing: 16) {
                DifficultyBadge(level: DifficultyLevel(rawValue: Int(lesson.difficulty)) ?? .beginner)
                
                Label("\(Int(lesson.defaultBPM)) BPM", systemImage: "metronome")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Score Display View

struct ScoreDisplayView: View {
    let scoreResult: ScoreResult
    @Binding var animateStars: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Main score
            VStack(spacing: 8) {
                Text("\(Int(scoreResult.totalScore))%")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor)
                
                Text(scoreDescription)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Star rating
            StarRatingView(
                rating: scoreResult.starRating,
                isPlatinum: scoreResult.isPlatinum,
                isBlackStar: scoreResult.isBlackStar,
                animate: animateStars
            )
            
            // Special achievements
            if scoreResult.isPlatinum || scoreResult.isBlackStar {
                SpecialAchievementView(
                    isPlatinum: scoreResult.isPlatinum,
                    isBlackStar: scoreResult.isBlackStar
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("controlsBackground"))
        )
    }
    
    private var scoreColor: Color {
        switch scoreResult.totalScore {
        case 90...100: return .green
        case 75..<90: return .blue
        case 50..<75: return .orange
        default: return .red
        }
    }
    
    private var scoreDescription: String {
        switch scoreResult.totalScore {
        case 90...100: return "Excellent!"
        case 75..<90: return "Great Job!"
        case 50..<75: return "Good Effort!"
        default: return "Keep Practicing!"
        }
    }
}

// MARK: - Star Rating View

struct StarRatingView: View {
    let rating: Int
    let isPlatinum: Bool
    let isBlackStar: Bool
    let animate: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                StarView(
                    isFilled: index < rating,
                    isPlatinum: isPlatinum && index < rating,
                    isBlackStar: isBlackStar && index < rating,
                    animationDelay: Double(index) * 0.1
                )
                .scaleEffect(animate ? 1.0 : 0.1)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.8)
                    .delay(Double(index) * 0.1),
                    value: animate
                )
            }
        }
    }
}

// MARK: - Star View

struct StarView: View {
    let isFilled: Bool
    let isPlatinum: Bool
    let isBlackStar: Bool
    let animationDelay: Double
    
    var body: some View {
        Image(systemName: isFilled ? "star.fill" : "star")
            .font(.system(size: 32))
            .foregroundColor(starColor)
            .overlay(
                // Special effects for platinum/black stars
                Group {
                    if isPlatinum {
                        Image(systemName: "star.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .opacity(0.8)
                            .scaleEffect(1.2)
                            .blur(radius: 2)
                    } else if isBlackStar {
                        Image(systemName: "star.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.black)
                            .overlay(
                                Image(systemName: "star")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            )
                    }
                }
            )
    }
    
    private var starColor: Color {
        if !isFilled {
            return .secondary
        } else if isBlackStar {
            return .black
        } else if isPlatinum {
            return .yellow
        } else {
            return .yellow
        }
    }
}

// MARK: - Special Achievement View

struct SpecialAchievementView: View {
    let isPlatinum: Bool
    let isBlackStar: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            if isPlatinum {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("Platinum Performance!")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.yellow.opacity(0.2))
                )
            }
            
            if isBlackStar {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.black)
                    Text("Memory Master!")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.1))
                )
            }
        }
    }
}

// MARK: - Performance Summary View

struct PerformanceSummaryView: View {
    let scoreResult: ScoreResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Summary")
                .font(.headline)
                .foregroundColor(Color("textColor1"))
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                PerformanceStatView(
                    title: "Perfect",
                    value: scoreResult.perfectCount,
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                PerformanceStatView(
                    title: "Early/Late",
                    value: scoreResult.earlyCount + scoreResult.lateCount,
                    color: .orange,
                    icon: "clock.fill"
                )
                
                PerformanceStatView(
                    title: "Missed",
                    value: scoreResult.missCount,
                    color: .red,
                    icon: "xmark.circle.fill"
                )
                
                PerformanceStatView(
                    title: "Max Streak",
                    value: scoreResult.maxStreak,
                    color: .blue,
                    icon: "flame.fill"
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("controlsBackground"))
        )
    }
}

// MARK: - Performance Stat View

struct PerformanceStatView: View {
    let title: String
    let value: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color("textColor1"))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("background"))
        )
    }
}

// MARK: - Detailed Results View

struct DetailedResultsView: View {
    let lesson: Lesson
    let scoreResult: ScoreResult
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section("Timing Analysis") {
                    ForEach(Array(scoreResult.timingResults.enumerated()), id: \.offset) { index, result in
                        TimingResultRowView(
                            index: index + 1,
                            result: result
                        )
                    }
                }
                
                Section("Statistics") {
                    StatisticRowView(title: "Total Score", value: "\(Int(scoreResult.totalScore))%")
                    StatisticRowView(title: "Completion Time", value: formatTime(scoreResult.completionTime))
                    StatisticRowView(title: "Perfect Notes", value: "\(scoreResult.perfectCount)")
                    StatisticRowView(title: "Early Notes", value: "\(scoreResult.earlyCount)")
                    StatisticRowView(title: "Late Notes", value: "\(scoreResult.lateCount)")
                    StatisticRowView(title: "Missed Notes", value: "\(scoreResult.missCount)")
                    StatisticRowView(title: "Extra Notes", value: "\(scoreResult.extraCount)")
                    StatisticRowView(title: "Max Streak", value: "\(scoreResult.maxStreak)")
                }
            }
            .navigationTitle("Detailed Results")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Timing Result Row View

struct TimingResultRowView: View {
    let index: Int
    let result: TimingResult
    
    var body: some View {
        HStack {
            Text("\(index)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Note at \(formatTime(result.targetEvent.timestamp))")
                    .font(.body)
                
                if let userEvent = result.userEvent {
                    Text("Played at \(formatTime(userEvent.timestamp))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Not played")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                TimingFeedbackBadge(timing: result.timing)
                
                Text("\(Int(result.score))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

// MARK: - Statistic Row View

struct StatisticRowView: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(Color("textColor1"))
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

struct LessonResultsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleResult = ScoreResult(
            totalScore: 85.5,
            starRating: 2,
            isPlatinum: false,
            isBlackStar: false,
            timingResults: [],
            streakCount: 12,
            maxStreak: 15,
            missCount: 3,
            extraCount: 1,
            perfectCount: 25,
            earlyCount: 4,
            lateCount: 2,
            completionTime: 120
        )
        
        let context = CoreDataManager.shared.context
        let lesson = Lesson(context: context)
        lesson.id = "preview-lesson"
        lesson.title = "Basic Rock Beat"
        lesson.defaultBPM = 120
        lesson.duration = 60
        lesson.difficulty = 2
        
        return LessonResultsView(
            lesson: lesson,
            scoreResult: sampleResult,
            onRetry: {},
            onClose: {}
        )
    }
}