# 单路通话控制基础与验收边界

2026-09-19 最新：正式单路监听/静音/重连/双端音源已接共享媒体及原生输出，见[监听实现与集中验收](CALL_MONITOR_VALIDATION.md)。下文“未实现媒体/未引用 controller”等是历史批次边界，不再代表当前代码。真实声音、双端安装及授权电话仍未验收。

日期：2026-09-16基础，2026-09-17补共享页面及正式执行装配。最新自动入口、发送前余额拦截、物理结束/结果同步与未完成边界见[对话到通话验证](CALL_FLOW_VALIDATION.md)。真实电话/媒体和双端仍未验收，不是完整通话能力交付。以下基础章节保留当批历史边界。

2026-09-17增量：自动确认/积分准入独立核心及27项合成回归完成，详见[准入验证与下一步接线](CALL_ADMISSION_VALIDATION.md)。本核心尚未装配正式统一页，不能将其视为自动入口、ledger同步或真实外呼验收。

## 源代码依据

Android固定v65 `4c781e3ccfcd148c1f205921534907ee0c5aa864`，未修改旧仓库：

- `core/model/RealtimeAssistantModels.kt`、`data/service/AssistantApiService.kt`：DTO、状态/挂断/监听票据3个接口。
- `features/assistant_tasks/TaskCallSessionPollingController.kt`：1500ms间隔。
- `TaskCallSessionStatusApplyController.kt`：过滤旧updatedAt、未取得callId时忽略NOT_FOUND。
- `TaskCallSessionStatusPolicy.kt`：物理终态和等待Agent结果的准确条件。
- `TaskCallSessionTranscriptPolicy.kt`：单路状态转写解析、前缀追加与快照替换。
- `TaskCallSessionUserCommandController.kt`、`TaskCallSessionCommandUseCase.kt`：明确挂断、失败不假装结束、原reason文案。
- 后端 `RealtimeSessionService.getCallSessionStatus/hangUpCall`：NOT_FOUND的callId为空、taskId回传请求值；因此不能把空callId响应一律当无效。

Q23保留的是监听/挂断/音源；不因旧代码还有handoff接口而新增接管/切回AI入口。多路不进入单路页。

## 实现位置与调用顺序

| 层 | 文件 | 职责/方法 |
|---|---|---|
| 领域 | `lib/features/calls/domain/call_session.dart` | Target定位；Snapshot的belongsTo/isTerminal/needsAgentOutcome；监听票据及Repository契约 |
| 领域 | `lib/features/calls/domain/call_transcript.dart` | parse识别角色，merge保留重复发言与种子行 |
| 数据 | `lib/features/calls/data/api_call_session_repository.dart` | status/hangUp/monitorTicket；AccountApi隔离账号，无网络重试业务POST |
| 状态 | `lib/features/calls/presentation/controller/call_session_controller.dart` | start/refresh/hangUp/markAgentOutcomeReceived/close；逐次轮询与晚到隔离 |
| 状态 | `call_session_state.dart` | idle/observing/awaitingOutcome/ended/closed，挂断请求态和错误分类 |
| 装配 | `lib/app/call_session_providers.dart` | 根据登录epoch创建真实HTTP仓库；仅读取provider不会查询、挂断或取票据 |

后续编排器应创建一个controller并显式start。它不负责发起或确认外呼；constructor、restore历史、close均不能拨号。状态取得具体callId后用它继续定位。controller只观察单个生命周期，不复用到新的通话。

`refresh`完成后才安排下一次1500ms查询，慢网络不堆请求。查询失败保留已知通话事实；认证失效关闭观察。响应必须归属当前task/call，旧时间戳不得更新转写。挂断命令使之前未完成的查询失效，重复挂断返回false而不发第二条POST。

后端终态ENDED/FAILED/NOT_FOUND停止轮询并通知onTerminal一次。taskId等于Agent session、没有Agent回执、ENDED+COMPLETED或FAILED+FAILED且resultCode不以AGENT_开头时，phase为awaitingOutcome。**这不是完成成功**。后续编排器必须继续从Agent/ledger同步结果，再用匹配callId调用markAgentOutcomeReceived；本批没有把该回调接到统一页，也不会生成虚假持久事件。

明确hangUp成功后置dismissRequested；网络失败保留页面/通话状态，不自动重发hangup；只有后续用户再次明确操作才可重试。close/dispose只取消本地定时器和观察，不挂断后台电话。

## 共用、真实与mock

- 以上均为Flutter/Dart共享实现，Android/iOS/Web使用同一契约，无新增原生代码或平台插件。
- 真实实现指仓库具有实际HTTP调用路径；本轮没有对线上真实电话调用状态/挂断/票据，也没有发起电话。
- 所有28项新增测试使用Dio合成适配器或Completer模拟服务，不联网、不发短信、不创建账号、不写积分、不碰真实通话。
- 正式App没有mock切换，也尚未引用本批controller；原“执行能力尚未接入”提示未被删掉或伪造成功代替。
- 监听票据只验证字段和时间解析并保存媒体参数；toString脱敏。未连接监听WebSocket、未播放PCM、未选择耳机/扬声器。接管RTC凭证不进入UI状态。

## 自动验证范围

`flutter test test/features/calls`覆盖：

1. API路径/POST/body/账号，空目标拒绝、跨task/call、错误DTO、未知状态、NOT_FOUND兼容、挂断失败不重发、票据格式/凭证脱敏。
2. 请求前与请求中的账号变更；真实provider按新登录epoch重建，旧实例不能请求新账号。
3. 轮询无重叠、取得callId前后NOT_FOUND差异、物理结束等待Agent结果、匹配回执解除等待。
4. 旧时间戳不改转写、挂断单飞、旧查询晚到不回退、挂断失败恢复读、不重发写、关闭/销毁无挂断与晚到隔离。
5. 终态消费者异常不把终态改成网络失败；转写多角色、重复发言、空数据与快照规则。

运行记录见根tasks和issue log。全量测试不代表正式页面或真实电话验收。

## 待接入后集中人工验收（当前不可直接按页面执行）

前提：完成自动确认/积分门禁、正式通话UI、onTerminal→ledger结果同步、监听媒体/音源适配；使用已授权测试号码且明确测试外呼/挂断。按用户原要求留到集中验收，不在本批索取授权或拨打电话。

| 场景 | 操作与预期 | 禁止情况/证据 |
|---|---|---|
| 建立与登记延迟 | 单路确认后进入通话页；登记前NOT_FOUND不显示“任务失败”，取得callId后进入实际状态 | 不能把查询HTTP200当接通；CALL_STATUS_IGNORED reason=not_found_without_active_call |
| 通话结束 | 远端挂断；电话观察结束，Agent结果未到时保持待结果，随后显示真实回执 | 不能凭ENDED显示业务成功；CALL_STATUS_APPLIED reason=terminal与对应ledger |
| 主动挂断 | 点击一次挂断，重复点不再发POST，收到响应后收起通话页 | CALL_HANGUP_REQUESTED/CONFIRMED；不得改成旧接管操作 |
| 弱网挂断 | 阻断一次请求，页面提示失败/继续同步；确认状态后人工决定是否再点 | CALL_HANGUP_FAILED reason=request_failed_no_retry，禁止自动重发 |
| 页面退出 | 退出仅释放本地观察，任务/回执后续按既定路径恢复 | CALL_OBSERVATION_CLOSED reason=local_only_no_hangup，无hangup请求 |
| 监听/音源 | 媒体接入完成后在双端验证监听/静音/音源、终态停播放 | 票据成功不等于有声音；本批未实现媒体 |
| 双端一致 | 同一合成流程阶段性安装Android/iOS，核对页面状态、按钮与安全区 | Web/单元测试不能代替真机；本批未新增安装证明 |

日志只输出事件名、sessionId/taskId/callId和固定reason，不打印号码、对话文本、ticket或异常原文。正式Release日志策略尚需与整体平台日志能力一起验收；当前诊断在assert中，仅Debug可见。

## 2026-09-17：共享页面与隔离演练

- `CallSessionPage`接通话状态、监听状态、模型、计时和三项回调，Web/Android/iOS共用。`CallControls`与`showCallAudioSources`映射监听/挂断/音源；只有Playing可切音源，蓝牙按可用性显示。转写卡自动跟随新快照，不在每秒计时时抢滚动。
- `CallPresentation`保持v65号码显示与接通计时；物理终态明确“等待任务结果/通话已结束”，没有推导业务成功。`CallPreviewController`组合已有生产轮询控制器及`PreviewCallRepository`，监听仅合成状态，完全不取媒体凭证、不播放、不改变设备音源。
- 正式App可达路径：普通拨号输入`20142014*#`并按拨号（只解锁不拨电话）→关闭→设置→开发者功能→进入隔离演练→单路通话页面演练。六个场景：呼叫中、接通、蓝牙、查询失败、挂断失败、结束等待结果。
- 演练页持续MOCK，可用“演练控制”发送合成接通/转写/查询恢复/远端结束/结果/监听失败/重连。挂断失败留页，明确再次点击才重试；挂断成功返回场景入口；“退出演练”/系统返回只清理本地对象。音源弹层取消不改选项。
- 新增12项测试，全量448项/analyze通过；320/390/430宽度、条件入口、弹层取消/系统返回、挂断重试及销毁后晚到受控。Web/Android Debug构建、OpenSpec18项通过。
- 浏览器普通App保留登录，开发者入口→场景→开启监听→蓝牙选择→停止监听（音源禁用）→挂断返回已实测；另实测首次挂断失败留页。截图确认源SVG、转写卡和底部三按钮。Web验证脚本纳入calls，369项共享回归+2项Chrome+1项Node通过。
- 本批未调用真实通话API、未写积分、未发短信、未重新安装设备；此前安装约束未绕过。共享页面不等于真实入口自动接入，2.1/2.2/2.3保持待办。

### 新页面集中验收步骤

先在Web通过上述路径演练，后续使用含本提交的双端测试包重复：接通→监听→音源（无蓝牙时只有听筒/扬声器）→关闭sheet→停止监听→音源禁用→挂断；失败场景首次挂断留页、第二次返回；等待结果场景不得显示任务成功。场景内可退出再进入，不留旧计时/音源。

这只能证明页面和合成状态交互。真实联调仍需授权测试号码和媒体端口：按前述时间窗/关联ID验证后端状态、媒体票据/流/播放器、物理结束与Agent回执、多路不进单路页、真实系统音源及终态停播。MOCK音源选择不能作为蓝牙/扬声器已接通证据。
