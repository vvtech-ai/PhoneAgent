# Flutter基础迁移目标交接核对

日期：2026-09-22；核对代码：`5351d75`，分支`codex/flutter-foundation`。本轮不改业务代码。

## 1. 结论与边界

按用户原目标，交接的是：复用Android登录、Web完成有效页面交互、阶段性双端验证、人工依赖能力已有共享/平台实现，并把操作和未验事项集中写清。**该基础迁移阶段已具备交接条件；不等于真实能力全部验收或可以直接正式发布。**

本结论结合正式路由/Provider/双端注册源码、当前连续测试、浏览器实测和既有真机原始结果；不是根据目录数量、无TODO或文档勾选推导。

用户允许的后置事项仍原样保留：视觉精校；真实声音、认证、系统权限和后台收件的集中人工验收；09-22明确暂缓的Android增量27点。正式Android同签名OTA/旧下载处置是发布前置，不擅自替用户决定或取消构建保护。

## 2. 三步目标逐项证据

| 原要求 | 当前证据及本轮复核 | 结论 |
|---|---|---|
| Android登录能否复用，尽量不再要验证码 | [真实登录阶段](ANDROID_LOGIN_CONFIRMATION_STAGE_20260921.md)：冷启动首页、真实两轮文字、任务恢复和普通包恢复后历史均在；本轮重新查看原始final-history截图。09-22 16:59恢复普通包后已再次确认首页，见[主清单](MIGRATION_HANDOFF.md) | 可以复用，没有因此再次发送验证码；不保证服务端令牌永不过期 |
| Web侧完成有效UI及交互，人工依赖可MOCK并说明 | P01–P29及P08a从AuthRoute/ShellRoute实际下级入口展开，见下表和[页面索引](PAGE_FLOW_COVERAGE.md)。当前16份目录/连续测试77项通过；最近浏览器权限三结果→退出→任务恢复→续聊通过；其他浏览器专项按索引逐项保留 | 页面和共享交互交接；外部能力明确MOCK，视觉精校未通过也不冒称通过 |
| 阶段完成后双端安装比较，避免返工 | 本轮读取`.local/shared-stage/android/result.json`及`ios/result.json`，两端各21图/22步骤、completed=true、nativeStorageCalls=0；重新查看两端04文字候选图。另读取Android确认卡六点、iOS文档四点原始结果；其余增量按专项列明 | 已做阶段性双端验证，不是只有Web。Android新增27点按用户决定暂缓，不替换成通过 |
| 人工依赖先实现，共享Flutter优先，平台接口才分开 | 正式conversation voice/speech、call monitor、translation device/runtime、clone flow、attachment、permission、recording、update providers均已检查；Android MainActivity和iOS AppDelegate注册已检查，非演练工厂。额外6项架构/双端正式翻译装配检查通过 | 共享业务与薄平台端口已接，真正设备/外部服务表现留待人工实测 |
| 参考现有Android及ios_newUI2，不复制旧架构 | 行为固定Android `4c781e3`，iOS参考`ddb996a`；[语音](VOICE_TRANSPORT_VALIDATION.md)、[SDK](IDENTITY_SDK_VALIDATION.md)、[位置](TRANSLATION_LOCATION_VALIDATION.md)有源方法/协议说明。当前Dart domain/audio无框架/设备依赖检查通过 | 不基于旧仓库当前分支猜行为，也没有复制两套原生业务 |
| 最终把人工步骤及实现讲清，之后由用户集中验收 | [主清单](MIGRATION_HANDOFF.md)第2节列实现分工；第4节M01–M14及M02a/M04a列入口、操作、预期和禁止结果；第5–7节列日志/失败处理/生产门禁，专项补协议与异常 | 已可按文档统一验收；不用用户逐批配合验证码、音频或确认安装 |

## 3. 有效页面实现与验证映射

本轮直接读取AuthRoute、ShellRoute、SettingsRoute、DeveloperToolsRoute、ConversationRoute和相关正式装配，核对下列入口；完整明细仍以[页面索引](PAGE_FLOW_COVERAGE.md)为准，不重复维护另一套功能范围。

| 页面范围 | 正式入口/实现 | 可复核验证 |
|---|---|---|
| P01–P02 登录/邀请码/两步初始化 | AuthRoute → AuthPage / InitializationHost → ShellRoute | AUTH_WEB_VALIDATION、INITIALIZATION_VALIDATION；目录挂载、shell_initialization连续测试；真实Android登录证据 |
| P03–P05 动态首页/模型/音色 | ShellRoute → HomePage / CallModelsPage / CallVoicesPage；business providers使用正式API | shell_workbench、shell_clone_workbench；HOME_MODEL_VALIDATION |
| P06–P10、P08a 统一对话/工具/文档/OCR/权限/联系人 | ConversationRoute组合Voice、Call、Recording、OCR、AgentDocument Host；conversation providers装配正式工具和服务 | shell_workbench、shell_attachment、shell_permission、shell_contact_tools；AGENT_DOCUMENT_VALIDATION、CONFIRMATION_BILLING_VALIDATION |
| P11–P15 联系人/备注/Skill/拨号/国家/最近/位置提示 | ContactsRoute、DialerRoute、DialPermissionHost；系统CallLog仅Android，iOS使用App记录 | shell_contacts、shell_translation；DIALER、DIAL_RECENT、DIAL_PERMISSION专项；双端12–13等阶段 |
| P16–P20 任务恢复/翻译历史/单路/批量/回执录音/赞踩及条件评分 | ShellRoute._task按canRestore优先；ConversationCallHost、TranslationHistoryRoute、CallEvaluationRoute | shell_history、shell_receipt、shell_call、workbench_feedback_points；双端基础/扩展及确认卡阶段 |
| P21–P22 国外翻译配置/通话/字幕/控制/结束回流 | TranslationDialerRoute、TranslationSessionRoute及正式runtime/media/finished providers | shell_translation；双端正式Provider装配2项；iOS拨号/翻译阶段；真实双媒体后验 |
| P23–P25 身份/声音克隆/积分流水 | IdentityRoute、CloneCreationRoute、PointsWalletRoute；SDK结果仍由后端核验 | shell_clone、shell_workbench、workbench_feedback_points；双端身份/克隆/钱包阶段 |
| P26–P29 设置/原音/退出/日志/Android更新/开发者 | SettingsRoute、LogReportRoute、AppUpdateRoute、DeveloperToolsRoute；iOS隐藏更新 | shell_workbench、shell_log_report、shell_developer；目录含OTA独立演练；iOS日志/开发者阶段 |

真实API与合成证据分开：普通8080和Android的真实文字闭环已验；复杂工具、计费、声音、SDK和上传收件不由MOCK证明。没有增加匿名日志导出、初始化翻译模型、充值、国内App SIP、可信来电SDK、记忆或旧独立对话页。

## 4. 本轮执行与产物一致性

- `flutter test`定向16文件：`test/shell_*workbench_test.dart`、`test/workbench_test.dart`、`test/workbench_feedback_points_test.dart`，**77项通过，测试阶段约16秒**。包括目录27场景挂载/退出，及正式共享路由多宽度连续交互；挂载测试不冒充全部业务状态验收。
- `flutter test test/architecture_test.dart test/features/translation/translation_dial_runtime_provider_test.dart`：**6项通过**。核对500行默认上限及已备案507行例外、纯配置/领域依赖、竖屏/包身份、Android/iOS正式翻译运行时节点/账号/原音/退出隔离；不采集媒体。
- 本轮合计83项定向，不是全量；沿用同一未修改代码上一轮analyze无问题及Web编译/实际浏览器结果，不反复执行相同检查。
- `git diff c93e783 HEAD -- lib android ios pubspec.yaml pubspec.lock`为空；最近普通Android/iOS构建对应正式实现仍有效。后续仅tool/test/docs变更，不因文档收尾重新构建或安装。普通设备不是新的MOCK包。
- 真机原始结果：Android确认卡53–58全部完成、forbiddenNativeCalls=0；iOS文档59–62全部完成、forbiddenNativeCalls=0。两端基础文字候选图结构/交互一致，字重、屏幕尺寸、滚动位置和MOCK栏换行不同，不声称像素一致。
- 本轮未请求短信、电话、认证、系统权限、真实上传，未改普通8080登录、Mac钥匙串或安全执行配置。

## 5. 下一阶段保留项（不得自动勾通过）

1. 按[集中主清单](MIGRATION_HANDOFF.md)真实验证音频/单多路电话/国外翻译/SDK/文件/权限/录音/钱包和日志收件。用户安排统一执行，失败再按证据修复。
2. iOS真实账号登录尚未验；需要时才集中请用户输入验证码一次，不把MOCK登录当真登录。
3. Android22–38、47–52、59–62共27点仍未执行，用户已批准本次跳过；不再安装重试或绕过策略，后续恢复该阶段需重新确定执行条件。
4. 视觉精校仍后置，系统控件允许平台差异；当前共享结构可交互不等于与设计逐像素一致。
5. Android正式发布前配置兼容生产签名/更高版本并验证旧状态升级；D03旧下载继续/废弃及回退策略未决。**不能现在把Dev包当成无缝OTA发布包。** 这保留原升级要求，不把“基本迁移已交接”解释为升级已完成。

OpenSpec仍保存后置真实/视觉验收和被暂缓设备任务，不为结束基础迁移而把未执行改成通过或整体归档。后续从这些明确事项继续，不再由历史文档中的旧“未登录/未接入”反复派生已完成开发。
