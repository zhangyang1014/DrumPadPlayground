# Requirements Document

## Introduction

基于现有 DrumPad 应用，开发一个类似 Melodics 的互动鼓练习软件。该系统将提供实时反馈、刻意练习工具和游戏化体验，帮助用户建立节奏稳定性、手脚独立性和常见 groove/rudiments 等基础技能。系统将把练习变成可量化、可复盘、可持续的习惯。

## Glossary

- **System**: 互动鼓练习软件系统
- **User**: 使用应用进行鼓练习的用户
- **Lesson**: 单节练习内容，包含多个步骤
- **Course**: 围绕特定概念或技巧组织的多个课程集合
- **Step**: 课程中的单个练习步骤，从简单到复杂递进
- **Performance_Mode**: 表现模式，正常速度下的完整演奏
- **Practice_Mode**: 练习模式，支持降速、循环、等待等辅助功能
- **Timing_Window**: 判定窗口，定义音符击打的时间准确度范围
- **BPM**: 每分钟节拍数，控制音乐速度
- **Loop_Region**: 循环区间，可重复练习的时间段
- **Wait_Mode**: 等待模式，系统暂停直到用户正确击打
- **Memory_Mode**: 记忆模式，隐藏引导提示的高级练习模式
- **Daily_Goal**: 每日练习目标，默认5分钟
- **Streak**: 连续达成每日目标的天数
- **Trophy**: 累计练习成就奖励
- **MIDI_Mapping**: MIDI设备到应用内鼓件的映射配置

## Requirements

### Requirement 1

**User Story:** 作为用户，我想要连接和配置我的MIDI鼓设备，以便能够使用物理鼓垫进行练习。

#### Acceptance Criteria

1. WHEN 用户通过USB连接MIDI设备 THEN System SHALL 自动识别并建立连接
2. WHEN 用户通过蓝牙连接MIDI设备 THEN System SHALL 提供配对界面并建立连接
3. WHEN System 无法识别设备 THEN System SHALL 提供手动MIDI映射功能
4. WHEN 用户完成MIDI映射 THEN System SHALL 验证所有鼓件映射正确性
5. WHEN 连接建立后 THEN System SHALL 显示连接状态和延迟信息

### Requirement 2

**User Story:** 作为用户，我想要浏览和选择练习内容，以便找到适合我当前水平的课程。

#### Acceptance Criteria

1. WHEN 用户进入内容浏览页面 THEN System SHALL 显示课程、单课和练习的分类列表
2. WHEN 用户选择难度筛选 THEN System SHALL 返回匹配难度的内容
3. WHEN 用户点击标签 THEN System SHALL 显示标签定义和相关内容
4. WHEN 用户预览课程 THEN System SHALL 播放音频预览和显示内容描述
5. WHERE 用户是新手 THEN System SHALL 推荐引导路径的下一课

### Requirement 3

**User Story:** 作为用户，我想要在表现模式下完整演奏课程，以便测试我的整体演奏能力。

#### Acceptance Criteria

1. WHEN 用户开始表现模式 THEN System SHALL 以原始BPM播放完整课程
2. WHEN 用户击打鼓垫 THEN System SHALL 提供实时时间判定反馈
3. WHEN 演奏结束 THEN System SHALL 计算并显示0-100%的分数
4. WHEN 分数达到阈值 THEN System SHALL 授予对应星级（50%=1星，75%=2星，90%=3星）
5. WHEN 用户达到100%分数 THEN System SHALL 解锁记忆模式

### Requirement 4

**User Story:** 作为用户，我想要使用练习模式的辅助功能，以便更有效地学习困难部分。

#### Acceptance Criteria

1. WHEN 用户调整BPM滑块 THEN System SHALL 改变播放速度到指定值
2. WHEN 用户开启自动加速 THEN System SHALL 在演奏良好时每次增加10 BPM
3. WHEN 用户设置循环区间 THEN System SHALL 重复播放指定时间段
4. WHEN 用户开启等待模式 THEN System SHALL 在目标音符处暂停直到正确击打
5. WHEN 用户在练习模式完成练习 THEN System SHALL 保存练习数据

### Requirement 5

**User Story:** 作为用户，我想要使用节拍器功能，以便保持稳定的节奏感。

#### Acceptance Criteria

1. WHEN 用户开启节拍器 THEN System SHALL 播放可听的节拍声音
2. WHEN 用户选择节拍器音色 THEN System SHALL 应用选定的6种音色之一
3. WHEN 用户设置细分 THEN System SHALL 支持1/4、1/8、1/16细分选项
4. WHEN 课程开始 THEN System SHALL 提供起拍提示即使节拍器关闭
5. WHEN 用户调节节拍器音量 THEN System SHALL 独立控制节拍器音量

### Requirement 6

**User Story:** 作为用户，我想要查看演奏后的详细反馈，以便了解我的错误并改进。

#### Acceptance Criteria

1. WHEN 演奏结束 THEN System SHALL 显示每个音符的判定结果（Perfect/Early/Late/Miss）
2. WHEN 用户查看回放 THEN System SHALL 提供时间轴上的错误定位
3. WHEN 发现错误区域 THEN System SHALL 允许直接设置循环练习该区域
4. WHEN 用户连续击打4个Perfect音符 THEN System SHALL 显示连击提示
5. WHEN 用户击打错误音符 THEN System SHALL 根据难度等级扣除相应分数

### Requirement 7

**User Story:** 作为用户，我想要追踪我的学习进度，以便了解我的改进情况和保持练习动力。

#### Acceptance Criteria

1. WHEN 用户完成课程 THEN System SHALL 更新用户等级和星级统计
2. WHEN 用户达成每日5分钟练习目标 THEN System SHALL 增加连续天数计数
3. WHEN 用户连续达成每日目标 THEN System SHALL 累积连击天数
4. WHEN 用户中断连击 THEN System SHALL 重置连击计数但保留奖杯进度
5. WHEN 用户查看进度概览 THEN System SHALL 显示等级、星级、连击、奖杯和建议下一步

### Requirement 8

**User Story:** 作为用户，我想要在记忆模式下练习，以便在没有视觉提示的情况下演奏。

#### Acceptance Criteria

1. WHEN 用户在表现模式获得100%分数 THEN System SHALL 解锁记忆模式
2. WHEN 用户进入记忆模式 THEN System SHALL 逐步隐藏引导提示
3. WHEN 记忆模式演奏 THEN System SHALL 移除音符预览和轨道高亮
4. WHEN 记忆模式达到100% THEN System SHALL 授予黑星成就
5. WHILE 记忆模式进行中 THEN System SHALL 保持音频伴奏和节拍器功能

### Requirement 9

**User Story:** 作为内容管理员，我想要导入和管理练习内容，以便为用户提供丰富的学习材料。

#### Acceptance Criteria

1. WHEN 管理员上传MIDI文件 THEN System SHALL 解析并转换为内部谱面格式
2. WHEN 创建新课程 THEN System SHALL 要求输入标题、难度、标签和学习目标
3. WHEN 设置课程步骤 THEN System SHALL 允许将完整谱面拆分为渐进步骤
4. WHEN 配置评分规则 THEN System SHALL 设置时间窗口和错误惩罚参数
5. WHEN 发布内容 THEN System SHALL 验证内容完整性并推送到客户端

### Requirement 10

**User Story:** 作为用户，我想要自定义音频和视觉设置，以便获得最佳的练习体验。

#### Acceptance Criteria

1. WHEN 用户启用高对比模式 THEN System SHALL 将彩色反馈改为白色加图标
2. WHEN 用户关闭连击闪烁 THEN System SHALL 禁用Perfect音符的闪烁效果
3. WHEN 用户调整音频延迟补偿 THEN System SHALL 应用延迟校正到判定系统
4. WHEN 用户选择音频输出设备 THEN System SHALL 切换到指定的音频设备
5. WHEN 检测到蓝牙音频连接 THEN System SHALL 警告用户可能的延迟问题