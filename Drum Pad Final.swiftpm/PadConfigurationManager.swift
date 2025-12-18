import Foundation
import Combine

// MARK: - Pad Configuration Manager

/// Pad配置和预设的持久化管理器（单例）
class PadConfigurationManager: ObservableObject {
    static let shared = PadConfigurationManager()
    
    // MARK: - Published Properties
    
    /// 当前激活的预设
    @Published var activePreset: DrumPadPreset?
    
    /// 当前的pad配置数组（16个）
    @Published var currentConfigurations: [PadConfiguration] = []
    
    /// 所有可用的预设列表
    @Published var availablePresets: [DrumPadPreset] = []
    
    // MARK: - Storage Keys
    
    private let presetsKey = "com.drumpad.savedPresets"
    private let activePresetIdKey = "com.drumpad.activePresetId"
    private let currentConfigurationsKey = "com.drumpad.currentConfigurations"
    
    // MARK: - Initialization
    
    private init() {
        // 加载保存的数据
        loadPresetsFromStorage()
        loadCurrentConfigurations()
        
        // 如果没有保存的配置，初始化为默认配置
        if currentConfigurations.isEmpty {
            resetToDefaultConfiguration()
        }
        
        // 确保内置预设存在
        ensureBuiltInPresetsExist()
    }
    
    // MARK: - Preset Management
    
    /// 保存新预设
    func savePreset(_ preset: DrumPadPreset) {
        var updatedPreset = preset
        updatedPreset.modifiedDate = Date()
        
        // 检查是否已存在（更新）
        if let index = availablePresets.firstIndex(where: { $0.id == preset.id }) {
            availablePresets[index] = updatedPreset
        } else {
            // 新增预设
            availablePresets.append(updatedPreset)
        }
        
        savePresetsToStorage()
        print("✅ 预设已保存: \(preset.name)")
    }
    
    /// 保存当前配置为新预设
    func saveCurrentAsPreset(name: String, description: String? = nil) -> DrumPadPreset {
        let newPreset = DrumPadPreset(
            name: name,
            description: description,
            padConfigurations: currentConfigurations,
            isBuiltIn: false
        )
        
        savePreset(newPreset)
        return newPreset
    }
    
    /// 删除预设
    func deletePreset(id: UUID) {
        guard let index = availablePresets.firstIndex(where: { $0.id == id }) else {
            print("⚠️ 预设未找到: \(id)")
            return
        }
        
        let preset = availablePresets[index]
        
        // 不允许删除内置预设
        guard !preset.isBuiltIn else {
            print("⚠️ 内置预设不可删除: \(preset.name)")
            return
        }
        
        availablePresets.remove(at: index)
        savePresetsToStorage()
        
        // 如果删除的是当前激活的预设，切换到默认预设
        if activePreset?.id == id {
            applyPreset(DrumPadPreset.defaultPreset())
        }
        
        print("✅ 预设已删除: \(preset.name)")
    }
    
    /// 应用预设到当前配置
    func applyPreset(_ preset: DrumPadPreset) {
        currentConfigurations = preset.padConfigurations
        activePreset = preset
        
        saveCurrentConfigurations()
        saveActivePresetId(preset.id)
        
        // 发送通知，通知UI更新
        NotificationCenter.default.post(
            name: .padPresetApplied,
            object: preset
        )
        
        print("✅ 预设已应用: \(preset.name)")
    }
    
    /// 加载预设列表
    func loadPresets() -> [DrumPadPreset] {
        return availablePresets
    }
    
    // MARK: - Pad Configuration Management
    
    /// 更新单个pad的配置
    func updatePadConfiguration(_ config: PadConfiguration) {
        guard config.id >= 0 && config.id < currentConfigurations.count else {
            print("⚠️ 无效的pad ID: \(config.id)")
            return
        }
        
        currentConfigurations[config.id] = config
        saveCurrentConfigurations()
        
        // 发送通知，通知UI更新
        NotificationCenter.default.post(
            name: .padConfigurationUpdated,
            object: config
        )
        
        print("✅ Pad配置已更新: #\(config.id) - \(config.name)")
    }
    
    /// 更新单个pad的效果器设置
    func updatePadEffects(padId: Int, effectSettings: PadEffectSettings) {
        guard padId >= 0 && padId < currentConfigurations.count else {
            print("⚠️ 无效的pad ID: \(padId)")
            return
        }
        
        currentConfigurations[padId].effectSettings = effectSettings
        saveCurrentConfigurations()
        
        print("✅ Pad效果器已更新: #\(padId)")
    }
    
    /// 获取单个pad的配置
    func getPadConfiguration(padId: Int) -> PadConfiguration? {
        guard padId >= 0 && padId < currentConfigurations.count else {
            return nil
        }
        return currentConfigurations[padId]
    }
    
    /// 重置单个pad到默认配置
    func resetPadToDefault(padId: Int) {
        guard padId >= 0 && padId < currentConfigurations.count else {
            print("⚠️ 无效的pad ID: \(padId)")
            return
        }
        
        currentConfigurations[padId] = PadConfiguration.defaultConfiguration(for: padId)
        saveCurrentConfigurations()
        
        print("✅ Pad已重置: #\(padId)")
    }
    
    /// 重置所有配置到默认
    func resetToDefaultConfiguration() {
        currentConfigurations = (0..<16).map { PadConfiguration.defaultConfiguration(for: $0) }
        activePreset = DrumPadPreset.defaultPreset()
        
        saveCurrentConfigurations()
        saveActivePresetId(activePreset!.id)
        
        print("✅ 已重置为默认配置")
    }
    
    /// 获取当前配置
    func getCurrentConfiguration() -> [PadConfiguration] {
        return currentConfigurations
    }
    
    // MARK: - Import/Export
    
    /// 导出预设为JSON字符串
    func exportPreset(_ preset: DrumPadPreset) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(preset),
              let jsonString = String(data: data, encoding: .utf8) else {
            print("❌ 预设导出失败: \(preset.name)")
            return nil
        }
        
        print("✅ 预设已导出: \(preset.name)")
        return jsonString
    }
    
    /// 从JSON字符串导入预设
    func importPreset(from jsonString: String) -> DrumPadPreset? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let data = jsonString.data(using: .utf8),
              var preset = try? decoder.decode(DrumPadPreset.self, from: data) else {
            print("❌ 预设导入失败")
            return nil
        }
        
        // 生成新的ID避免冲突
        preset.id = UUID()
        preset.isBuiltIn = false
        
        // 保存导入的预设
        savePreset(preset)
        
        print("✅ 预设已导入: \(preset.name)")
        return preset
    }
    
    /// 导出当前配置为JSON
    func exportCurrentConfiguration() -> String? {
        let tempPreset = DrumPadPreset(
            name: "Exported Configuration",
            description: "导出的配置",
            padConfigurations: currentConfigurations
        )
        return exportPreset(tempPreset)
    }
    
    // MARK: - Private Storage Methods
    
    /// 保存预设列表到UserDefaults
    private func savePresetsToStorage() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // 只保存非内置预设（内置预设每次启动时自动添加）
        let userPresets = availablePresets.filter { !$0.isBuiltIn }
        
        if let encoded = try? encoder.encode(userPresets) {
            UserDefaults.standard.set(encoded, forKey: presetsKey)
            print("💾 预设列表已保存 (\(userPresets.count)个)")
        } else {
            print("❌ 预设列表保存失败")
        }
    }
    
    /// 从UserDefaults加载预设列表
    private func loadPresetsFromStorage() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let data = UserDefaults.standard.data(forKey: presetsKey),
           let userPresets = try? decoder.decode([DrumPadPreset].self, from: data) {
            availablePresets = userPresets
            print("💾 预设列表已加载 (\(userPresets.count)个)")
        } else {
            availablePresets = []
            print("ℹ️ 未找到保存的预设")
        }
    }
    
    /// 保存当前配置到UserDefaults
    private func saveCurrentConfigurations() {
        let encoder = JSONEncoder()
        
        if let encoded = try? encoder.encode(currentConfigurations) {
            UserDefaults.standard.set(encoded, forKey: currentConfigurationsKey)
            print("💾 当前配置已保存")
        } else {
            print("❌ 当前配置保存失败")
        }
    }
    
    /// 从UserDefaults加载当前配置
    private func loadCurrentConfigurations() {
        let decoder = JSONDecoder()
        
        if let data = UserDefaults.standard.data(forKey: currentConfigurationsKey),
           let configs = try? decoder.decode([PadConfiguration].self, from: data) {
            currentConfigurations = configs
            print("💾 当前配置已加载 (\(configs.count)个pad)")
        } else {
            currentConfigurations = []
            print("ℹ️ 未找到保存的配置")
        }
        
        // 加载激活的预设ID
        if let activePresetIdString = UserDefaults.standard.string(forKey: activePresetIdKey),
           let activePresetId = UUID(uuidString: activePresetIdString) {
            activePreset = availablePresets.first { $0.id == activePresetId }
        }
    }
    
    /// 保存激活预设的ID
    private func saveActivePresetId(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: activePresetIdKey)
    }
    
    /// 确保内置预设存在
    private func ensureBuiltInPresetsExist() {
        let builtInPresets = DrumPadPreset.builtInPresets()
        
        for builtIn in builtInPresets {
            // 如果内置预设不在列表中，添加它
            if !availablePresets.contains(where: { $0.name == builtIn.name && $0.isBuiltIn }) {
                availablePresets.insert(builtIn, at: 0)
            }
        }
        
        print("✅ 内置预设已确保存在 (\(builtInPresets.count)个)")
    }
    
    // MARK: - Utility Methods
    
    /// 验证配置有效性
    func validateConfiguration(_ config: PadConfiguration) -> Bool {
        // 检查基本属性
        guard config.id >= 0 && config.id < 16 else {
            print("⚠️ 无效的pad ID: \(config.id)")
            return false
        }
        
        guard config.volume >= 0 && config.volume <= 1.0 else {
            print("⚠️ 无效的音量: \(config.volume)")
            return false
        }
        
        guard config.effectSettings.reverbMix >= 0 && config.effectSettings.reverbMix <= 100 else {
            print("⚠️ 无效的混响混合度: \(config.effectSettings.reverbMix)")
            return false
        }
        
        guard config.effectSettings.delayMix >= 0 && config.effectSettings.delayMix <= 100 else {
            print("⚠️ 无效的延迟混合度: \(config.effectSettings.delayMix)")
            return false
        }
        
        return true
    }
    
    /// 获取预设统计信息
    func getPresetStatistics() -> (total: Int, builtIn: Int, user: Int) {
        let builtInCount = availablePresets.filter { $0.isBuiltIn }.count
        let userCount = availablePresets.filter { !$0.isBuiltIn }.count
        return (total: availablePresets.count, builtIn: builtInCount, user: userCount)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// 预设已应用通知
    static let padPresetApplied = Notification.Name("padPresetApplied")
    
    /// Pad配置已更新通知
    static let padConfigurationUpdated = Notification.Name("padConfigurationUpdated")
}
