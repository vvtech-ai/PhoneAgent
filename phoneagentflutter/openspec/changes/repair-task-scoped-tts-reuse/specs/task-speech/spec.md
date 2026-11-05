## ADDED Requirements

### Requirement: Task scoped healthy synthesis connection

同一账号代次、任务会话、endpoint 和实际音色配置内，连续独立回复 SHALL 复用健康 WSS。进入任务 / 新输入 SHOULD 提前握手且 SHALL NOT 合成文本。空闲 60 秒 SHALL 释放连接。

#### Scenario: Complete replies reuse, interruption isolates

- WHEN A、B、C 回复逐次完成并未超出空闲期限
- THEN 三次合成使用同一物理连接，分别排空各自 PCM
- WHEN 未完成回复被打断，旧 PCM / 完成迟到
- THEN 旧物理连接作废，新回复不接收旧数据；旧租约释放不影响新连接

### Requirement: Connection controls survive idle

ready 和 pong SHALL 独立于 active synthesis 处理，完成 SHALL 保留连接心跳。配置过期错误 SHALL 仅在未输出 PCM 且有限 fresh retry 预算可用时重握手。

#### Scenario: Idle controls and expiry recovery

- WHEN 预连接收到 ready，或上一句完成后收到 pong
- THEN 控制状态正常更新且不产生合成，心跳继续保持
- WHEN 未输出音频的请求收到 reconnect_required
- THEN 仅在本请求剩余一次恢复预算内重新握手，不重复已交付音频

### Requirement: Scope invalidation

退出任务、账号代次 / endpoint / 音色配置变化、后台或网络失效 SHALL 作废旧连接。恢复前台 SHALL NOT 补播旧回复。确认播报完成与结果音频门禁 SHALL 沿用现有合同。

#### Scenario: Scope changes cancel old playback and isolate late events

- WHEN 账号、任务、音色或模型配置变化，或任务退出 / 进入后台
- THEN 旧连接与所属播放资格失效，迟到租约和音频不影响新轮
- WHEN 网络恢复或应用回到前台
- THEN 后续新消息可正常播报且不自动补播旧回复

### Requirement: Task TTS first audio retry and result handoff diagnostics

各环境的任务 TTS 在 synthesize 发送后 2 秒仍未收到 PCM 时 SHALL 使用现有的一次 fresh retry。重试 SHALL 关闭旧连接并隔离迟到 PCM，不增加第二次重试，也不改变合成完成与实际播放排空的区分。

已显示的持久通话结果到达 TTS 控制器时，诊断 SHALL 以会话 ID 和结果 sequence 记录固定的门禁、匹配或入队状态，SHALL NOT 保存正文、账号或凭据。诊断 SHALL NOT 重新打开已作废的播报资格。

#### Scenario: Silent first attempt and visible result without TTS send

- WHEN 任一环境的任务 TTS 首次请求在 synthesize 后 2 秒内没有 PCM
- THEN 仅使用现有一次 fresh retry，旧连接的迟到 PCM 不进入新播报
- WHEN 已显示持久结果但播报门禁关闭或结果未匹配
- THEN 记录固定原因以供诊断，保持原播报状态且不补播旧结果

### Requirement: Explicit stop and automatic audio cancellation remain distinct

用户明确停止当前播报 SHALL 清空当前会话后续结果播报资格，晚到的批量或单路结论 SHALL 保持静音。应用生命周期或播放端自动取消旧音频 SHALL 停止旧声音，但 SHALL NOT 将该自动事件当作用户明确停止。后台 SHALL NOT 开始新合成；返回前台并完成旧音频释放后，只有同会话中新提交、已显示且未消费的持久结果 MAY 播报一次。真实播放失败、退出、关闭语音与旧会话继续按既有规则禁止播报。批量结论被阻止时诊断 SHALL 记录固定门禁来源，不保存正文。

#### Scenario: Stop button versus call screen lifecycle

- WHEN 用户明确停止当前播报，之后批量或单路结论提交
- THEN 旧音频停止，后续结论不播报，批量诊断标记明确停止
- WHEN 通话界面使应用进入后台，或播放端自行取消旧音频，之后同会话结论提交
- THEN 后台不播；回前台且旧音频释放后结果最多播报一次，重复投影不重播
