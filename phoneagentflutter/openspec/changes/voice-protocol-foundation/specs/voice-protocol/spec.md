## ADDED Requirements

### Requirement: ASR故障必须按现有单次后端回退执行
主ASR错误或启动8秒未就绪时 MUST 只尝试一次既有realtime/transcription网关，携带真实当前账号及语言，不新增平台识别SDK或供应商直连。备用网关 MUST 仅在ready后上传16k PCM16 mono，关闭时不得发送主ASR控制消息或重放旧音频。

#### Scenario: 资源和提交交接
- **WHEN** 主ASR故障且本手势仍有效
- **THEN** 先隔离旧回调、等旧采集实际释放再启动备用；清未确认partial而保留已确认final，沿原手势收尾只提交一次

#### Scenario: 停止与再次失败
- **WHEN** 普通关闭、用户取消、页面/账号失效、原生采集失败、旧采集无法释放或备用识别失败
- **THEN** 不再创建识别链路；清理失败保持可重试，不能假报麦克风空闲或自动提交失败片段

### Requirement: 网络失败的用户句必须先核对服务端事实再恢复
普通VOICE用户命令发生传输失败时 MUST 保留本页原文本与commandId；下一次显式语音或键盘输入 MUST 先同步完整ledger，MUST NOT 自动重放请求、录音、文档或外呼确认。

#### Scenario: 原命令完成或待修订
- **WHEN** 用户显式输入且原命令已有有效持久助手回复
- **THEN** 先恢复持久消息，重复原句不发送，新补充作为新轮；若原命令未完成则重叠合并并带supersedesCommandId发送新命令，用户气泡不重复追加

#### Scenario: 同步失败与生命周期
- **WHEN** ledger缺失/不完整/冲突，或同步期间关闭/恢复历史
- **THEN** 前者保留待恢复事实且不发送，后者作废晚到结果；按住可显示恢复前缀，但取消/ASR错误不自动提交未确认片段

### Requirement: 通话结果播报必须来自已应用持久消息
单路与批量结果 MUST 关联当前终态标记、匹配finishReason的持久助手回复及已应用消息投影；MUST 使用该消息正文而非瞬态final.text。重复事件/终态只播一次，恢复历史、新轮或取消不得误播旧结果。

#### Scenario: 结果乱序与单路返回
- **WHEN** 结果、持久回复或只读补齐先后到达，或单路通话刚结束
- **THEN** 等关联及页面门禁满足才播报；当前封口PCM仍待消费时等待排空，不中断前句或重复执行外呼

#### Scenario: 历史与生命周期
- **WHEN** 恢复历史、用户打断、后台、退出或切换账号
- **THEN** 作废待播关系与旧回调，不因晚到结果自动恢复音频；Web仅通过同页MOCK替换外部端口验证

### Requirement: 统一页普通回复必须共享流式播报
统一VOICE会话当前回复 MUST 保留v65分句、Markdown清理、固定需求音色及交互提示规则；多句MUST串行合成并共用有界PCM输出，不等每句实际排空才开始下一句合成。键盘切换只改变输入控件，不静音回复；历史恢复和已作废轮次 MUST 不自动播报。

#### Scenario: 交互和打断
- **WHEN** 当前回复delta/final/补问/候选到达或用户按下输入、离页、后台、进入单路通话
- **THEN** 前者沿相应提示规则入队，后者取消当前缓冲/合成/输出且拒绝旧回调；失败保留消息文字，不重新发送Agent请求或自动重录

#### Scenario: 播报时按住说话
- **WHEN** 当前回复正在播报且不处于批量执行/单路通话
- **THEN** 即使回复流尚未结束也允许手势打断，取消当前Agent流及播报、恢复输入状态，再走已有权限/采集；纯思考未播报时不得凭此跳过既有发送门禁

#### Scenario: 合成和实际完成
- **WHEN** 最后一条合成结束但PCM仍待播
- **THEN** 保持待播状态直至设备实际消费和释放；Web合成设备仅验证同一编排，不声称真机声音通过

### Requirement: PCM输出必须由真实播放确认并支持抢占释放
输出端口 MUST 以outputId隔离单次生命周期，play成功仅表示设备实际消费而非复制到缓冲；共享队列 MUST 有界、区分合成完成与设备排空。TTS MUST 使用媒体音量，不把AppAudio通信策略混入。

#### Scenario: 合成提前完成
- **WHEN** complete到达而仍有排队或原生在途PCM
- **THEN** 保持draining，全部实际消费并释放设备后才报告drained，不提前恢复其他音频owner

#### Scenario: 取消或设备中断
- **WHEN** 用户取消、切换账号、离开前台或设备播放失败
- **THEN** 作废旧回调、停止实际输出，不自动恢复或伪装成功；停止失败保留音频占用且可重试清理

#### Scenario: Web合成验证
- **WHEN** 在明确MOCK入口注入合成socket与output
- **THEN** 复用正式TTS播放组合、队列和租约，不发真实语音请求或声音；不把合成消费视为真机通过

### Requirement: PCM采集必须真实释放并隔离轮次
采集端口 MUST 输出16k/PCM16/mono且单次最多640字节，按captureId隔离并限制在途读取及缓冲；MUST 只检查已有权限而不自行弹窗。共享编排 MUST 在ASR ready后开始采集，停止失败不得归还音频租约。

#### Scenario: 取消或离开前台
- **WHEN** 用户取消、切换账号或原生进入后台/被中断
- **THEN** 停止PCM上行并释放实际硬件，旧数据不串入新轮，不自动重启；手势松手的收尾由上层规则决定，不等同底层立即stop

#### Scenario: 慢消费或释放失败
- **WHEN** 原生缓冲超限或停止失败
- **THEN** 明确失败且停止上行，不静默丢音频；实际停止未确认前保留占用，允许显式重试清理

### Requirement: 网关传输必须独立归属并可终止
系统 MUST 通过自有API上下文的ASR/TTS WebSocket通信，每轮独立连接且取消后丢弃旧事件；连接晚到MUST关闭而非启动采集。握手/ready MUST 有界，禁止自动重连或重放用户语音。

#### Scenario: 显式停止和断开
- **WHEN** 上层调用ASR底层release/stop
- **THEN** 发送stop_capture，停止PCM/partial，最多接一次非空late final；90秒空闲关闭，取消则立即作废所有结果并发送finish

#### Scenario: 合成超时和尾块
- **WHEN** TTS合成收到音频、complete或超时
- **THEN** dev/prod保留v65首音5秒；test环境按后续任务TTS变更试行首包静默2秒后使用原有限重试。完成15–60秒边界和24000/5760字节缓存不变，complete发送尾块但不表示播放排空
- **AND** 有音频完成超时显式软完成，首音超时失败；超限明确失败，不输出正文/音频/地址凭据日志

### Requirement: 语音协议保持 v65 契约
系统 MUST 保留 ready、start_capture/open_listening、stop_capture、finish、synthesize、cancel 及现有返回事件，ASR 与 TTS 音频格式分开声明；不得新增供应商直连。

#### Scenario: 编解码
- **WHEN** 处理合法控制消息或服务端事件
- **THEN** 只映射对应的类型及字段；未知事件不猜作成功，损坏字段显式失败且不回显原文。

### Requirement: 录音轮次隔离
系统 MUST 在 ready 后放行当前轮 PCM，底层stop后保留一次非空 late final；取消、新轮或过期 MUST 拒绝旧事件。手势松手 MUST 沿v65进入最多2000ms收尾：有效final提前结束，否则合并缓冲final/partial后停止提交，不能将底层stop直接等同手势松手。

#### Scenario: 底层停止与取消
- **WHEN** 当前轮已 ready 并显式stop
- **THEN** 不再采集或接受 partial，但可接受一次本轮非空 final；取消后该 final 也必须拒绝。

#### Scenario: 手势与收尾
- **WHEN** 用户按下、向上移动至少58逻辑像素后松手，或正常松手
- **THEN** 按下立即启动，不新增长按时长门禁；上滑取消不提交，正常松手继续最多2000ms收尾并且只提交一次；按住60000ms按v65已有文本规则停止提交

#### Scenario: 正式提交和权限晚到
- **WHEN** 合法识别文本完成或等待权限期间已经离页/松手/取消
- **THEN** 前者调用现有会话发送入口并标记ASR来源；后者不因晚到授权启动录音。Web普通入口不调用真实语音，隔离演练不得写真实账号

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
