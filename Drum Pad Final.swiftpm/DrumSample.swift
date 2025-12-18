import AVFoundation

struct DrumSample {
    var name: String
    var fileName: String
    var midiNote: Int
    var audioFile: AVAudioFile?
    
    init(_ displayName: String, file: String, note: Int) {
        name = displayName
        fileName = file
        midiNote = note
        
        guard let resourceURL = ResourceLoader.loadAudioFile(named: file) else {
            return
        }
        
        do {
            audioFile = try AVAudioFile(forReading: resourceURL)
        } catch {
            print("Could not load audio file: \(resourceURL)")
            print("Error: \(error)")
        }
    }
}

