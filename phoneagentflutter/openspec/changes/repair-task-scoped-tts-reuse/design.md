## Ownership

TaskTtsConnectionOwner 管理单任务连接和带代次租约，不拥有正文、倒计时或业务状态。Riverpod family 使用 ConversationEntry，监听账号 ID / loginEpoch、runtime endpoint 与实际 task-tts-voice 配置。配置变化立即作废握手快照。普通任务配置读取失败沿用服务端权威选音合同，不增加阻断任务的设置门禁。

TaskTtsSession 负责 wire / request 两层状态：空闲 ready/pong 正常处理，完成只停请求计时器；无明确 complete 的软超时必须换 wire，防止迟到 PCM 串入新请求。reconnect_required 仅复用当前请求的一次 fresh retry 预算。二进制 PCM 无请求 ID，合成中的取消必须关闭物理连接。

ConversationTtsStream 管每回复文字队列、PCM 队列和焦点。合成完成归还租约；播放仍独立排空。已归还旧租约的晚取消不得关闭下一轮。foreground 恢复不重播旧文本，网络可用不是供应商健康证明。

已合成但未排空的回复保留失效监听，换配置 / 后台 / 退出仍立即停止旧 PCM；60 秒 idle 只释放 wire，不截断已合成音频。新回复继承 owner 当前离线快照，避免错过 broadcast 的早先断网事件而无限等待。逐 reply 的 send / receive / complete / retry 继续绑定本轮 trace，物理连接以 mediaRequestId 与 requestGeneration 关联，预热 connect / ready 仍是任务连接诊断。

## Boundaries

供应商 ACK 后无音频的根因未明，连接复用只减少重复握手。各环境的任务 TTS 首包静默等待统一为 2 秒后重连；只缩短首次静默等待，不增加重试次数，也不改变 24,000 字节首缓存门槛。供应商若在 2–5 秒间正常返回首 PCM，可能提前切断，须用真机与新诊断评估。测试不冒充设备音频、真实后端或供应商恢复证据。

已显示的持久结果若没有 TTS send，仅记录会话 ID、结果 sequence 和固定门禁原因或入队结果。诊断不保存正文、账号或凭据；结果匹配、静音、通话暂停和后台旧音隔离仍按现有身份处理。此前日志不足以认定当时漏播的具体门禁，后续现场证据见下节。

## 批量结论漏播的停止来源区分

test 批次 `batch-665cbc9a6e5b35fcaee43e0b93c927aa` 在结论到达前已失去播报资格，终态记为 `resultEligibilityLost`，可见结论记为 `turnInterrupted`；旧诊断没有记录来源，不能据此判断用户按了停止。现有 `pause()` 同时被停止按钮与 App 生命周期调用，底层播放自行进入 cancelled 时也会清掉结果资格。这两条自动路径足以产生同类症状，但尚未证明哪条发生于该批次。

保留停止按钮的 `pause()`：清空资格，后到结论继续静音。生命周期改走 `pauseForLifecycle()`：停止旧音频，后台不领取持久结果，返回前台且旧音频确已释放后仅领取同会话新提交、可见、未消费的结果。底层自行取消只停止当前音频，不清空后续结果匹配；真实播放失败仍关闭资格。显式 `interrupt()`、退出、关语音、账号变化与旧轮次失活保持原行为。批量终态的诊断新增固定原因 `userStoppedSpeech`、`explicitInterruption`、`playbackFailed`，无需保存正文或用户输入。
