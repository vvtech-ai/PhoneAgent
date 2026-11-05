# Android旧国外翻译待归档记录：升级兼容与验收

2026-09-21，源码基点1d4a99b加本批兼容实现。已完成合成验证和Android编译，**尚未完成生产同签名升级或真实后台收件验证**。

## 为什么必须迁移

固定Android v65 `4c781e3ccfcd148c1f205921534907ee0c5aa864`：

- `features/translation_call/history/local/PendingRealtimeTranslationStore.kt`：`filesDir/realtime-translation/pending/pending-<SHA256(accountId)前32位>.json`保存账号待办；不是后台可随时重建的缓存。
- `history/domain/RealtimeTranslationArchiveContract.kt`：包含账号、clientCallId、WORLD_CALL录音定位信息、原通话时间和字幕。
- `RealtimeTranslationArchivePolicy.recoverAfterProcessDeath`、`RealtimeTranslationArchiveCoordinator.recover/archive`：进程重启恢复未完成同步，沿原clientCallId幂等归档，不重新拨号。

Flutter原先只认识自身安全存储格式，同包升级保留旧文件不等于新App能读取。此缺口会使尚未上报的国外翻译记录遗漏，不能归类为“仅待人工听音”。本批完成旧格式读取与正式队列接线。

## 实现链路

| 位置 | 责任 |
|---|---|
| [LegacyTranslationArchiveFile](../../android/app/src/main/kotlin/com/vvtech/phone_agent/LegacyTranslationArchiveFile.kt) | 当前账号哈希文件；8MiB有界读取、严格UTF-8、拒绝符号链接越界；不枚举、写入或删除 |
| [LegacyTranslationArchiveChannel](../../android/app/src/main/kotlin/com/vvtech/phone_agent/LegacyTranslationArchiveChannel.kt) | 后台任务队列读取；实际包名必须com.vvtech.aiassistant；返回版本/账号/文件内容，不输出内容到日志 |
| [DeviceLegacyTranslationArchive](../../lib/features/translation/data/device_legacy_translation_archive.dart) | 桥接响应版本、账号和缺失语义验证；读取错误继续抛出，不当空数据 |
| [LegacyTranslationArchiveCodec](../../lib/features/translation/data/legacy_translation_archive_codec.dart) | 白名单映射旧Gson字段，核对有效项；不复制国内录音路径、phoneAgentCallId或额外媒体票据 |
| [SecureTranslationArchiveStore](../../lib/features/translation/data/secure_translation_archive_store.dart) | 仅新key缺失时导入；同key跨实例串行；保存成功才返回，已有空队列同样优先 |
| [旧源Provider](../../lib/app/legacy_translation_archive_providers.dart) / [正式归档Provider](../../lib/app/translation_archive_providers.dart) | 非Web Android且精确prod API才装配旧源；原生另查生产包；绑定原登录并复用现有Controller |

共享Controller随后按已有恢复规则保存并调用`PUT api/realtime-translation-calls/{clientCallId}`。不新增电话、挂断、计费API或初始化步骤。iOS没有已发布旧App数据迁移要求，本桥接不在iOS注册；两端继续共用归档编排。

| 旧状态/情况 | 处理 |
|---|---|
| WORLD_CALL / CONNECTED | 保留接通及最后观察时间，由既有恢复规则封口；不用重启时间 |
| TERMINAL_DRAINING | 保留已结束时间和已知字幕，交既有封口流程 |
| READY_TO_ARCHIVE / ARCHIVING | 保留原clientCallId及结束快照，失败只重试归档 |
| PRE_CONNECT / COMPLETED / TERMINAL_FAILURE | 不加入新待办，不制造已接通记录或重复已完成任务 |
| DOMESTIC_ANDROID | 不导入、不上传国内录音；旧文件仍保留，不实现国内SIP |
| 串号、未知有效阶段、非法ID/时间/locator、畸形JSON或超限 | 整次导入失败，不静默跳过有效坏项后写空队列 |
| 新key存在或损坏 | 存在时直接使用；损坏明确失败，均不回退覆盖为旧数据 |
| 写失败、源错误、登录失效 | 不提前归档；失败按已有状态提示重试，登录失效不发布给新账号 |

读取固定账号文件会在本机解析同文件的国内条目以排除它们；不会把国内字段写入新安全队列。账号文件哈希不是授权机制，当前账号来自正式登录Provider。新队列写成功就是一次导入凭据，成功清空后仍保留空新key，防止旧文件再次被读取。

## 本批验证

- Dart 12项新增、合计29项定向通过：`legacy_translation_archive_codec_test.dart`、`legacy_translation_archive_store_test.dart`、`legacy_translation_archive_provider_test.dart`及既有`translation_archive_data_test.dart`、`translation_archive_controller_test.dart`、`translation_finished_provider_test.dart`，测试阶段约2秒。
- 正式Provider矩阵覆盖Android/iOS × dev/prod × 精确prod/其他API；HTTP被合成adapter完全替换。只有Android精确prod读取旧源。原生实际生产包条件仅编译/代码检查，未用Dev包冒充生产迁移。
- 旧CONNECTED→安全存储写失败零请求→503保留待办→同一PUT重试成功→重启零重复；保留原结束时间、字幕和定位凭据；全部合成数据，无真实SMS、电话、录音或后台写入。
- 原生4项JVM临时文件测试，0失败/0跳过；哈希、只读/缺失、文件超限/坏UTF-8、符号链接越界和非文件目标；测试任务首次12秒。
- `flutter analyze`无问题（3.3秒）；Android Debug构建通过（9.4秒），使用已有Android Studio JBR，工具链未升级。
- 首轮测试的HTTP断言误把绝对URL当相对path；改为精确完整URI断言后通过。移除一个未用测试import并修正测试File可空提示，没有放宽业务断言。
- 无全量回归、无新设备安装、无iOS重建。此批无页面变化，不重复Web逐屏截图。Android只读安装时间仍2026-09-20 22:27:05，不能证明普通App登录已恢复。

## 集中人工/发布验收步骤

1. 在有授权、可保留/备份测试数据的同生产包测试设备，按真实旧版本制造一笔已接通但归档接口暂时失败的WORLD_CALL；记录时间窗和clientCallId，不记录grant或字幕原文到Git。
2. 核对旧文件确有待办、新安全队列尚不存在；凭据保护和发布签名按OTA专项要求处理。**不要为了演练清理用户真实新队列或卸载App**。
3. 同签名、高versionCode保留数据升级，确认旧登录可复用。正常进入首页后，通过App同步状态及后台同clientCallId查验：只有既有归档PUT，无create/merchant-call/重新拨号。
4. 核对历史归档的原接通/结束时间、字幕及录音定位有效；一次断网/恢复重试后后台仍同一个业务记录。确认原文件保留、新队列在成功后为空。
5. 冷启动、token刷新及退出再登录同账号，不再导入已完成旧待办；切换另一个账号无串号。iOS/Dev/其他API不发旧源调用。
6. 如真实旧文件超过8MiB、格式损坏或缺有效录音定位，保留原件并报错，专项处理，不自动截断/删除。新格式已存在时不会合并遗漏旧记录；需要人工核查这种非首次升级情形。

旧文件只读保留不等于降级安全：旧版可能再次读取它；后台clientCallId幂等能防新增重复记录，但不构成完整数据回滚保证。生产签名/versionCode、其他有效旧状态和无账号任务补偿队列仍由[集中主清单](MIGRATION_HANDOFF.md)跟踪，不用此子项声明整体迁移完成。
