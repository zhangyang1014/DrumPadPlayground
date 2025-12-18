import SwiftUI

@main
struct DrumPadAppApp: App {
    
    @StateObject private var conductor = Conductor()
    
    // 使用 @State 跟踪音频引擎是否已初始化
    @State private var isAudioInitialized = false

    init() {
        print("🚀 DrumPadApp: 应用启动，音频引擎将在视图加载后初始化...")
        
        // 重要修复：不在 init() 中启动音频引擎
        // 这会阻塞主线程，可能导致 Watchdog 超时和 SIGTERM
        // 音频引擎初始化移动到 onAppear 中延迟执行
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(conductor)
                .onAppear {
                    // 延迟初始化音频引擎，避免阻塞主线程
                    initializeAudioEngineAsync()
                }
        }
    }
    
    /// 异步初始化音频引擎，避免主线程阻塞导致 Watchdog 超时
    private func initializeAudioEngineAsync() {
        // 防止重复初始化
        guard !isAudioInitialized else {
            print("🎵 DrumPadApp: 音频引擎已初始化，跳过")
            return
        }
        
        print("🚀 DrumPadApp: 开始异步初始化音频引擎...")
        
        // 在后台线程执行音频初始化，然后在主线程更新状态
        DispatchQueue.global(qos: .userInitiated).async {
            // 延迟一小段时间，确保 UI 完全加载
            Thread.sleep(forTimeInterval: 0.1)
            
            // 在主线程启动音频引擎（AudioKit 需要在主线程操作）
            DispatchQueue.main.async {
                conductor.start()
                print("✅ DrumPadApp: 音频引擎初始化完成 (running: \(conductor.engine.avEngine.isRunning))")
            }
        }
    }
}
