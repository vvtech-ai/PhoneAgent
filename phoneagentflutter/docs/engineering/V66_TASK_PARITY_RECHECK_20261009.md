# v66.0.3任务范围再次复核

基准为只读远端快照`origin/test/v66.0.3 a0bedb12afd8aa47c82f70fe1e93bf034706f727`。只核对首页任务入口、统一对话、任务列表与直接关联历史/恢复、通话结束展示。Android源码路径相对`android/app/src/main/java/com/vvtech/aiassistant/`。不能以旧演示文件存在判为正式缺口。

## 本轮发现及已补齐

| 差异 | 正式源码依据 | Flutter修正与自动证据 |
| --- | --- | --- |
| 头部仍显示旧四阶段栏 | `assistant_singleflow/SingleFlowNativeContentShell.kt`调用`assistant/SingleFlowConversationContent.kt`的SingleFlowHeader，只有品牌、关闭与语音状态；未调用旧阶段栏 | 共用ConversationHeader删除阶段文字/进度条；native_stage_bar/conversation_progress_widget测试覆盖普通、紧凑、大字体及两平台主题；任务实际状态仍由既有事实决定 |
| 会话列表多插入“任务详情”页 | `assistant/FinalTaskPageItem.kt`直接onOpenConversation(session)；`AssistantNavigationPolicy.kt`将Result重定向到统一对话 | ShellTaskNavigation的会话任务直接restore原session；无session历史/翻译保留原详情。task_entry_semantics、conversation_navigation及相关Shell跨页测试证明防重、返回列表、终态仍可输入、历史无工具重放 |
| 普通文字复制未采用v66完整消息操作 | `assistant_conversation/MessageCopyPolicy.kt`、CopyableMessageContainer、V67MessageCopyMenu；只复制完成的普通用户/助手文字 | ConversationCopyMenu接系统Clipboard，复制完整原文；流式当前回复、notice、工具/附件/回执卡不提供该菜单。两平台主题复制/流式禁止测试通过；真实iOS剪贴板待设备验收 |
| ASK_USER自然回答（用户最新取舍） | 原pendingTool身份及当前AgentService.run normalizePendingAnswer | 已撤回额外表单/选择/日期控件，问题复用普通气泡，通过原文字/语音message回答；自然回答历史/恢复/防重测试 |

此前结构化answer_questions迁移记录已被用户明确取舍覆盖；当前自然回答由原pendingTool及普通message承接，不新增独立回答输入框。旧接口存在不等于本批新增控件的依据。

## 范围内其余正式能力复查

| 能力 | v66依据 | 现有Flutter承接/验证 |
| --- | --- | --- |
| 首页卡片可用、版本、显隐与排序 | assistant_home/HomeCardEntryDispatcher、domain/HomeCardPreferencePolicy/HomeConfigPolicy | 首页Repository、实际安装版本端口、账号偏好和统一导航；失败、配置变化和账号迟到测试 |
| 首页通知进入任务及已读 | assistant_shell导航及任务刷新/已读效果 | 首页通知共享任务投影、返回刷新，沿用原已读接口和账号代际 |
| 餐厅/联系人选项及文字/语音继续 | SingleFlowConversationContent、session选择策略 | 既有OptionsCard、optionReply、联系人工具协调；原pending身份继续，Shell选择及联系人恢复测试 |
| 外呼确认、提问、等待、修改、取消、新需求、含糊 | assistant_session/CallConfirmationReplyCoordinator/ConversationCallConfirmationHandler | 确认Policy/Flow、当前卡呈现门禁、1500ms可取消准入，七分类专项；不自动拨号 |
| 展示补充问答及保存失败重试 | assistant_session/CallConfirmationSupplementSteps及历史补充接口 | 同ledger补充事件、账号/session outbox；重复/迟到/失败/重进测试；Java新增接口真实部署待验 |
| 普通停止与批量确认、部分失败 | assistant_agent/AgentTaskStopCoordinator及批量停止接口 | 原StopCoordinator/Binding，关闭不挂断；停止后工具失效、timeline终态与重试测试 |
| 未发送文字退出恢复、提交失败保留 | local/taskdraft/TaskDraftStore、TaskDraftShellEffect | SecureTaskDraftRepository/Controller；账号/环境/session、迟到读取与提交接受专项 |
| 任务播报开关、按住/短按/取消引导 | local/speech/TaskAiSpeechPreference、assistant_voice/VoiceGuidePolicy | 原语音Controller加设备偏好/Guide；有效时间戳、取消、后台暂停规则、失败重试测试 |
| 权限/通讯录查询、文档/OCR输入 | AgentResult的有效工具及统一对话Host | 复用既有Tool/Action/Attachment协调器，补统一请求签名；Shell权限、查询、文档恢复证明不自动重放 |
| 模型与计费确认快照 | SingleFlowComposer及TaskCallConfirmationBillingSnapshotPolicy | 既有模型选择、原准入/计费展示；当前任务确认/恢复测试，不改积分业务 |
| 单路/批量实时进度、物理结束、最终结果 | SingleFlowConversationContent、session终态及CallResult卡 | 原Call/Batch/Receipt投影，物理结束释放输入；SSE完成不假报成功，attempt/command隔离 |
| 录音播放保存、AI评价及用户评分 | SingleFlowConversationContent调用AgentCallEvaluationRoute/TaskRatingCallRoute及批量对应路由 | 既有RecordingHost及CallEvaluationRoute内TaskRatingRoute；Shell录音取消、单/批回执评分与草稿专项 |
| 模板与批量CSV下载及打开 | assistant_artifacts/ArtifactDownloadCoordinator/PureVoiceArtifactCard | ArtifactProjection/Card/DownloadController与双端文件端口；类型/大小/401/取消/防重专项，实际系统Files待验 |
| 统一分页、置顶、折叠、未读与删除限制 | assistant/FinalTasksPage、assistant_tasks分页/菜单/置顶可见性策略 | 当前统一15条分页与服务端排序，Repository/Controller/PresentationHost；无置顶不显示折叠入口，未读不隐藏；定向竞争/操作测试 |
| 历史加载、详情内容、恢复原身份 | session/AssistantConversationRestore*及FinalTaskPageItem | 原History/ledger、网络失败可重试，仅明确无ledger兼容；终态可进入原会话，历史不自动权限/上传/外呼 |
| 普通退出、账号切换、迟到与重复事件 | 原session/stream归属与取消gate | 保留当前更严格账号/session/command/attempt隔离；退出订阅释放、批量已有例外及定向回归 |

## 不应新增的旧文件能力

- TaskReceiptCopyButton的`TaskReceiptCopyButtonsVisible=false`：不新增回执复制图标；普通消息复制与它不同。
- 独立AssistantFinalResultPage的分享/AI建模按钮：Result正式路由被重定向，分享回调仍占位，不新增该页面。
- 记忆、翻译业务、克隆、积分及通用设置仍不在本次扩展范围。任务已有翻译详情仅保留直接接线。

## 验收边界

实现和Android/iOS共享主题测试不等于双端设备验收。Android设备使用隔离MOCK账号和内存端口，不证明生产接口、真实电话或媒体成功。Windows没有macOS/Xcode/iOS设备；iOS构建、Files、剪贴板、键盘/后台及升级必须另验。当前Java确认分类/补充接口、C1配置和供应商能力仍需真实部署联调。

最终全量、Android最新截图及分支交付证据统一更新到`V66_TASK_PARITY_VALIDATION_20261009.md`，未经用户验收不归档。

历史设备记录曾验证结构化问卷；当前已改为自然回答并另行重验，见最新验证文档。旧记录不代表当前产品入口。
## 最新列表与任务记忆补齐（2026-10-09）

| 本批能力 | v66最终源码依据 | 实现与边界 |
| --- | --- | --- |
| 列表标题与时间 | TaskPageRows、TaskDisplayTextPolicy、TaskDisplayTimePolicy、FinalUiHelpers | 按session补activeSkillTitle，仅改变展示；普通任务第二行为createdAt相对时间，翻译保留原标题/直接详情，不增加任务行 |
| 首载、分页、置顶、未读 | assistant-task-list-r20-r33、AssistantTaskPageComponents、TaskPinnedUnreadVisibilityPolicy | 首载居中28dp进度；四种分页文案；折叠控制位于置顶与普通项之间，未读置顶保持可见；清未读/置顶/删除/折叠采用原XML路径 |
| 长按菜单 | TaskItemActionMenuHost/Policy | 选中行克隆、背景模糊、260dp菜单及原删除/拨打中提示；关闭保留滚动位置，两平台小屏测试 |
| 置顶与清未读 | 后续单项pin响应及最新未读规则 | 已有Repository/Controller乐观调整、目标DTO合并、失败回滚与分页游标；不整页重载，清未读即时投影，竞争测试保留原未读状态 |
| 可见最终结果标读 | TaskResultReadPolicy、FinalTaskResultReadEffect | 独立可见性Host及确认 owner；前台当前账号/session最终回执才调用read，SSE结束/物理挂断/离页迟到结果不标读 |
| 首页失败 | DefaultHomeConfigRepository、HomeConfigFallbackPolicy、FinalHomePage | 移除新增失败提示块，仍使用内置卡片和原下拉刷新，内部loadFailed不伪造成功 |
| 任务AI语音 | TaskVoicePreferenceStore、TaskVoiceReplySnapshot；当前Java TaskTtsVoicePreferenceService | v66默认请求Maia；当前v71独立任务TTS配置优先，不以preview绕过。Maia/Andre选择入口在旧设置页，本批不新增任务内选择入口，设置暂不动 |
| 联系人确认及记忆 | restaurant-contact-memory、RestaurantContactMemoryAskStore/OfferPolicy、FinalRestaurantContactMemoryOfferEffect | 当前任务原ASK_USER自然回答；新增账号级已询问标记并随每轮传递。记忆开关/快照/同意后的manageMemory由既有Java负责，不自动读取或回写我的身份/登录手机号，不新增表单或记忆管理页 |

冲突处理：早期“折叠所有置顶”和“置顶整页刷新”以最新有效未读可见及单项响应替代。旧默认本地Maia/Andre与当前服务端任务TTS模型/音色配置不同，保留当前后端有效契约；设置迁移另行处理。当前v71已包含餐厅联系人提示词和通用记忆工具，无须改Java或数据库。纯v71确认分类/补充接口缺口仍保留，不因本批通过抹去。

“我的身份”设置入口隐藏与任务内联系人是两个来源：当前后端agent-execution要求联系人来自本任务明确输入/选择，并禁止读取或回写身份资料；用户记忆只提供建议，本任务指定的信息优先。存储仅含已询问布尔值。Android旧SharedPreferences标记的生产升级迁移、本机真实记忆写入与iOS实机均未验证。