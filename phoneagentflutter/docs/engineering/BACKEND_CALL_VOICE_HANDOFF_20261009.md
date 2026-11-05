# 开发环境外呼、转写与结果数据交接

采集日期：2026-10-09，时间均为北京时间。环境：`https://chakenai-dev.vvtech.tech`，日志主机220；最后一次只读采集21:43。没有重启、部署、改库、补写事件或主动拨打电话。

## 判断与边界

前端和服务端都发现了问题，不能统一归为网络断开或统一归为后端。

| 项目 | 已确认的前端问题和本批修正 | 当前云端证据及判断 |
| --- | --- | --- |
| 监听、听筒/外放 | 状态/挂断/票据原误走SDK且遗漏Bearer；监听WSS使用匿名连接。现按独立App接Agent、账号鉴权和既有SignedVoiceSocket | 21:38:53–21:38:55四次票据请求被Agent以“通话不存在”拒绝。请求到达服务端但没有得到票据，尚未进入监听WSS；需核对实际通话与任务关联，不能仅凭异常判断客户端ID必然正确或必然错误 |
| 通话转写 | 既有状态轮询的Agent路由和账号鉴权已修复，保留服务端dialogueDetail展示 | Runtime有转写初始化IOException、SDK有通话事件入箱失败。已证明服务端异常，尚未按同一callAttempt关联到用户这次缺失转写的全部过程 |
| 通话录音 | SDK内容地址原被Agent基地址校验拒绝；录音Bearer和保存作用域已修正 | 当前日志不含录音接口完整响应，不能认定文件已生成或接口缺字段；需核对录音生成、结果callId锚点、SDK信息/内容响应 |
| 模型评价、任务评分 | 模型评价SDK接口补Bearer，继续原可见性和评分入口 | 当前日志不含完整评价/任务评分响应，尚不能确认是否返回模型名及评分资格；通话事件投影异常需要优先排查 |
| 积分、任务结果 | 结构化任务完成/失败标题、字段和普通结果正文纠偏；账单继续用返回billingSummary | SDK在INBOX持续抛IllegalStateException；Runtime事件outbox有Redis超时。可能影响终态和账单投影，但没有同一通话完整关联证据，不伪造积分或终态 |
| 按住说话识别 | Runtime地址、ASR协议及C1/Bearer与当前App一致；本批未改输入识别协议 | 手机云HTTPS可达，Runtime转写连接初始化报错。配置缺失及关闭竞态是源码推断，不能把事件outbox Redis超时直接当作ASR唯一原因 |

## 实际日志摘录

仅保留服务、时间、路径、固定错误文案和异常类；账号、联系人、号码、会话/通话ID、票据、原始消息与SQL均不进入本记录。原始日志只保存在本机Git忽略目录，用于授权排查。

### 监听票据被拒绝

服务：`aiassistant-agent-sse`，文件：`/logs/java/chaken-ai/dev/aiassistant-agent-sse/info.log`。

```text
21:38:53 POST /api/assistant/realtime/call/monitor/token
21:38:53 IllegalArgumentException: 通话不存在
21:38:54 POST /api/assistant/realtime/call/monitor/token
21:38:54 IllegalArgumentException: 通话不存在
21:38:54 POST /api/assistant/realtime/call/monitor/token
21:38:54 IllegalArgumentException: 通话不存在
21:38:55 POST /api/assistant/realtime/call/monitor/token
21:38:55 IllegalArgumentException: 通话不存在
```

另有21:10:26–21:10:37八次相同拒绝，共12次；请求入站与异常各记一行，不能计为24次失败。21:38这组发生在21:29新版云包安装之后。当前v71的`CallMonitorService.issueTicket`先执行`sessions.find(taskId, callId)`，未找到便抛上述错误，随后才生成Redis票据。请核对部署服务所使用的注册表、PA1通话映射、终态清理时机，以及状态接口返回的callId/taskId是否可被票据接口查询；部署源码提交尚未确认。

Flutter通过原session请求状态，再从服务端快照解析callId；未从确认卡联系人或工具ID生成callId。需要后端按实际请求关联验证映射，不能以合成测试代替真实ID核对。

### SDK通话事件持续无法入箱

服务：`aiassistant-sdk-api`，文件：`/logs/java/chaken-ai/dev/aiassistant-sdk-api/info.log`。以下为最后采样，之前21:26起已见同类日志：

```text
21:42:27 Pa1CallEventController - pa1_call_event_ack_unavailable stage=INBOX exceptionClass=IllegalStateException
21:42:30 Pa1CallEventController - pa1_call_event_ack_unavailable stage=INBOX exceptionClass=IllegalStateException
21:42:34 Pa1CallEventController - pa1_call_event_ack_unavailable stage=INBOX exceptionClass=IllegalStateException
```

当前v71源码在`stage=INBOX`调用`inbox.accept(event)`，捕获运行时异常后返回HTTP503 / `RECOVERY_REQUIRED`。日志未打印底层原因，本记录不猜测为DDL、主密钥或某个数据库字段。请后端取得完整异常链，检查事件去重/序列/入箱、账单锁及投影事务、重试与ACK；按同一callAttempt关联结果和账单。

### Runtime事件投递Redis超时

服务：`aiassistant-runtime-netty`，文件：`/logs/java/chaken-ai/dev/aiassistant-runtime-netty/console.log`。

```text
21:29:17.877 IllegalStateException: model event recovery scan unavailable
Caused by: IllegalStateException: model event outbox unreadable
Caused by: QueryTimeoutException: Redis command timed out
Caused by: RedisCommandTimeoutException
RedisPhoneMediaEventOutbox.pendingJtis:222
PhoneMediaEventDelivery.deliverPending:73
```

这是媒体事件outbox/恢复扫描异常，不能据此证明它就是按住说话ASR失败原因。请检查该服务的Redis连通性、超时及待投递事件恢复，再与SDK入箱失败关联。

### 转写初始化写入已关闭连接

服务：`aiassistant-runtime-netty`，文件：同目录`netty.log`及`console.log`。

```text
21:30:10.087 / 21:30:10.096 / 21:30:15.458 / 21:30:19.840
IOException: WebSocket session is closed
NettyWebSocketSession.sendMessage:127
SpeechTranscriptionWebSocketHandler.sendJson:180
SpeechTranscriptionWebSocketHandler.afterConnectionEstablished:49
NettyTaskVoiceWebSocketHandler.openSession:149
```

源码推断：当前v71的`afterConnectionEstablished:49`位于`!transcriptionClient.isEnabled()`分支，尝试返回“后端实时转写暂未配置完成”后关闭连接；实际部署JAR提交未核实，所以只能列为配置未完成与连接关闭竞态的线索。请同时核对主任务ASR和兼容Doubao转写的实际配置是否启用、连接生命周期与供应商响应。无需在交接中提供密钥。

## 结果字段还需取得的证据

21:11:10及21:39:23 Agent记录了call_finished/CALL_RESULT相关处理，但日志没有完整结果payload。未解析到字段不能写成“接口返回空字段”，也不能以事件已发送证明结果数据齐全。

请在服务端按同一taskId/callId/callAttempt关联以下内容，分享时脱敏：

1. 外呼创建与媒体就绪、接通、结束事件；状态接口与监听票据接口实际查询到的通话。
2. 状态响应中的dialogueDetail及最终结果metadata里的dialogueTranscript/dialogueDetail、callId，以及录音SDK响应/文件状态。原版录音入口依赖有效callId和实际对话内容。
3. 最终结果的receiptFields、billingSummary/billingState/chargedPoints/remainingPoints及投影持久化结果。
4. 模型评价GET响应中的modelName/延迟和任务评分可评资格。仅传code或终态不足以证明可展示。
5. ASR握手、start_capture、上行音频与partial/final的对应链；不要把无登录探针当作有效识别测试。

## 本批前端交付与验证

- 接口依据独立App `origin/v71@257f512538d08f8b4b5ccafe1d601041479cc07a`：`AssistantApiService`、`NetworkModule`、`CallRecordingRepository`、`CallMonitorAudioSocketClient`。
- UI依据旧`origin/test/v66.0.3@a0bedb12`正式纯语音链路，确认卡上限280、原标题/渐变；原确认回复和单路/多路积分胶囊，列表自动分页、任务结果展示均复用既有能力。
- 固定Flutter3.32.0：最终全量3495通过、1既有跳过、0失败；analyze无问题。监听提供器合同验证C1/Bearer及Android/iOS路由适配调用，不能代替真实听筒音频验收。
- 手机包三个服务均直连开发域名，包内不含原127.0.0.1三服务地址；ARM64正式main调试包保留数据安装。包SHA256：`DE93027378A25703750C4436D7B7DFFE09FDCF816F06FAC3869B572B76797A4A`。
- 用户确认列表自动翻页及确认问题显示；之后报告监听仍失败。真实录音/评分/积分/转写和听筒音频尚未验收；Windows无iOS构建环境，未宣称iOS实机通过。
- 本轮没有修改后端或数据库，也没有部署之前已推送的联系人提示补丁。该补丁的部署状态与本报告故障分开记录。

## 最新App复核后的客户端归因补充

2026-10-09后续fetch的独立App origin/v71为fd2d5bee。源码及先红后绿测试确认Flutter客户端确有遗漏，不能把此前缺少完整payload的媒体/评分/积分现象全部归为后端：

1. App优先解析CALL_OUTCOME_REPORTED.callReceipt；Flutter此前仅取CALL_COMPLETED/STARTED，丢掉语义结果里的dialogueDetail、callId、电话等。只有reported结果的样例真实复现转写及评分请求身份缺失，现已补齐。
2. App把回执callId写入结果metadata给录音/评分入口；Flutter ledger未提供录音锚点，同时额外要求先有可见转写才查录音。现保留有效锚点并移除额外转写门禁，明确未接通规则保留。
3. Flutter投影遗漏工具结果账单/字段，终态缺账单时又丢掉已有有效账单；现按同session/attempt恢复最新有效账单，包括零扣费，不借用其他通话、不合成积分。
4. 多路批次接口/每路转写及callId/多次结算/批次评分身份与最新App一致，新增两平台主题回归；未发现需要另建请求链的多路差异。

上述修正针对客户端数据已返回却未展示的场景，不证明本次云端真实响应已经包含完整数据。21:38监听票据“通话不存在”、SDK INBOX异常、Runtime转写初始化IOException等此前服务端事实仍有效，日志时间与证据边界不变。本批未修改/部署后端或数据库，未主动拨号，后端人员仍需按本记录核查真实生成、事件投影及实际响应。任务TTS音色由当前Runtime的账号TASK_TTS配置/受信session决定；客户端普通播放不带preview purpose，不能把名义speaker字段当成实际使用音色的证据。