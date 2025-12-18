import SwiftUI

// MARK: - Pad Preset Manager View

/// Pad预设管理界面 - 管理、保存、加载、导入导出预设
struct PadPresetManagerView: View {
    @EnvironmentObject var conductor: Conductor
    @StateObject private var configManager = PadConfigurationManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    // 状态
    @State private var showingSavePresetDialog = false
    @State private var showingImportDialog = false
    @State private var showingExportSheet = false
    @State private var showingDeleteConfirmation = false
    
    @State private var newPresetName: String = ""
    @State private var newPresetDescription: String = ""
    @State private var importText: String = ""
    @State private var exportText: String = ""
    @State private var presetToDelete: DrumPadPreset?
    @State private var presetToExport: DrumPadPreset?
    
    var body: some View {
        NavigationView {
            List {
                // 内置预设区域
                Section(header: Text("内置预设").font(.headline)) {
                    ForEach(builtInPresets) { preset in
                        PresetRowView(preset: preset, isActive: isActivePreset(preset))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                applyPreset(preset)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    presetToExport = preset
                                    exportPreset(preset)
                                } label: {
                                    Label("导出", systemImage: "square.and.arrow.up")
                                }
                                .tint(.blue)
                            }
                    }
                }
                
                // 用户预设区域
                Section(header: HStack {
                    Text("我的预设").font(.headline)
                    Spacer()
                    Button(action: { showingSavePresetDialog = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }) {
                    if userPresets.isEmpty {
                        Text("暂无自定义预设")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(userPresets) { preset in
                            PresetRowView(preset: preset, isActive: isActivePreset(preset))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    applyPreset(preset)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        presetToDelete = preset
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        presetToExport = preset
                                        exportPreset(preset)
                                    } label: {
                                        Label("导出", systemImage: "square.and.arrow.up")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }
                
                // 导入导出区域
                Section(header: Text("导入/导出").font(.headline)) {
                    Button(action: { showingImportDialog = true }) {
                        Label("从JSON导入预设", systemImage: "square.and.arrow.down")
                    }
                    
                    Button(action: { exportCurrentConfiguration() }) {
                        Label("导出当前配置", systemImage: "square.and.arrow.up")
                    }
                }
                
                // 统计信息
                Section(header: Text("统计信息").font(.headline)) {
                    HStack {
                        Text("预设总数")
                        Spacer()
                        Text("\(configManager.availablePresets.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("内置预设")
                        Spacer()
                        Text("\(builtInPresets.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("自定义预设")
                        Spacer()
                        Text("\(userPresets.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("预设管理")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingSavePresetDialog) {
                SavePresetDialog(
                    presetName: $newPresetName,
                    presetDescription: $newPresetDescription,
                    onSave: saveNewPreset
                )
            }
            .sheet(isPresented: $showingImportDialog) {
                ImportPresetDialog(
                    importText: $importText,
                    onImport: importPreset
                )
            }
            .sheet(isPresented: $showingExportSheet) {
                if let preset = presetToExport {
                    ExportPresetSheet(preset: preset, exportText: exportText)
                }
            }
            .alert("确认删除", isPresented: $showingDeleteConfirmation, presenting: presetToDelete) { preset in
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deletePreset(preset)
                }
            } message: { preset in
                Text("确定要删除预设「\(preset.name)」吗？此操作不可撤销。")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var builtInPresets: [DrumPadPreset] {
        configManager.availablePresets.filter { $0.isBuiltIn }
    }
    
    private var userPresets: [DrumPadPreset] {
        configManager.availablePresets.filter { !$0.isBuiltIn }
    }
    
    private func isActivePreset(_ preset: DrumPadPreset) -> Bool {
        return configManager.activePreset?.id == preset.id
    }
    
    // MARK: - Actions
    
    private func applyPreset(_ preset: DrumPadPreset) {
        configManager.applyPreset(preset)
        print("✅ 预设已应用: \(preset.name)")
    }
    
    private func saveNewPreset() {
        guard !newPresetName.isEmpty else { return }
        
        let preset = configManager.saveCurrentAsPreset(
            name: newPresetName,
            description: newPresetDescription.isEmpty ? nil : newPresetDescription
        )
        
        print("✅ 新预设已保存: \(preset.name)")
        
        // 重置输入
        newPresetName = ""
        newPresetDescription = ""
    }
    
    private func deletePreset(_ preset: DrumPadPreset) {
        configManager.deletePreset(id: preset.id)
        print("✅ 预设已删除: \(preset.name)")
    }
    
    private func exportPreset(_ preset: DrumPadPreset) {
        if let jsonString = configManager.exportPreset(preset) {
            exportText = jsonString
            presetToExport = preset
            showingExportSheet = true
            print("✅ 预设已导出: \(preset.name)")
        }
    }
    
    private func exportCurrentConfiguration() {
        if let jsonString = configManager.exportCurrentConfiguration() {
            exportText = jsonString
            presetToExport = nil
            showingExportSheet = true
            print("✅ 当前配置已导出")
        }
    }
    
    private func importPreset() {
        guard !importText.isEmpty else { return }
        
        if let preset = configManager.importPreset(from: importText) {
            print("✅ 预设已导入: \(preset.name)")
            importText = ""
            showingImportDialog = false
        } else {
            print("❌ 预设导入失败")
        }
    }
}

// MARK: - Preset Row View

struct PresetRowView: View {
    let preset: DrumPadPreset
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 激活指示器
            Circle()
                .fill(isActive ? Color.green : Color.clear)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(preset.name)
                        .font(.headline)
                        .foregroundColor(isActive ? .blue : Color("textColor1"))
                    
                    if preset.isBuiltIn {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                if let description = preset.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(formatDate(preset.createdDate))
                        .font(.caption2)
                    
                    if preset.modifiedDate != preset.createdDate {
                        Image(systemName: "pencil")
                            .font(.caption2)
                        Text(formatDate(preset.modifiedDate))
                            .font(.caption2)
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Save Preset Dialog

struct SavePresetDialog: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var presetName: String
    @Binding var presetDescription: String
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("预设信息")) {
                    TextField("预设名称", text: $presetName)
                    TextField("描述（可选）", text: $presetDescription)
                }
            }
            .navigationTitle("保存预设")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(presetName.isEmpty)
            )
        }
    }
}

// MARK: - Import Preset Dialog

struct ImportPresetDialog: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var importText: String
    let onImport: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("粘贴预设JSON代码")
                    .font(.headline)
                    .padding(.top)
                
                TextEditor(text: $importText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("导入预设")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("导入") {
                    onImport()
                }
                .disabled(importText.isEmpty)
            )
        }
    }
}

// MARK: - Export Preset Sheet

struct ExportPresetSheet: View {
    @Environment(\.presentationMode) var presentationMode
    let preset: DrumPadPreset?
    let exportText: String
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if let preset = preset {
                    Text("预设:\(preset.name)")
                        .font(.headline)
                        .padding(.top)
                } else {
                    Text("当前配置")
                        .font(.headline)
                        .padding(.top)
                }
                
                ScrollView {
                    Text(exportText)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Button(action: copyToClipboard) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("复制到剪贴板")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("导出预设")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = exportText
        #endif
        print("✅ 已复制到剪贴板")
    }
}

// MARK: - Preview

struct PadPresetManagerView_Previews: PreviewProvider {
    static var previews: some View {
        PadPresetManagerView()
            .environmentObject(Conductor())
            .preferredColorScheme(.dark)
    }
}
