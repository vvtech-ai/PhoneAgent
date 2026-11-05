# voice-protocol 规范

## Purpose

规定需求语音协议与生命周期基础。此为 B1 目标契约；实施/设备验证进度以 tasks.md 和 B1 证据为准。

## Requirements

### Requirement: ASR故障必须按现有单次后端回退执行
主ASR错误或启动8秒未就绪时 MUST 只尝试一次既有realtime/transcription网关，携带真实当前账号及语言，不新增平台识别SDK或供应商直连。备用网关 MUST 仅在ready后上传16k PCM16 mono，关闭时不得发送主ASR控制消息或重放旧音频。

#### Scenario: 资源和提交交接
- **WHEN** 主ASR故障且本手势仍有效
- **THEN** 先隔离旧回调、等旧采集实际释放再启动备用；清未确认partial而保留已确认final，沿原手势收尾只提交一次

#### Scenario: 停止与再次失败
- **WHEN** 普通关闭、用户取消、页面/账号失效、原生采集失败、旧采集无法释放或备用识别失败
- **THEN** 不再创建识别链路；清理失败保持可重试，不能假报麦克风空闲或自动提交失败片段

### Requirement: 语音协议保持 v65 契约
系统 MUST 保留 ready、start_capture/open_listening、stop_capture、finish、synthesize、cancel 及现有返回事件，ASR 与 TTS 音频格式分开声明；不得新增供应商直连。

#### Scenario: 编解码
- **WHEN** 处理合法控制消息或服务端事件
- **THEN** 只映射对应的类型及字段；未知事件不猜作成功，损坏字段显式失败且不回显原文。

### Requirement: 录音轮次隔离
系统 MUST 在 ready 后放行当前轮 PCM，底层显式 stop 后保留一次非空 late final；取消、新轮或过期 MUST 拒绝旧事件。按固定 v65，手势松手 MUST 先继续采集最多 2000ms 收尾，有效 final 可提前停止提交；不得把手势与底层 stop 等同。本纠偏及实现进度见 active change `voice-protocol-foundation` 4.3b，不代表整项验收或归档。

#### Scenario: 底层停止与取消
- **WHEN** 当前轮已 ready 并调用底层 stop
- **THEN** 不再采集或接受 partial，但可接受一次本轮非空 final；取消后该 final 也必须拒绝。

#### Scenario: 旧轮回调
- **WHEN** 新轮开始后旧轮收到 ready 或文本
- **THEN** 不影响当前轮；transport 必须绑定真实连接上下文，不能盲目重标当前轮。

### Requirement: 音频独占租约
系统 MUST 只允许一个音频 owner 持有有效租约，过期租约不能释放新 owner。

#### Scenario: 交接
- **WHEN** 旧 owner 已停止并释放资源，新 owner 获取租约
- **THEN** 旧 owner 的延迟释放必须无效，重复获取不得创建并行占用。

### Requirement: 合成完成与播放排空分离
系统 MUST 对播放记账实行有界容量和轮次隔离，complete 仅关闭输入，剩余音频实际消费为零后才 drained。

#### Scenario: 合成结束仍有音频
- **WHEN** 收到 complete 且存在未播放数据
- **THEN** 保持 draining，不把它判为播放完毕；取消后不接受旧音频或旧消费回调。

#### Scenario: 容量不足
- **WHEN** 新音频超过剩余容量
- **THEN** 返回 backpressure 且不更改计数；适配器等待容量或明确失败，不静默丢音频。

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
