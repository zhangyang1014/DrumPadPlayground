import SwiftUI

// MARK: - Pad Effect Editor View

/// Pad效果器编辑面板 - 用于实时调整单个pad的效果器参数
struct PadEffectEditorView: View {
    @EnvironmentObject var conductor: Conductor
    @Environment(\.presentationMode) var presentationMode
    
    /// 要编辑的pad配置
    @Binding var padConfiguration: PadConfiguration
    
    /// 是否显示编辑器
    @Binding var isPresented: Bool
    
    /// 本地状态（用于实时预览，不立即保存）
    @State private var localConfig: PadConfiguration
    
    /// 是否有未保存的更改
    @State private var hasUnsavedChanges: Bool = false
    
    /// 初始化
    init(padConfiguration: Binding<PadConfiguration>, isPresented: Binding<Bool>) {
        self._padConfiguration = padConfiguration
        self._isPresented = isPresented
        self._localConfig = State(initialValue: padConfiguration.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Pad信息卡片
                    padInfoSection
                    
                    // 音量控制
                    volumeSection
                    
                    // 混响效果器
                    reverbSection
                    
                    // 延迟效果器
                    delaySection
                    
                    // 操作按钮
                    actionButtonsSection
                }
                .padding(20)
            }
            .background(Color("background").ignoresSafeArea())
            .navigationTitle("编辑Pad效果器")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("取消") {
                    handleCancel()
                },
                trailing: Button("完成") {
                    handleSave()
                }
                .fontWeight(.semibold)
            )
        }
        .onChange(of: localConfig) { _ in
            hasUnsavedChanges = true
        }
    }
    
    // MARK: - UI Sections
    
    /// Pad信息区域
    private var padInfoSection: some View {
        HStack(spacing: 16) {
            // Pad颜色预览
            RoundedRectangle(cornerRadius: 12)
                .fill(localConfig.color)
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Pad #\(localConfig.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(localConfig.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color("textColor1"))
                
                Text(localConfig.soundFile)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 静音/效果器开关
            VStack(spacing: 8) {
                Toggle(isOn: $localConfig.isMuted) {
                    Image(systemName: localConfig.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundColor(localConfig.isMuted ? .red : .blue)
                }
                .labelsHidden()
                
                Toggle(isOn: $localConfig.isEffectEnabled) {
                    Image(systemName: localConfig.isEffectEnabled ? "waveform" : "waveform.slash")
                        .foregroundColor(localConfig.isEffectEnabled ? .green : .gray)
                }
                .labelsHidden()
            }
        }
        .padding()
        .background(Color("controlsBackground"))
        .cornerRadius(12)
    }
    
    /// 音量控制区域
    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.blue)
                Text("音量")
                    .font(.headline)
                Spacer()
                Text("\(Int(localConfig.volume * 100))%")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: $localConfig.volume,
                in: 0...1,
                step: 0.05
            ) {
                Text("音量")
            } minimumValueLabel: {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } maximumValueLabel: {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accentColor(.blue)
        }
        .padding()
        .background(Color("controlsBackground"))
        .cornerRadius(12)
    }
    
    /// 混响效果器区域
    private var reverbSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(.purple)
                Text("混响效果器")
                    .font(.headline)
                Spacer()
            }
            
            // 混响混合度
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("混合度")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(localConfig.effectSettings.reverbMix))%")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $localConfig.effectSettings.reverbMix,
                    in: 0...100,
                    step: 1
                )
                .accentColor(.purple)
            }
            
            // 混响预设类型
            VStack(alignment: .leading, spacing: 8) {
                Text("混响类型")
                    .font(.subheadline)
                
                Picker("混响类型", selection: $localConfig.effectSettings.reverbPreset) {
                    ForEach(ReverbPresetType.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .accentColor(.purple)
            }
        }
        .padding()
        .background(Color("controlsBackground"))
        .cornerRadius(12)
    }
    
    /// 延迟效果器区域
    private var delaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.orange)
                Text("延迟效果器")
                    .font(.headline)
                Spacer()
            }
            
            // 延迟混合度
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("混合度")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(localConfig.effectSettings.delayMix))%")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $localConfig.effectSettings.delayMix,
                    in: 0...100,
                    step: 1
                )
                .accentColor(.orange)
            }
            
            // 延迟反馈
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("反馈量")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(localConfig.effectSettings.delayFeedback))%")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $localConfig.effectSettings.delayFeedback,
                    in: 0...100,
                    step: 1
                )
                .accentColor(.orange)
            }
            
            // 延迟时间
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("延迟时间")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.2fs", localConfig.effectSettings.delayTime))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $localConfig.effectSettings.delayTime,
                    in: 0.05...2.0,
                    step: 0.05
                )
                .accentColor(.orange)
            }
        }
        .padding()
        .background(Color("controlsBackground"))
        .cornerRadius(12)
    }
    
    /// 操作按钮区域
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // 试听按钮
            Button(action: previewSound) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                    Text("试听效果")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            HStack(spacing: 12) {
                // 重置按钮
                Button(action: resetToDefault) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("重置")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(12)
                }
                
                // 应用预设按钮
                Menu {
                    Button("默认设置") {
                        applyPresetSettings(.default)
                    }
                    Button("摇滚风格") {
                        applyPresetSettings(.rock)
                    }
                    Button("爵士风格") {
                        applyPresetSettings(.jazz)
                    }
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("预设")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    /// 试听当前pad的效果
    private func previewSound() {
        // 临时应用当前编辑的效果器参数
        conductor.updatePadConfiguration(localConfig)
        
        // 播放pad
        conductor.playPad(padNumber: localConfig.id, velocity: 1.0)
        
        print("🎵 试听Pad #\(localConfig.id)")
    }
    
    /// 重置为默认设置
    private func resetToDefault() {
        localConfig = PadConfiguration.defaultConfiguration(for: localConfig.id)
        hasUnsavedChanges = true
        print("🔄 Pad #\(localConfig.id) 已重置为默认设置")
    }
    
    /// 应用预设效果器设置
    private func applyPresetSettings(_ preset: EffectPresetType) {
        switch preset {
        case .default:
            localConfig.effectSettings = PadEffectSettings.defaultSettings()
        case .rock:
            localConfig.effectSettings = PadEffectSettings.rockSettings()
        case .jazz:
            localConfig.effectSettings = PadEffectSettings.jazzSettings()
        }
        hasUnsavedChanges = true
        print("🎛 应用预设: \(preset)")
    }
    
    /// 保存更改
    private func handleSave() {
        // 更新binding
        padConfiguration = localConfig
        
        // 保存到manager
        PadConfigurationManager.shared.updatePadConfiguration(localConfig)
        
        // 更新Conductor
        conductor.updatePadConfiguration(localConfig)
        
        hasUnsavedChanges = false
        isPresented = false
        
        print("✅ Pad #\(localConfig.id) 配置已保存")
    }
    
    /// 取消编辑
    private func handleCancel() {
        if hasUnsavedChanges {
            // 可以在这里添加确认对话框
            // 目前直接取消
        }
        isPresented = false
    }
}

// MARK: - Effect Preset Type

enum EffectPresetType {
    case `default`
    case rock
    case jazz
}

// MARK: - Preview

struct PadEffectEditorView_Previews: PreviewProvider {
    static var previews: some View {
        PadEffectEditorView(
            padConfiguration: .constant(PadConfiguration.defaultConfiguration(for: 0)),
            isPresented: .constant(true)
        )
        .environmentObject(Conductor())
        .preferredColorScheme(.dark)
    }
}
