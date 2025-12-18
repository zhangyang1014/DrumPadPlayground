import SwiftUI
import AVFoundation
import AudioKit

// MARK: - 自定义 ReverbPresetStepper
// 替代 AudioKitUI 中的 ReverbPresetStepper，解决版本兼容性问题

struct ReverbPresetStepper: View {
    @Binding var preset: AVAudioUnitReverbPreset
    
    // 所有可用的混响预设
    private static let allPresets: [(AVAudioUnitReverbPreset, String)] = [
        (.smallRoom, "Small Room"),
        (.mediumRoom, "Medium Room"),
        (.largeRoom, "Large Room"),
        (.mediumHall, "Medium Hall"),
        (.largeHall, "Large Hall"),
        (.plate, "Plate"),
        (.mediumChamber, "Medium Chamber"),
        (.largeChamber, "Large Chamber"),
        (.cathedral, "Cathedral"),
        (.largeRoom2, "Large Room 2"),
        (.mediumHall2, "Medium Hall 2"),
        (.mediumHall3, "Medium Hall 3"),
        (.largeHall2, "Large Hall 2")
    ]
    
    private var currentIndex: Int {
        Self.allPresets.firstIndex(where: { $0.0 == preset }) ?? 0
    }
    
    private var presetName: String {
        Self.allPresets.first(where: { $0.0 == preset })?.1 ?? "Unknown"
    }
    
    var body: some View {
        GeometryReader { geo in
            let font = Font.system(size: geo.size.height * 0.45, weight: .light)
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.17))
                HStack {
                    // 上一个预设按钮
                    Text("◀")
                        .font(font)
                        .onTapGesture {
                            selectPreviousPreset()
                        }
                    
                    Spacer()
                    
                    // 下一个预设按钮
                    Text("▶")
                        .font(font)
                        .onTapGesture {
                            selectNextPreset()
                        }
                }
                .padding(SwiftUI.EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
                
                // 预设名称
                Text(presetName.uppercased())
                    .font(font)
            }
        }
    }
    
    private func selectPreviousPreset() {
        let newIndex = (currentIndex - 1 + Self.allPresets.count) % Self.allPresets.count
        preset = Self.allPresets[newIndex].0
    }
    
    private func selectNextPreset() {
        let newIndex = (currentIndex + 1) % Self.allPresets.count
        preset = Self.allPresets[newIndex].0
    }
}

// MARK: - 自定义 NodeOutputView
// 替代 AudioKitUI 中的 NodeOutputView，显示简化的音频波形

struct NodeOutputView: View {
    let node: Node
    
    @State private var amplitudes: [CGFloat] = Array(repeating: 0.3, count: 50)
    @State private var timer: Timer?
    
    init(_ node: Node) {
        self.node = node
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<amplitudes.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: index))
                        .frame(
                            width: max(2, (geometry.size.width - CGFloat(amplitudes.count) * 2) / CGFloat(amplitudes.count)),
                            height: max(4, geometry.size.height * amplitudes[index])
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func barColor(for index: Int) -> Color {
        let progress = Double(index) / Double(amplitudes.count)
        if progress < 0.6 {
            return .green
        } else if progress < 0.8 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            updateAmplitudes()
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateAmplitudes() {
        // 模拟音频波形动画
        // 在实际实现中，可以从 AudioKit 的 node 获取真实的音频数据
        withAnimation(.easeInOut(duration: 0.05)) {
            for i in 0..<amplitudes.count {
                // 生成平滑变化的随机值
                let randomChange = CGFloat.random(in: -0.1...0.1)
                let newValue = amplitudes[i] + randomChange
                amplitudes[i] = max(0.1, min(0.9, newValue))
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CustomAudioKitViews_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // ReverbPresetStepper 预览
            ReverbPresetStepper(preset: .constant(.mediumHall))
                .frame(width: 200, height: 40)
                .foregroundColor(.white)
                .padding()
                .background(Color.gray)
            
            // NodeOutputView 需要一个真实的 Node，这里无法在预览中展示
            Text("NodeOutputView 需要 AudioKit Node")
                .padding()
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
