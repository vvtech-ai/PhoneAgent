## ADDED Requirements

### Requirement: 定位拒绝使用瞬时反馈
客户端 SHALL 在当前任务收到定位拒绝时显示一次 Toast，真实权限结果 SHALL 继续回传；SHALL NOT 在对话底部保留设置提示和按钮。

#### Scenario: 普通拒绝或永久拒绝
- **WHEN** 当前任务收到 DENIED 或 SETTINGS_REQUIRED
- **THEN** 仅显示一次对应定位 Toast，后续可提供城市或区域，重建页面不重复提示

### Requirement: 实时转写跟随实际内容
通话页面 SHALL 在 SSE 新增转写时滚动到最新内容；相同内容的计时或音源刷新 SHALL NOT 改变用户滚动位置。

#### Scenario: SSE 先于轮询快照
- **WHEN** 实时转写新增且轮询 source 未变化
- **THEN** 最新 AI 或对方转写即时进入可见区域

### Requirement: 后台目录音色支持动态试听
客户端 SHALL 允许当前目录中非空 ID 的系统音色调用已有试听端口，SHALL NOT 用固定本地资源表限制生产试听。

#### Scenario: IndexTTS 或 Qwen Audio 预置声音
- **WHEN** 用户点击后台目录音色试听
- **THEN** 使用对应模型及音色已有 URL 或生成接口，且不切换当前音色

### Requirement: 监听问题有可验证的媒体证据
监听修复 SHALL 通过可重复测试验证；诊断 SHALL 不包含票据、鉴权、号码、音频或转写正文。

#### Scenario: 监听中断
- **WHEN** 首帧超时、缓冲溢出、播放失败或连接中断
- **THEN** 能区分安全原因类别，且不影响后台电话或重放外呼
