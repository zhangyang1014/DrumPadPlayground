import SwiftUI

// MARK: - Legacy Drum Pad View

struct LegacyDrumPadView: View {
    @State private var selectedPad: Int? = nil
    @State private var volume: Double = 0.8
    @State private var isRecording = false
    @State private var recordedSequence: [DrumHit] = []
    
    private let drumPads = [
        DrumPad(id: 0, name: "Kick", color: .red, soundFile: "bass_drum_C1"),
        DrumPad(id: 1, name: "Snare", color: .blue, soundFile: "snare_D1"),
        DrumPad(id: 2, name: "Hi-Hat", color: .green, soundFile: "closed_hi_hat_F#1"),
        DrumPad(id: 3, name: "Open Hat", color: .yellow, soundFile: "open_hi_hat_A#1"),
        DrumPad(id: 4, name: "Crash", color: .orange, soundFile: "crash_F1"),
        DrumPad(id: 5, name: "Hi Tom", color: .purple, soundFile: "hi_tom_D2"),
        DrumPad(id: 6, name: "Mid Tom", color: .pink, soundFile: "mid_tom_B1"),
        DrumPad(id: 7, name: "Low Tom", color: .cyan, soundFile: "lo_tom_F1"),
        DrumPad(id: 8, name: "Clap", color: .brown, soundFile: "clap_D#1")
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Legacy Drum Pad")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("The original drum pad experience")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            
            // Volume Control
            VStack(spacing: 8) {
                HStack {
                    Text("Volume")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(volume * 100))%")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $volume, in: 0...1, step: 0.1)
                    .accentColor(Color("knobFill"))
            }
            .padding(.horizontal)
            
            // Recording Controls
            HStack(spacing: 16) {
                Button(action: toggleRecording) {
                    HStack {
                        Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                        Text(isRecording ? "Stop" : "Record")
                    }
                    .foregroundColor(isRecording ? .red : .blue)
                    .font(.headline)
                }
                
                Button("Clear") {
                    recordedSequence.removeAll()
                }
                .foregroundColor(.orange)
                .font(.headline)
                
                Button("Playback") {
                    playbackSequence()
                }
                .foregroundColor(.green)
                .font(.headline)
                .disabled(recordedSequence.isEmpty)
            }
            .padding(.horizontal)
            
            // Drum Pads Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(drumPads, id: \.id) { pad in
                    DrumPadButton(
                        pad: pad,
                        isSelected: selectedPad == pad.id,
                        volume: volume
                    ) {
                        hitPad(pad)
                    }
                }
            }
            .padding(.horizontal)
            
            // Recording Status
            if isRecording {
                VStack(spacing: 4) {
                    Text("Recording...")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Text("\(recordedSequence.count) hits recorded")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if !recordedSequence.isEmpty {
                Text("\(recordedSequence.count) hits in sequence")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .navigationTitle("Legacy Mode")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("background"))
    }
    
    // MARK: - Actions
    
    private func hitPad(_ pad: DrumPad) {
        selectedPad = pad.id
        
        // Play sound
        LegacyAudioManager.shared.playSound(pad.soundFile, volume: volume)
        
        // Record hit if recording
        if isRecording {
            let hit = DrumHit(
                padId: pad.id,
                timestamp: Date(),
                velocity: Float(volume)
            )
            recordedSequence.append(hit)
        }
        
        // Reset selection after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            selectedPad = nil
        }
    }
    
    private func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            recordedSequence.removeAll()
        }
    }
    
    private func playbackSequence() {
        guard !recordedSequence.isEmpty else { return }
        
        let startTime = recordedSequence.first!.timestamp
        
        for hit in recordedSequence {
            let delay = hit.timestamp.timeIntervalSince(startTime)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if let pad = drumPads.first(where: { $0.id == hit.padId }) {
                    selectedPad = pad.id
                    LegacyAudioManager.shared.playSound(pad.soundFile, volume: Double(hit.velocity))
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        selectedPad = nil
                    }
                }
            }
        }
    }
}

// MARK: - Drum Pad Button

struct DrumPadButton: View {
    let pad: DrumPad
    let isSelected: Bool
    let volume: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(pad.color.opacity(isSelected ? 1.0 : 0.8))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .scaleEffect(isSelected ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isSelected)
                
                Text(pad.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color("textColor1"))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Models

struct DrumPad {
    let id: Int
    let name: String
    let color: Color
    let soundFile: String
}

struct DrumHit {
    let padId: Int
    let timestamp: Date
    let velocity: Float
}

// MARK: - Legacy Audio Manager

class LegacyAudioManager: ObservableObject {
    static let shared = LegacyAudioManager()
    
    private init() {}
    
    func playSound(_ soundFile: String, volume: Double) {
        // This would integrate with the existing Conductor or AudioKit setup
        // For now, we'll use a simple implementation
        print("Playing sound: \(soundFile) at volume: \(volume)")
        
        // In a real implementation, this would:
        // 1. Load the audio file from Resources
        // 2. Play it through AudioKit with the specified volume
        // 3. Handle any audio session management
    }
}

// MARK: - Preview

struct LegacyDrumPadView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LegacyDrumPadView()
        }
    }
}