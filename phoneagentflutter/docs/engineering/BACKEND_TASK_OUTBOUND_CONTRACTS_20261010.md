# 任务外呼与Skill后端确认项

本轮仅修正Flutter客户端；Java、数据库、服务部署/重启均未执行。UI参考v66.0.3@a0bedb12，最新App参考v71@146152a，Java参考远端v71@8ebd7db4。本文件区分源码已证实差异、旧运行日志和仍缺的真实响应，不把客户端测试当服务端成功。

## 1. 最新监听契约与当前Java源码不一致（优先）

| 边界 | App最新请求与本轮Flutter | 当前Java v71事实 | 后端需确认 |
| --- | --- | --- | --- |
| 监听票据 | SDK POST /api/agent-calls/monitor/token，Bearer/C1及当前userId、callId | SDK源码没有该路由；Agent AssistantRealtimeController仍提供/api/assistant/realtime/call/monitor/token | 开发域名对应版本/网关是否已有新SDK路由；票据所有权及真实已接通通话的注册一致性 |
| 监听WSS | Runtime /ws/assistant/call/monitor?ticket=…，同账号签名握手 | RuntimeWebSocketRouteRegistry只注册task-voice ASR/TTS及realtime/transcription；RouteGate在Upgrade前拒绝未注册路径，其测试明确此monitor返回404 | 部署是否含新handler或网关转发；不能只以WSS端口可达判断支持 |
| 状态与挂断 | 保留Agent /api/assistant/realtime/call/session/status、/hangup | 当前Agent仍有接口 | 是否与SDK票据共享同一callId/owner和物理CONNECTED状态 |

客户端已按最新App修改归属、物理CONNECTED后取票、8秒票据/10秒首PCM超时、有界重连，以及未监听/静音时的音源预选。没有回退匿名握手或悄悄切回旧路径。以上是源码冲突；本轮没有有效账号云端真实外呼测试，不能断言当前部署一定404或新路由已经可用。

准确源码路径：

- App app/src/main/java/com/vvtech/aiassistant/data/service/SdkCallMonitorApi.kt、features/assistant_tasks/TaskCallMonitorController.kt、features/assistant_audio/CallMonitorAudioSocketClient.kt。
- Java aiassistant-agent-sse/src/main/java/com/vvtech/aiassistant/agentsse/assistant/controller/AssistantRealtimeController.java。
- Java aiassistant-runtime-netty/src/main/java/com/vvtech/aiassistant/runtimenetty/config/RuntimeWebSocketRouteRegistry.java；transport/websocket/RuntimeWebSocketRouteGate.java、RuntimeWebSocketChannelInitializer.java；对应RouteGateTest。

## 2. 订餐Skill与v66最后快照的后端差异

逐行只读比较legacy backend/src/main/resources/skills与Java aiassistant-agent-sse/src/main/resources/skills，11个文件中只有restaurant-booking.md不同，其他10个相同。不能把服务端Skill提示词搬进Flutter来弥补。

| v66最终有效规则 | 当前Java v71差异 | 应确认的观察行为 |
| --- | --- | --- |
| 已确认姓名/电话与适用于订餐的已有记忆相同时，不再次问是否保存，不依赖“餐厅预订联系人”固定标题 | 当前提示仍依赖固定标题、无同一联系人复用判定 | 手动通用记忆里的有效联系人只建议、由本轮确认；相同联系人不重复保存或反复询问 |
| 记忆关闭且用户主动要求记住/更新，当前回复立即提示开启，不等待联系人收集结束 | 当前只有一般开启提醒 | 此回复立即提醒，但不阻塞订餐，不写记忆 |
| 商家明确无需预订/直接到店，接受答复并记录“未登记预订信息”，不继续报联系人或索要短信；含糊答复不能当成功 | 当前没有该分支，成功判定只含已完成预订 | 直接到店答复的通话结果、receiptFields及任务成功口径 |

客户端已传账号级实际已询问标记和首轮选中联系人，显示原ASK_USER普通气泡并允许自然回答；不读取我的身份/登录手机号，不自行调用manageMemory，不代替模型判断哪些信息已收集。

此前“联系人未确认就出卡”的220日志已有脱敏证据及97d93ea0独立提示补丁，但尚未证明部署；该补丁的合入/部署与上述v66最终差异需要后端一起核对。本轮没有追加修正、构建或部署。

## 3. 媒体、模型评价、任务评分和账单

已确认客户端曾丢失reported.callReceipt、有效callId和工具账单；前批已修正。本轮继续补同attempt终态ledger的媒体/字段/账单，保留持久结果权威与零扣费。不能再把这些已证实客户端遗漏全部归后端。

仍需后端针对同一个脱敏session/command/callAttempt/callId核对：

1. CALL_OUTCOME_REPORTED.callReceipt、TOOL_RESULT_RECORDED与timeline中的callId、dialogueDetail/dialogueTranscript、receiptFields、billingSummary；只记录“事件已发送”不足以证明内容完整。
2. 单路SDK录音/评价、批次评价和逐路recording响应；文件可用状态、真实有音频的Content响应及owner。接通失败时没有录音/评价不得伪造。
3. 最终chargedPoints/remainingPoints、各次尝试计费快照和批次稳定路序；积分预占不当作最终扣费，不重复乘billingMultiplier。
4. task-ratings的固定首个合格call/batch锚点及评价权限；终态可恢复不等于任意状态均可评分。
5. 当前TASK_TTS账号配置和受信session音色。客户端普通TTS不带preview目的；实际供应商音色/媒体参数以服务端计划及真实播放证据确认。

## 4. 既有运行日志（2026-10-09，非本轮新采集）

完整脱敏证据见BACKEND_CALL_VOICE_HANDOFF_20261009.md。本轮没有重新登录服务器或读取用户手机任务数据。

- 21:38 Agent监听票据四次“通话不存在”。该证据对应当时旧Agent路径，不能外推为新SDK路径实测结果。
- SDK通话事件INBOX出现503/RECOVERY_REQUIRED；Runtime媒体outbox的Redis读取超时。请确认事件入箱、投递、恢复与通话注册/结果持久化关联。
- Runtime转写初始化IOException: WebSocket session is closed；配置未启用分支只是按当时源码推断，部署提交未核实。
- 日志缺完整结果payload，因此还不能证明转写/录音/评分/积分为空，也不能证明新前端已收到完整数据。

## 5. 确认回复分类与补充事实的部署契约

Flutter已复用api/agent/call-confirmation/reply和api/agent/conversations/{sessionId}/call-confirmation-supplements能力，QUESTION只问当前确认信息，补充事实写原ledger，不发新Agent轮次/消费pending工具。只读检索当前Java v71的Agent/SDK main源码，没有这两个端点或对应CallConfirmationReply/ConfirmationSupplement实现；需要后端确认既有独立补丁是否合入实际部署分支，不能只依据旧本地编译结果。该源码缺口不等于本轮实测开发域名404。

建议后端确认记录包含部署提交/服务前缀、脱敏关联ID、状态码、错误类型和必需字段是否存在；不要共享Bearer、签名材料、监听票据、手机号、联系人全文或原始音频。本文件供用户交接，不自动发给第三方。
