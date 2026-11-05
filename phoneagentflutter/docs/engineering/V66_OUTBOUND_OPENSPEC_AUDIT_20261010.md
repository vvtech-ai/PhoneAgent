# v66.0.3任务外呼OpenSpec与当前客户端复核

本轮按用户要求继续实施客户端差异修正，后端、数据库、服务部署保持只读。界面采用v66正式PureVoice链路；功能与接口采用最新独立App v71。不会把历史归档需求、演示页面或占位功能全部重新加入产品。

## 固定依据与阅读范围

| 仓库 | 只读远端快照 | 用途 |
| --- | --- | --- |
| 历史aiassistant | origin/test/v66.0.3@a0bedb12afd8aa47c82f70fe1e93bf034706f727 | 最终可达界面、任务/外呼OpenSpec、Skill原文 |
| 独立aiassistant-app | origin/v71@146152a22dc47d306e163753f2a395bd7d754b5c | 当前模型、ledger媒体补全、SDK监听票据与Runtime播放 |
| aiassistant-java | origin/v71@8ebd7db475e4c8b7cd873fc013667983f3bcab25 | 当前服务契约、Skill归属与后端缺口 |
| Flutter | codex/refactor-conversation-task-flow；基线origin/codex/dev@9a8d4e64 | 本轮唯一修改/交付分支 |

索引历史远端openspec全部2075个Markdown文件，筛出34个任务外呼能力的204份spec，另核对8个直接依赖能力的43份spec，共247份、671个Requirement实例，包含重复标题和历史修改/移除。按能力去重阅读要求与场景、核对相关change的设计及任务记录，再沿正式页面与请求链核对。完整Requirement标题/场景名称/来源路径及矩阵组索引见同目录V66_OUTBOUND_REQUIREMENT_INDEX_20261010.csv；这是追溯目录，不是671项真机验收完成证明。

## 当前客户端覆盖矩阵

路径均相对Flutter根目录；测试相对test/。下表“已覆盖”指源码和自动验证，真实服务/设备项目另列，不宣称全部运行验收通过。

| 组 | 要求与有效行为 | 当前实现及本轮处理 | 主要自动证据 |
| --- | --- | --- | --- |
| A01 | 首页发布配置、失败内置回退、Slogan进程快照、图标及入口显隐 | home/data、home/domain及Shell导航已覆盖；不增加配置失败提示、初始化设置页或Skill入口 | home_repository、v66_home_fallback_presentation、home_controller_failure、shell_navigation |
| A02 | Skill预选/开场/选中联系人仅首轮传递，国际号不进用户文案 | conversation_submission、AgentCommand；本轮home_config_mapper读取selectedContactOpening，contact_skill_opening优先当前模板、无模板保留v66三类原文 | contact_skill_opening_parity、skill_task_orchestration_parity、contact_task_entry |
| A03 | 去掉四阶段栏/顶部渐变；七段声纹、同排无底盘喇叭及关闭图标 | 共用ConversationHeader/状态行和Native图标资源已覆盖；设备级AI发声偏好复用原Controller | native_stage_bar、v66_conversation_header、task_voice_preferences相关测试 |
| A04 | 按住说话/向下箭头、短按引导、上滑取消；partial入框、撤销保留；TTS用暂停按钮 | voice协议、TaskVoiceGuideController、语音转文字草稿适配已覆盖；按用户要求不加“识别中”等额外说明 | voice/、voice_dock/及手动ASR定向测试 |
| A05 | 文字1–5行、回车换行、稳定焦点/键盘、85%编辑Sheet、收回保留光标 | 共用输入Dock/编辑Sheet和持久草稿已覆盖；无条件更换输入节点的问题此前已修复 | task_composer/、drafts/、composer相关测试 |
| A06 | 环境检测/重试、网络及服务异常按真实状态显示 | 原环境Controller及状态展示已覆盖；不固定延时伪造通过，不移植翻译本地SIP新流程 | environment及agent_context相关测试 |
| A07 | 餐厅/联系人候选详情、距离评分、地址/营业状态，不生成mock候选 | ConversationOptionContent/optionReply已覆盖；本轮标题及评分/距离单行，地址/营业两行省略，保留最终源码“未营业” | restaurant_option_card、option_reply及联系人选择测试 |
| A08 | ASK_USER用户自然回答，不新增表单/日期/选择/额外输入框 | 原pendingTool和普通message已覆盖，按用户明确取舍展示普通AI气泡 | natural_answer及ASK_USER测试 |
| A09 | 单/多路确认卡、双积分胶囊、卡后AI询问、呈现后本轮明确确认，沉默不拨号 | 原CallLaunchCoordinator/确认Policy已覆盖；PureVoice上限280、绿色渐变，无独立执行按钮；contactPhone保持用户指定旧逻辑 | call_confirmation、confirmation_prompt、conversation_call_flow、confirmation_billing |
| A10 | CONFIRM/EDIT/CANCEL/NEW_REQUEST/QUESTION/WAIT/UNCLEAR，补充事实原ledger幂等恢复 | 原ReplyCoordinator、SupplementOutbox及账号session归属已覆盖；部署接口另列后端确认 | confirmation/及supplement专项 |
| A11 | 停止任务在输入行；关闭观察不挂断；批量既有例外及禁止历史自动重放 | StopCoordinator、CallSessionController/ConversationCallController、Batch协调已覆盖；无第二状态机 | conversation_submission_gate、call_session、batch_stop及late-event测试 |
| A12 | 外呼头部按物理状态、接通前后分别MM:SS，模型和完整电话号码 | 本轮CallPresentation/ConversationCallController补接通中计时，首次CONNECTED归零，重复不重置；计时不参与计费 | conversation_call_timer、call_preview、conversation_call_flow |
| A13 | 当前监听SDK票据/Runtime签名WSS，物理CONNECTED后请求，首PCM接受后才播放状态 | 本轮Repository/提供器/媒体边界接最新App；8秒票据、10秒首音频、最多3次800ms重试，终态/离页/账号取消 | call_monitor_v71_parity、call_monitor_provider_contract、call_session_api及账号契约 |
| A14 | 听筒/外放预选、静音仍可切换、蓝牙及返回关闭本地播放 | 本轮解除仅playing可选限制，预选不启动监听；既有平台输出适配 | call_monitor_controller、call_pages、call_monitor_pages；两平台提供器合同 |
| A15 | 物理结束与业务成功分开，完成/失败/异常回执，转写不假造 | 原receipt投影与PureVoice结果卡已覆盖；本轮同attempt终态补全缺失callId/转写/字段/账单，持久状态/字段优先 | terminal_receipt_overlay_parity、reported_call_receipt_media、call_receipt_status/widget |
| A16 | 单路录音不额外依赖转写；每路有效身份、模型评价与固定任务评分锚点 | 原RecordingHost、Evaluation/TaskRatingRoute已覆盖，显式未接通隐藏；本轮终态补全使接口有有效身份可用 | receipt_recording_policy、recording/、feedback/、batch_receipt_media_parity |
| A17 | 单/多路积分快照、零扣费仍显示、失败有账单、余额千分位、不乘二次倍率 | 原billing投影/显示共用；本轮终态缺失时保留同通话已有账单，不猜积分 | call_receipt_billing_recovery、receipt_overlay、points/及batch_receipt_media_parity |
| A18 | 批量进度/每路结果、部分失败、重拨合并、各次结算、批次评分、CSV及模板 | 原Batch/Artifact投影和下载适配已覆盖；不按完成次序重排路序，不新增自动重拨 | batch/、artifacts/、batch_receipt_media_parity及下载测试 |
| A19 | 模型名称/说明以服务端为准，实际延迟、倍率、手动弹窗、选择防重 | 本轮modelId/activeModelId优先，appSubtitle兼容description，同provider多模型不误去重，移除硬编码推荐 | call_model_api/controller、native_model_card_semantics及latency测试 |
| A20 | 任务AI语音使用后端账号TASK_TTS，播放/静音/恢复不重放 | 既有SignedVoiceSocket/RuntimeTaskTts普通请求无preview目的；不新增任务声音设置面板 | task_tts及task_ai_speech、voice focus测试 |
| A21 | 订餐记忆首次询问实际展示才按账号记已询问，拒绝/忽略不保存不阻塞 | RestaurantMemoryOfferHost、SecureRestaurantMemoryAsked、AgentContextBuilder已覆盖；不读取我的身份或登录手机号，不创建专用记忆保存接口 | restaurant_contact_memory_offer/context/provider测试 |
| A22 | 统一15条分页，自动底部加载、防重/失败重试、置顶独立、乐观操作、原图标和菜单 | 现有TaskRepository/Controller/PresentationHost已覆盖；有效最终未读置顶仍可见；无置顶不显示收纳 | task_auto_pagination、task_pagination、task_action_overlay、task_pinned_visibility及mutation测试 |
| A23 | 原任务列表进入原会话，历史/翻译有效详情，恢复原session，失败可重试 | ShellTaskNavigation、History/ledger和TaskDetailController已覆盖；本轮timeline全部5xx保留失败/重试，不像最新App降为空历史 | task_detail_api/controller/route、conversation_navigation、api_history及task_entry_semantics |
| A24 | 普通消息复制、未发送草稿、账号切换、迟到/重复事件、返回共享刷新 | 原Store/Controller/订阅代际已覆盖；不复制旧巨型Android Root/ViewModel | copy、drafts、account/late event及notification/navigation测试 |
| A25 | SIP外呼、供应商转写/音色、工具/记忆规则、原子扣费、后端outbox与部署契约 | 后端职责，客户端只消费；见BACKEND_TASK_OUTBOUND_CONTRACTS_20261010.md，当前不能标为实际已对齐 | 合成契约测试不能代替真实生成/服务端运行证据 |
| A26 | 翻译/克隆/钱包管理/设置/日志上传等依赖规范中的无关功能 | 只检查本需求直接调用方，不同步业务模块或旧Android架构重构任务 | 全量回归覆盖直接共享代码；不新增这些模块功能 |

## 历史冲突裁决

- 旧spec的四阶段/渐变/独立声纹，按后续task-ai-speech-control及v66实际PureVoice入口删除；按住说话引导按最新正式规则，不恢复旧3秒延时。
- 通用Agent确认卡320与默认PureVoice280并存，本产品默认入口采用后者；胶囊白/绿、CLOSED“不营业/未营业”以最终正式源码为准。
- 早期置顶全部折叠、整页刷新，按最终未读可见策略和单项pin响应处理；旧双来源列表合并由当前统一分页接口替代，不建立第二列表。
- 联系人开场历史多次更改：保留v66三类正式文案；有最新v71后端模板时遵循模板，完整号码仍仅放独立selectedContact。
- 用户明确要求自然回答、TTS期间暂停按钮，覆盖历史表单或语音抢占要求；不顺手恢复这些额外控件。
- 任务评分使用最终固定首个合格锚点，拒绝旧任务/旧call回调；旧Result独立页面、回执复制/分享占位不可作为新增依据。
- 最新App将timeline全部5xx判无ledger并兼容，Flutter保留已有更严格的失败和重试；只有明确不支持/没有ledger的历史进入兼容视图。

## Skill核对与验收边界

远端只读逐行比较11个Skill文件：meeting-notification、meeting-notification-v2、event-invitation、batch-invitation、apology-master、parking-move、sales-recommendation、general-message-relay、hotel-booking、flight-booking在Java Agent与v66相同；restaurant-booking有9个差异行，属于后端记忆和无需预订规则。本轮不增加这些Skill的新入口，能否开放仍由首页发布配置决定。

客户端差异已实施，不代表真实转写、录音、评分、账单、记忆或监听均已正常。Android安装前次被系统中止，本轮新包与验证结果另记；Windows无macOS/Xcode/iOS真机构建条件。后台、真实电话、供应商音色和生产升级保持待验，不归档。详细验证见V66_OUTBOUND_VALIDATION_20261010.md。
