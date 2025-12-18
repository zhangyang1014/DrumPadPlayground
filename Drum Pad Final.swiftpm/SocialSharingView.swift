import SwiftUI

struct SocialSharingView: View {
    @ObservedObject var socialManager: SocialSharingManager
    @StateObject private var progressManager = ProgressManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedShareType: ShareType = .progress
    @State private var customMessage: String = ""
    @State private var selectedPlatforms: Set<SocialPlatform> = []
    @State private var showingPreview = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Share type selector
                shareTypeSection
                
                // Content preview
                contentPreviewSection
                
                // Custom message
                customMessageSection
                
                // Platform selection
                platformSelectionSection
                
                // Share button
                shareButtonSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("Share Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var shareTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What would you like to share?")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ShareTypeCard(
                    type: .progress,
                    title: "Progress Update",
                    description: "Share your current level and achievements",
                    icon: "chart.line.uptrend.xyaxis",
                    isSelected: selectedShareType == .progress
                ) {
                    selectedShareType = .progress
                }
                
                ShareTypeCard(
                    type: .achievement,
                    title: "New Achievement",
                    description: "Share your latest unlocked achievement",
                    icon: "trophy.fill",
                    isSelected: selectedShareType == .achievement
                ) {
                    selectedShareType = .achievement
                }
                
                ShareTypeCard(
                    type: .score,
                    title: "Perfect Score",
                    description: "Share your perfect performance",
                    icon: "star.fill",
                    isSelected: selectedShareType == .score
                ) {
                    selectedShareType = .score
                }
                
                ShareTypeCard(
                    type: .lesson,
                    title: "Lesson Complete",
                    description: "Share a completed lesson",
                    icon: "checkmark.circle.fill",
                    isSelected: selectedShareType == .lesson
                ) {
                    selectedShareType = .lesson
                }
            }
        }
    }
    
    private var contentPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
                .fontWeight(.semibold)
            
            SharePreviewCard(
                shareType: selectedShareType,
                progressManager: progressManager,
                customMessage: customMessage
            )
        }
    }
    
    private var customMessageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add a personal message (optional)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if #available(iOS 16.0, *) {
                TextField("What's on your mind?", text: $customMessage, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
            } else {
                // iOS 15 兼容写法（无 axis/lineLimit 多行支持，可退化为单行输入）
                TextField("What's on your mind?", text: $customMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
    
    private var platformSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share to")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(SocialPlatform.allCases, id: \.self) { platform in
                    PlatformButton(
                        platform: platform,
                        isSelected: selectedPlatforms.contains(platform)
                    ) {
                        if selectedPlatforms.contains(platform) {
                            selectedPlatforms.remove(platform)
                        } else {
                            selectedPlatforms.insert(platform)
                        }
                    }
                }
            }
        }
    }
    
    private var shareButtonSection: some View {
        VStack(spacing: 12) {
            Button(action: shareContent) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Now")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedPlatforms.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(12)
            }
            .disabled(selectedPlatforms.isEmpty)
            
            Text("Your progress will be shared to \(selectedPlatforms.count) platform\(selectedPlatforms.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func shareContent() {
        let content = createShareableContent()
        
        for platform in selectedPlatforms {
            socialManager.shareToSocialMedia(content, platform: platform)
        }
        
        // Add to shareable content history
        socialManager.shareableContent.insert(content, at: 0)
        
        dismiss()
    }
    
    private func createShareableContent() -> ShareableContent {
        let progress = progressManager.getProgressSummary()
        
        switch selectedShareType {
        case .progress:
            return socialManager.createShareableProgress(progress)
        case .achievement:
            let achievement = progress.recentAchievements.first ?? Achievement.levelUp(level: progress.currentLevel)
            return socialManager.createShareableAchievement(achievement)
        case .score:
            let mockScore = ScoreResult(
                totalScore: 100.0,
                starRating: 3,
                isPlatinum: true,
                isBlackStar: false,
                timingResults: [],
                streakCount: 10,
                missCount: 0,
                completionTime: 180
            )
            return socialManager.createShareableScore(mockScore, lessonTitle: "Advanced Rock Beat")
        case .lesson:
            return ShareableContent(
                id: UUID().uuidString,
                type: .lesson,
                title: "Lesson Completed!",
                description: customMessage.isEmpty ? "Just completed another drum lesson! 🥁" : customMessage,
                imageData: nil,
                data: nil,
                createdAt: Date()
            )
        }
    }
}

// MARK: - Supporting Views

struct ShareTypeCard: View {
    let type: ShareType
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .blue)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SharePreviewCard: View {
    let shareType: ShareType
    let progressManager: ProgressManager
    let customMessage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("You")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("now")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text(previewText)
                .font(.subheadline)
            
            if shareType == .progress {
                progressPreviewContent
            } else if shareType == .achievement {
                achievementPreviewContent
            } else if shareType == .score {
                scorePreviewContent
            }
            
            HStack {
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                        Text("Like")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                        Text("Comment")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var previewText: String {
        if !customMessage.isEmpty {
            return customMessage
        }
        
        let progress = progressManager.getProgressSummary()
        
        switch shareType {
        case .progress:
            return "Just reached level \(progress.currentLevel) in my drum training! 🥁 \(progress.totalStars) stars earned and \(progress.currentStreak) day streak going strong! #DrumTrainer #Music"
        case .achievement:
            return "New achievement unlocked! 🏆 Loving the progress I'm making with my drum skills! #DrumTrainer #Achievement"
        case .score:
            return "Perfect score! 🌟 Just nailed 'Advanced Rock Beat' with 100% accuracy! The practice is paying off! #DrumTrainer #PerfectScore"
        case .lesson:
            return "Another lesson completed! 📚 Step by step, getting better at drums every day! #DrumTrainer #Practice"
        }
    }
    
    private var progressPreviewContent: some View {
        let progress = progressManager.getProgressSummary()
        
        return HStack(spacing: 16) {
            VStack {
                Text("\(progress.currentLevel)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                Text("Level")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack {
                Text("\(progress.totalStars)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
                Text("Stars")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack {
                Text("\(progress.currentStreak)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Text("Day Streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private var achievementPreviewContent: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .font(.largeTitle)
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading) {
                Text("Level Up!")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("Reached Level 5")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private var scorePreviewContent: some View {
        HStack {
            VStack {
                Text("100%")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                HStack {
                    ForEach(0..<3) { _ in
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Advanced Rock Beat")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Perfect Performance")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct PlatformButton: View {
    let platform: SocialPlatform
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: platform.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : platformColor)
                
                Text(platform.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? platformColor : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var platformColor: Color {
        switch platform {
        case .twitter: return .blue
        case .facebook: return Color(red: 0.23, green: 0.35, blue: 0.60)
        case .instagram: return Color(red: 0.83, green: 0.32, blue: 0.55)
        case .discord: return Color(red: 0.35, green: 0.39, blue: 0.96)
        }
    }
}

// MARK: - Extensions

extension ScoreResult {
    init(totalScore: Float, starRating: Int, isPlatinum: Bool, isBlackStar: Bool, timingResults: [TimingResult], streakCount: Int, missCount: Int, completionTime: TimeInterval) {
        self = ScoreResult(
            totalScore: totalScore,
            starRating: starRating,
            isPlatinum: isPlatinum,
            isBlackStar: isBlackStar,
            timingResults: timingResults,
            streakCount: streakCount,
            maxStreak: streakCount,
            missCount: missCount,
            extraCount: 0,
            perfectCount: 0,
            earlyCount: 0,
            lateCount: 0,
            completionTime: completionTime
        )
    }
}