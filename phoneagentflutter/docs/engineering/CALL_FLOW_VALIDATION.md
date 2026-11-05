# 对话到通话的共享执行链路

日期：2026-09-17。固定行为基线v65 `4c781e3`，现有HTML/CSS和组件优先，视觉校准后置。**正式会话已装配自动确认/积分/单路页面/结果同步；本批验证使用隔离外部端口，不等于真实电话或媒体通过。**

## 实现与流转

| 入口/核心方法 | 数据与状态流转 |
|---|---|
| app/call_admission_providers.dart | 绑定登录epoch、环境/API、账号、钱包和当前模型；通过既有AccountApi调用，不新增后端/数据库/提示词 |
| ConversationController._accept / ConversationCallController.receive | 仅实时MAKE_CALL_REQUEST产生待执行身份；保留原始spec构造alias，1500ms后准入；历史恢复只remember，绝不执行 |
| CallLaunchCoordinator.interceptSubmission | 已提示不足后的新输入先刷新余额；仍不足只弹框，允许才发送原始输入一次；等待时不接受并发提交，关闭/恢复取消晚到 |
| ConversationCallController.restoreHistory / CallLaunchCoordinator.restoreContext | 仅可恢复pending makeCall重建静默restored上下文；恢复本身无确认/余额刷新/弹框。用户输入时按隔离存储的当前alias及同任务历史alias检查已通知，只拦截再次不足；未知/充足/首次不足转发原输入，不自动执行历史 |
| ConversationController._confirmCall | 原session、voice、独立commandId/idempotencyKey和pendingToolCallId发送confirm_call，不伪造用户确认消息，不重放用户输入 |
| ConversationCallController._observe / ConversationCallHost | 单路在提交前打开共用CallSessionPage并观察登记；多路留在统一页。活动单路的重复/替换工具不触发第二次呼叫 |
| CallSessionController / ConversationCallController._sync | 状态1500ms只读观察；物理终态需要Agent结果时保持等待；读取ledger出现匹配callId的agentOutcome才收起并展示回执 |
| ConversationFactSync.accept / merge | 合并REST持久事实与SSE，不覆盖较新SSE；只容忍相同事件的时间戳精度规范化，正文、归属、序号和其他metadata冲突仍拒绝且不部分写入 |
| ConversationCallController.hangUp / dismissCall / close | 明确挂断才调用接口，单飞；系统返回只清理本地观察，退出统一页清理全部本地会话，不挂断后台电话 |
| AgentFailure / ConversationFailurePresentation / confirmationFailed | 结构化NETWORK优先，旧错误按v65窄网络模式；模型超时不等于断网。无callId的明确非网络失败收起并允许调整输入，网络未知/已登记callId保留观察；不因retryable自动重发，安全提示不暴露原始诊断 |
| ConversationCallController.acceptReceipts / ConversationFactSync.hasOutcome | 当前confirm命令的终态final或匹配callId的持久agentOutcome直接结束本地观察；拒绝其他命令/通话、RUNNING和只有物理结束的回执；已有结果不必再等REST |

ConversationEventStream独立管理订阅，ConversationLiveMessages负责临时消息形状，ConversationCallNotice负责不足提示，CallRequestHistory负责历史身份上下文。恢复协调交给ConversationCallController后，ConversationController为493行；Web/Android/iOS复用这套Dart逻辑和页面。本批未改SIP、ASR、TTS或原生插件。

首次不足提示沿后端相同command身份生成临时消息，以后可由ledger替换；再次不足不重复发提示POST。余额未知交给后端原子准入，不本地扣费。提交端口结束仅代表命令流已交接，不代表服务端接单、电话接通或任务成功。

## Web演练

现有开发者解锁后：设置 → 开发者功能 → 进入隔离交互演练（MOCK）→ 对话到通话全流程演练。

- 单路：发送合成需求 → 自动通话页 → 合成远端结束 → 保持“通话已结束，等待任务结果” → 合成结果到达 → 统一页按用户输入、确认、转写、结果顺序展示。
- 多路：发送合成需求 → 留在统一页展示批量结果；没有单路页面、监听/音源/挂断控件。
- 不足：首次一条消息；再次先刷新、弹框；关闭后原会话保留，无第二条用户消息、无第二次Agent提交。再次点击仍可以弹框。
- 不确定：确认网络异常后只观察和同步，不自动重发。自动测试另覆盖已知拒绝与已有callId时不同的关闭行为。
- 模型超时：服务端MODEL_TIMEOUT且未登记callId，收起观察显示安全提示；切换文字并输入草稿后发送可用，不强制当作断网恢复。
- 实时结果：当前确认流直接返回终态回执，不点击合成远端结束或结果按钮，自动回统一页展示结果。
- 恢复不足：首次不足后点击“恢复合成历史”，保留用户/确认/不足消息，无自动弹框；再次提交刷新后才弹框，关闭后无第二条用户消息。此连续流程已经浏览器验证；演练提示持久化到内存ledger，不写真实账号。

PreviewCallFlow仅替换Agent、历史、余额、提示存储和通话仓库；共用正式Controller和Widget。号码是保留合成号码，MOCK标记持续显示，不访问真实账号/通话/积分服务。首次演练的历史缺少用户事实曾导致回执顺序不正确，已补完整合成USER_TURN_ACCEPTED/TOOL_REQUESTED，再通过浏览器截图复验。

浏览器实测单路、多路、首次/再次不足与弹框返回；网络不确定/已知失败/系统返回由Widget与状态测试覆盖。本批没有新增短信，没有清理或重新获取登录凭据；刷新Web直接恢复原会话。

结构化失败增量浏览器实测：上述模型超时、失败后文字草稿/发送可用、实时结果回统一页已确认。回执headline位于合并语义卡中，精确文本定位未找到后用截图核实实际展示，非功能失败。刷新时生产模型显示加载失败、首页余额未取得，因此本批只声明MOCK交互通过，不宣称真实后端可用或真实联调通过。

## 自动验证

- 新增27项：conversation_call_flow_test 14项、conversation_submission_gate_test 6项、conversation_fact_sync_test 7项；全部合成数据。
- 结构化失败增量新增27项：agent_failure_test 13项、conversation_structured_failure_test 14项；包含旧网络兼容、结构化优先、安全提示、五种失败分类、已登记callId保护、旧命令/异call结果、物理结束与Agent结果分离及晚到隔离。
- 历史恢复增量新增14项conversation_restored_admission_test，当前全量737项测试、flutter analyze通过；覆盖同任务不同确认身份与异任务隔离，前批723项保持通过。
- 19项OpenSpec、392个Dart文件格式检查、git diff --check通过；改动源码/测试均不超过500行。初次多行if括号lint已修正。
- Web debug和Android debug按测试环境构建；Android必须使用完整`https://agent.vvtech.tech/aiassistant-api/`，不是域名根路径。构建命令不能作为真实接口联调证明。
- OpenSpec变更保持active，未完成项不归档。无本批iOS新构建/真机安装证据；标准安装恢复确认仍待处理，不绕过之前的拒绝。

## 仍需实现的边界

1. call-started/status等活动增量及多路进度仍需按v65处理，不把这些消息伪造成物理状态快照；结构化业务失败、单路final及持久agentOutcome直接协调已接入。
2. 历史当前makeCall确认发送门禁已接入并验证；不根据历史消息文字猜测不足标记，不扩展v65恢复mapper未恢复的批量spec。真实跨设备历史/本机通知存储仍需集中验收。
3. 活动多路逐项进度、退出后仅接收/账号隔离、结束任务刷新与最终历史恢复已接共享实现（2026-09-18，见BATCH_FLOW_VALIDATION.md）。真实后台事件/ledger/积分结算、双端后台/进程恢复仍需集中验收；不把合成演练当真实多路通过。
4. 准入余额刷新与钱包UI内存状态统一已接入，独立余额/流水过期和并发保护详见WALLET_FEEDBACK_VALIDATION；持久缓存、结算事件和真实收费验证仍待完成，不得增加本地扣费。
5. 监听票据后的真实传输/播放和系统音源。正式页点击监听明确提示未接，不模拟正在播放；音源未播放时禁用。
6. Android/iOS阶段真机和集中人工验收、最终视觉校准。上述是迁移范围内待办，不是删减功能。

## 集中人工验收（尚未执行）

前提：测试环境、已有登录、明确授权测试号码及积分；先恢复标准设备安装/启动验证，不把debug包当Android无缝OTA升级包。

| 操作 | 预期 | 禁止出现 |
|---|---|---|
| 单路需求形成确认 | 1500ms后只有一次confirm_call，单路自动显示；未登记时NOT_FOUND继续观察 | 恢复历史即拨号、重复工具导致重复外呼 |
| 首次不足后再次输入 | 首次消息，第二次刷新余额后弹框或继续原输入；后端最终准入 | 第二次先发Agent再弹框、客户端伪造扣费/成功 |
| 弱网或服务拒绝 | 网络不明继续核实；明确拒绝且无callId收起；有callId保留观察 | 自动重发外呼、把未知状态写成失败/成功 |
| 通话结束与结果延迟 | 物理结束仍等待Agent结果；回执按真实事实展示 | 把ENDED直接当任务成功、旧REST覆盖较新SSE |
| 返回/挂断/退出 | 返回不挂断；明确挂断单次提交；退出本地无晚到写回 | 自动挂断后台电话、重复挂断 |

日志只核对sessionId/taskId/callId及CALL_STATUS_APPLIED、CALL_STATUS_IGNORED、CALL_HANGUP_REQUESTED、CALL_HANGUP_CONFIRMED、CALL_OBSERVATION_CLOSED、conversation_failure、ledger_merge。不得在证据中保存号码、转写、token或监听票据。
