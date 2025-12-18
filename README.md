# FingerDrumHero

An interactive drum practice application built with SwiftUI and AudioKit, designed to help drummers of all levels improve their timing, technique, and musical skills through structured lessons and real-time feedback.

![Build Status](https://github.com/zhangyang1014/DrumPadPlayground/workflows/CI/badge.svg)
![Platform](https://img.shields.io/badge/platform-iOS%2015.2%2B-blue)
![Language](https://img.shields.io/badge/language-Swift%205.7-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### 🥁 Interactive Practice
- **Real-time feedback** on timing and accuracy
- **Multiple practice modes**: Performance, Practice, and Memory
- **MIDI drum device support** for authentic playing experience
- **Built-in metronome** with 6 different sounds and subdivisions

### 📚 Structured Learning
- **Progressive lesson system** from beginner to advanced
- **Organized courses** around specific techniques and styles
- **Step-by-step skill building** with clear learning objectives
- **Custom content import** via MIDI files

### 🎯 Gamified Progress
- **Star rating system** (1-3 stars + Platinum + Black Star)
- **Achievement tracking** with trophies and milestones
- **Daily practice goals** and streak counting
- **User level progression** that unlocks new content

### ⚙️ Customizable Experience
- **Adjustable BPM** and loop regions for focused practice
- **Wait mode** that pauses until correct input
- **High contrast mode** for accessibility
- **Latency compensation** for perfect timing accuracy

### ☁️ Cloud Synchronization
- **CloudKit integration** keeps progress synced across devices
- **Offline-first design** with automatic sync when connected
- **Backup and restore** functionality for peace of mind

## Technical Architecture

### Core Systems
- **Audio Engine**: Built on AudioKit 5.x for low-latency audio processing
- **MIDI Processing**: Real-time MIDI input handling and device management
- **Score Engine**: Precise timing evaluation with configurable windows
- **Lesson Engine**: Flexible playback system supporting multiple practice modes
- **Progress Management**: Comprehensive tracking with CloudKit synchronization

### Data Models
- **Core Data** for local persistence with CloudKit sync
- **Property-based testing** ensuring correctness across all components
- **Modular architecture** supporting easy extension and maintenance

## Requirements

- **iOS 15.2+** or **iPadOS 15.2+**
- **Xcode 15.2+** for development
- **MIDI drum device** (recommended, but works with touch controls)
- **Wired headphones** recommended for best timing accuracy

## Installation

### For Users
The app will be available on the App Store after submission and approval.

### For Developers

1. **Clone the repository**
   ```bash
   git clone https://github.com/zhangyang1014/DrumPadPlayground.git
   cd DrumPadPlayground
   ```

2. **Open in Xcode**
   ```bash
   open "Drum Pad Final.swiftpm"
   ```

3. **Install dependencies**
   Dependencies are managed through Swift Package Manager and will be automatically resolved.

4. **Build and run**
   Select an iPad simulator or device and press ⌘+R

## Development

### Project Structure
```
Drum Pad Final.swiftpm/
├── Sources/
│   ├── Audio/              # AudioKit integration and MIDI handling
│   ├── Lessons/            # Lesson engine and content management
│   ├── Scoring/            # Real-time evaluation and feedback
│   ├── Progress/           # User progress and achievement tracking
│   ├── UI/                 # SwiftUI views and components
│   └── Data/               # Core Data models and CloudKit sync
├── Tests/                  # Comprehensive test suite
├── Resources/              # Audio samples and assets
└── Documentation/          # User manual and technical docs
```

### Testing

The project includes comprehensive testing with both unit tests and property-based tests:

```bash
# Run all tests
xcodebuild test -scheme "Drum Pad Final" -destination "platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)"

# Run only property-based tests
xcodebuild test -scheme "Drum Pad Final" -only-testing "PropertyTests"
```

**Test Coverage**: 61 property-based tests covering 29 correctness properties across all major system components.

### Code Quality

- **SwiftLint** for code style consistency
- **Property-based testing** for correctness verification
- **Continuous Integration** with GitHub Actions
- **Code coverage** tracking and reporting

### Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure all tests pass and follow the existing code style.

## Architecture Decisions

### Why Property-Based Testing?
We use property-based testing extensively because:
- **Audio timing** requires precision across infinite input combinations
- **MIDI processing** must handle diverse device behaviors correctly
- **Score calculation** needs mathematical correctness guarantees
- **User progress** must maintain consistency across all scenarios

### Why AudioKit?
AudioKit provides:
- **Low-latency audio processing** essential for real-time feedback
- **Mature MIDI handling** with broad device compatibility
- **Cross-platform consistency** for future expansion
- **Active community** and ongoing development

### Why SwiftUI?
SwiftUI enables:
- **Rapid UI development** with declarative syntax
- **Built-in accessibility** support
- **Smooth animations** for engaging user experience
- **iPad-optimized** layouts and interactions

## Performance Considerations

- **Audio latency**: <20ms target for real-time feedback
- **Memory usage**: Optimized for extended practice sessions
- **Battery life**: Efficient audio processing and background handling
- **Storage**: Compressed audio assets and efficient data models

## Accessibility

The app includes comprehensive accessibility support:
- **VoiceOver** compatibility for screen readers
- **Dynamic Type** support for text scaling
- **High Contrast** mode for visual accessibility
- **Reduced Motion** options for motion sensitivity

## Privacy & Security

- **Local-first**: All practice data stored locally by default
- **Optional sync**: CloudKit sync requires explicit user consent
- **No tracking**: No analytics or user behavior tracking
- **Secure storage**: Sensitive data encrypted using iOS keychain

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **AudioKit** team for the excellent audio framework
- **Swift Testing** community for property-based testing tools
- **Drum education** community for feedback and requirements
- **Beta testers** who helped refine the user experience

## Support

- **Documentation**: See `Documentation/USER_MANUAL.md`
- **Issues**: Report bugs via GitHub Issues
- **Discussions**: Join community discussions in GitHub Discussions
- **Contact**: [apple@bugelife.com](mailto:apple@bugelife.com)

---

**Built with ❤️ for the drumming community**