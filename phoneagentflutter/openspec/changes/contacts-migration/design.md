## Context

Android 固定 4c781e3：AssistantContactPageHostArgs、AssistantContactRemarkRequest、FinalContactsData、DeviceContactPhoneCountryPolicy、DeviceContactDataSource。iOS 固定 ddb996a：AIContactsService.m 使用 CNContactStore 后台读取，授权回调主线程；AIContactsViewController 取首个号码仅为原生参考，不覆盖 v65 多号码产品基线。

## Goals / Non-Goals

目标：联系人真实平台端口与 Flutter 共享列表/详情/备注业务，后续接入设计页面与技能/拨号。
不做：联系人自动上传、后端目录替代系统列表、历史目录删除/AI 建模入口、iOS 系统通话记录、默认真实拨号。

## Decisions

### 本机拨号元数据与正式来源（2026-09-18）

固定v65 AssistantCallRecordState/FinalCallRecordStorage、AssistantSystemPhoneCallRecordPolicy、AssistantClientCallRecordPolicy：本机记录按账号保存，普通系统交接成功也记录，但最近拨号只合并App翻译子集；新翻译Finished会按callId+kind去重插入，未接通失败也可形成拨号元数据。服务端详情/录音归档与本机元数据不是同一件事，不能拿后台任务列表伪装本机记录，也不新增旧Calls/CallDetail页到任务页。

本子批复用DialRecentCall元数据模型，在dialer/domain/app_call_record_repository.dart定义load/append/clear/changes，data/app_call_record_codec.dart和secure_app_call_record_repository.dart按环境/API/账号hash分槽，整份blob含scope/schema。修改串行读改写、同callId+kind去重；读取/格式失败不当空成功或覆盖；旧账号/close拒绝晚到。只保存元数据，不存媒体票据/录音/全文字幕，不做服务端归档或旧Android存储导入。

app/app_call_record_providers.dart账号代次装配，data/app_dial_recent_source.dart投影并通知正式dialRecentProvider刷新；normal成功交接经DialerController可注入回调和app记录器写入，preview禁写；translation_dialer_route的普通模式同样接入。跨账号/跨实例写序列、记录失败不把系统交接误报失败或自动重复拨号。翻译生产媒体尚未装配，本子批提供共享Finished接收端与合成演练，不能声称真实翻译记录已产生。

手写微批≤3文件，默认500行。测试持久恢复/账号隔离/未知schema/并发append-clear/关闭、普通交接成功与失败/preview、正式两源列表和本地变化通知；Web隔离内存槽位完整回填/清空闭环。无新依赖/后端/数据库/SIP/ASR/TTS改动；全量/analyze/OpenSpec/三端构建，系统电话/旧数据/双端安装仍集中待验。

### 已授权Android系统记录读取（2026-09-17）

核对v65 DeviceCallLogDataSource/DeviceCallLogMapper及AssistantCallsDialSheet：系统记录来自CallLog，App最近记录来自本机FinalCallRecordStorage中的翻译子集，不是后端任务列表。本批只接系统来源，App来源继续明确notConnected，不能用远端任务结果伪装本机归档。

新增Android CallLogChannel薄读取（后台executor、主线程返回、单次请求、销毁取消），MainActivity注册及READ_CALL_LOG声明；绝不调用requestPermissions或adb授权。Dart DeviceCallLogChannel只在Android调用load，读取必要id/号码/缓存姓名/时间，最多20有效项；iOS/Web直接unsupported。原生读取前和结果交付前复查权限，撤权清空，不把null cursor/异常当成功空列表，不输出号码/姓名。普通与翻译页共用既有controller/列表/回填，未来定位决定后的申请门禁单独接入，不增加现阶段申请按钮。

测试mock method channel仅合成内容，覆盖unsupported不调用、拒绝不泄露rows、schema失败、过滤及上限；Flutter全量/analyze、Web/Android构建。真机授权/撤权/前台刷新与OEM差异仍是独立验收，不用构建替代。

### 最近通话共享交互增量（2026-09-17）

按用户静态优先授权，先完成两类拨号页共用的最近记录交互。DialRecentCallModels/Policy/AssistantDialHistoryList 为固定v65行为来源：仅系统记录和App翻译记录参与合并，source+id去重，时间倒序最多20项；空输入显示历史，输入后显示T9；行选择只回填，空号码呼叫按钮先回填第一条而非直接呼叫。无效号码不可选；翻译记录不会自动开启翻译，恢复国家和有效主叫语言，不恢复被叫语言。

本批增加dial_recent_call.dart（纯模型/政策）、dial_recent_source.dart（类型化来源）、dial_recent_controller.dart（两源独立失败/单飞/销毁保护）、dial_recent_list.dart和host，普通/翻译路由接线。生产来源尚未接系统CallLog/本地翻译归档时明确返回notConnected，不能把空数组伪装为成功；iOS/Web系统源unsupported。独立PreviewDialRecentSource仅用于显式MOCK，模拟记录不会写入账号、触发权限或电话。真实权限按v65定位决定后再申请的序列留后续，不能为了展示列表提前弹窗；不把后端任务列表替代拨号历史。

验证：纯模型合并、格式与选择政策，双源加载/撤权/失败/单飞/销毁，普通和翻译回填/空号按钮无拨出、320/390/430宽度；浏览器MOCK连续路径；analyze、全量test、Web/Android Debug。组件静态来源和未校准差异记入design/dialer，真实源、旧数据、真机与最终视觉仍未验收。

### 拨号联系人建议增量（2026-09-17）

固定v65 DialContactSuggestionPolicy/AssistantDialContactSuggestionList/DialContactDirectoryState：只读已授权系统联系人，不在拨号建议里申请权限。纯数字查询；按contactId（缺失按name）分组，姓名拼音全拼/首字母T9前缀命中仅取组首号码，姓名优先，号码子串其次，最多10项。号码匹配排除已知国际区号，高亮映射回显示号码。不采用Agent姓名模糊评分替代此规则。

新增dialer/domain/dial_contact_suggestion.dart、presentation/controller/dial_contacts_controller.dart及widgets/dial_contact_suggestions.dart，app/dial_contact_providers.dart装配既有平台联系人和纯Dart拼音字库。首次/恢复前台静默重新加载，撤权/失败不保留旧联系人，dispose晚到不更新。DialerPage增加内容插槽，普通和翻译路由同用列表；选择回填姓名/规范dialNumber（DeviceContactPhoneCountryPolicy优先normalized国际号码，不混用systemDialNumber），翻译页同步国家偏好但不改语言、不执行拨号。Web普通不可用，显式拨号MOCK用PreviewDialContacts，不访问真实端口。

本增量不替代最近通话（系统+本地翻译）数据源、定位或真实权限验收；不新增历史API。复用现有静态拨号设计，列表取有效v65组件参数。测试纯策略/加载生命周期/三宽度与两路回填，浏览器演练、analyze/全量test/Web和Android构建。视觉集中后校准。

- DeviceContactSource 只返回权限结果和原始 name/phone/normalizedPhone；Dart ContactPhonePolicy 保留 lookupPhone 与 raw systemDialPhone，目录 key 沿 v65 去非数字及 86/0086 前缀。国际号码标准化不丢国家码，国内原始座机前导 0 保留。按 name+lookupPhone 去重、排序，同名不同号码不合并。
- List 与备注目录是独立来源；目录 list GET userId，备注 POST 绑定当前账号，保留已有 displayName/primaryRelation/speakingStyle，仅 description trim/空转 null。不增加 DELETE/API 建模调用。
- ContactsController 分开设备 loading/permission/error 和 directory loading/error，局部失败不清除另一来源。详情以所选设备记录和目录 key 关联。保存单飞，保留失败草稿，晚到请求不覆盖新账号/新详情；目录刷新与保存互斥或代次隔离。
- 原生通道统一为 load(requestPermission=false)，内部仅授权状态检查、按显式参数请求授权、读取；读取前及返回前再次校验权限。Web unsupported 不申请系统权限；显式测试端口提供合成数据，不把 mock 混入正式平台。
- 2026-09-17 用户批准静态 HTML/CSS 与现有组件优先完成交互，视觉后校准；不再以运行态设计截图作为实现前置。列表、详情与备注编辑复用共享控制器；Web 通过显式进入的隔离模拟端口演练，不读取系统通讯录、不写真实目录。账号晚到通过 AccountApi 和 autoDispose 控制器双重保护。

## Risks / Trade-offs

### 普通拨号页面增量（2026-09-17）

继续2.4普通拨号：固定DialCountryCatalog仅CN/JP/SG/US；DialPhoneNumberPolicy区分中国手机/座机/服务/短号和国际E164，分机解析不作为自动DTMF拨出。Flutter DialerController管理输入/14位数字上限/删除/清空/地区/单飞交接；DialerPage和CountrySelectorPage消费状态与回调。联系人入口携带原始systemDialPhone，不用后端目录key代拨号。

Android使用ACTION_DIAL而非ACTION_CALL，不申请CALL_PHONE；iOS按原iOS实现使用tel URL并保留系统确认。平台通道只接受规范号码，返回opened/unsupported/failed，不把交接成功当通话完成。Web不调用tel导航，显示明确不可用；只有用户显式开启debug演练时模拟交接，不读账号或发真实电话。国内SIP仍排除，海外翻译媒体/最近通话/定位/开发者工具交接待独立批次，不能宣称全部拨号功能完成。

修改路径：lib/features/dialer/domain、data、presentation；lib/app/dialer_providers.dart；ShellRoute/联系人动作路由；Android SystemDialerChannel+MainActivity；iOS AppDelegate薄注册。最多3文件一微批。测试号码格式、输入上限/删除、地区切换/返回、错误/互斥/Web隔离、通道参数；analyze/fulltest/Web/Android构建，iOS编译按现有Mac同步链路执行，设备实际拨号集中人工确认。

- 国家号码和系统拨号混用风险：两个字段分离，源政策单测覆盖中国/国际/分机/重复联系人。
- 权限或读取失败与空列表混淆：状态类型区分，清晰拒绝/不可用，不伪造成功。通讯录数据不输出日志。
- iOS SDK/构建基线较旧：只依赖现有系统 Contacts API，版本差异单独处理，不升级 Flutter/Xcode。
- 真实联系人与备注不可当 fixture：只用合成数据验证写入，人工确认真实权限和保存。
