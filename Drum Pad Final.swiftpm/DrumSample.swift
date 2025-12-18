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
            print("⚠️ DrumSample: 找不到文件 \(file).wav")
            return
        }
        
        do {
            audioFile = try AVAudioFile(forReading: resourceURL)
        } catch {
            print("⚠️ DrumSample: 无法加载 \(resourceURL): \(error)")
        }
    }
}
