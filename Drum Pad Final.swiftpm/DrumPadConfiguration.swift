import SwiftUI
import AVFoundation

// MARK: - Pad Effect Settings

/// 单个pad的效果器参数配置
struct PadEffectSettings: Codable, Equatable {
    /// 混响混合度 (0-100)
    var reverbMix: Float
    
    /// 混响预设类型
    var reverbPreset: ReverbPresetType
    
    /// 延迟混合度 (0-100)
    var delayMix: Float
    
    /// 延迟反馈量 (0-100)
    var delayFeedback: Float
    
    /// 延迟时间（秒）- 基于tempo自动计算
    var delayTime: Float
    
    /// 默认效果器设置（无效果）
    static func defaultSettings() -> PadEffectSettings {
        return PadEffectSettings(
            reverbMix: 5.0,
            reverbPreset: .smallRoom,
            delayMix: 0.0,
            delayFeedback: 10.0,
            delayTime: 0.25
        )
    }
    
    /// 摇滚风格效果器设置（较强混响+适度延迟）
    static func rockSettings() -> PadEffectSettings {
        return PadEffectSettings(
            reverbMix: 35.0,
            reverbPreset: .largeHall,
            delayMix: 25.0,
            delayFeedback: 30.0,
            delayTime: 0.25
        )
    }
    
    /// 爵士风格效果器设置（自然混响+轻微延迟）
    static func jazzSettings() -> PadEffectSettings {
        return PadEffectSettings(
            reverbMix: 20.0,
            reverbPreset: .mediumHall,
            delayMix: 10.0,
            delayFeedback: 15.0,
            delayTime: 0.375
        )
    }
}

// MARK: - Reverb Preset Type

/// 混响预设类型（封装AVAudioUnitReverbPreset以支持Codable）
enum ReverbPresetType: String, Codable, CaseIterable {
    case smallRoom = "smallRoom"
    case mediumRoom = "mediumRoom"
    case largeRoom = "largeRoom"
    case mediumHall = "mediumHall"
    case largeHall = "largeHall"
    case plate = "plate"
    case mediumChamber = "mediumChamber"
    case largeChamber = "largeChamber"
    case cathedral = "cathedral"
    
    var displayName: String {
        switch self {
        case .smallRoom: return "Small Room"
        case .mediumRoom: return "Medium Room"
        case .largeRoom: return "Large Room"
        case .mediumHall: return "Medium Hall"
        case .largeHall: return "Large Hall"
        case .plate: return "Plate"
        case .mediumChamber: return "Medium Chamber"
        case .largeChamber: return "Large Chamber"
        case .cathedral: return "Cathedral"
        }
    }
    
    var avPreset: AVAudioUnitReverbPreset {
        switch self {
        case .smallRoom: return .smallRoom
        case .mediumRoom: return .mediumRoom
        case .largeRoom: return .largeRoom
        case .mediumHall: return .mediumHall
        case .largeHall: return .largeHall
        case .plate: return .plate
        case .mediumChamber: return .mediumChamber
        case .largeChamber: return .largeChamber
        case .cathedral: return .cathedral
        }
    }
}

// MARK: - Pad Configuration

/// 单个pad的完整配置（音色、效果器、外观）
struct PadConfiguration: Codable, Equatable, Identifiable {
    /// Pad编号（0-15）
    var id: Int
    
    /// 自定义名称
    var name: String
    
    /// 自定义颜色（存储为十六进制字符串）
    var colorHex: String
    
    /// 音频文件名
    var soundFile: String
    
    /// 独立音量 (0-1)
    var volume: Float
    
    /// 效果器设置
    var effectSettings: PadEffectSettings
    
    /// 是否静音
    var isMuted: Bool
    
    /// 是否启用效果器
    var isEffectEnabled: Bool
    
    /// 计算属性：颜色对象
    var color: Color {
        get {
            Color(hex: colorHex) ?? Color.red
        }
        set {
            colorHex = newValue.toHex() ?? "#CC1919"
        }
    }
    
    /// 默认配置
    static func defaultConfiguration(for padId: Int) -> PadConfiguration {
        // 根据pad ID获取默认的鼓垫配置
        let defaultPads = [
            // 第一行：镲片
            ("CRASH\nLEFT", "crash_F1"),
            ("CRASH\nRIGHT", "crash_F1"),
            ("RIDE", "closed_hi_hat_F#1"),
            ("RIDE\nBELL", "open_hi_hat_A#1"),
            
            // 第二行：通鼓
            ("TOM 1", "hi_tom_D2"),
            ("TOM 2", "mid_tom_B1"),
            ("TOM 3", "lo_tom_F1"),
            ("TOM 4", "lo_tom_F1"),
            
            // 第三行：特殊打击
            ("KICK", "bass_drum_C1"),
            ("RIM\nSHOT", "clap_D#1"),
            ("SIDE\nSTICK", "snare_D1"),
            ("OPEN\nHAT", "open_hi_hat_A#1"),
            
            // 第四行：基础节奏
            ("KICK", "bass_drum_C1"),
            ("SNARE", "snare_D1"),
            ("HI HAT", "closed_hi_hat_F#1"),
            ("HI HAT", "closed_hi_hat_F#1")
        ]
        
        let padInfo = padId < defaultPads.count ? defaultPads[padId] : ("PAD \(padId)", "bass_drum_C1")
        
        return PadConfiguration(
            id: padId,
            name: padInfo.0,
            colorHex: "#CC1919", // 默认红色
            soundFile: padInfo.1,
            volume: 0.8,
            effectSettings: PadEffectSettings.defaultSettings(),
            isMuted: false,
            isEffectEnabled: true
        )
    }
}

// MARK: - Drum Pad Preset

/// 完整的鼓垫预设（包含所有16个pad的配置）
struct DrumPadPreset: Codable, Equatable, Identifiable {
    /// 预设唯一ID
    var id: UUID
    
    /// 预设名称
    var name: String
    
    /// 创建时间
    var createdDate: Date
    
    /// 最后修改时间
    var modifiedDate: Date
    
    /// 16个pad的配置数组
    var padConfigurations: [PadConfiguration]
    
    /// 预设描述（可选）
    var description: String?
    
    /// 是否为内置预设（内置预设不可删除）
    var isBuiltIn: Bool
    
    /// 创建新预设
    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        padConfigurations: [PadConfiguration],
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.padConfigurations = padConfigurations
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.isBuiltIn = isBuiltIn
    }
    
    /// 默认预设（清爽原声）
    static func defaultPreset() -> DrumPadPreset {
        let configs = (0..<16).map { PadConfiguration.defaultConfiguration(for: $0) }
        return DrumPadPreset(
            name: "Default Kit",
            description: "清爽原声鼓组，适合练习和录音",
            padConfigurations: configs,
            isBuiltIn: true
        )
    }
    
    /// 摇滚预设（强劲有力）
    static func rockPreset() -> DrumPadPreset {
        var configs = (0..<16).map { PadConfiguration.defaultConfiguration(for: $0) }
        
        // 为摇滚风格调整参数
        for i in 0..<configs.count {
            configs[i].volume = 0.9 // 更大音量
            configs[i].effectSettings = PadEffectSettings.rockSettings()
            
            // KICK和SNARE更强烈
            if configs[i].name.contains("KICK") {
                configs[i].volume = 1.0
                configs[i].effectSettings.reverbMix = 40.0
            } else if configs[i].name.contains("SNARE") {
                configs[i].volume = 0.95
                configs[i].effectSettings.reverbMix = 45.0
                configs[i].effectSettings.delayMix = 30.0
            }
        }
        
        return DrumPadPreset(
            name: "Rock Kit",
            description: "强劲有力的摇滚鼓组，适合重型音乐",
            padConfigurations: configs,
            isBuiltIn: true
        )
    }
    
    /// 爵士预设（温暖自然）
    static func jazzPreset() -> DrumPadPreset {
        var configs = (0..<16).map { PadConfiguration.defaultConfiguration(for: $0) }
        
        // 为爵士风格调整参数
        for i in 0..<configs.count {
            configs[i].volume = 0.7 // 较小音量，更细腻
            configs[i].effectSettings = PadEffectSettings.jazzSettings()
            
            // 踩镲和RIDE更突出
            if configs[i].name.contains("HAT") || configs[i].name.contains("RIDE") {
                configs[i].volume = 0.75
                configs[i].effectSettings.reverbMix = 25.0
            }
            
            // KICK和SNARE更柔和
            if configs[i].name.contains("KICK") {
                configs[i].volume = 0.65
                configs[i].effectSettings.reverbMix = 15.0
            } else if configs[i].name.contains("SNARE") {
                configs[i].volume = 0.7
                configs[i].effectSettings.reverbMix = 22.0
            }
        }
        
        return DrumPadPreset(
            name: "Jazz Kit",
            description: "温暖自然的爵士鼓组，适合流畅演奏",
            padConfigurations: configs,
            isBuiltIn: true
        )
    }
    
    /// 获取所有内置预设
    static func builtInPresets() -> [DrumPadPreset] {
        return [
            defaultPreset(),
            rockPreset(),
            jazzPreset()
        ]
    }
}

// MARK: - Color Extensions

extension Color {
    /// 从十六进制字符串创建颜色
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// 转换为十六进制字符串
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}
