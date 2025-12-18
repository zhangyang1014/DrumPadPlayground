import SwiftUI

// MARK: - Color Extensions for Drum Pad Instruments

extension Color {
    /// 根据打击垫名称返回对应的乐器颜色
    /// - Parameter padName: 打击垫名称
    /// - Returns: 对应的颜色
    static func drumPadColor(for padName: String) -> Color {
        if padName.contains("KICK") {
            return Color(red: 1.0, green: 0.42, blue: 0.21) // #FF6B35 橙色
        } else if padName.contains("SNARE") {
            return Color(red: 1.0, green: 0.42, blue: 0.62) // #FF6B9D 粉色
        } else if padName.contains("HI HAT") || padName.contains("HAT") {
            return Color(red: 0.58, green: 0.88, blue: 0.83) // #95E1D3 绿色
        } else if padName.contains("TOM") {
            return Color(red: 0.98, green: 0.78, blue: 0.31) // #F9C74F 黄色
        } else if padName.contains("CRASH") || padName.contains("RIDE") {
            return Color(red: 0.31, green: 0.80, blue: 0.77) // #4ECDC4 青色
        } else {
            // 其他特殊打击（RIM SHOT, SIDE STICK, OPEN HAT）
            return Color(red: 0.58, green: 0.88, blue: 0.83) // 默认绿色
        }
    }
    
    /// 调整颜色亮度
    /// - Parameter amount: 亮度调整量（-1.0 到 1.0，正值变亮，负值变暗）
    /// - Returns: 调整后的颜色
    func adjustedBrightness(_ amount: Double) -> Color {
        // 使用 UIColor/NSColor 来调整 HSB 值
        #if os(iOS)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // 调整亮度，确保在 0-1 范围内
        let newBrightness = max(0, min(1, brightness + CGFloat(amount)))
        
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(newBrightness), opacity: Double(alpha))
        #else
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        NSColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let newBrightness = max(0, min(1, brightness + CGFloat(amount)))
        
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(newBrightness), opacity: Double(alpha))
        #endif
    }
}

// MARK: - Legacy Drum Pad View

struct LegacyDrumPadView: View {
    @EnvironmentObject var conductor: Conductor
    @StateObject private var configManager = PadConfigurationManager.shared
    
    @State private var selectedPad: Int? = nil
    @State private var volume: Double = 0.8
    @State private var isRecording = false
    @State private var recordedSequence: [DrumHit] = []
    
    // 新增：预设和效果器编辑状态
    @State private var showingPresetManager = false
    @State private var showingPadEditor = false
    @State private var editingPadId: Int? = nil
    
    // 4x4 打击垫布局 - 按照标准鼓垫模板配置
    // 第一行：镲片区域
    // 第二行：通鼓区域
    // 第三行：特殊打击区域
    // 第四行：基础节奏区域
    private let drumPads = [
        // 第一行：镲片（青色系）
        DrumPad(id: 0, name: "CRASH\nLEFT", color: .drumPadColor(for: "CRASH"), soundFile: "crash_F1"),
        DrumPad(id: 1, name: "CRASH\nRIGHT", color: .drumPadColor(for: "CRASH"), soundFile: "crash_F1"),
        DrumPad(id: 2, name: "RIDE", color: .drumPadColor(for: "RIDE"), soundFile: "closed_hi_hat_F#1"),
        DrumPad(id: 3, name: "RIDE\nBELL", color: .drumPadColor(for: "RIDE"), soundFile: "open_hi_hat_A#1"),
        
        // 第二行：通鼓（黄色系）
        DrumPad(id: 4, name: "TOM 1", color: .drumPadColor(for: "TOM"), soundFile: "hi_tom_D2"),
        DrumPad(id: 5, name: "TOM 2", color: .drumPadColor(for: "TOM"), soundFile: "mid_tom_B1"),
        DrumPad(id: 6, name: "TOM 3", color: .drumPadColor(for: "TOM"), soundFile: "lo_tom_F1"),
        DrumPad(id: 7, name: "TOM 4", color: .drumPadColor(for: "TOM"), soundFile: "lo_tom_F1"),
        
        // 第三行：特殊打击（橙色、绿色系）
        DrumPad(id: 8, name: "KICK", color: .drumPadColor(for: "KICK"), soundFile: "bass_drum_C1"),
        DrumPad(id: 9, name: "RIM\nSHOT", color: .drumPadColor(for: "RIM SHOT"), soundFile: "clap_D#1"),
        DrumPad(id: 10, name: "SIDE\nSTICK", color: .drumPadColor(for: "SIDE STICK"), soundFile: "snare_D1"),
        DrumPad(id: 11, name: "OPEN\nHAT", color: .drumPadColor(for: "OPEN HAT"), soundFile: "open_hi_hat_A#1"),
        
        // 第四行：基础节奏（橙色、粉色、绿色系）
        DrumPad(id: 12, name: "KICK", color: .drumPadColor(for: "KICK"), soundFile: "bass_drum_C1"),
        DrumPad(id: 13, name: "SNARE", color: .drumPadColor(for: "SNARE"), soundFile: "snare_D1"),
        DrumPad(id: 14, name: "HI HAT", color: .drumPadColor(for: "HI HAT"), soundFile: "closed_hi_hat_F#1"),
        DrumPad(id: 15, name: "HI HAT", color: .drumPadColor(for: "HI HAT"), soundFile: "closed_hi_hat_F#1")
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // 快速状态检查（可折叠）
            QuickStatusView(conductor: conductor)
            
            // 标题区域
            VStack(spacing: 4) {
                Text("PAD SETUP TEMPLATE")
                    .font(.system(size: 24, weight: .black, design: .default))
                    .italic()
                    .foregroundColor(Color("textColor1"))
            }
            .padding(.top, 8)
            
            // 音量控制和预设菜单
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.secondary)
                
                Slider(value: $volume, in: 0...1, step: 0.05)
                    .accentColor(Color(red: 0.31, green: 0.80, blue: 0.77)) // 青色系，匹配镲片颜色
                
                Text("\(Int(volume * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40)
                
                // 新增：预设快速切换菜单
                Menu {
                    // 当前激活预设显示
                    if let activePreset = configManager.activePreset {
                        Text("当前: \(activePreset.name)")
                            .font(.caption)
                        Divider()
                    }
                    
                    // 快速切换预设
                    ForEach(configManager.availablePresets) { preset in
                        Button(action: {
                            applyPreset(preset)
                        }) {
                            HStack {
                                Text(preset.name)
                                if preset.isBuiltIn {
                                    Image(systemName: "star.fill")
                                }
                                if configManager.activePreset?.id == preset.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 管理预设
                    Button(action: {
                        showingPresetManager = true
                    }) {
                        Label("管理预设", systemImage: "gearshape")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("预设")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            
            // 4x4 打击垫网格 - 主要区域
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(drumPads, id: \.id) { pad in
                    DrumPadButton(
                        pad: pad,
                        isSelected: selectedPad == pad.id,
                        volume: volume,
                        action: {
                            hitPad(pad)
                        },
                        onLongPress: {
                            // 长按进入编辑模式
                            editingPadId = pad.id
                            showingPadEditor = true
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
            
            // 录制控制区域（纯图标方形按钮，增强光影效果）
            HStack(spacing: 16) {
                // 录制按钮
                Button(action: toggleRecording) {
                    Image(systemName: isRecording ? "stop.fill" : "record.circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    (isRecording ? Color.red : Color.red.opacity(0.8)).adjustedBrightness(0.1),
                                    isRecording ? Color.red : Color.red.opacity(0.8)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                .padding(1)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
                        .shadow(color: Color.red.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                
                // 清除按钮
                Button(action: { recordedSequence.removeAll() }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.orange.adjustedBrightness(0.1),
                                    Color.orange
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                .padding(1)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
                        .shadow(color: Color.orange.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                
                // 回放按钮
                Button(action: playbackSequence) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    (recordedSequence.isEmpty ? Color.gray : Color.green).adjustedBrightness(0.1),
                                    recordedSequence.isEmpty ? Color.gray : Color.green
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                .padding(1)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
                        .shadow(color: (recordedSequence.isEmpty ? Color.gray : Color.green).opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .disabled(recordedSequence.isEmpty)
                .opacity(recordedSequence.isEmpty ? 0.5 : 1.0)
            }
            .padding(.vertical, 10)
            
            // 录制状态指示
            if isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("录制中... \(recordedSequence.count) 次敲击")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } else if !recordedSequence.isEmpty {
                Text("已录制 \(recordedSequence.count) 次敲击")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .navigationTitle("Drum Pad")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("background"))
        .onAppear {
            print("📱 LegacyDrumPadView.onAppear: 视图已加载")
            print("📱 LegacyDrumPadView: AudioEngine 运行中: \(conductor.engine.avEngine.isRunning)")
            print("📱 LegacyDrumPadView: 鼓样本数量: \(conductor.drumSamples.count)")
            
            // 配置 LegacyAudioManager 以使用 Conductor
            LegacyAudioManager.shared.configure(with: conductor)
            
            // 仅在引擎确实未运行时才尝试启动（作为后备措施）
            if !conductor.engine.avEngine.isRunning {
                print("⚠️ LegacyDrumPadView: 音频引擎未运行，尝试启动（后备措施）...")
                // 使用延迟调用避免阻塞 UI
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if !conductor.engine.avEngine.isRunning {
                        conductor.start()
                    }
                }
            }
        }
        // 预设管理器面板
        .sheet(isPresented: $showingPresetManager) {
            PadPresetManagerView()
                .environmentObject(conductor)
        }
        // Pad效果器编辑面板
        .sheet(isPresented: $showingPadEditor) {
            if let padId = editingPadId,
               let configBinding = getPadConfigurationBinding(for: padId) {
                PadEffectEditorView(
                    padConfiguration: configBinding,
                    isPresented: $showingPadEditor
                )
                .environmentObject(conductor)
            }
        }
    }
    
    // MARK: - Actions
    
    private func hitPad(_ pad: DrumPad) {
        print("👆 hitPad: 点击了 \(pad.name) (id: \(pad.id), soundFile: \(pad.soundFile))")
        selectedPad = pad.id
        
        // Play sound
        print("👆 hitPad: 调用 LegacyAudioManager.playSound...")
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
    
    /// 应用预设
    private func applyPreset(_ preset: DrumPadPreset) {
        configManager.applyPreset(preset)
        print("✅ 预设已应用: \(preset.name)")
    }
    
    /// 获取指定pad的配置绑定（用于编辑器）
    private func getPadConfigurationBinding(for padId: Int) -> Binding<PadConfiguration>? {
        guard padId >= 0 && padId < conductor.padConfigurations.count else {
            return nil
        }
        
        return Binding(
            get: {
                return conductor.padConfigurations[padId]
            },
            set: { newConfig in
                conductor.updatePadConfiguration(newConfig)
                configManager.updatePadConfiguration(newConfig)
            }
        )
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

// MARK: - 圆形波形可视化视图

struct CircularWaveformView: View {
    let energy: Float
    let color: Color
    let isActive: Bool
    
    @State private var animationPhase: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var isAnimating: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                // 外圈旋转渐变环（能量感应）
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                color.opacity(0.2),
                                color.opacity(Double(energy) * 0.8 + 0.2),
                                color.opacity(0.2),
                                color.opacity(Double(energy) * 0.6 + 0.1),
                                color.opacity(0.2)
                            ]),
                            center: .center,
                            startAngle: .degrees(animationPhase),
                            endAngle: .degrees(animationPhase + 360)
                        ),
                        lineWidth: 3
                    )
                    .frame(width: size * 0.95, height: size * 0.95)
                
                // 中圈能量脉冲环
                Circle()
                    .strokeBorder(
                        color.opacity(Double(energy) * 0.7 + 0.1),
                        lineWidth: 2
                    )
                    .frame(width: size * 0.75, height: size * 0.75)
                    .scaleEffect(pulseScale)
                
                // 内圈 - 12 个旋转脉冲点
                ForEach(0..<12, id: \.self) { index in
                    Circle()
                        .fill(
                            color.opacity(Double(energy) * 0.9 + 0.1)
                        )
                        .frame(width: 4, height: 4)
                        .offset(y: -size * 0.32)
                        .rotationEffect(.degrees(Double(index) * 30 + animationPhase * 0.5))
                        .scaleEffect(isActive ? 1.0 + CGFloat(energy) * 0.5 : 0.5)
                }
                
                // 中心能量指示点
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                color.opacity(Double(energy) * 0.8 + 0.2),
                                color.opacity(0.1)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.15
                        )
                    )
                    .frame(width: size * 0.3, height: size * 0.3)
                    .scaleEffect(1.0 + CGFloat(energy) * 0.3)
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .opacity(isActive ? 1.0 : 0.3)
        .onChange(of: isActive) { newValue in
            if newValue && !isAnimating {
                startAnimations()
            } else if !newValue {
                stopAnimations()
            }
        }
        .onAppear {
            if isActive {
                startAnimations()
            }
        }
    }
    
    private func startAnimations() {
        isAnimating = true
        // 外圈旋转动画
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            animationPhase = 360
        }
        // 脉冲缩放动画
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.0 + CGFloat(max(energy, 0.2)) * 0.15
        }
    }
    
    private func stopAnimations() {
        isAnimating = false
        withAnimation(.easeOut(duration: 0.3)) {
            animationPhase = 0
            pulseScale = 1.0
        }
    }
}

// MARK: - Drum Pad Button

struct DrumPadButton: View {
    let pad: DrumPad
    let isSelected: Bool
    let volume: Double
    let action: () -> Void
    let onLongPress: () -> Void  // 新增：长按回调
    
    @EnvironmentObject var conductor: Conductor
    @State private var isLongPressing = false
    
    var body: some View {
        ZStack {
            // 背景鼓垫 - 动态颜色主题，增强光影效果
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            pad.color.opacity(isSelected ? 1.0 : 0.95).adjustedBrightness(0.15),  // 顶部高光
                            pad.color.opacity(isSelected ? 1.0 : 0.95),                            // 中间原色
                            pad.color.opacity(isSelected ? 0.95 : 0.9).adjustedBrightness(-0.1)   // 底部阴影
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(1.0, contentMode: .fit)
                .overlay(
                    // 内部高光效果
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .padding(2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isLongPressing ? Color.blue : Color.black.opacity(0.15), lineWidth: isLongPressing ? 3 : 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: isSelected ? 2 : 8, x: 0, y: isSelected ? 1 : 4)
                .shadow(color: pad.color.opacity(0.3), radius: isSelected ? 0 : 4, x: 0, y: isSelected ? 0 : 2)  // 颜色光晕
                .scaleEffect(isSelected ? 0.92 : 1.0)
                .animation(.easeInOut(duration: 0.08), value: isSelected)
            
            // 圆形波形可视化叠加层
            CircularWaveformView(
                energy: conductor.audioEnergy,
                color: .white,
                isActive: isSelected
            )
            .frame(width: 50, height: 50)
            .allowsHitTesting(false)
            
            // 打击垫名称 - 白色粗体斜体文字，增大字号
            Text(pad.name)
                .font(.system(size: 18, weight: .heavy, design: .default))
                .italic()
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
                .padding(4)
                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 2)
            
            // 设置图标（右上角）
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "gearshape.fill")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(4)
                }
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            // 点击手势 - 播放音色
            TapGesture()
                .onEnded { _ in
                    // 重置长按状态（修复：短点击时也要重置状态）
                    isLongPressing = false
                    action()
                }
        )
        .simultaneousGesture(
            // 长按手势 - 进入编辑模式
            LongPressGesture(minimumDuration: 0.5)
                .onChanged { _ in
                    isLongPressing = true
                }
                .onEnded { _ in
                    isLongPressing = false
                    onLongPress()
                }
        )
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
    
    private var conductor: Conductor?
    
    // 建立文件名到 Conductor drumSamples 中样本名称的映射
    // 由于 4x4 打击垫使用相同的音频文件，这里映射到 Conductor 中的样本名称
    private let soundFileToSampleName: [String: String] = [
        "bass_drum_C1": "KICK",
        "snare_D1": "SNARE",
        "closed_hi_hat_F#1": "HI HAT",
        "open_hi_hat_A#1": "OPEN HI HAT",
        "crash_F1": "CRASH",
        "hi_tom_D2": "HI TOM",
        "mid_tom_B1": "MID TOM",
        "lo_tom_F1": "LO TOM",
        "clap_D#1": "CLAP"
    ]
    
    private init() {}
    
    /// 配置 LegacyAudioManager 以使用指定的 Conductor
    func configure(with conductor: Conductor) {
        self.conductor = conductor
        print("✅ LegacyAudioManager configured with Conductor")
    }
    
    func playSound(_ soundFile: String, volume: Double) {
        // 检查 Conductor 是否已配置
        guard let conductor = conductor else {
            print("⚠️ LegacyAudioManager: Conductor not configured")
            return
        }
        
        // 根据文件名查找对应的 drum sample
        guard let sampleName = soundFileToSampleName[soundFile] else {
            print("⚠️ LegacyAudioManager: Unknown sound file: \(soundFile)")
            return
        }
        
        // 在 Conductor 的 drumSamples 中查找对应的索引
        guard let padIndex = conductor.drumSamples.firstIndex(where: { $0.name == sampleName }) else {
            print("⚠️ LegacyAudioManager: Could not find drum sample for: \(sampleName)")
            return
        }
        
        // 播放音频，应用独立的音量控制
        conductor.playPad(padNumber: padIndex, velocity: Float(volume))
        
        print("🎵 Playing: \(sampleName) (pad \(padIndex)) at volume: \(Int(volume * 100))%")
    }
}

// MARK: - Quick Status View

struct QuickStatusView: View {
    let conductor: Conductor
    @State private var isExpanded = false
    
    var isHealthy: Bool {
        conductor.engine.avEngine.isRunning && conductor.drumSamples.count == 9
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isHealthy ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text(isHealthy ? "音频正常" : "音频异常")
                        .font(.caption2)
                        .foregroundColor(isHealthy ? .secondary : .red)
                    
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("引擎:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(conductor.engine.avEngine.isRunning ? "✅ 运行" : "❌ 停止")
                            .font(.caption2)
                            .foregroundColor(conductor.engine.avEngine.isRunning ? .green : .red)
                    }
                    
                    HStack {
                        Text("样本:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(conductor.drumSamples.count)/9")
                            .font(.caption2)
                            .foregroundColor(conductor.drumSamples.count == 9 ? .green : .red)
                    }
                    
                    Divider()
                    
                    HStack(spacing: 6) {
                        Button("重启") {
                            conductor.engine.stop()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                conductor.start()
                            }
                        }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                        
                        Button("测试") {
                            conductor.playPad(padNumber: 0, velocity: 1.0)
                        }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal, 12)
                .transition(.opacity)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview

struct LegacyDrumPadView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LegacyDrumPadView()
                .environmentObject(Conductor())
        }
    }
}