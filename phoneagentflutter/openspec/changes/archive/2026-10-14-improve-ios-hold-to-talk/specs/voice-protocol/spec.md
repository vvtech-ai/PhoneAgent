## ADDED Requirements
### Requirement: iOS 按住说话保留握手期间音频
iOS 任务主动语音 MUST 在已有授权且实际按住后启动采集并与识别连接并行，在 ready 前仅保留本轮最多 2 秒内存音频；MUST 只在识别 ready 后按序上传。Android 现有时序和其他录音模式 MUST 保持不变。
#### Scenario: 慢握手
- **WHEN** iOS 用户按住后立即说短句而识别服务还未 ready
- **THEN** 已启动麦克风的本轮音频在有界缓存中保留，ready 后按原顺序送出，不提前上传
#### Scenario: 取消或备用切换
- **WHEN** 本轮取消、底层停止、账号失效或识别连接失败
- **THEN** 清理本轮缓存且等待硬件实际停止，不上传旧帧，不向备用识别重放
#### Scenario: 独立任务采样模式
- **WHEN** iOS 正式任务语音启动普通录音
- **THEN** 使用旧版对应 default 模式，不改变其他录音或全双工 voiceChat 配置，停止后恢复会话
