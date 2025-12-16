import Foundation

// Simple debug test to understand the timing logic
struct ScoringProfile {
    let perfectWindow: TimeInterval = 0.020      // ±20ms
    let earlyWindow: TimeInterval = 0.050        // ±50ms
    let lateWindow: TimeInterval = 0.050         // ±50ms
    let missThreshold: TimeInterval = 0.100      // ±100ms
}

struct TargetEvent {
    let timestamp: TimeInterval
    let noteNumber: Int
}

struct MIDIEvent {
    let timestamp: TimeInterval
    let noteNumber: Int
}

enum TimingFeedback: String {
    case perfect = "perfect"
    case early = "early"
    case late = "late"
    case miss = "miss"
    case extra = "extra"
}

func calculateTimingFeedback(_ event: MIDIEvent, targetEvents: [TargetEvent], profile: ScoringProfile) -> TimingFeedback {
    // Find the closest target event that matches this input
    var bestMatch: (target: TargetEvent, timeDiff: TimeInterval)?
    
    for target in targetEvents {
        // Check if note numbers match
        if target.noteNumber == event.noteNumber {
            let timeDiff = abs(event.timestamp - target.timestamp)
            
            // Only consider targets within miss threshold
            if timeDiff <= profile.missThreshold {
                if bestMatch == nil || timeDiff < bestMatch!.timeDiff {
                    bestMatch = (target, timeDiff)
                }
            }
        }
    }
    
    guard let match = bestMatch else {
        // No matching target found - this is an extra hit
        return .extra
    }
    
    // Determine timing feedback based on time difference
    let timeDiff = event.timestamp - match.target.timestamp
    
    print("Event at \(event.timestamp), Target at \(match.target.timestamp), TimeDiff: \(timeDiff)")
    print("Perfect window: ±\(profile.perfectWindow), Early window: ±\(profile.earlyWindow), Late window: ±\(profile.lateWindow)")
    
    if abs(timeDiff) <= profile.perfectWindow {
        print("-> Perfect")
        return .perfect
    } else if timeDiff < -profile.perfectWindow && abs(timeDiff) <= profile.earlyWindow {
        // Early hit: user hit before the target time
        print("-> Early")
        return .early
    } else if timeDiff > profile.perfectWindow && abs(timeDiff) <= profile.lateWindow {
        // Late hit: user hit after the target time
        print("-> Late")
        return .late
    } else {
        // Outside all timing windows
        print("-> Miss")
        return .miss
    }
}

// Test case
let profile = ScoringProfile()
let target = TargetEvent(timestamp: 1.0, noteNumber: 60)
let targets = [target]

// Test early hit
let earlyEvent = MIDIEvent(timestamp: 0.97, noteNumber: 60) // 30ms early
let earlyResult = calculateTimingFeedback(earlyEvent, targetEvents: targets, profile: profile)
print("Early test result: \(earlyResult)")

// Test late hit  
let lateEvent = MIDIEvent(timestamp: 1.03, noteNumber: 60) // 30ms late
let lateResult = calculateTimingFeedback(lateEvent, targetEvents: targets, profile: profile)
print("Late test result: \(lateResult)")