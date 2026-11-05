# Flutter 任务编排知识库

完整行为标准在本仓 [AGENTS.md](../../AGENTS.md) 的 `task-orchestration-v1.10`，本知识库补充本端源码职责、数据与事件流。规则、知识结构与某一批修复进度分开；本文件不依赖其他人的检出或个人机器信息。当前修复、旧版回归映射与未验边界见 [任务编排回归审计](../qa/TASK_ORCHESTRATION_REGRESSION_AUDIT_20261020.md)。

## 1. 四类入口

| 入口 | 源码责任 | 输入与语义 |
| --- | --- | --- |
| 首页任务卡 | HomeController、DioHomeRepository、HomeConfigMapper、ShellTaskNavigation.entry | 卡片版本 / Skill / 开场形成新会话上下文 |
| 联系人 Skill | ContactSkillsController、contact_actions、contactSkillOpening、ContactTaskRoute | 选定姓名 / 目标号码、Skill、联系人专用开场；正式入口接入 ConversationRoute |
| 任务列表恢复 | ShellTaskNavigation.task、ConversationRestoreFlow | 按原 session 恢复账本与 pending，不当成新任务 |
| 通话 / 旧任务详情 | TaskDetailRoute、TaskDetailController、TaskDetailPage | 按原回执展示只读信息，显式继续与另建任务分开 |

联系人系统拨号、翻译技能和任务列表翻译历史有既有专用路径，不能通过共享任务页改写其业务。联系人模板优先使用 selectedContactOpening 替换名字；缺模板沿用既有 v66 文案规则再使用普通开场，空姓名不编造称呼。道歉走专用 Consent。

## 2. 配置、输入与冻结上下文

HomeCard 包含 id、title、status、action、skillId、opening、selectedContactOpening、minimumVersion、imageUrl 等字段。HomeConfigMapper 解析发布版本和 Skill 引用；HomeCard.canEnter 管动作、发布状态与最低版本，不负责推断当前会员权益。

HomePublishedSnapshots为首页可选更新端口。DioHomeRepository保留单飞签名GET和ETag，先提供有效缓存/环境随包内容，再发布验证通过的完整配置；内存应用不等待磁盘写入。HomeController订阅时处理缓存迟到与销毁，首页变化不会改写已复制到ConversationEntry的卡片事实。testHomeSnapshot只用于test，其他环境保持原确认基础快照；环境选择不请求网络、不增加首屏等待。用户排序与显隐仍由原HomeCardPreferencePolicy投影。

ConversationEntry 承载 session、Skill、开场、已选联系人、恢复标志和账号所属代次。ConversationSubmission 将用户输入映射为 AgentCommand 和本地回显；初次命令携带 initialSkillId / initialOpening / selectedContact，续接使用自己的 command 与 pending 身份。

OCR-first 上传通过 OcrUpload 在 upload-intents 与 complete 的元数据中携带同一初始 Skill 和已选联系人，入口来自 ConversationController.pendingInitialEntry；已发送业务输入后不重复携带。后端在首次授权时持久保存绑定。ConversationRestoreFlow 不执行工具，控制器仅在已存在 USER_TURN_ACCEPTED 或旧历史无法区分时设置 initialSent；只有开场/OCR 的恢复不误认为业务首轮已发送。原账号/页面代次、OCR 图片重试和历史锚点继续使用原职责。

AgentCommand 还包含 userId、idempotencyKey、traceId、actionId / payload、inputKind、supersedesCommandId 和 callVoiceSelection。输入回显、初始开场、工具确认和模型选择不能共用一个含糊身份。页面状态重建不应被当成新的用户操作。

## 3. 数据到页面的主链

```text
DioAgentGateway → SSE frame / AgentEvent 解码
  → ConversationEventFlow / 当前代次检查
  → ConversationMessageStore：durable facts + live messages
  → ConversationMessages / ConversationMessageMerge / presentation projection
  → ConversationState → ConversationMessageTile / 确认与结果组件

历史 REST → TimelineSource / LedgerSync
  → ConversationRestoreFlow → 清旧 overlay、装载同会话账本
  → 恢复投影 / 只读详情
```

| 对象 | 字段 / 职责 |
| --- | --- |
| AgentEventKind | text、thinking、thinkingDone、status、toolStart / Complete / Card、signal、finalResponse、committed、error、done、heartbeat、unknown |
| AgentEvent | text、sessionId、payload、ledger、eventName；传输类型与 payload 业务子类型分开 |
| LedgerEvent | eventId、sessionId、sequence、schemaVersion、type、payload、command / task / call / attempt、metadata |
| LedgerProjection | status、continuable、pendingRestorable、migrationStatus、projectedThrough |
| ConversationMessage | 展示身份、所属轮次 / 工具及正文 / 选项 / 确认 / 回执 / 思考等 payload |

账本内容指纹用于识别副本与冲突，不能替代不同事件身份。SSE 时间精度与持久化时间精度的差别，不是跨轮按相同文字合并的理由。工具名、模型名、文案和网络到达时间不能单独决定排序。

## 4. 交互、确认、通话与恢复

- ConversationPresentationProjection 管 live / restore 展示；QuestionPromptPresentation 等纯规则只处理明确同身份的重复内容，不操作后端或音频。
- 选项选择保留旧卡快照、使其失活，并追加独立用户回显；activeOptionsId 与 pendingToolCallId 的职责不同，不能以“页面还有一张卡”认定可以执行。
- ConversationConfirmationFlow 将当前可见拨打卡的全部自然语言答复交给 CallConfirmationReplyCoordinator，后端按账本中的当前卡片判断整句语义；客户端不按固定话术或后缀授权，也不重复覆盖语义结果。原 call launch 协调器继续负责准备倒计时、准入和提交；确认呈现、账号/session/tool/内容签名和代次检查缺一不可。明确按钮使用显式确认动作，旧卡返回、切模或迟到回答不能自动拨号。
- QUESTION/WAIT/UNCLEAR 及语义失败使用原补充问答记录并保留当前卡；批量补充通过 CALL_CONFIRMATION_SUPPLEMENT 交付。BatchConfirmationPending 只在同会话、同一未结束的最新 confirmBatchTask 仍有合法补充事实时恢复输入绑定，不授予执行权限或创建新卡。API 的有界 cardText 仅为兼容提示，权威内容由后端按身份读取。
- 通话观察、结果与普通消息的 owner 分开。等待接通、已接通、停止受理、物理结束、结果整理不混成一个“完成”标记；媒体与语义字段只补同次通话。
- 所有多路 Skill 的冻结执行名单恰为一人时，BatchSingleCallController 通过批次只读通话接口复用 CallSessionPage；多人逐个拨打或仅剩一路不切换。确认卡、批次执行/计费/重拨/回执/评分仍归原 owner。准备展示只认同身份 SDK launchReady，结束/关闭/停止事实优先；不从确认、callId 或进度推断启动。
- 一人批次页面挂断通过 ConversationStopBinding.stopObservedBatch 衔接现有停止受理、在途禁用和结果恢复；不另起普通单呼挂断。实时与恢复批次进度使用同一接入点，旧 attempt 和已结束批次不能复活页面；监听仍使用真实 batchId/callId，观察不提交确认或拨打命令。
- 连续一人外呼按有效 command/batch/attempt 区分：前批次已完成后，当前新命令的新一人批次进度建立独立观察，重新等待所属 SDK launchReady。不能依赖缺失的 toolStart，也不能由重复工具提示清空活动通话或停止标记；已结束批次集合保留以过滤迟到事件。
- ConversationRestoreFlow 读取原 session 的事实，清旧进程 overlay，再按有效 pending 恢复操作权；TaskDetailController 读取原详情，TaskDetailPage 的卡片只读。两条路径应遵循同一消息与结果规则，不能因组件共用就省略跨入口回归。
- 任务列表已读是原任务的阅读状态，不应改变业务终态、执行电话或凭空授予评分资格。

## 5. 结果、两类评价与 TTS

结果区域的内容和顺序由 AGENTS 固定；录音需要可信媒体锚点，结果不完整时按相同身份原位补齐。receiptFeedbackTarget 将单通 / 批量回执映射为 FeedbackTarget，CallEvaluationRoute 承载模型评价与 TaskRatingRoute，二者独立。

TaskRatingController 管资格、草稿、提交、只读与卡片 owner；ApiTaskRatingRepository 校验回执目标、资格和提交身份。评分接口使用 task-ratings 的 calls / batches 查询及 eligibilities 提交。资格晚到、失败恢复、owner 交接与账号变化必须按 RATING 场景测试，不能仅靠重新进页触发初始化。

ConversationSpeechController 负责任务页回复播报，CommittedReplyNarration 协调已应用事实与结果说明；ReplySpeechPlayback 负责实际合成、排队、排空、取消和失败。voice host 处理用户开关、输入 / 生命周期门控和页面归属。任务页 TTS 与电话对端的媒体播放是不同范围；文字出现、进入队列、实际可听完成不等价。

实时确认补充沿 ConversationEventFlow.onLiveCommitted → conversation_event_binding → ConversationSpeechController.acceptConfirmationSupplement 接线：只在首次已成功应用的当前输入事实完成显示后，核对 command/record、会话及当前待确认卡，再将 CALL_CONFIRMATION_SUPPLEMENT.assistantText 交给原播放队列。不同事件即使同文案也有独立资格；重复交付、历史恢复和补查的旧事实不自动播报，静音/后台/打断仍按原音频门禁。此接线不改变确认判断、pending 或拨号动作，也不伪造 TEXT_REPLY。

开场、补问、确认与结果按各自身份取得播报资格；历史不自动重播。输入、静音、选项、切模和离页按原播放生命周期中断旧音频，不因此删除文字、停止任务或丢草稿。确认提示阶段与所属倒计时协调；结果说明由同次通话的结果与音频门禁共同放行，评分查询不阻塞播报。入队、合成、播放开始、排空或失败必须分开观察；失败不能冒充已播放，后续新消息不能被旧取消代次吞掉。

取消、结果同步和短暂异常属于运行状态，由当前操作身份在顶部协调；不是追加对话正文的理由。过渡状态在可信终态、恢复或所属操作失效时撤销，置灰按钮重复点击无副作用。业务确认提示与结果说明仍是独立保留的正文，不能为了消除技术提示一起清空。 单路与多路停止复用 ConversationStopBinding 的在途、已受理和结果归属；首轮同步结束不释放等待结果期间的交互门禁。ConversationPage 在原思考占位使用同一展示 key 原位显示临时任务处理进度，NativeThinkingCard 复用原样式并区分进度标题与真实思考。ConversationComposer 在停止期间优先禁用共享按钮，结果就绪后恢复原 TTS 打断和输入；按钮样式不变。顶部只读同步和明确失败重试沿原端口，进度不进入消息账本、历史或 TTS；回归编号 STOP-01、THINK-01、HISTORY-01、VOICE-01。

## 6. 源码与回归索引

ConversationBatchActivity 从当前 ready / sending 会话的 transient batchReceipt 派生执行、核对、汇总及静态未确认展示，供 ConversationPage 原占位和 ConversationStatusPresentation 共用。事件流断开不代表批次结束，当前页不依赖重新进任务才能恢复展示；可信终态仍由既有批次结果替换和停止 owner 清理。该投影不改变会话 phase、输入门禁、补查次数、账本或播报，Android / iOS 使用同一 Dart 逻辑。

ConversationStopBinding 的首次停止入口同时覆盖 sending 与 ready 且 BatchProgressTracker 仍活跃的批次；后者正是批次临时展示的事实来源。全部逐路可信结果已齐等待汇总时沿 awaitingAggregate 关闭首次停止，观察耗尽清除活跃 tracker 后也不凭静态 VERIFYING 回执重新开放。页面继续通过原 onStop 接线到停止协调器，受理后保持禁用、同批次可信终态后恢复；不在 widget 内创建第二套停止准入或网络调用。

按类型 / 文件名定位：home_config_mapper、dio_home_repository、shell_task_navigation、contact_actions、contact_skill_opening、dio_agent_gateway、agent_event_decoder、agent_protocol、ledger_event、conversation_submission、conversation_message_store、conversation_message_merge、conversation_presentation_projection、conversation_restore_flow、conversation_confirmation_flow、task_detail_controller、task_rating_controller、conversation_speech_controller。

已有测试族包括 apology_committed_timeline、apology_voice_flow、conversation_message_merge、conversation_thinking_stream / ui、confirmation_interaction、task_rating_controller / widget、contact_skill_opening_parity、contact_task_entry、任务详情与历史恢复等。对照旧版时要检查事件序列和断言，不能按名字判定“已有覆盖”。

增加回归时使用真实 controller / provider / widget 连续输入，断言身份、内容、坐标顺序、active 状态和副作用次数；接口与平台用合成端口隔离。新增测试必须守住明确业务语义，生产 Bug 先记录 RED 再最小修复 GREEN，不为跑通测试增加任意 sleep、放宽断言或改成伪成功。

## 7. 记忆提问与账号上下文

RestaurantContactMemoryOffer / RestaurantMemoryAskedStore 维护客户端按账号的保存询问展示标记并输出 restaurantContactMemoryAsked；首轮等待读取，服务端与当前任务已询问事实共同判断。实际展示后记住，后续任务不再主动问保存；未展示或旧账号迟到回调不得记为已问。同任务及账本恢复继续保留已询问事实。shown 既不是保存成功，也不是本次使用授权；已有记忆使用仍由服务端逐任务确认。

记忆使用提问沿用真实 askUser / pending 身份、用户回显和旧卡失活规则；新任务的使用授权不能由本地 asked 标记、Skill 关联或过去任务回答推断。历史恢复不自动采用未确认候选、不播旧提问。记忆检索、权威更新与采纳规则由公共后端负责，客户端负责原问题和回答的正确呈现，不根据“页面有记忆”自行补执行参数。

## 主动召回、保存判重与任务语音连接

- 停止主动记忆询问后，用户仍可明确要求采用当前 Skill 中已展示且版本 / 用途一致的候选；变更或指向不明时补必要确认。界面和历史沿用原 askUser / pending 身份，授权决定由公共后端提交与恢复。新任务不继承授权。
- 保存判重由后端独立比较当前明确输入与当前 Skill 已有联系人，完整同内容不再次询问保存或新增；更正原记录和新增联系人分别确认，未采用记忆正文不因判重进入模型。
- TTS 健康连接可在同账号 / 同任务 / 同配置的连续回复之间复用，预连接只握手。连接保活、单次合成和 PCM 播放分别管理；旧租约、迟到音频和旧 response.done 不能影响新轮。长时间空闲、配置过期、账号 / 音色 / 任务变化、后台与网络失效按对应边界释放，不自动重播历史。
- conversationTaskSpeechProvider 的 family 随真实 ConversationEntry、账号与登录代次建立 TaskTtsConnectionOwner；每次回复通过 TaskTtsLease 租约使用连接。ConversationTtsStream 继续负责单次排队与播放，不能让旧回复的 close 关闭新回复持有的连接。任务音色设置并行刷新，目录查询失败不增加普通回复的等待门禁，实际可用音色仍由服务端握手校验。


## 8. 记忆管理与确认展示的统一来源

- CallConfirmationPrompt 按 ToolRequested.assistantText 和稳定工具子身份呈现提示，旧账本兼容固定工具展示合同。ConversationMessageStore / Merge 保持实时、补账本和恢复的同一位置，卡片失活后提示仍可回看；进度清理不删除业务提示。
- MEMORY_OPERATION_NOTICE 是后端持久化的记忆业务结果；实时 memory_notice 沿既有一次播报入口消费，账本副本按所属 command / record 协调。恢复只展示，不重新播报；同 command 独立正文不能被说明覆盖。
- ConversationQuestions 与 SpeechPromptPolicy 对无有效问题的内部 askUser 使用同一有效性规则，不显示或播报默认“再确认几件事”；有效旧 question、具体 title 和 items 保留。内部跳过标记不能吞掉带有效题目的业务卡。
- MemoryController 为同一次 ADD 维护稳定 operationId，失败重试或未编辑再次保存复用；用户改内容或新建另一个动作创建新身份。接口业务失败经固定安全映射展示具体可修正原因，网络失败仍可重试。
- MemoryEditorPage 按快照条数及 Unicode 码点容量校验，更新扣除原条目长度。账号登录代次隔离、已停用 Skill 标签保留；账号级保存询问 shown 标记控制跨任务主动保存询问；服务端另保留当前任务已询问事实，二者均不是使用授权。

## 相关候选、操作结果和客户端上下文

检索逐项判断当前 Skill 范围候选的相关性，同用途的多位联系人保持完整备选；选择授权只覆盖用户明确选中项。检索完整性与采用同意不能共用“最佳一条”的假设，未采用原文仍不进入任务模型。管理结果中的安全状态与写入结果独立保留，候选正文按账号、Skill 和命令隔离；保存确认上下文含本次工具回答，内部隐藏标记不成为用户说明。

道歉任务专属模型及恢复配置优先于全局模型，确认报价和准入共用有效来源，不更改全局选择或旧报价。日志上传读取实际安装版本，读取失败保留包；账号切换隔离沿用原认证边界。Web 展示服务端记录，不重算客户端版本或任务准入。

评分继续沿用既有资格、首次回执锚点、政策快照与已有回归，本轮不改变。连续验证编号见 AGENTS 的 MEMORY-11 / MEMORY-12 / MODEL-03 / LOG-01；现场记录与规则分别维护。

首轮缺资料补问与后续轮次使用相同后端实时状态。主模型跳过召回时仅在普通缺字段 askUser 扩展点按当前命令有界补核相关性，转既有记忆确认；不对每条普通回复增加调用，不把音色 ready 本地提示当作已执行记忆检索。

## 餐厅候选资格与跨端展示

餐厅候选由后端搜索及 showOptions 归一化决定资格，客户端餐厅选项投影只呈现同一候选的号码可用性和说明，不自行筛选或重排。普通附近 / 地区 / 菜系推荐只包含可拨打门店；指定店名或品牌的无号命中在出现时同步提示，历史恢复沿用原身份与说明，不授权拨号。定位授权或城市补充沿原重搜入口进行；受影响连续回归为 RESTAURANT-01/02 及 ENTRY-05/06/08、CONFIRM-01/02/03、HISTORY-01、MEMORY-07/15。

## 任务操作结果与页面通知归属

TaskController 持有操作结果的单次 effect，TaskPageMutation 只修改已加载窗口；成功删除后的草稿清理仍按原账号和 TaskRef。TasksPresentationHost 消费共享通知，以页面 owner 撤销自身可见和排队反馈，不清理其他能力的通知。PageRouteVisibility 观察实际 Navigator 的页面归属；列表内任务菜单 / 确认 PopupRoute 不算离页，详情 / 会话 PageRoute 入栈才使旧页面反馈失效。原操作正常完成，返回页面不重播旧反馈；App 路由注册、账号释放与独立宿主装配应共用同一观察器来源。


餐厅候选资格补充：品牌名搜索返回多家分店时，同样在数量上限前过滤无号；仅明确餐厅且相关命中唯一门店可保留无号说明。limit=1 不等于唯一命中。服务端负责资格和最终候选编号，客户端与历史消费同一事实，不能在页面二次筛选重排。

## 确认识别异常反馈

拨打确认回复保持原完整语义路径及scope校验。API兼容可选replyId与unavailable标记；同一次HTTP操作带独立replyId，传输重试可复用。识别失败/超时属于临时不可用，ConversationConfirmationFlow保持当前卡片并提示重试，不落成用户含糊答复的补充正文，不调用confirm。有效UNCLEAR/WAIT/QUESTION仍沿原补充流程，明确同意仍进入原准入/倒计时/拨打owner；记忆采用和保存确认保持独立。批量重拨来源和执行集合由服务端校验，客户端不另造任务身份。验证见openspec/changes/repair-batch-retry-confirmation。
