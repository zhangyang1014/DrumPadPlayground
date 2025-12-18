import Foundation

// MARK: - Resource Loading Test

struct ResourceTest {
    static func testResourceLoading() {
        print("🔍 Testing resource loading...")
        
        // Test audio files
        let audioFiles = [
            "bass_drum_C1",
            "snare_D1", 
            "closed_hi_hat_F#1",
            "crash_F1",
            "clap_D#1",
            "hi_tom_D2",
            "lo_tom_F1",
            "mid_tom_B1",
            "open_hi_hat_A#1"
        ]
        
        print("\n📁 Testing audio file loading:")
        for fileName in audioFiles {
            if let url = ResourceLoader.loadAudioFile(named: fileName) {
                print("✅ Found: \(fileName).wav at \(url.path)")
            } else {
                print("❌ Missing: \(fileName).wav")
            }
        }
        
        // Test Core Data model
        print("\n🗄️ Testing Core Data model loading:")
        if let modelURL = ResourceLoader.loadCoreDataModel(named: "DrumTrainerModel") {
            print("✅ Found Core Data model at: \(modelURL.path)")
        } else {
            print("❌ Missing Core Data model")
        }
        
        // Test metronome sounds (these might not exist yet)
        print("\n🎵 Testing metronome sound loading:")
        let metronomeFiles = ["metronome_click", "metronome_beep", "metronome_tick"]
        for fileName in metronomeFiles {
            if let url = ResourceLoader.loadAudioFile(named: fileName) {
                print("✅ Found: \(fileName).wav at \(url.path)")
            } else {
                print("⚠️ Missing (will use synthetic): \(fileName).wav")
            }
        }
        
        print("\n🔍 Resource loading test completed.")
    }
}