import SwiftUI

@main
struct DrumPadAppApp: App {
    
    let conductor = Conductor()

    init() {
        // 确保音频引擎在应用启动时初始化
        print("🚀 DrumPadApp: 应用启动，初始化音频引擎...")
        conductor.start()
        print("🚀 DrumPadApp: 音频引擎初始化完成")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(conductor)
        }
    }
}
