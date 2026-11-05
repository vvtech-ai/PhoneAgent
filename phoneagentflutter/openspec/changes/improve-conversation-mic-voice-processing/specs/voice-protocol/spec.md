## ADDED Requirements

### Requirement: 对话麦克风优先使用平台语音处理

对话按住说话的设备采集 MUST 在 Android 优先使用 `VOICE_COMMUNICATION` 并保留已有 AEC/NS，在 iOS 使用 `voiceChat` 和 Voice Processing；普通文件/克隆采集、全双工通话采集和 Web 合成端口 MUST 保持各自原有采集模式。

#### Scenario: Android conversation capture

- **WHEN** 正式 Android 对话语音创建 `speechInput` 采集
- **THEN** 原生优先创建 `VOICE_COMMUNICATION`，失败后按既有顺序回退到 `VOICE_RECOGNITION` 和 `MIC`，并不启用 AGC

#### Scenario: iOS conversation capture

- **WHEN** 正式 iOS 对话语音创建 `speechInput` 采集
- **THEN** AVAudioSession 使用 `voiceChat`，输入节点启用 Voice Processing 后再安装 PCM tap

#### Scenario: non-conversation capture remains isolated

- **WHEN** 文件/克隆采集或全双工通话创建非对话采集
- **THEN** 不继承本需求的对话语音处理开关，继续使用原有测量或全双工会话
