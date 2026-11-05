# 联系人迁移实现与验证记录

## 最新增量（2026-09-18）

本机 App 拨号元数据仓库、正式最近记录读取、普通交接记账、开发者 Filled/Empty 的真实本地消费者已接入。联系人控制器现为登录生命周期内保留，清空使在途旧读取失效；账号切换仍销毁。35新增/1707全量、三端构建和隔离浏览器通过，见 [本机记录与列表验证](APP_CALL_RECORDS_VALIDATION.md)。翻译 Finished 写入、旧数据和真机仍未验收，以下早期数量仅是历史节点。

## 当前状态（2026-09-17）

正式联系人 Tab 已接入列表、详情、备注编辑、动态 Skill 选择与统一对话入口。页面按用户批准的静态 HTML/CSS 优先方式实现，视觉差异见 `design/contacts/interaction-contract.md`。普通系统拨号、Agent 重名工具和真实权限/备注/外呼验收仍未完成，不将本批等同联系人模块全部交付。

本批新增 14 项回归（联系人专项共 34 项），涵盖 320/390/430 宽度、同名多号码、编辑取消/保存/失败重试、保存中返回拦截、键盘和两倍字体、CONTACT_DETAIL 首轮消费以及离线 Agent 不读取账户。普通浏览器主入口实际验证列表→详情→备注保存→Skill→默认语音→切文字→离线回复→返回详情，全程保留登录、无短信/真实备注写入/拨号。

本批收尾：359 项全量 tests、analyze、17 OpenSpec、普通 Web debug build、使用测试环境完整 `https://agent.vvtech.tech/aiassistant-api/` 的 Android Debug build 均通过。一键 Web 为 241 项共享回归 + 2 Chrome 传输 + 1 Node 代理测试。本批未重装设备，未新增 iOS 编译/签名证明，不能用构建代替双端验收。

## 实现位置与边界

| 内容 | 实现 | 共用/平台 |
|---|---|---|
| 国内/国际号码、备注匹配 key、原始系统拨号号码分离 | `lib/features/contacts/domain/contact_phone_policy.dart` | Dart 共用，沿固定 v65 |
| 多号码、去重/排序、设备与目录模型 | `lib/features/contacts/domain/contact_records.dart` | Dart 共用；目录不生成系统联系人 |
| 账号目录 GET、备注 POST | `lib/features/contacts/data/api_contact_directory_repository.dart` | 共用 AccountApi；保留显示名/关系/说话风格；无历史删除/AI 建模入口 |
| 独立加载、详情草稿、保存单飞、失败/晚到隔离 | `lib/features/contacts/presentation/controller/contacts_controller.dart` | Dart 共用 |
| 平台映射 | `lib/features/contacts/data/device_contact_channel.dart` | Web 明确 unsupported；普通刷新不请求权限 |
| 系统读取 | Android `ContactsChannel.kt`；iOS `ContactsChannel.swift` | 仅授权/后台读取/主线程回调，不包含备注业务 |
| 生命周期/导航 | `lib/app/contact_providers.dart`、`presentation/pages/contacts_route.dart` | 正式 Shell 接入、账号变化与路由销毁隔离、前台重查权限 |
| 列表/详情/备注 | `presentation/pages/contacts_page.dart`、`contact_detail_page.dart`；`widgets/contact_remark_editor.dart` | Flutter 共用；2000 字、失败留稿、保存中禁止退出 |
| 技能入口/统一页 | `presentation/pages/contact_actions.dart`、`contact_task_route.dart`；`domain/contact_skill_opening.dart` | 仅可用 OpenSkill；共享统一页和控制器，首轮 selectedContact.source=CONTACT_DETAIL |
| 显式 Web 演练 | `data/preview_contacts.dart`、`preview_contact_agent.dart` | debug Web 主动进入；内存备注和离线回复，不读取账号/调用真实 Agent |

原生通道 `com.vvtech.phone_agent/contacts`，方法 `load`，参数 `requestPermission` 默认 false。仅 true 且系统允许时请求授权；不自动扩大授权，不写系统联系人。两端均返回所有号码；名称、号码、通讯录正文不写日志，也不自动上传。仅用户保存当前联系人备注时向既有测试/生产后端发送该项字段。

Web 正式端口不伪造通讯录权限。主入口联系人 Tab 的“进入联系人交互演练（MOCK）”显式开启合成数据；列表/详情/统一页持续标记 MOCK，退出演练清空内存，不会把合成联系人写入真实目录。Skill 配置仍可使用现有首页只读数据，不携带联系人。身份/模型阶段已有登录保持不变，不为此批重新申请验证码。

## 代码基线

- Android v65 `4c781e3`：AssistantContactPageHostArgs、AssistantContactRemarkRequest、FinalContactsData、DeviceContactPhoneCountryPolicy、DeviceContactDataSource。
- iOS `ddb996a`：AIContactsService 使用 CNContactStore，AIContactsViewController 只取首个号码；仅借鉴原生读取，不继承该多号码限制。
- Android 仅声明 READ_CONTACTS，未添加 WRITE_CONTACTS/系统通话记录权限。参考 [Android Contacts Provider](https://developer.android.com/identity/providers/contacts-provider)。
- iOS 声明 NSContactsUsageDescription，只取姓名和号码，不取系统 note 字段。有限授权含义见 [Apple limited access](https://developer.apple.com/documentation/contacts/cnauthorizationstatus/limited)；现有 Xcode 15.2 使用 raw value 4 兼容判断，iOS 18 实机有限授权仍需人工验证，不能以 iOS 16 编译证明。

## 前一基础批次验证（2026-09-16，保留历史）

- 最终全量 **249 项 Flutter 测试**、`flutter analyze` 无问题；`openspec validate --all` 随本批最终文档一起校验。联系人新增 20 项专项测试，另有 1 项 Android 原生集成测试，不混为同一计数。

- 共享逻辑专项覆盖：备注清空/null、已有字段保留、后端返回号码不匹配、账号切换、失败保留草稿、重复保存、旧 GET 不覆盖新 POST、切换详情及销毁晚到；号码覆盖 CN/SG/JP/US/未知国家、国内座机前导零、分机、同名多号码。
- MethodChannel 合成测试：显式权限参数、Web 不调用原生、拒绝不泄漏行、limited 与 authorized 共用模型、非法返回拒绝。
- Android Debug 主入口编译通过；隔离 `emulator-5554` 原无 Flutter dev 包，运行 `integration_test/contacts_permission_smoke_test.dart`，实际原生通道返回未授权状态，1 项通过，没有权限弹窗或读取真实通讯录。
- Mac 新临时目录 `PhoneAgentFlutterContacts.cZTO5M` 使用本地 HEAD 基础快照加本批增量，`flutter build ios --debug --no-codesign` 通过。依赖锁文件内容在 EOL 标准化后完全一致，没有升级工具链。旧工程、dirty CocoaPods 配置和 screen/debugger 均保留。
- Web debug 主入口构建通过；新模块尚未挂页面，该构建不代表联系人 Web UI 已验证。
- 后续普通包覆盖安装命令被策略拒绝，未执行且未绕过；实体 Android 仍是前一已安装版本，iPhone 仍是 Stage121015a。本轮不声称双端新页面安装通过。
- 隔离模拟器保留权限测试入口；已重新构建普通主入口 APK，但其重新覆盖安装同样尚未执行。

## 当前页面的集中人工验收

列表/详情/备注与技能统一页已可从正式联系人 Tab 操作；以下真实权限和账户写入未由自动化代做。普通拨号页与双端系统交接已接入（见 DIALER_VALIDATION.md），重名工具仍是后续项。没有提前勾选真机验收。

1. 使用专门测试联系人，首次进列表不自动申请；点击授权后分别验证允许/拒绝，再从系统设置撤销/恢复权限。预期区分未授权、读取失败和真正空列表，不展示撤销前缓存。
2. 准备同名两号码、同名同号重复项、+86 手机、国内座机、+65 号码和分机。预期多号码保留、重复项去重；普通拨号入口保留系统原始号码，不把去符号的目录 key 当拨号号码。
3. 打开详情备注，修改/取消、保存成功、断网保存失败后重试。预期失败留草稿与旧备注，成功只更新该项；原有关系/说话风格不丢失。验证后手动恢复原测试备注，不删除真实联系人。
4. 正在保存时返回或切换其他详情/账号。预期不把前一联系人的成功/失败写进新详情，不泄漏旧账号目录。
5. iOS 18+ 选择有限联系人授权，列表只出现所选子集；系统设置改为完整/撤销后刷新。当前仅代码处理及模拟契约测试，未实机证明。
6. “发起任务”已携带 CONTACT_DETAIL 姓名/号码与选定 Skill 进入统一页；第一条有效输入才发送上下文，后续轮次不重复。普通拨号现进入共享拨号盘预填原始号码/地区/姓名，点击后才交系统确认；Web 普通端明确不支持，演练端不产生电话；真机交接仍待集中验收。

平台错误代码：`busy`、`read_failed`、`permission_failed`（iOS）、`disposed`（Android）。它们是通道返回值，不表示现阶段已有统一日志采集或后台关联 ID；页面接入时还需完善脱敏诊断与集中验收入口。

## Agent 按号码查询续接（2026-09-17）

实现：`conversation/domain/tools/phone_contact_lookup.dart` 使用既有设备端口并按v65匹配；`data/tools/api_contact_lookup_continuation.dart` 回传 `api/assistant/agent/contact-lookup-result`；统一Controller拒绝重复工具及晚到结果，HTTP后同步新command对应ledger。Android/iOS只提供权限、号码行和系统标签（label），不移植业务状态机。iOS系统标签本地化，Android保留自定义标签；此项允许平台差异。

手机端链路已接正式Provider，不是仅有MOCK。首次工具查询依v65请求通讯录权限（普通列表首次进入仍不主动请求）；拒权回传`found=false, reason=PERMISSION_DENIED`，读取失败或浏览器不支持回传`DEVICE_LOOKUP_FAILED`。命中只发姓名/source/可选系统标签note，不发送整本通讯录、不拿后端备注冒充系统标签。保留v65双向号码后缀及第一匹配规则，不擅改为新号码策略。

Web合成入口：联系人→交互演练→演示联系人→发起任务→选择Skill→切文字→发送。网关仅生成合成号码查询，复用共享查询及Controller；回传端口仅内存返回“共享查询找到演示联系人”。浏览器已走通，MOCK不读取设备、不接真实账号/HTTP、不发电话。自动测试额外覆盖HTTP精确字段、错误会话/账号切换、拒权、错误、重复、退出、候选续接及ledger消息去重；真实后端回传尚未实测。

集中人工验收：使用专门合成联系人和测试环境，在统一页触发按号码查询；分别允许/拒绝系统权限，预期Agent继续补问而不是卡在“未接入”。同一号码两个联系人、空姓名首行、国际号码和自定义标签按源规则检查；不要用真实私人联系人做自动回传验证。查询时退出/切账号后不应出现跨页回复；断网失败先同步历史，不自动重复POST。可按`sessionId`/`pendingToolCallId`核对请求及后台`contact-lookup-result merged`，客户端失败日志为`conversation_failure session=...`（不输出联系人内容）；不把系统通道错误码当作已上传的关联日志。

本批仅号码查询。按姓名的重名候选、繁简/ASR拼音、设备真机权限和真实Agent闭环仍待完成/集中验证；当前未重新安装两端，不能将双端构建当真机通过。

自动验证：新增22项、全量506项、analyze通过；Android Debug与Mac无签名iOS构建通过（临时独立源码目录，不碰已有工程/解锁会话）。已有pending工具从历史自动恢复仍属后续任务，本批没有把live查询等同完整历史工具恢复。

后续姓名查询已完成共享规则及live续接：见[姓名候选验证](CONTACT_NAME_LOOKUP_VALIDATION.md)。上面的506项及“仅号码”描述为前一批历史记录；当前531项全量通过，Web演练已扩展为号码→姓名→同名候选→选择继续。真实权限、ASR入口、pending恢复仍未验收。
