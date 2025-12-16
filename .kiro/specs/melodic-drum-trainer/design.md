# Design Document

## Overview

本设计文档描述了基于现有 DrumPad 应用构建 Melodics 风格互动鼓练习软件的技术架构。系统将扩展现有的 AudioKit 基础，添加实时评分、课程管理、进度追踪和多种练习模式。

核心设计原则：
- 低延迟音频处理（<20ms）
- 实时MIDI输入处理和评分
- 模块化架构支持扩展
- 数据驱动的课程内容系统
- 离线优先的用户体验

## Architecture

### 系统架构图

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Presentation  │    │    Business     │    │      Data       │
│      Layer      │    │     Logic       │    │     Layer       │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • ContentView   │    │ • LessonEngine  │    │ • CoreData      │
│ • LessonPlayer  │    │ • ScoreEngine   │    │ • FileManager   │
│ • ProgressView  │    │ • ProgressMgr   │    │ • UserDefaults  │
│ • SettingsView  │    │ • AudioEngine   │    │ • CloudKit      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   AudioKit      │
                    │   Foundation    │
                    │ • Conductor     │
                    │ • MIDI Handler  │
                    │ • Audio Engine  │
                    └─────────────────┘
```

### 技术栈

- **UI Framework**: SwiftUI
- **音频处理**: AudioKit 5.x
- **数据持久化**: Core Data + CloudKit
- **MIDI处理**: AudioKit MIDI + Core MIDI
- **属性测试**: Swift Testing Framework
- **最低版本**: iOS 15.2, iPadOS 15.2

## Components and Interfaces

### 1. Audio Engine (扩展现有 Conductor)

```swift
protocol AudioEngineProtocol {
    func setupMIDIInput()
    func processMIDIEvent(_ event: MIDIEvent)
    func startPlayback(lesson: Lesson, mode: PlaybackMode)
    func pausePlayback()
    func setTempo(_ bpm: Float)
    func setLoopRegion(_ start: TimeInterval, _ end: TimeInterval)
}
```

### 2. Lesson Engine

```swift
protocol LessonEngineProtocol {
    func loadLesson(_ lessonId: String) -> Lesson?
    func getCurrentStep() -> LessonStep?
    func advanceToNextStep()
    func setPlaybackMode(_ mode: PlaybackMode)
    func getTargetEvents(for timeRange: TimeRange) -> [TargetEvent]
}
```

### 3. Score Engine

```swift
protocol ScoreEngineProtocol {
    func processUserInput(_ event: MIDIEvent, at timestamp: TimeInterval)
    func calculateScore() -> ScoreResult
    func getTimingFeedback(for event: MIDIEvent) -> TimingFeedback
    func resetScore()
}
```

### 4. Progress Manager

```swift
protocol ProgressManagerProtocol {
    func updateProgress(lessonId: String, score: ScoreResult)
    func getDailyProgress() -> DailyProgress
    func updateStreak()
    func unlockAchievement(_ achievement: Achievement)
}
```

### 5. Content Manager

```swift
protocol ContentManagerProtocol {
    func importMIDIFile(_ url: URL) -> Lesson?
    func createCourse(title: String, lessons: [Lesson]) -> Course
    func validateContent(_ content: LessonContent) -> ValidationResult
    func publishContent(_ content: LessonContent)
}
```

## Data Models

### Core Models

```swift
struct Lesson: Codable, Identifiable {
    let id: String
    let title: String
    let courseId: String?
    let instrument: Instrument
    let defaultBPM: Float
    let timeSignature: TimeSignature
    let duration: TimeInterval
    let tags: [String]
    let steps: [LessonStep]
    let scoringProfile: ScoringProfile
    let audioAssets: AudioAssets
}

struct LessonStep: Codable, Identifiable {
    let id: String
    let lessonId: String
    let order: Int
    let title: String
    let description: String
    let targetEvents: [TargetEvent]
    let bpmOverride: Float?
    let assistLevel: AssistLevel
}

struct TargetEvent: Codable {
    let timestamp: TimeInterval
    let laneId: String
    let noteNumber: Int
    let velocity: Int?
    let duration: TimeInterval?
}

struct ScoreResult: Codable {
    let totalScore: Float // 0-100
    let starRating: Int // 1-3
    let isPlatinum: Bool // 100% in Performance Mode
    let isBlackStar: Bool // 100% in Memory Mode
    let timingResults: [TimingResult]
    let streakCount: Int
    let missCount: Int
}

struct TimingResult: Codable {
    let targetEvent: TargetEvent
    let userEvent: MIDIEvent?
    let timing: TimingFeedback
    let score: Float
}

enum TimingFeedback: String, Codable {
    case perfect = "perfect"
    case early = "early" 
    case late = "late"
    case miss = "miss"
    case extra = "extra"
}
```

### Configuration Models

```swift
struct ScoringProfile: Codable {
    let perfectWindow: TimeInterval // ±20ms
    let earlyWindow: TimeInterval   // ±50ms  
    let lateWindow: TimeInterval    // ±50ms
    let missThreshold: TimeInterval // ±100ms
    let extraPenalty: Float
    let gradePenaltyMultiplier: Float
}

struct AudioAssets: Codable {
    let backingTrackURL: URL?
    let clickTrackURL: URL?
    let previewURL: URL?
    let stemURLs: [String: URL] // instrument -> URL
}

enum PlaybackMode: String, Codable {
    case performance = "performance"
    case practice = "practice"
    case memory = "memory"
}

enum AssistLevel: String, Codable {
    case full = "full"           // 显示所有引导
    case reduced = "reduced"     // 部分引导
    case minimal = "minimal"     // 最少引导
    case none = "none"          // 无引导（记忆模式）
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

基于需求分析，以下是系统必须满足的关键正确性属性：

### MIDI连接和设备管理属性

**Property 1: MIDI设备连接一致性**
*For any* MIDI设备连接事件，系统应该正确识别设备类型并建立相应的连接状态
**Validates: Requirements 1.1, 1.2**

**Property 2: MIDI映射完整性**
*For any* 完成的MIDI映射配置，所有必需的鼓件都应该有对应的MIDI音符映射
**Validates: Requirements 1.4**

**Property 3: 连接状态显示一致性**
*For any* 设备连接状态变化，UI显示的连接信息应该与实际连接状态保持一致
**Validates: Requirements 1.5**

### 内容浏览和筛选属性

**Property 4: 内容筛选准确性**
*For any* 难度筛选条件，返回的所有内容都应该匹配指定的难度级别
**Validates: Requirements 2.2**

**Property 5: 标签关联正确性**
*For any* 标签点击操作，显示的相关内容都应该包含该标签
**Validates: Requirements 2.3**

**Property 6: 新手推荐一致性**
*For any* 新手用户状态，推荐的课程应该来自引导路径且符合初学者难度
**Validates: Requirements 2.5**

### 演奏和评分属性

**Property 7: BPM播放准确性**
*For any* 设定的BPM值，实际播放速度应该与设定值保持一致（误差<1%）
**Validates: Requirements 3.1, 4.1**

**Property 8: 实时判定准确性**
*For any* 用户输入的MIDI事件，时间判定结果应该基于预定义的时间窗口准确分类
**Validates: Requirements 3.2**

**Property 9: 评分计算一致性**
*For any* 相同的演奏输入序列，在相同配置下应该产生相同的分数结果
**Validates: Requirements 3.3**

**Property 10: 星级阈值正确性**
*For any* 计算出的分数，星级应该正确映射（50%=1星，75%=2星，90%=3星，100%=白金星）
**Validates: Requirements 3.4**

**Property 11: 解锁条件准确性**
*For any* 100%分数的表现模式完成，记忆模式应该被解锁
**Validates: Requirements 3.5, 8.1**

### 练习模式属性

**Property 12: 自动加速递增性**
*For any* 开启自动加速的良好演奏，BPM应该每次增加10直到达到原始速度
**Validates: Requirements 4.2**

**Property 13: 循环播放边界性**
*For any* 设定的循环区间，播放应该在指定的开始和结束时间点之间重复
**Validates: Requirements 4.3**

**Property 14: 等待模式暂停准确性**
*For any* 目标音符位置，等待模式应该在该位置暂停直到接收到正确的用户输入
**Validates: Requirements 4.4**

### 节拍器属性

**Property 15: 节拍器音色应用性**
*For any* 选择的节拍器音色，播放的节拍声音应该使用对应的音色样本
**Validates: Requirements 5.2**

**Property 16: 节拍器细分准确性**
*For any* 设定的细分值（1/4、1/8、1/16），节拍器应该以对应的时间间隔播放
**Validates: Requirements 5.3**

**Property 17: 起拍提示独立性**
*For any* 课程开始，无论节拍器开关状态如何都应该提供起拍提示
**Validates: Requirements 5.4**

### 反馈和回放属性

**Property 18: 判定结果完整性**
*For any* 演奏结束，每个目标音符都应该有对应的判定结果（Perfect/Early/Late/Miss）
**Validates: Requirements 6.1**

**Property 19: 连击计数准确性**
*For any* 连续的Perfect音符序列，当达到4个时应该触发连击提示
**Validates: Requirements 6.4**

**Property 20: 错误惩罚一致性**
*For any* 错误音符输入，扣分应该根据当前难度等级应用相应的惩罚权重
**Validates: Requirements 6.5**

### 进度追踪属性

**Property 21: 进度更新原子性**
*For any* 课程完成事件，用户等级和星级统计应该同时更新且保持一致
**Validates: Requirements 7.1**

**Property 22: 每日目标累积性**
*For any* 练习会话，当累计时间达到5分钟时应该标记每日目标完成
**Validates: Requirements 7.2**

**Property 23: 连击重置保留性**
*For any* 连击中断事件，连击计数应该重置为0但奖杯进度应该保持不变
**Validates: Requirements 7.4**

### 记忆模式属性

**Property 24: 记忆模式视觉隐藏性**
*For any* 记忆模式激活，音符预览和轨道高亮应该被隐藏但音频功能保持正常
**Validates: Requirements 8.3, 8.5**

**Property 25: 黑星成就条件性**
*For any* 记忆模式中的100%分数，应该授予黑星成就
**Validates: Requirements 8.4**

### 内容管理属性

**Property 26: MIDI解析转换性**
*For any* 有效的MIDI文件输入，解析后的内部谱面格式应该保持原始的时间和音符信息
**Validates: Requirements 9.1**

**Property 27: 内容验证完整性**
*For any* 发布的课程内容，所有必需的元数据（标题、难度、标签、学习目标）都应该存在且有效
**Validates: Requirements 9.2, 9.5**

### 设置和可访问性属性

**Property 28: 高对比模式转换性**
*For any* 高对比模式激活，所有彩色时间反馈应该转换为白色加图标的形式
**Validates: Requirements 10.1**

**Property 29: 延迟补偿应用性**
*For any* 设定的音频延迟补偿值，判定系统的时间窗口应该相应调整
**Validates: Requirements 10.3**

## Error Handling

### 音频系统错误处理

1. **MIDI连接失败**: 提供手动映射选项，显示详细错误信息
2. **音频引擎启动失败**: 重试机制，降级到基本音频功能
3. **延迟过高**: 自动检测并警告用户，建议使用有线连接

### 数据完整性错误处理

1. **课程数据损坏**: 验证数据完整性，提供重新下载选项
2. **进度数据丢失**: 本地备份机制，CloudKit同步恢复
3. **评分计算异常**: 日志记录，回退到安全的默认评分

### 用户输入错误处理

1. **无效MIDI映射**: 实时验证，高亮缺失的映射
2. **不支持的文件格式**: 清晰的错误提示，支持格式列表
3. **网络连接问题**: 离线模式，本地缓存内容

## Testing Strategy

### 双重测试方法

本项目将采用单元测试和基于属性的测试相结合的方法：

- **单元测试**: 验证具体示例、边界情况和错误条件
- **基于属性的测试**: 验证跨所有输入应该成立的通用属性
- 两者结合提供全面覆盖：单元测试捕获具体错误，属性测试验证通用正确性

### 单元测试要求

单元测试将覆盖：
- 特定的MIDI输入序列和预期的评分结果
- 边界条件（极慢/极快BPM，空课程等）
- 错误条件（无效MIDI数据，网络失败等）
- 组件间的集成点

### 基于属性的测试要求

- **测试框架**: 使用 Swift Testing Framework 进行基于属性的测试
- **测试配置**: 每个属性测试运行最少100次迭代以确保随机性覆盖
- **测试标记**: 每个基于属性的测试必须使用注释明确引用设计文档中的正确性属性
- **标记格式**: 使用格式 '**Feature: melodic-drum-trainer, Property {number}: {property_text}**'
- **实现要求**: 每个正确性属性必须由单个基于属性的测试实现

### 测试生成器策略

为了有效测试音频和MIDI系统，将创建智能生成器：

1. **MIDI事件生成器**: 生成有效的MIDI音符事件，包括时间戳、音符号和力度
2. **课程内容生成器**: 生成有效的课程结构，包括步骤和目标事件
3. **用户输入生成器**: 模拟各种用户输入模式，包括准确、早、晚和错误的击打
4. **时间窗口生成器**: 生成各种评分配置和时间窗口设置

### 性能测试

- **延迟测试**: 验证音频处理延迟<20ms
- **内存测试**: 长时间练习会话的内存使用稳定性
- **并发测试**: 多个音频流和MIDI输入的并发处理

### 集成测试

- **端到端练习流程**: 从课程选择到完成评分的完整流程
- **设备兼容性**: 不同MIDI设备的连接和映射
- **数据同步**: 本地和云端进度数据的同步一致性