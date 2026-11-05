## Why

对话按住说话时，当前设备采集链路会把 2–3 米处的人声作为普通 PCM 送入 ASR。现有 ASR/VAD 只能判断是否有人声，不能判断说话人身份；需要先在平台采集层启用系统语音处理，降低远场人声进入 ASR 的概率。

## What Changes

- 对 Android 对话语音输入优先使用 `VOICE_COMMUNICATION`，保留 `VOICE_RECOGNITION`/`MIC` 回退以及已有 AEC/NS。
- 对 iOS 对话语音输入使用 `voiceChat` 并启用 `AVAudioInputNode` Voice Processing。
- 普通录音、文件/克隆采集、全双工通话采集、ASR 协议、VAD 参数、挂断状态机和数据模型保持不变。

## Capabilities

### Modified Capabilities

- `voice-protocol`

## Impact

仅影响 Flutter 对话麦克风的平台采集参数和对应测试；无数据库、接口、依赖或持久化迁移。系统语音处理不能提供绝对说话人隔离，真实效果仍需 Android/iOS 设备验证。
