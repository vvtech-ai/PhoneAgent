# 有效页面与连续交互覆盖表

2026-09-22；交接核对基点5351d75，各专项报告保留自身提交与验证日期。功能范围仍以[MIGRATION_BASELINE](../requirements/MIGRATION_BASELINE.md)为准；视觉精校按用户批准后置。本文是页面及验收索引，不能单独充当通过证明；当前基础迁移结论、源码与83项定向收尾证据见[目标交接核对](MIGRATION_GOAL_AUDIT_20260922.md)。下方日期段落是历史阶段记录，旧“仍待登录”等描述由主清单最新事实覆盖。

## 2026-10-09 初始化固定原生配对与共同布局增量

| 范围 | 实现与验证 | 仍待完善 |
|---|---|---|
| 模型卡 | ba22d94共同紧凑整卡及具名选中；3507880同步固定原生Qwen/Seeduplex能力说明，未知/V3不推断、重复描述只显示一次；最新初始化及两步Shell45项5秒、analyze4.9秒 | 真实目录、音色/克隆与服务端保存；展示标签不等于克隆许可 |
| 顶部与字段 | 0355f85标题居中/完整48热区及大字，c152e7f浅边框/蓝选中焦点/统一占位；实际合成12位电话截11位，返回草稿姓名/女/电话保留 | 中文IME、真实读屏及Android完整运行；48热区相对UIKit36/42/44为明确适配 |
| 固定UIKit对照 | e7d4490四范围原始字节SHA及独立无服务宿主；最新同合成目录两端能力说明与选择实际PNG、domain/policy SHA吻合 | 三行卡span261/257物理像素约1.3点高差及约2点位置差、系统字形；未标整页V通过 |

原始图位于ignored的`.local/ui-reference/ios-initialization-reference`，明细见[活动任务](../../openspec/changes/native-ui-interaction-parity/tasks.md)。只运行独立纯UI身份，无SDK/真实认证/短信/外呼，当前增量不能用历史冻结3658/1宣称新的全量。

## 2026-10-09 联系人备注及拨号完整流程增量

- `8bae721`修复备注重复编辑入口及旧编辑器取消/保存/输入污染：8项问题先复现，备注/删除/提示邻接39项通过，保存忙态及正式联系人Shell最终13项通过（范围重叠，分别计数）；analyze3.7秒。实际iOS取消→重开→合成输入→保存回详情已复验。
- `2062317`实际备注取消不保存、保存后列表重入保留、删除确认取消不改内容；`2eb2fcf`实际拨号123→国家搜索65→新加坡选中/重入→删除一位12→对方日语→提示返回→关闭翻译拨号回普通拨号→关闭回联系人→重开保留12/+65。
- 原始图在ignored的`.local/ui-reference/ios-contact-remark`与`ios-dialer-country`；只独立纯UI内存端口，未删除备注、读取真实通讯录、拨打电话或初始化SDK。真实服务/全国家语种目录/跨进程偏好、双端原生整页配对仍待验，不以正常点击替代旧回调竞态测试。

## 2026-10-09 登录初始化、身份及评分最新增量

以下增量已保存至`codex/dev_zys`；历史全量冻结2b0c43f的3658通过/1跳过不包含这些修改，各批定向分别计数，不合并成新的全量结论。

| 共用业务 | 已实现及实际iOS正常流程 | 尚需完善/验收 |
|---|---|---|
| 登录与两步初始化 | e25f8bb独立未登录演练；错误验证码留登录、合成登录、身份跳过与填写、模型返回保留草稿、完成首页；a6133f8协议唯一具名勾选、性别/模型具名选中与忙态禁用，42项定向/分析通过 | 真实短信/账号、服务端保存、双端系统键盘与读屏、固定原生整页配对；合成协议动作不接受真实服务条款 |
| 模型与系统音色 | 9129fd9实际Qwen音色Andre→Ethan、关闭回传；Seeduplex选择、音色取消、设置摘要×2.0及重入保持 | 真实目录/音频/偏好持久化；演练单voice与非活动卡默认摘要不证明每模型持久保留 |
| 身份编辑 | 4f388ca性别单节点selected/enabled/tap，27项定向/分析通过；实际选中→取消恢复→保存回设置→重入回显；初始化姓名Synthetic UI/女回显 | 真实认证/SDK/克隆音色清理与文件/账户联调，完整原生视觉 |
| 评分与回执 | 9701aae弹层/成功独立一次性返回，最新saving门禁、旧入口禁止叠加成功反馈；34项定向/分析通过；实际草稿关闭重开、失败重试、完成回来源、只读查看再关闭 | 真实评分/奖励/音频及跨进程恢复；旧回调竞态由专项测试证明，不能用单次平台点击冒称实际竞态验收 |

原始运行图分别保存在ignored的`.local/ui-reference/ios-shell-login`、`ios-onboard-selection`、`ios-identity-gender`、`ios-rating-return`及`ios-model-selection`，执行细节和真实IO边界见[活动任务](../../openspec/changes/native-ui-interaction-parity/tasks.md)。全部使用独立纯UI身份，无普通App替换或可信SDK初始化；Android普通数据未动。SDK已复制入工程并从指定原生读取私有配置，安全模型短期配置及真实测试条件仍独立待补，详见[国内联调缺口](DOMESTIC_TRANSLATION_INTEGRATION_GAPS_20261008.md)。

## 2026-10-09 当前连续补验索引

本轮新增实际Web补验覆盖P01–P08a/P09、P11/P13/P14/P16/P17/P19–P26/P29及可信来电不可用返回边界。范围是工程自带合成端口，P08/P09/普通对话部分历史来自同内存会话事件，P17翻译详情仍为静态种子；不证明真实上传、电话、积分、磁盘恢复或双端原生全流程一致。字幕/回执文本语义、原声滑块名称、中性不可用提示、身份/克隆输入名称、克隆试听单节点、邀请码可读文本及外呼表单共同样式已修复，详情见[当前业务补验台账](NATIVE_FEATURE_PARITY_MATRIX.md#2026-10-09-共用业务连续交互补验与修复)及[执行任务](../../openspec/changes/native-ui-interaction-parity/tasks.md)。

后续增加身份编辑放弃/保存自动返回、纯模拟克隆至完成、开发者拨号串与号码草稿/保存、JP/Gemini强制开关返回重入、手动日志上传失败和只清理恢复、邀请复制与海报取消。克隆输入、试听和邀请码均有双端语义定向测试；外呼共同样式有短屏/两倍字与共用标题相邻验证。纯Shell成功提示不代表真实SDK/上传/电话/积分或相册成功，正式平台V仍未关闭。

截图条件已逐项记录：旧完整Shell流程414×800，新标签早期1280×720，后续mobile原图明确414×800；截图文件扩展名不替代实际格式/尺寸。合成语种缺字、两端系统键盘/读屏/手势和真实服务验收仍待，不能将本文下方历史“Web通过”理解为所有最新页面/状态已通过。

## 2026-10-09 iOS联系人及翻译历史补验

P11/P13：实际备注具名输入及取消；五个Skill具名按钮→联系人上下文会话→关闭详情，正常弹层关闭也只回详情。旧回调重复pop及两次await账号变化由9df9db0双平台专项验证，不冒称实际设备竞态。平台输入未生效，不将Widget语义编辑当真实键盘保存。

P21：c154499同模拟器固定iOS实际语种页与生产Flutter选择页，中文初始→日语返回→重新进入选中→取消保留，两侧正常64行；Flutter48返回相对原生42热区保留6点差异，动态字/完整三端仍待。

P17：e8f15f8修合成第二条时间10:30一致；d32501a正式历史入口独立加载/播放/保存失败场景实际重试，取消不报成功、确认才模拟保存，关闭重入无旧反馈，字幕保留。音频/导出均内存端口，无声音/磁盘/真实后端；合成processing已实际AX加载/禁用→ready，短暂状态未留PNG；Android连续错误与真实声音/保存仍待。

P16/P17最新展示续批：22b7b2e共同记录日期及851157c两个正式页星期/跨年实际进入返回；af12cc6/1a2f1fe标题号码同列、明确行高/字距，3f7352e固定UIKit纯展示对照，第一蓝字幕正常同561–794。88cd44d统一平面气泡，149f9ac系统字体回退宽度已量化未假称消除。2f17988两倍字实际显示关闭；f24be67/b906d2f空字幕固定字节配对及行高修复，仍2物理像素基线差。8e6a0b0初次加载/失败UI，2b0c43f两侧实际合成重试到内容、加载/等待中关闭不复活，Flutter大字亦核验。此为展示部件+本地宿主流程，按钮48热区与UIKit36、SafeArea center差异保留，不是原controller/后端/真实录音验收。

详见[最新业务实施表](NATIVE_FEATURE_PARITY_MATRIX.md#2026-10-09-联系人与翻译历史最新实施证据)与[执行记录](../../openspec/changes/native-ui-interaction-parity/tasks.md)。此增量不改写历史全量冻结和真实能力待验。最新跨模块冻结2b0c43f默认全量3658通过/1跳过（7分10秒），显式UI_AGENT_DOCUMENT及UI_DOCUMENT_PARSE_DELAY_MS=10000专项2通过（3秒）；二者范围分别保留，不代表真实后端或SDK验收。

## 2026-10-05 新版原生差异索引

下表只建立追踪关系，不修改下方9月历史验收结论。新版来源、入口调用链、实现状态、六类场景及平台配置见[原生功能对齐台账](NATIVE_FEATURE_PARITY_MATRIX.md)。旧页面已实现不等于新版能力全部对齐；新增NF编号不是已经交付的新页面。

| 原页面编号 | 新版业务编号 |
|---|---|
| P01 | NF01、NF27、NF30 |
| P02 | NF02 |
| P03 | NF03 |
| P04/P05 | NF04 |
| P06 | NF05、NF06、NF15 |
| P07 | NF05、NF07 |
| P08/P08a | NF08 |
| P09 | NF09 |
| P10 | NF10 |
| P11/P13 | NF11 |
| P12/P14/P15 | NF12 |
| P16 | NF05、NF13 |
| P17 | NF13、NF16、NF27 |
| P18 | NF14 |
| P19 | NF15、NF36 |
| P20 | NF16、NF17、NF27 |
| P21 | NF18 |
| P22 | NF19 |
| P23 | NF20 |
| P24 | NF21 |
| P25 | NF22、NF28–NF31 |
| P26 | NF23、NF27、NF37 |
| P27 | NF24 |
| P28 | NF25、NF27 |
| P29 | NF26 |
| 原覆盖表未单列 | NF28–NF31邀请；NF32国内SIP；NF33可信来电；NF34 Live Activity；NF35后台/中断；NF36任务产物；NF37关于/账号；NF38待核实入口 |

当前仍有两步初始化、iOS仅App通话记录、无匿名导出等用户决定；国内SIP/可信来电由旧排除进入新版后续设计，不把此索引视为已经接入。iOS“注销”仅signOut、首页快捷输入与手动更新入口待核实，详见台账。

## 邀请功能接入更新（2026-10-05）

P25钱包已增加邀请入口；NF28活动/码/记录、NF29复制/海报、NF30欢迎/链接/注册归因、NF31奖励通知已接入。P01保留普通登录，新增稳定注册请求标识和结构化错误；P25仍以服务端余额为准。共享协议/登录恢复/窄屏页面/存储隔离等定向验证见[邀请实施证据](INVITE_PARITY_VALIDATION.md)。Android/iOS构建与真实系统唤起/相册/注册到账分别记账，不用客户端配置代替域名验证。

## 如何判断覆盖

当前结论统一见[集中验收主清单](MIGRATION_HANDOFF.md)，该文档已按e4c2f77当前接线整理，不再从本页历史“仍待登录/匿名导出”派生任务。新增[Agent文档iOS四点](AGENT_DOCUMENT_VALIDATION.md)通过；Android增量组因启动/附加策略限制未运行。正常main的Android Profile已知演练标记检查通过，见[产物边界](RELEASE_PREVIEW_BOUNDARY_VALIDATION.md)，不是新设备或全路由验收。

2026-09-21 14:46新增[Android真实登录/文字与确认卡阶段](ANDROID_LOGIN_CONFIRMATION_STAGE_20260921.md)：登录冷启动复用，无SMS；普通App真实两轮文字→任务恢复→阶段覆盖后再次恢复历史通过。confirmation与iOS同组六点32秒通过，9预检、禁止端口0调用、两份安全偏好摘要不变。补齐本组Android证据，不扩大为其余平台步骤全部通过。

2026-09-21新增[iOS确认卡阶段](IOS_CONFIRMATION_STAGE_20260921.md)：ec643d5上独立53–58六图/29秒，普通卡换模型后恢复、批量联系人展开/收起及恢复后文字确认通过；9项相关预检和analyze通过。仅内存业务端口，Android当前版本、真实持久化与生产升级仍独立待验，不重跑此前52图。

2026-09-21新增[iOS两步初始化阶段](IOS_INITIALIZATION_STAGE_20260921.md)：6c30648基点独立47–52六图约9秒，填写/返回保留/选择模型/完成与空身份跳过均直接进首页，无翻译配置和重复保存。13项相关预检/analyze通过；仅内存业务端口，不证明设备冷启动持久化、Android或真实身份认证。

2026-09-21新增[Release演练边界核验](RELEASE_PREVIEW_BOUNDARY_VALIDATION.md)：正式附件结果处理器补编译短路，开启/关闭配置各10项连续定向通过；正式main Web Release的11个已知演练标记均移除、8个保留入口正向对照存在。仅产物/指定流程证据，不等于原生Release或全路由已验。

2026-09-21新增[iOS键盘布局阶段](IOS_KEYBOARD_STAGE_20260921.md)：fc0e679上独立43–46四图/12秒，真实系统键盘占位260px时输入/发送可达，收起为0，关闭→任务恢复不重发。应用窗口截图不含系统按键层；不证明IME组合输入、系统返回或Android键盘。普通iOS测试包已恢复，无SMS，不重跑旧42图。

2026-09-21新增[真实Web文字阶段](WEB_REAL_TEXT_STAGE_20260921.md)：83e8dc6加本批提示修正，8080同源登录自动恢复，真实两轮文字→退出→任务恢复→续聊及再次整页刷新恢复通过，不使用MOCK、不发短信或外呼。原音页过期提示同步修正，8122开关/比例/重进另用隔离内存验证。Android登录和双端阶段仍独立，不从Web结果推定完成。

本轮iOS独立新增开发者33–38六个检查点约60秒通过，见[开发者小阶段](IOS_DEVELOPER_STAGE_20260921.md)；不是把旧32图改写为本次38图全跑。4专用预检、4完整前序兼容预检及5驱动保护通过，后续可按组执行，避免重复整套页面。

- **正式接线**：从AuthRoute/ShellRoute及其实际下级入口追踪，不把旧代码、独立Preview或目录卡片数量当产品页面。
- **连续证据**：从实际入口操作到返回/恢复；单页测试不能替代。下表“验证入口”指可复用的专项/测试位置，不表示本轮重跑或所有断言已满足。
- **增量实测**：联系人链路后已补[文档/OCR连续链路](ATTACHMENT_CONTINUOUS_VALIDATION.md)；其余保留既有证据，不借定向测试声称全部页面、真实接口或真机已通过。
- **双端**：Android已验21截图；iOS最新32截图/33步骤，增加拨号/翻译及单路通话/日志，见[最新iOS记录](IOS_CALL_LOG_STAGE_20260921.md)。共同的原模型/文字恢复/两历史/设置、P11备注、P12拨号回填、P19批量回执、P20评分、P23身份查看、P24合成克隆及P25钱包见[扩展记录](EXTENDED_DEVICE_STAGE_20260920.md)。只覆盖报告列出的状态和提交，不标整组或当前版本全通过。

## 从正式入口展开

| 编号 | 入口 → 页面或交互面 | 当前实现／验证入口 | 仍需的连续或平台证据 |
|---|---|---|---|
| P01 | 启动 → 登录、验证码、邀请码、恢复失败重试 | AuthRoute/AuthPage；[登录](AUTH_WEB_VALIDATION.md) | 安卓09-21冷启动和测试阶段后登录复用已确认，无SMS；iOS真实登录独立，不能自动沿用安卓证据 |
| P02 | 登录后 → 首次身份初始化 | AuthRoute→InitializationHost→身份→通话模型→首页；[初始化](INITIALIZATION_VALIDATION.md) | 用户确认两步；正式App隔离Web填写/返回/选模型/完成与跳过通过，50项相关定向通过；不设置翻译模型，双端真实存储待验 |
| P03 | 首页 → 动态Skill卡、不可用入口、积分摘要 | ShellRoute/HomePage；[连续测试](../../test/shell_workbench_test.dart) | 真实首页配置/空错态、完整双端扩展检查 |
| P04 | 首页或对话模型按钮 → 模型选择浮层 | CallModelsPage，正式Provider共用；[模型](HOME_MODEL_VALIDATION.md) | 模型服务和实际通话消费集中验收 |
| P05 | 设置 → 模型列表 → 音色／试听／克隆管理 | CallModelsPage/CallVoicesPage；[克隆连续测试](../../test/shell_clone_workbench_test.dart) | 真音频/真实模型资产，双端更广覆盖 |
| P06 | 首页Skill → 统一对话 → 按住／文字切换／退出 | ConversationRoute/Page与VoiceHost；[语音输入](VOICE_INPUT_VALIDATION.md)、[文字连续](../../test/shell_workbench_test.dart)、[确认卡计费](CONFIRMATION_BILLING_VALIDATION.md) | 普通卡历史费率/换模型/恢复及扩展batch-plus结构/联系人展开/决策更新/恢复续聊均已Web及定向验证；新增卡片同版本双端、真实升级和麦克风/ASR/TTS集中验，不恢复旧独立模式 |
| P07 | 对话 → 补问、候选、工具进度、权限工具 | 正式ConversationPage及工具Host；[权限](PERMISSION_TOOL_VALIDATION.md)含完整App三种结果→退出恢复→续聊的定向验证 | 复杂工具真实后台收件、系统授权另验；样例不当真实执行 |
| P08 | 对话添加 → 文档选择／解析／直接发送／取消 | openConversationAttachments/DocumentImportSheet；[连续证据](ATTACHMENT_CONTINUOUS_VALIDATION.md) | 完整App合成导入→历史恢复已验；真实文件/后台上传另验，独立文档演练仍不提交对话 |
| P08a | Agent索要文档 → 单选／解析／取消结果 → 继续文字 | ConversationActionFlow/AgentDocumentHost；[专项](AGENT_DOCUMENT_VALIDATION.md) | 正式Route/Provider已接，62项相关回归及Web成功/取消/继续通过；iOS四点MOCK真机通过，Android对应阶段未跑，双端真实系统选择/后台收件待集中验收 |
| P09 | 对话添加 → 相册／OCR处理／只读结果／长文展开收起 | ConversationOcrHost及正式附件控制器；[连续证据](ATTACHMENT_CONTINUOUS_VALIDATION.md) | 合成选图→文字携带上下文→历史恢复及续聊已验；无额外确认步骤，真相册/OCR留平台验收 |
| P10 | 对话工具 → 选联系人／号码查询 | 共享PhoneContactLookup/NameContactLookup；[连续测试](../../test/shell_contact_tools_workbench_test.dart) | 完整App号码/姓名自动续接→候选→退出任务恢复→选择已在Web及两宽定向通过；真实OS通讯录/授权、后台结果与ASR姓名输入仍待集中验收 |
| P11 | 联系人Tab → 列表 → 详情 → 备注编辑／保存／取消 | ContactsRoute/ContactDetailPage/ContactRemarkEditor；[本轮测试](../../test/shell_contacts_workbench_test.dart) | **本轮Web及两宽定向通过**；真实OS权限/通讯录与备注API另验 |
| P12 | 联系人详情 → 拨号回填／国家 → 系统交接 | showContactDial→DialerRoute；同上测试 | 本轮合成系统端口计数通过，无真实电话；系统交接另验 |
| P13 | 联系人详情 → 动态Skill → 对话 → 任务恢复 | showContactSkills→正式ConversationRoute；同上测试 | **本轮Web连续通过**；首轮selectedContact且恢复不重发由定向断言；后台上下文另验 |
| P14 | 底部拨号 → 区号搜索、号码、T9、最近记录 | DialerRoute/DialCountryPage及共享Host；[拨号](DIALER_VALIDATION.md)、[最近](DIAL_RECENT_VALIDATION.md) | 系统键盘/拨号/Android CallLog；iOS仅App记录 |
| P15 | 拨号／翻译 → 位置说明、权限、设置返回 | DialPermissionHost及共享控制器；[权限顺序](DIAL_PERMISSION_VALIDATION.md) | 双端实际拒绝/设置返回/首次顺序；不能批量伪造授权 |
| P16 | 任务Tab → 列表 → 会话恢复／其他记录 | TasksPage、ShellRoute._task；[对话历史](CONVERSATION_CORE_VALIDATION.md) | 终态会话仍可恢复；无会话普通记录走新统一页，不复制旧详情页 |
| P17 | 任务Tab → 翻译历史 → 录音播放／保存 | TranslationHistoryRoute/Page、RecordingAudioRoute；[连续测试](../../test/shell_history_workbench_test.dart) | 既有Web/双端MOCK证据；真实文件/音频/后台记录另验 |
| P18 | 对话单路执行 → 通话页 → 监听／音源／挂断／返回 | ConversationCallHost/CallSessionPage；[完整App连续证据](CALL_CONTINUOUS_VALIDATION.md)、[iOS阶段](IOS_CALL_LOG_STAGE_20260921.md) | Web和iOS已验入口→监听/音源→挂断→任务恢复→续聊，普通返回不挂机有定向断言；真实电话/媒体/回执及本链路Android阶段仍待 |
| P19 | 对话多路 → 逐项进度／回执／恢复 | 统一页批量控件，不进入单路页；[批量](BATCH_FLOW_VALIDATION.md) | 批量后台结果/计费/旧任务恢复集中验收 |
| P20 | 回执 → 录音、赞踩、eligible条件评分、成功只读 | ConversationRecordingHost/CallEvaluationRoute/TaskRatingRoute；[连续证据](RECEIPT_CONTINUOUS_VALIDATION.md)、[旧评分草稿导入](LEGACY_RATING_DRAFTS_VALIDATION.md) | 完整App合成任务恢复→录音→赞踩/条件评分→跨任务草稿→失败重试/只读已验；旧草稿导入共享/原生合成验证及Android编译通过，真实升级、音频/保存/后台奖励及双端扩展另验 |
| P21 | 首页翻译／拨号切翻译 → 国外配置／语种／模型 | TranslationDialerRoute/SettingsRoute/LanguagePage；[连续测试](../../test/shell_translation_workbench_test.dart) | 实际可信位置/准入/模型可用性；无国内App SIP |
| P22 | 翻译配置 → 通话 → 字幕／静音／音源／DTMF → 结束回流 | TranslationSessionRoute/CallPage及Finished绑定；同上测试、[归档](TRANSLATION_FINISHED_VALIDATION.md) | 共享Web闭环；双端真实声音/路由/回退/后台归档集中验收 |
| P23 | 设置 → 我的身份 → 编辑／保存／删除／失败恢复 | IdentityRoute/Page；[身份清理](IDENTITY_CLEANUP_VALIDATION.md) | 真实身份服务与删除后设备存储；不自动采集身份 |
| P24 | 身份／音色 → 克隆创建 → SDK核验 → 录音候选 → 保存 | CloneCreationRoute/FlowPage/EnrollmentPage；[连续测试](../../test/shell_clone_workbench_test.dart) | 真实SDK、释放、服务端PASS、收费及录音集中验收 |
| P25 | 首页积分 → 钱包 → 积分流水 | PointsWalletRoute/WalletPage/LedgerPage；[钱包](WALLET_FEEDBACK_VALIDATION.md) | 服务端激活/余额/流水与跨进程恢复；无充值支付入口 |
| P26 | 设置 → 原音参数／退出确认 | SettingsRoute/OriginalAudioPage/logout dialog；[连续测试](../../test/shell_workbench_test.dart) | 双端实际保存和新翻译消费；模拟退出不等于真实登录恢复 |
| P27 | 设置 → 日志准备／上传／失败重试／清理失败 | LogReportRoute/Page；[完整入口增量](LOG_REPORT_VALIDATION.md)、[iOS阶段](IOS_CALL_LOG_STAGE_20260921.md) | 完整App Web及iOS准备→上传失败重试→仅清理重试→返回重进已验；Android阶段/真实收件待验，匿名本地导出已由用户撤销。Android managed异常、共享租约/ASR/TTS/PCM及翻译双媒体诊断已接，不重复列为未实现 |
| P28 | Android设置或启动 → 更新检查／下载／权限／安装 | AppUpdateRoute/UpdateInstallRoute/StartupUpdateHost；[OTA](OTA_INSTALL_VALIDATION.md) | **正式签名及完整旧状态/降级未完成**；iOS无OTA，不能取消保护直接交付 |
| P29 | 拨号暗号 → 设置开发者 → 外呼号码／网络／列表／位置／翻译配置／权限重置 | DeveloperToolsRoute及子页；[连续测试](../../test/shell_developer_workbench_test.dart)、[iOS小阶段](IOS_DEVELOPER_STAGE_20260921.md) | Web既有连续证据；本轮iOS暗号/号码失败重试保存取消删除/列表/权限重置返回/断网门禁/退出取消通过，真实系统来源/后端号码及Android对应阶段另验，不代表每个开关都操作 |

## 本轮联系人断点及证据

修复前：Web完整App已注入联系人端口，ContactsRoute却按kIsWeb切入另一个PreviewContacts和ContactTaskRoute，用户必须另点演练，任务不会出现在完整App列表。单纯VM测试走手机分支不能覆盖这个Web断点。

修复后：默认平台选择提取为contactsSharedFlowEnabledProvider（仍为!kIsWeb），只有隔离tool宿主覆盖true。合成联系人/备注与系统拨号端口按loginEpoch重建；正式路由、控制器、详情、编辑、Skill、对话和任务共享，正常Web及手机端原行为不改。

2026-09-20浏览器8122实际：保存甲备注→查看乙无备注→乙发起订餐厅→文字提交→关闭→任务列表新增→恢复→选择候选回复→返回甲备注仍在→模拟退出重登后备注清空。所有姓名号码为PreviewContacts内置合成值。浏览器此前一次AX setValue未让输入生效，改用DOM文本框fill并先核对表单内容再保存；未据此修改产品代码。

新增3条（含320/430连续流程和正常Web不调用设备端口），联系人+首页+开发者+最近记录共62条定向通过，analyze无问题。系统交接只调用ShellContactsPorts，测试断言一次及号码；没有真实短信、系统电话、备注写入或设备安装，不把MOCK交接提示当实际已拨通。

## 下一轮优先项

### P14/P21/P22 拨号与翻译连续验证（2026-09-21）

基点80d1ae8之后的本批修复：TranslationDialerRoute默认及普通拨号子入口不再硬编码原生SystemDialerChannel，改为当前systemDialerProvider（显式参数仍优先，正式默认保持原生）；完整App MOCK不再绕过端口。国家/设置/会话路由仅在未继承目标容器时补作用域，避免Riverpod重复frameScheduler，跨容器覆盖仍保留。

浏览器额外复现普通呼叫模拟成功后“本机记录保存失败”：默认AppDialHistoryRecorder的`1 << 32`在Dart JavaScript目标为0，Chrome最小测试抛RangeError，改为4294967296后通过。记录格式、随机范围、分类及最近列表筛选不变；普通系统交接元数据不因此新增为翻译最近记录。没有对真实设备发起电话。

可重复路径：8122→完整App→底部拨号→实时翻译配置→关闭翻译/提示→区号搜索不存在值空态→搜索美国并返回；修复后重新加载经首页同声传译→同样关闭/选美国→输入2025550123→普通呼叫模拟不再报保存失败。再开启翻译→我的语言日语/返回确认/改回中文→海外模型GPT及JP节点→返回→开启拨号前提示→关闭确认后再确认→注入媒体就绪/对方接通/双语字幕→静音/扬声器/拨号盘/5→挂断→返回配置→删除号码后出现对应翻译最近记录。2026-09-21实际浏览器走通，error日志为空；DWDS一条开发环境warn，无真实接口、位置、音频、电话或账户变更。

自动化证据：新增7项两入口Android/iOS主题边界与容器测试，相关40条定向通过；后续默认ID的1条Chrome测试、21条记录/边界定向通过；`extended_device_stage_test`两个尺寸375×667/393×820预检通过，analyze无问题。测试数量有重叠，不能累加成唯一用例数。共享`dial_translation_stage_pages.dart`新增22–25四个截图检查点与原生拨号0调用保护，已接入同一设备入口；仅预检，不把旧21截图报告改为25张，也不宣称本批真机安装完成。首次预检沿用旧联系人号码和屏外长按已按正常清空/滚动修正，未放宽断言。

新增设备步骤仍待下一阶段，真实权限/系统拨号/电话接通/媒体/后台归档仍按集中清单人工验证。

后续2026-09-21已完成[iOS扩展真机阶段](IOS_DIAL_STAGE_20260921.md)：25截图/26步骤与隔离断言通过，普通App重新安装启动并确认登录页；测试只修复iOS转场固定等待导致定位歧义。七张关键图检查范围及23/25滚动视口限制见报告；Android新增步骤仍待，不更新旧Android21图为已验25图。真实权限/媒体/后台归档边界不变。

### P10 联系人工具续接（2026-09-20 增量）

修复的是验收宿主接线：之前deviceContactSource已合成，但PhoneContactLookup/NameContactLookup的续接仍创建Api实现，空API环境不能继续。仅tool的shellContactsOverrides覆盖为正式匹配器+同一ShellConversationPorts内存续接；工具请求、结果和后续候选都记入当前session ledger。正式lib/平台/API契约未修改，不新增正式关键词识别或按钮。

可重复Web路径：[8122目录](http://127.0.0.1:8122/)→基础App→订餐厅→切文字→发送“按号码查询联系人”，出现“MOCK · 号码查询：演示联系人；未拨号。”→发送“按姓名查询联系人”，出现两条同名不同号码候选→关闭→任务列表“MOCK · 按号码查询联系人”→恢复→选择第二项→显示“第 2 个”和“已收到你的选择。”。两个精确输入仅是独立MOCK服务器触发条件，不进入正式Agent或产品规则；普通输入仍用既有合成餐厅流程。

2026-09-20 23:02浏览器实测以上路径通过；恢复前后查询次数不增加、typed来源、选择命令及pending ID、再次恢复只读、登录代次重置由320/430宽定向测试断言。新增3条，相关共45条通过（约6秒），analyze无问题，Web目录重编译14.1秒；未全量、未重打双端、无真实通讯录/短信/外呼/后台上传。此补漏不扩大为P10所有真实能力通过。

首次新测试在对话页直接调用signOut产生ApiFailure.signedOut；当时改为“先关闭对话再退出”只证明正常路径。后续3.17已完成两阶段导航释放的共享修复，保留活跃对话强制失效最小回归，并验证模型弹层/草稿刷新/重登录及四类嵌套入口；见[生命周期证据](SESSION_NAVIGATION_VALIDATION.md)。真实系统资源及新版双端安装不在本次通过范围。

1. P08/P09共享合成连续证据已补；真实文件/识别和双端效果仍留集中验收，不把MOCK当服务验收。
2. P20完整App回执评价连续证据已补；继续页面覆盖及Profile/Release演练入口核验。
3. 安全附加式双端已扩到上方指定状态，iOS已新增部分P14/P21–P22，Android对应扩展及单路/日志新链路仍待阶段验证；不能因同一模块某页通过就勾整组。真实声音、电话、SDK与系统安装按[集中主清单](MIGRATION_HANDOFF.md)统一人工验收。

以上不是新产品范围；页面和正式实现已按[目标交接核对](MIGRATION_GOAL_AUDIT_20260922.md)收尾，真实设备/外部服务验收、正式OTA和视觉精校仍如实保留。Android新增27点由用户09-22批准暂缓，不再重试或作为其他工作的阻塞；未执行不标通过。用户定义的基础迁移交接不等于生产发布或全部真实能力通过。


### 2026-10-09 iOS隔离完整翻译与外呼增量

P21/P22在完整纯Shell实际走首页→提示→预检→媒体就绪→振铃→接通→双语字幕→静音/扬声器→按键盘不支持提示→挂断自动返回→首页；P21语种日语选择/重入/取消及海外模型切换/重入/关闭均实际确认。所有media、计费、配置与记录为内存假端口，环境无证明不转绿，DTMF是失败边界，不能列为真实通话通过。语种行64最小共同几何已修正，8项定向覆盖双平台/两倍字。P29另有固定iOS原生外呼四态运行参考及Flutter边框/状态色修正，25项定向通过；原生SDK/账户服务未导出。原图及限制见[当前增量台账](NATIVE_FEATURE_PARITY_MATRIX.md#2026-10-09-外呼原生参考与ios翻译实际增量)。

2026-10-09 初始化与联系人跨模块里程碑完成：冻结源码 `2eb2fcf896e07f9804fbdae8e7912bfe89256285`，全量 `flutter test --no-pub --reporter expanded` 退出0，3706项通过、1项按UI_AGENT_DOCUMENT开关跳过，耗时7分10秒；日志 `/tmp/phoneagent-onboarding-contact-milestone-tests.log`。跳过项先前已以UI_AGENT_DOCUMENT=true及UI_DOCUMENT_PARSE_DELAY_MS=10000单独验证2项通过，本轮未重复，不并入3706计数。此前同源码analyze无问题；全量期间仅文档及纯隔离UI记录，无lib/test/tool/ios/android差异。真实SDK、后台模型配置、外呼收费、正式签名/Android OTA与完整原生像素验收仍待验。用户指定SDK配置从参照项目读取已落实为工程内SDK副本及忽略的安全配置，不在日志或Git输出凭证。下一子任务继续拨号路由旧回调保护，不归档。

2026-10-09 拨号及预设增量：4c6c9a2普通拨号当前route/controller归属（23项8秒），4a75728翻译拨号异步迟到释放（43项9秒与追加10项6秒竞态），272e17e预设旧开关/语言/系统返回（32项10秒），计数存在重叠分别报告。最新analyze7.6秒无问题。纯隔离iOS实际国家返回123/+65、翻译关闭回普通123/+86及首页；预设日语返回、翻译关闭语言禁用、重入关闭和日语保留、再开启恢复可用，无呼叫。原始guarded-translation-country/guarded-presets-reentered-off已查看；SDK配置从参照工程读取及副本接线已完成，不再请求来源。3706/1全量仅覆盖2eb2fcf，真实SDK/模型服务/外呼/OTA/整页原生视觉仍待验。

2026-10-09 共同设置选择具名语义：core163/专项82两个源码微批，外层唯一container/button/label/enabled/selected/onTap及exclude内部OutlinedButton语义，视觉/48热区/大字保持。双平台1/2倍四有效RED具名节点hasSelectedState=false；修后语义/视觉各一次、disabled保留当前selected但无tap，翻译及全部五直接开发者调用方/正式Shell共39项14秒通过，analyze7.4秒无问题；影响已界定，不重复全量。另独立tool420单文件微批增加10个拨号/翻译/新helper/共同选择源码SHA，Shell login参数1项含3非法组合0.001秒通过，不称全部编译清单。纯.shell重建45333实际同传→预设→海外设置初Gemini具名button selected→选GPT仅GPT selected；原始setting-choice-selected实际查看，10SHA逐项对实际源匹配。无普通包/SDK/网络/电话/真实偏好，SDK条件及全像素仍待验。OpenSpec39/diff，pubspec.lock保持，中文提交推送后继续任务长列表已规划验证。

2026-10-09 H47L键盘分页实际补验：独立.tasksscroll构建安装启动48971，直接生产TasksPage/30条synthetic，无onOpen业务行为或网络。CUA点击首行后Next真实偏移0→536→1072→1608→1972且任务30可见；三次连续快速Next仅推进一页，逐次fresh AX后核验，不按按键次数臆测结果。Home无效一次，改Prior逐页返回1436→900→364→0。点击fixture两倍字范围3174，Next每页510.4，逐页到3174/任务30；Prior逐页回0，再恢复普通字号0/1972。四原始normal-bottom/large-bottom/large-top/normal-top在.local/ui-reference/ios-tasks-keyboard，均实际查看，顶部首卡阴影可见。未新增生产或tool源，工具TextScaler不是系统动态字号。此为真实外接键盘分页/回顶与布局证据，未称触摸拖动/滚轮已恢复，H47L触摸手势部分仍待验且不勾整体完成；此前两次失败未重放。无普通App/SDK/位置/电话/数据清理，不重复analyze/全量/普通双端构建，纯文档OpenSpec/diff。

2026-10-09 路由生命周期里程碑：生产源码冻结c14f983f8bf54fbee18788f0ba9584d0e898ea46，累计普通/翻译拨号、预设/语言/模型/海外设置/目录、共同选择语义及外呼/关于/开发者重置/原音触发一次全量回归；当前执行中未写通过计数。源码与工具/平台不再改动，只补纯隔离运行证据和文档，外部pubspec.lock保持。原音19项2秒/analyze2.5秒、外呼35项10秒及追加竞态4项、关于8项4秒、开发者重置9项5秒为各自定向范围，重叠不合计，不把此前2eb2fcf全量当覆盖本轮修改。

可信说明页独立两倍字补验：pure.trustedintro.large启动51237，键盘Next实际视口移至底部“开始”（AX文字未变，截图实证）；开始仅fixture结果“未调用可信SDK”→重新查看→直接AX返回element点击无效一次→刷新实际节点的公开Cancel动作返回“独立说明页已关闭”。large-bottom/large-return原始PNG在ios-trusted-intro-keyboard且实际查看。当前只有展示、键盘分页与公开取消动作运行证据；未声明触摸/边缘手势、真实SDK或完整原生V通过，工具TextScaler不同于系统动态字体。无普通App/真实授权/电话/网络。

2026-10-09 可信凭据独立两倍字补验：pure.trustedcredentials.large启动51714，synthetic长姓名/企业/编号与日期，无账户/SDK/通知端口；Next视口真实分页（AX整树文字不变，截图显示证书尾编号/颁发机构/说明及返回首页），点击可见返回回四状态菜单。再进入pending显示正在验证→返回、failed显示验签失败→返回、uncertified显示谨慎采信且无可信凭证→返回；每次实际AX核验，pending/failed未留PNG不称有截图。large-top/large-bottom/large-uncertified三原始PNG在ios-trusted-credentials-keyboard且均实际查看；首屏及长证书自然换行，未声称同原生整页像素V/触摸手势通过。公开verified只是合成输入，不当真实验签成功。全量仍执行中、c14f983生产/平台/工具无diff，只有文档；不新增SDK初始化或真实SIM/APNS/电话。

2026-10-09 路由生命周期跨模块里程碑完成：源码冻结c14f983f8bf54fbee18788f0ba9584d0e898ea46，全量flutter test --no-pub --reporter expanded退出0，3777通过/1跳过/0失败，7分38秒；日志/tmp/phoneagent-route-lifecycle-milestone-tests.log。唯一默认opt-in文档UI开关跳过保留（既有显式开关专项2通过不是本轮新执行，不并入3777）。期间lib/test/tool/ios/android无diff，仅文档与独立pure UI运行；source HEAD仍c14f983，analyze此前2.5秒无问题，外部pubspec.lock28条host-only差异不提交。新全量取代2eb2fcf的3706/1作为此冻结源码最新回归，不覆盖未来修改；OpenSpec39、四报告182相对文件目标存在及diff校验通过，本次未查锚点。SDK工程副本/安全配置来源已落实，真实SDK初始化/SIM/APNS/后台、模型短期配置、真实媒体/电话/结算/录音上传、Android同签名OTA/旧数据和iOS发布、三端全部状态像素与触摸手势仍待验，不归档。
