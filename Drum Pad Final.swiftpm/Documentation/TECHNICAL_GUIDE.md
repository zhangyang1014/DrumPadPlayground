# Technical Guide - Melodic Drum Trainer

## Architecture Overview

Melodic Drum Trainer follows a modular MVVM architecture with clear separation of concerns across audio processing, data management, and user interface layers.

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
├─────────────────────────────────────────────────────────────┤
│ ContentView │ LessonPlayerView │ ProgressView │ SettingsView │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    Business Logic Layer                     │
├─────────────────────────────────────────────────────────────┤
│ LessonEngine │ ScoreEngine │ ProgressManager │ ContentManager │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      Data Layer                             │
├─────────────────────────────────────────────────────────────┤
│   CoreData   │   CloudKit   │  UserDefaults  │ FileManager  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                   AudioKit Foundation                       │
├─────────────────────────────────────────────────────────────┤
│    Conductor    │   MIDI Handler   │    Audio Engine       │
└─────────────────────────────────────────────────────────────┘
```

## Core Systems

### 1. Audio Engine (Conductor.swift)

The audio engine is built on AudioKit and handles all real-time audio processing.

**Key Responsibilities:**
- MIDI input processing and device management
- Audio playback and metronome functionality
- Low-latency audio routing and mixing
- Device connection monitoring

**Performance Targets:**
- Audio latency: <20ms
- MIDI processing: <5ms
- Memory usage: <50MB during active practice

**Implementation Details:**
```swift
class Conductor: ObservableObject {
    private let engine = AudioEngine()
    private var midiManager: MIDIManager
    
    // Target latency for real-time feedback
    private let targetLatency: TimeInterval = 0.020 // 20ms
    
    func setupAudio() {
        // Configure audio session for low latency
        engine.output = mixer
        try? engine.start()
    }
}
```

### 2. Lesson Engine (LessonEngine.swift)

Manages lesson playback, progression, and practice mode functionality.

**Key Features:**
- Multi-mode playback (Performance, Practice, Memory)
- BPM control and auto speed-up
- Loop region management
- Wait mode implementation

**State Management:**
```swift
enum PlaybackMode {
    case performance    // Full tempo, complete evaluation
    case practice      // Variable tempo, loop regions, wait mode
    case memory        // Hidden visual cues, full evaluation
}

enum PlaybackState {
    case stopped, playing, paused, waiting
}
```

### 3. Score Engine (ScoreEngine.swift)

Provides real-time timing evaluation and scoring functionality.

**Timing Windows:**
- Perfect: ±20ms
- Early/Late: ±50ms  
- Miss: >±100ms

**Scoring Algorithm:**
```swift
func calculateScore(for results: [TimingResult]) -> ScoreResult {
    let totalEvents = results.count
    let perfectCount = results.filter { $0.timing == .perfect }.count
    let earlyLateCount = results.filter { 
        $0.timing == .early || $0.timing == .late 
    }.count
    
    // Base score calculation
    let baseScore = (perfectCount * 100 + earlyLateCount * 75) / totalEvents
    
    // Apply difficulty multipliers and penalties
    return applyDifficultyModifiers(baseScore, results)
}
```

### 4. Progress Manager (ProgressManager.swift)

Tracks user progress, achievements, and statistics.

**Data Tracking:**
- Practice session duration and frequency
- Lesson completion rates and scores
- Daily goal achievement and streaks
- User level progression and XP

**Achievement System:**
```swift
enum AchievementType {
    case practiceTime(minutes: Int)
    case perfectScore(lessonId: String)
    case dailyStreak(days: Int)
    case levelReached(level: Int)
}
```

## Data Models

### Core Data Schema

The app uses Core Data with CloudKit synchronization for data persistence.

**Primary Entities:**
- `User`: User profile and preferences
- `Lesson`: Lesson content and metadata
- `LessonStep`: Individual practice steps within lessons
- `PracticeSession`: Individual practice session records
- `Achievement`: User achievement tracking

**Relationships:**
```
User ←→ PracticeSession ←→ Lesson
User ←→ Achievement
Lesson ←→ LessonStep
```

### CloudKit Integration

**Sync Strategy:**
- Automatic background sync when network available
- Conflict resolution favoring most recent data
- Offline-first design with local fallback

**Sync Entities:**
- User progress and achievements
- Custom lesson content
- Settings and preferences
- Practice session history

## Testing Strategy

### Property-Based Testing

The app uses extensive property-based testing to ensure correctness across all input combinations.

**Test Categories:**
1. **MIDI Processing Properties** (7 tests)
2. **Score Engine Properties** (12 tests)  
3. **Lesson Engine Properties** (8 tests)
4. **Content Management Properties** (6 tests)
5. **Progress Tracking Properties** (9 tests)
6. **UI Component Properties** (8 tests)
7. **Settings Properties** (5 tests)
8. **CloudKit Sync Properties** (4 tests)
9. **Audio Device Properties** (2 tests)

**Example Property Test:**
```swift
@Test("Score calculation consistency")
func scoreCalculationConsistency() {
    // Property: Same input should always produce same score
    let generator = TimingResultGenerator()
    
    for _ in 0..<100 {
        let results = generator.generate()
        let score1 = scoreEngine.calculateScore(for: results)
        let score2 = scoreEngine.calculateScore(for: results)
        
        #expect(score1.totalScore == score2.totalScore)
        #expect(score1.starRating == score2.starRating)
    }
}
```

### Test Generators

Smart generators create realistic test data:

**MIDI Event Generator:**
```swift
struct MIDIEventGenerator {
    func generateRealisticTiming() -> TimeInterval {
        // Generate timing with human-like variance
        let baseTime = targetTime
        let humanVariance = Double.random(in: -0.050...0.050) // ±50ms
        return baseTime + humanVariance
    }
}
```

## Performance Optimization

### Memory Management

**Audio Buffers:**
- Circular buffers for real-time audio processing
- Automatic cleanup of unused audio samples
- Memory pool for MIDI event objects

**UI Optimization:**
- Lazy loading of lesson content
- Image caching for lesson thumbnails
- View recycling in content browser

### Battery Optimization

**Background Processing:**
- Minimal background audio processing
- Intelligent sync scheduling
- CPU usage monitoring and throttling

**Audio Session Management:**
```swift
func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playAndRecord, 
                           mode: .default, 
                           options: [.defaultToSpeaker, .allowBluetooth])
    try? session.setPreferredIOBufferDuration(0.005) // 5ms for low latency
}
```

## Security Considerations

### Data Protection

**Local Storage:**
- Core Data encryption at rest
- Keychain storage for sensitive settings
- Secure file handling for imported content

**Network Security:**
- CloudKit provides end-to-end encryption
- Certificate pinning for API calls
- No sensitive data in network logs

### Privacy Compliance

**Data Collection:**
- No personal information beyond Apple ID for sync
- No usage analytics or tracking
- Local-first data processing

**User Consent:**
- Explicit opt-in for CloudKit sync
- Clear privacy policy and data handling disclosure
- User control over data sharing and deletion

## Deployment

### Build Configuration

**Release Settings:**
```swift
// Build Settings
SWIFT_OPTIMIZATION_LEVEL = -O
ENABLE_BITCODE = NO
STRIP_SWIFT_SYMBOLS = YES
```

**Info.plist Configuration:**
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is used for audio input calibration to ensure accurate timing feedback during drum practice.</string>

<key>NSLocalNetworkUsageDescription</key>
<string>Local network access is used to discover and connect to MIDI drum devices on your network.</string>
```

### App Store Optimization

**Keywords Strategy:**
- Primary: drums, drumming, practice, music education
- Secondary: MIDI, rhythm, metronome, lessons
- Long-tail: interactive drum trainer, drum timing practice

**Localization:**
- English (primary)
- Spanish, French, German (planned)
- Right-to-left language support

## Monitoring and Analytics

### Performance Monitoring

**Key Metrics:**
- Audio latency measurements
- Memory usage during practice sessions
- Battery consumption rates
- Crash-free session percentage

**Logging Strategy:**
```swift
enum LogLevel {
    case debug, info, warning, error, critical
}

struct Logger {
    static func log(_ message: String, level: LogLevel) {
        // Local logging only, no remote analytics
        os_log("%@", log: .default, type: logType(for: level), message)
    }
}
```

### Error Handling

**Recovery Strategies:**
- Automatic audio engine restart on failure
- Graceful degradation when MIDI devices disconnect
- Data corruption detection and repair
- Network failure handling with offline mode

## Development Workflow

### Code Quality

**SwiftLint Rules:**
- Line length: 120 characters
- Function complexity: max 10
- File length: max 500 lines
- Consistent naming conventions

**Git Workflow:**
- Feature branches for all changes
- Required code review for main branch
- Automated testing on all pull requests
- Semantic versioning for releases

### Continuous Integration

**GitHub Actions Pipeline:**
1. Code quality checks (SwiftLint)
2. Unit and property-based tests
3. Build verification
4. Security scanning
5. Performance testing

**Release Process:**
1. Version bump and changelog update
2. Full test suite execution
3. Archive build creation
4. App Store Connect upload
5. TestFlight distribution
6. Production release

## Troubleshooting

### Common Issues

**Audio Latency:**
- Check audio session configuration
- Verify buffer size settings
- Test with different audio devices
- Monitor CPU usage during processing

**MIDI Connection:**
- Verify device compatibility
- Check USB/Bluetooth connection
- Test manual MIDI mapping
- Monitor MIDI message flow

**CloudKit Sync:**
- Verify iCloud account status
- Check network connectivity
- Monitor sync operation logs
- Test conflict resolution

### Debug Tools

**Audio Debugging:**
```swift
#if DEBUG
func logAudioMetrics() {
    let latency = engine.outputNode.presentationLatency
    let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
    Logger.log("Audio latency: \(latency)s, Sample rate: \(sampleRate)Hz", level: .debug)
}
#endif
```

**MIDI Debugging:**
```swift
func logMIDIEvent(_ event: MIDIEvent) {
    #if DEBUG
    Logger.log("MIDI: \(event.noteNumber) velocity: \(event.velocity) time: \(event.timestamp)", level: .debug)
    #endif
}
```

## Future Architecture Considerations

### Scalability

**Multi-Platform Support:**
- Shared business logic framework
- Platform-specific UI implementations
- Cross-platform data synchronization

**Performance Scaling:**
- Background processing optimization
- Advanced caching strategies
- Predictive content loading

### Extensibility

**Plugin Architecture:**
- Modular lesson content system
- Third-party instrument support
- Custom scoring algorithms

**API Integration:**
- Music service integration
- Social platform connectivity
- Educational platform partnerships

---

*This technical guide is maintained alongside the codebase and updated with each major release.*