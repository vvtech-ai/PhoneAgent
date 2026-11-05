## Context

`AsrCaptureSession` 在识别 ready 后会持续转发采集 PCM。Android 当前普通采集优先 `VOICE_RECOGNITION`，iOS 对话采集使用 `.default`，因此平台语音处理没有完整开启。服务端 `server_vad` 不是说话人识别器，调高阈值会损伤用户近场轻声输入。

## Decisions

1. 只改变 `speechInput=true` 的对话麦克风路径。
2. Android 将 `VOICE_COMMUNICATION` 放在对话输入的首选源，失败时回退既有源；AEC、NS 保持开启，AGC 仍关闭。
3. iOS 将对话会话模式改为 `.voiceChat`，并在安装 tap 前调用 `setVoiceProcessingEnabled(true)`；测量录音和全双工会话不走该分支。
4. 不引入本地 VAD 阈值、不修改供应商 VAD、不添加声纹或说话人识别依赖。

## Risks

- 厂商可能对 `VOICE_COMMUNICATION` 或 Voice Processing 有不同实现，可能改变音色、增益或蓝牙路由；必须用真机对近场、远场和首句采集分别验收。
- 系统语音处理不是说话人识别，不能承诺在强远场人声下 100% 拒绝。
