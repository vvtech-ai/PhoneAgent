# Android v65旧状态迁移台账

核对日期：2026-09-21。Flutter基点`9054a14`；旧Android固定`4c781e3ccfcd148c1f205921534907ee0c5aa864`，不以旧仓库当前工作树为准。产品范围以[批准基线](../requirements/MIGRATION_BASELINE.md)及用户答复优先。

这是一轮**有代码证据的迁移分类**，不是“全部旧状态已完成迁移”的声明。用途是缩小后续工作范围，避免每轮重新扫描历史功能，或把所有旧文件都搬到Flutter。

## 1. 判定规则与核查范围

每个数据项必须同时看来源、正式消费者、账号/环境归属及权威来源：

- 本机唯一且仍用于有效功能：必须兼容，或明确列为未完成，不能仅因旧文件保留就宣称迁移成功。
- 服务端已保存的镜像：可以重新获取，不把缓存格式复制当成必要架构；首次离线显示差异单独说明。
- 用户已排除的功能：不迁移其页面/业务，不为读取旧字段重新添加入口；原文件不因排除而自动删除。
- 无可靠归属或证据不足：保留原件、记录下一项核查，不默认交给当前账号，更不先发状态变更请求。

本轮搜索了旧Android自有源码中的SharedPreferences创建/注入、SQLite、文件目录及相应消费者；重点覆盖登录、根设置、翻译、通话元数据、评分、时间线、钱包、OTA和诊断。不把关键词命中等同于穷尽；第三方SDK内部文件、系统数据库、服务端数据库和运行时动态文件不在“已经逐个盘清”的声明范围。

旧源码路径下表统一相对`android/app/src/main/java/com/vvtech/aiassistant/`。复核用`git show 4c781e3:<路径>`，不要切换或修改旧仓库分支。

## 2. 已有导入实现：剩余是真实升级验证

| 数据 | 固定来源/消费者 | 当前Flutter处理与证据 |
|---|---|---|
| 登录 | `account/AccountIdentityProvider`；account_identity的phone/access token | [登录专项](LEGACY_LOGIN_MIGRATION_VALIDATION.md)：同生产包/精确prod作用域，新登录优先，消费标记防退出后复活；不重发短信 |
| 国外翻译/原音偏好 | `data/translation/TranslationCallSettingsRepository`、根设置与拨号消费者 | [偏好专项](LEGACY_PREFERENCES_MIGRATION_VALIDATION.md)：有效开关、语言、节点、海外模型、强制测试配置与原音比例保留；不迁移国内SIP |
| 初始化跳过 | 根偏好identity_initialization_skipped | 同偏好专项；设备级跳过导入，最新初始化仅身份→通话模型→首页，不读写国外翻译模型 |
| 定位国家缓存 | `data/translation/AndroidTranslationRegionRepository`；translation_region_state国家ISO/原采样时间 | 同偏好专项；保留缓存语义和原时间，不变成当前GPS、不读坐标、不用区号推断国家 |
| 身份采集认证录音 | `noBackupFilesDir/voice_clone_certified`及对应录音消费者 | [录音专项](LEGACY_RECORDING_MIGRATION_VALIDATION.md)：按已有校验/作用域导入，不导入全部音频临时文件 |
| App内通话元数据 | `features/assistant_shell/AssistantCallRecordState` | [通话记录专项](LEGACY_CALL_RECORDS_MIGRATION_VALIDATION.md)：保留有效本机元数据，不把它当系统CallLog；iOS仍只App内历史 |
| 条件评分草稿 | `data/local/taskrating/TaskRatingDraftStore` | [评分专项](LEGACY_RATING_DRAFTS_VALIDATION.md)：分数/建议/重试key与读取失败保护；新值优先、清除不复活，不替代赞踩 |
| 国外翻译待归档 | `features/translation_call/history/local/PendingRealtimeTranslationStore` | [待归档专项](LEGACY_TRANSLATION_ARCHIVE_VALIDATION.md)：9054a14已接WORLD_CALL原ID/时间/字幕/locator首次导入，复用幂等PUT，不重拨；国内/已完成/未接通不导入 |

“已导入实现”不等于真实数据验收。统一前提仍是实际生产包名、兼容签名及高版本覆盖；Dev安装或合成端口只能证明对应代码边界。旧源只读保留不是完整降级方案。

## 3. 可重新取得的数据：不复制旧存储格式

| 数据 | 代码依据 | 处理及可见差异 |
|---|---|---|
| 动态首页JSON/ETag | `data/homeconfig/HomeConfigLocalDataSource`、`DefaultHomeConfigRepository.load`调用published接口；304才用缓存，失败走既有fallback | Flutter [DioHomeRepository](../../lib/features/home/data/dio_home_repository.dart)重新拉取并建立自己的缓存，不导入assistant_home_config_cache；首次请求可能是完整200而非304，不丢用户输入或入口配置权威数据 |
| 首页标语轮换下标 | `data/homeconfig/HomeSloganRotationStore.next`按配置版本+next_index选择 | Flutter已有按版本轮换；升级后可从首条重新开始，不改变入口或后台配置。不为保留轮换下标引入旧存储适配 |
| 时间线SQLite | `data/local/timeline/TimelineCacheDatabase/Store`只存event/projection；`data/repository/timeline/ConversationTimelineRepository.sync/fullResync`从REST/SSE权威事件重建，旧库升级自身也会清表 | 不复制conversation_timeline_cache.db；Flutter从现有历史接口恢复。首次离线无法凭旧SQLite展示的边界必须如实保留，不能伪造已拉取历史；它不是未发出用户命令队列 |
| 钱包余额/流水快照 | `data/local/points/PointsWalletCache`保存PointsAccountDto/PointsLedgerPageDto；`PointsWalletRepository.account/ledger`从后台取得 | Flutter [钱包控制器](../../lib/features/points/presentation/controller/points_wallet_controller.dart)已有自己的缓存/刷新，旧镜像不作迁移必需项。首次离线可能没有旧余额预览；不可把缓存当可扣余额，更不可显示为余额被清零 |
| 已归档翻译历史/远端录音 | 历史Repository从后台读取，录音缓存依赖既有locator/grant | 使用当前历史接口和录音下载；与第2节“尚未成功归档”严格区分，不以远端可下载推断所有本机pending可丢 |

这些分类只决定旧数据格式是否需要导入，不允许删掉现有Flutter缓存、断网提示、重试或后台历史功能。

## 4. 明确不带入本期的历史状态

| 项目 | 判定依据 | 边界 |
|---|---|---|
| 旧联系方式/personal_info_list | `FinalSettingsPageV3`仍有onOpenContactMethods参数但未生成对应卡片；`FinalContactMethodPolicy.loadFinalContactMethods`存在不代表入口有效；批准范围已排除旧联系方式 | 不迁移旧个人信息列表；不影响现有“我的身份”、系统联系人、号码备注或联系人选择 |
| 国内/国际SIP账号选择 | `TranslationCallSettingsPolicy.visibility`只在中国分支showSipAccounts=true；国外为false，未知地区隐藏；本期明确排除国内App SIP | 不迁移selected_domestic_sip_account_id/selected_international_sip_account_id来复活账号页；国外HTTP/LiveKit/AppAudio和原音配置仍保留 |
| 首页旧通知横幅已读集合 | `AssistantHomeNotificationReadState`保存read_home_notification_ids；用户Q04首页仅动态入口，其他历史相关移除 | 不恢复旧通知横幅/内嵌会话；不误删后台任务或任务列表状态 |
| 旧独立文本/纯文本/语音模式选择 | 用户明确统一页同屏切换；`rememberAssistantRootSettingsPreferenceState`本身按默认纯语音状态启动 | 不导入旧页面路由/模式恢复；Flutter仍默认按住说话、底部切文字，不代表下节voice_language_code可以丢弃 |
| 开发者解锁旧常量 | `rememberAssistantRootSettingsPreferenceState`的developerModeEnabled以remember(false)创建，没有从旧常量读持久开关 | 继续进程内拨号串解锁，不新增永久开发者状态；原有工具都保留 |
| 可信来电SDK/引导状态 | 用户Q18明确暂时不接SDK | 不复制其SDK状态或新增权限引导；不影响身份采集SDK |
| 国内录音journal/PCM/m4a | 本期不接国内App SIP；旧WORLD_CALL归档导入已排除此route | 不导入本地国内录音上传管线、不自动清旧文件；已在后台的历史展示不因排除SDK而整体删除 |

## 5. 具体兼容项及增量状态

| 编号 | 已确认事实 | 下一步与禁止误判 |
|---|---|---|
| L01 语音识别语言（实现已完成） | `AssistantVoiceLanguageState`读取index9_native_screen.voice_language_code，主ASR与后端回退均使用 | [语言专项](LEGACY_VOICE_LANGUAGE_VALIDATION.md)：旧值白名单、新安全存储优先与同key串行，正式工厂每手势一次快照接主/回退；71相关定向（14新增）通过，取消/失败不启动迟到录音。不增语言页或翻译初始化；实际识别和生产升级集中验收 |
| L02 无账号异常补偿（处置已确认） | `TaskErrorRecoveryPendingStore`两组sessionId仅在index9_task_error_exit，无账号、环境或时间。Flutter新队列已有明确scope和幂等命令 | 用户2026-09-21确认以服务端最新状态为准；旧标记不导入、不重放，旧文件保留，新Flutter有效队列正常持久化/重试。现有正式接线符合，见[补偿专项](CONVERSATION_ERROR_STATUS_VALIDATION.md)，不再是待决策缺口 |
| L03 积分不足已提示标记（实现已完成） | `SharedPreferencesTaskCallPointsAdmissionNoticeStore`按account+conversation+confirmation哈希；`TaskCallPointsAdmissionContextHolder.current/markNotified`用于首次提示/再次不足分流 | [旧标记专项](LEGACY_CALL_ADMISSION_VALIDATION.md)：同生产作用域只读哈希桥接、新存储优先、先保存再返回；43相关Dart/3JVM及analyze/Android构建通过。仍待真实同签名升级，不实际发送外呼来证明存储兼容 |
| L04 确认时模型/余额快照（实现已接） | 有效统一页普通卡及LargeTaskConfirmationCard；旧Store存在scoped/unscoped两种key | [计费专项](CONFIRMATION_BILLING_VALIDATION.md)：普通及扩展batch-plus共享卡/历史投影/安全快照/旧哈希源已接，扩展结构与展开/决策/执行确认去重通过Web与相关定向。非Pending缺快照不补造当前值；不新增执行按钮，不以此证明真实升级或当前版本双端已验 |
| L05 旧OTA活动任务与已下载APK | final_ota_active_download/final_ota_installer包含下载ID、路径、目标版本/摘要，根设置另有force及最近检查日期；Flutter新DownloadStore仅恢复自己的scope | 纳入生产发布/版本策略：目标已安装或低版本不能重新安装；未知路径不能直接信任/删除；高版本仍进行中的旧任务是否继续需要单独归属和包证据。不把旧任务记录简单当普通缓存迁入，也不以新下载恢复测试当旧任务已兼容 |

以上不是额外新增功能。L01/L03/L04已完成实现增量，真实升级单列；其余按各自证据继续，初次台账分类未访问真实旧数据或执行后台补偿。

## 6. 文件与系统边界

- App权限、系统通讯录/CallLog归OS管理。保留数据同包升级的系统状态由实际安装验证；禁止导入旧布尔值来伪造已授权。iOS没有系统CallLog迁移。
- 临时TTS/候选试听/麦克风草稿、下载中的`.part`与用户已经导出的文件不是同一类别。临时资源不批量导入；用户下载/导出的文件不得自动删除、搬家或重命名。
- 旧AppFileLogger文本不具备当前账号隔离，不自动并入新账号ZIP。Flutter结构化日志/加密归档已实现；用户确认仅保留日志上传，不新增匿名本地导出，不扩展为采集所有系统日志。
- SDK内部密钥、票据、缓存不扫描或复制。身份由后端接口确定；认证录音走第2节专用受控导入，不通过SDK目录整包迁移。

## 7. 验证与下一步

本轮为代码取证和文档分类，无业务代码修改；只做OpenSpec、diff和文档链接校验，不运行全量测试、重打双端或制造真实电话。9054a14的29项Dart/4JVM证据只属于旧国外归档实现，不包装成这份台账所有数据均已验收。

L01/L03/L04实现与定向验证已完成；L02已确认保留旧文件且不重放，L05仍不得在缺发布证据时强行恢复。首页/时间线/钱包缓存不再反复列作“漏迁全部数据库”。真实声音、身份、系统权限和后台收件按[集中主清单](MIGRATION_HANDOFF.md)交用户统一验证，不继续新增无界诊断或逐屏演练作为迁移前置。
