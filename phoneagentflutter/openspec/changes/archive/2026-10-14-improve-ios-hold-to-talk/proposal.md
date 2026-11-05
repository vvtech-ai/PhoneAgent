## Why
用户反馈主动按住说话时 iOS 不如 Android 流畅。旧 iOS 0c652847 的 AIVoiceBackendSpeechClient 从实际按下开始采集，并在 ASR 未 ready 时保留 2 秒音频；当前 AsrCaptureSession 等网络 ready 才开麦，握手期间的开头语音无法恢复。当前普通采样使用 measurement，旧版任务输入使用 default。
## What Changes
仅 iOS 正式任务语音工厂启用提前开麦、2 秒有界缓存和 ready 后按序上传；Android 保留原启动时序。任务语音输入单独标记 speechInput，在 iOS 原生选择 default 模式，其他普通录音仍沿用 measurement，全双工通话保持 voiceChat。
## Impact
不更改识别协议、后端、服务路由、语言、松手 2 秒收尾和提交规则。不强制开启旧版曾禁用的 VoiceProcessing，不自动选择或修改蓝牙路由。不重用主 ASR 音频到备用连接。
