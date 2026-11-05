# 结构化诊断日志与上报验证

## 双端设备环境（2026-10-26 用户追加）

当前正式 ZIP 新增 `device-environment.json`，与 `diagnostics.jsonl` 并存，覆盖下文历史“只有 diagnostics.jsonl / 不读取硬件型号”的说明。白名单包含 schema、available、实际安装 appVersion/appBuild、osName/osVersion、brand/manufacturer/model、可取得的 hardwareModel、Android apiLevel。不包含序列号、UDID、用户设备名称或签名内容。Android hardwareModel 来自 Build.DEVICE，iOS 来自 uname.machine；iPhone16,1 等是系统原始硬件型号，不臆造营销名称。

设备快照在 prepare 捕获，普通日志与带日志反馈的后台 deviceInfo 优先取同一快照，摘要有界至现有数据库 512 UTF-16 单元内。元数据读取失败不丢日志，ZIP 标记 available=false；上传重试补读真实信息并固定，不能读取则保留失败。补读不改写已准备的 ZIP 字节与 SHA256。账号变化拒绝旧包；反馈仍整体成功后才清理，清理失败只重试清理。

独立模型/平台适配/摘要格式化/provider 接线分别承担单一职责，未增加依赖、数据库字段或权限；随后用户指定双端版本为 1.0.53（46），已更新版本源及 Android 构建脚本。243 条相关自动回归通过，含双平台 Widget 与实际 ZIP 解压；Android 适配器 Kotlin 独立编译通过。完整 Gradle 缺开发私有输入、Mac 主机 DNS 不可达、Windows iOS 脚本有既有符号链接/路径失败；完整双端构建、设备原生值、相册及真实后台收件尚无本批证据。验收时下载 ZIP 核对这两个条目，并比较系统设置及后台摘要。

## 2026-09-21用户确认（覆盖下方历史范围判断）

现有产品只有日志上传，不新增“匿名日志本地导出”页面或分享能力；下文曾列为待办的匿名导出撤销，不作为迁移阻塞。现有上传、账号隔离、内部ZIP准备保持不变。Android普通Dev已于09-21 14:26保留数据覆盖恢复并冷启动普通登录页，不再等待用户确认安装；当前未登录，没有发送短信或实际上传。真实收件、锁屏和异常恢复仍是集中验证项。

## 共享语音连接与PCM诊断（2026-09-21，最新增量）

普通语音输入/主ASR及后端回退、回复TTS和音色试听正式工厂已接共享media诊断：连接与ready分开，首个PCM仅一次，协议complete不等于实际播放，设备停止失败保持重试。操作开始绑定Journal，延迟fallback/分句/停止不归新账号；不存正文/PCM/URL/原始错误。15新增、217相关及后续3项provider通过（去重218），analyze/OpenSpec通过，无全量/真音频/新安装。详见[实现与日志读法](VOICE_MEDIA_DIAGNOSTICS_VALIDATION.md)。

后文历史“PCM/媒体底层全部未接”现收敛为翻译LiveKit/AppAudio及其余专属路径诊断仍缺，不应重复普通语音实现；匿名/未绑定用户导出、真实服务收件和声音验收仍未完成。

## Android未捕获异常摘要（2026-09-21，当前增量）

覆盖后文历史“原生crash完全未接”的描述：Android现已在Application注册Java/Kotlin默认未捕获异常处理器，Dart正式RuntimeDiagnosticsHost挂NativeCrashHost导入既有Journal及ZIP；iOS/Web不调用新增通道。参考v65 AppCrashHandler，而不是复制其任意堆栈日志。指定iOS ddb996a自有.m/.mm/.h/.swift中NSSetUncaughtExceptionHandler/uncaughtExceptionHandler/logCrash/SIGABRT检索未匹配；第三方SDK二进制符号不能证明已有自定义捕获需求。

- **原生只处理必须同步的系统边界**：`NativeCrashApplication`安装；`NativeCrashRecorder`尽力采集后始终转交原Thread/Throwable给前处理器，无前处理器则重新抛原异常。`CrashSummaryStore`以独立AndroidKeyStore AES-256-GCM密钥加密，noBackupFilesDir/native-diagnostics-v1，随机nonce、AAD绑定文件名(scope+UUID)、临时文件fsync后rename。含当天15个自然日、最多32条暂存，过期按文件写入日期；只清严格白名单文件与中断pending，未知文件保留。
- **共享归属和导入**：`NativeCrashImporter`和`DeviceNativeCrashPort`只接受UUID、UTC时间、主线程布尔、argument/state/assertion/other。导入operation为androidMainUnhandled/androidBackgroundUnhandled，UUID进入traceId；不存异常正文、堆栈、类名、线程名、手机号、token或账号明文。Dart按环境/API/账号生成SHA256 scope，结果固定原Journal，flush成功才按精确UUID清暂存；后台恢复/同scope再次激活可重试。
- **时序保护**：Provider的scope监听可能早于“当前Journal”间接Provider失效，因此宿主明确用`diagnosticJournalByScopeProvider(scope)`取实例。已关闭Journal的`flush(requireOpen:true)`必须失败，不能把丢弃事件当成功后清原生记录。同进程重试按Journal+UUID避免重复入队；跨进程若在Journal提交后、native确认前终止，可能重复同UUID，不承诺exactly-once或零丢失。
- **账号/覆盖边界**：原生仅保留本进程最后收到的scope，启动未绑定为unassigned；不恢复上次账号，不把未绑定摘要交给新账号。异步桥接命令送达前的短窗口仍按旧绑定，记录不是异常瞬间业务账号的绝对证明。未绑定及signed-out用户导出仍未接，登录后设置ZIP不会混入匿名摘要。
- **验证**：9条新增Dart测试；日志/认证/音频诊断Provider/Agent诊断共182条定向17秒通过，analyze 4.2秒无问题。10条JVM真实AES-GCM、临时文件、篡改/改名、丢密钥、随机nonce、精确清理、32条/15天、原处理器故障注入通过；Android Debug构建12.3秒。测试曾暴露并修正取Journal时序；首轮比较器/测试override及一次无效测试目录已纠正，最终完整上述定向集合通过。没有全量、真实上传或真机崩溃/新安装。

### 集中设备验证边界

本批APK仅构建，未覆盖真机；既有iOS运行进程仍正常。后续Android受控Debug验证应覆盖：发生真实Java/Kotlin未捕获异常后原系统崩溃处理仍生效；重新以调试器启动/恢复同账号后，日志ZIP出现同UUID且无正文；换账号不得见旧摘要；实际Keystore/磁盘失败不阻止原处理。故意崩溃需单独授权测试，不在正式页面新增崩溃按钮，不卸载/清登录。JVM密码学测试不是AndroidKeyStore硬件/锁屏证据。

不覆盖Application安装前的崩溃、后续SDK替换且不转交的handler、NDK信号、ANR、OS强杀、全部OOM或iOS崩溃。OOM和磁盘故障仅尽力保存；底层媒体诊断、匿名导出、真实后台收件和生产降级仍分别待办，不由本项勾选整体日志/迁移完成。

## 共享音频占用诊断（2026-09-21）

正式`audioPlaybackFocusProvider`已装配共享`AudioFocusTrace`，在每次申请开始固定当前Journal；仲裁器仍跨登录保留同一实例。租约持有该申请的sink，账号切换触发的停止、超时或迟到释放不会写入新账号。没有修改播放、录音、翻译、SDK或原生通道的执行协议。

- `operation=audioFocus`；`audio.owner`白名单覆盖conversationCapture/conversationTts/callMonitor/identityCapture/clonePreview/recording/translationAppAudio/translationLivekit，其他归unknown。`stage=acquire/release/stop/stopWait`，固定result、failureKind和耗时；request/lease仅本进程序号，不是后台会话ID，不保证跨启动唯一。占用冲突附固定blockedBy类型。
- acquire成功仅证明共享准入；release证明调用方交还租约，stop成功证明注册的停止回调已完成，**均不独立证明硬件已静音**。超时记录stopWait失败，原租约不释放，下次仍复用尚在途的停止；回调自身抛TimeoutException只记stop失败，不冒充仲裁等待超时。失效申请记cancelled，不假造成功。已失效租约的重复release不记第二次成功。
- 任意owner/异常原文、号码、PCM、转写、URL和凭据不进入日志；诊断工厂与sink故障均隔离，不替换原业务异常。新版本读取旧无audio字段日志，未知可选分类归unknown；旧二进制降级读取新operation仍需发布专项。
- 8条新增、135条音频/直接调用方/日志定向约9秒通过，analyze无问题。验证正式Provider账号切换、停止超时/迟到、保护性占用、取消、诊断失败，以及合成内存存储的Journal序列化重建→实际ZIP解压27事件。没有新文件归档/双端设备测试，不把内存重建当作设备落盘；沿既有正式Journal归档工厂接入。
- 原生crash、PCM/媒体传输底层诊断和登录前匿名导出仍未关闭。人工验收M06–M10中遇到占用问题，可用本记录确定哪个固定模块持有租约、停止是否等待超时；实际声音和系统释放仍需设备证据。无真实音频/电话/SMS/上传/新安装，无全量回归。

## 完整App设置连续入口（2026-09-21）

基点6d971fc后本批将LogReportRoute内的ZipLogRepository/ApiLogUploader装配迁入`app/log_report_providers.dart`，默认仍绑定当前账号和原Journal、原HTTP上传协议。页面不再自行构造数据端口；匿名账号仍显示请先登录，不增加匿名导出或自动混合日志。

完整App宿主通过`shell_diagnostics_preview.dart`覆盖该Provider，`shell_log_report_preview.dart`按登录代次保留同一真实ZIP/内存Journal；首次上传和首次清理各合成失败，之后成功。仅tool包含失败脚本，无HTTP/文件/系统存储；正式页面文案不改，最外层常驻MOCK标识，因此其中“日志上传成功”只表示本场景合成完成，不代表后台收件。

可重复路径：[8122目录](http://127.0.0.1:8122/) → 基础App → 设置 → 日志上报 → 上传诊断日志（合成失败）→ 再次上传（合成成功、清理失败）→ 仅重试本地清理 → 返回 → 重进。浏览器实际从1条234字节到最终0条134字节ZIP，所有状态/返回可达、error为空；没有点击独立演练代替正式入口。新依赖接线后完整重启隔离开发服务13.2秒，不动8080账号。

新增3条：320/430完整App及默认Provider；最终日志/页面/协议/共享App5文件共26条定向约6秒通过，analyze无问题，未跑全量。断言初入不上传、上传失败同一ZIP重试、清理重试不上传、晚于快照新增日志保留、页面重进同源、活跃页退出登录/重登重置、系统安全存储0调用；默认Provider仍为ZipLogRepository，空API配置上传返回ApiFailure.unavailable而非模拟成功。ZIP解压验证实际结构和无合成凭据。初次analyze的测试冗余import已移除，最终无问题。

没有本批双端安装/真实上传；真实后台收件和锁屏/强杀另待人工，原生crash/音频与匿名用户导出仍是开发缺口。此项只关闭Web完整入口缺口，不扩大为日志整体完成。

## 登录请求正式采集（2026-09-21）

`DioAuthGateway`现在通过共享`AuthRequestDiagnostics`记录send-code/login的完整结果；正式`authGatewayProvider`在请求开始选择当前Journal，不watch账号Journal，因此身份变化不会关闭同一登录客户端。每次请求保留自己的sink、状态码和Stopwatch；并发乱序完成不会交换账号归属或状态码。

- 固定`operation=authSendCode/authLogin`及`auth.outcome`：codeAccepted、inviteRequired、credentialsReturned，或既有AuthFailure固定类别/unknown。HTTP200畸形响应记failed；凭据返回不代表SessionStore落盘或已进入首页，邀请码响应也不是已登录。没有记录真实手机号、验证码、邀请码、challenge、token、账号、URL、任意响应或异常。
- 每请求仅一条完成事件，含HTTP状态（无响应为0）和耗时；未完成/强杀请求不会产生完成事件，不声称已有起始日志或崩溃保证。沿既有Journal延迟保存、快照前flush与移动端加密文件工厂，无新增自动上传。诊断工厂/写入失败不能改变原业务结果、异常或重试次数。
- 11条新增，认证模块/日志模块/Agent诊断共164条定向约14秒通过，analyze无问题。包含完整DTO、6类服务端拒绝、传输失败、并发乱序、sink失败、正式Provider账号切换/实例稳定、Journal重建→真实ZIP及旧格式/未知字段脱敏；全部合成HTTP/存储，不发SMS或实际日志。没有UI/原生/依赖变化，不重复全量或设备构建。
- **仍未实现：登录前日志的用户导出。** signed-out事件只保留在匿名scope，现有设置上报只读当前账号，不自动把匿名历史转给下一个账号；上面的ZIP测试是对选定合成Journal的能力测试，不代表登录前用户已有导出入口。OpenSpec 2.1b4b继续未完成。SessionStore读取/写入专项事件、原生crash和音频诊断也不属于本批已实现范围。
- 新版本可读取旧无auth字段日志；未知auth.outcome归unknown、不透传额外字段。旧二进制对新增operation的降级兼容仍需发布专项，不据本批声称支持。

集中人工验收时，使用批准的一次登录联调核对脱敏结果及原流程；不要为了验证日志额外发送短信。未解决匿名导出前，不要求用户在当前账号设置上传中寻找先前signed-out事件。

## Agent事件分类正式接线（2026-09-20）

`DioAgentGateway`在账号/取消/会话校验后调用共享`recordAgentEvent`，沿原正式provider写入当前账号Journal。覆盖工具开始/完成/卡片、signal/final/error/status及timeline_committed；固定v65的16种工具、11种ResultType、16种持久事件均可分类。服务端未知名称只记unknown，不复制正文、参数、结果文本、payload键或不保证UUID的toolCallId；原assert任意type/payloadKeys输出已移除。

- JSON新增可选`agent`对象：固定`frame/signal/tool/ledger`、正安全整数`sequence`，sessionId/traceId沿原UUID白名单。`agent.sequence`是服务端ledger序号，绝不是本机上传watermark。
- `agentSignal`保留用于signal/error，其余结构事件为`agentEvent`。非error的`result=received`仅表示已接收，不代表工具成功、电话接通或任务终态；error为failed，流自身仍按既有终止语义记录started/succeeded/failed/cancelled。
- 不逐token记录text/thinking，也不记录heartbeat/done。旧无agent字段日志继续可读；未知可选分类读取时归unknown。只保证新版本读旧格式，**不保证降级旧二进制能读新增operation/result**，正式降级策略仍待发布专项。
- 新增9条：真实SSE→正式Gateway→Journal重建→实际ZIP；别名/未知/敏感字段、错会话、取消、换账号晚到、sink失败、900条增量帧不挤占结构日志；实际临时目录归档重建与watermark分离。日志及直接调用方112条定向通过，未运行全量。首轮命令把AccountApi测试路径写错而exit 1，其余断言通过；正确路径补测及最终完整定向集合均通过。
- 没有新UI、原生依赖或手机安装，不重建双端包；合成HTTP和本机临时目录不等于真实后台收件。登录请求、原生crash、SIP/ASR/TTS/音频诊断仍是开发缺口；这批也不覆盖HTTP历史读取的逐事件重放或工具执行端内部步骤。

## 当前状态：正式移动端加密归档（2026-09-20 续接）

以下状态覆盖后文历史批次的“尚未接正式App/最近256条”描述。Android/iOS正式`diagnostics_providers`现已选择文件Journal：保留含当天15个本地自然日，密文分片上限5MiB；Web/桌面仍用既有256条安全存储Journal，隔离MOCK仍为内存。256条现在只是移动端待写缓冲上限，不是持久归档容量；长期存储故障或突发超限仍可能丢待写事件，不承诺零丢失。

- 加密/事务/保留/一次导入/ZIP全部共享Dart。固定[cryptography 2.7.0](https://pub.dev/packages/cryptography/versions/2.7.0)提供AES-256-GCM，随机nonce、认证标签，AAD绑定scope摘要和文件名；索引也加密。每scope随机32字节密钥仅放现有安全存储，已有文件但密钥缺失时拒绝重建覆盖。密文编码开销计入5MiB，单分片明文最多3,932,128字节。
- Android使用App Support私有目录和已有`allowBackup=false`；iOS新增薄`DiagnosticDirectoryChannel`，只创建固定目录、设置并读回首次解锁后文件保护及排除备份属性。Keychain仍为`unlocked_this_device`，锁屏时读密钥失败可以导致暂存失败；未把目录保护当作锁屏写入保证。加解密在独立isolate执行，目录事务仍只保证当前isolate跨实例串行。
- 旧Flutter v1结构事件经原白名单解码，一次导入标记与分片在同一索引提交；之后才清旧槽位，清槽失败只重试清理。按导入日归档、原UTC事件时间不改。不会读取或复制旧Android任意文本日志。
- 每次准备至多4MiB原始JSON事件，ZIP超过5MiB拒发；`hasMore`提示剩余，成功后点击“继续准备剩余日志”，再显式上传。只确认本批最后序号；上传中新增事件保留。真实服务端当前大小限制/收件未验证，固定v65后端配置300MB不能代替线上事实。

### 本批实际证据

- 新增23条，日志模块81条；加AccountApi及扩展共享流程共91条定向通过，最终复验约14秒；analyze无问题。包括认证加密篡改/错误密钥/作用域、5MiB密文边界、一次导入/清理失败、在途追加、400条持久化和多批ZIP不丢不重；没有全量回归。
- Web普通目标Debug构建33.5秒；Android验证目标14.4秒、普通目标10.5秒构建成功；Mac iOS无签名构建134秒，解锁会话签名验证目标构建28.3秒并成功安装启动。Mac源码取样18份相同，pbxproj因CocoaPods生成引用/阶段和排序不同，关键签名/Bundle/部署目标无差异，新通道仍在编译源列表。
- 独立`tool/previews/diagnostic_storage_probe.dart`在两台真机调用正式文件工厂及真实安全存储，用每次新建的合成scope写400条→重建读取400条→小预算ZIP34条→新增1条→仅本地确认→剩367条；两端`completed/cleanup/encrypted/recreated=true`，iOS目录保护核验为true。探针无业务HTTP、登录、短信或媒体调用，不等于抓包证明所有系统网络为零；不是零存储MOCK。仅删除自己的合成scope文件及两个合成安全存储槽位，不清用户日志。
- iOS已恢复普通`lib/main.dart`，实时VM返回`ios/main`，screen保持分离。Android UID和首次安装时间未变，但普通包自动恢复被执行策略拒绝；未绕过重试，已请用户手动保留数据覆盖恢复，22:45只读包时间仍为探针安装时间。**普通包恢复及当前登录待确认**，不是已恢复登录。
- 附加`flutter test --platform chrome test/features/app_logs/log_report_page_test.dart`停在loading超过8分钟，确认同一测试/Chrome进程仍活后Ctrl+C结束（exit 1）；未归为测试断言失败，也未标此命令通过。随后用独立`tool/previews/log_batch_preview.dart`（390宽，真实压缩合成ZIP、纯内存模拟上传，不装配账号/存储/HTTP）启动8123，最终编译8.4秒。浏览器实测34条/161字节→模拟上传→继续准备→17条/158字节且仍需显式上传→完成仅返回按钮，新增分批交互通过；不是移动端文件归档或服务端收件证据。

### 仍需完成/集中验收

Agent工具类型已由上节正式接线；原生崩溃、登录请求、SIP/ASR/TTS/音频诊断仍未迁移，是开发缺口。真实后台收件、锁屏/重启密钥可用性、系统强杀/断电、实际15日运行与跨时区保留是待设备/人工验收；本批不以合成事件替代这些结果。Android普通包恢复仍单列待核验。

## 2026-09-20：15天文件归档底层（尚未接正式App）

新增 `core/diagnostics/diagnostic_archive.dart`、`diagnostic_archive_files.dart` 与 `app_logs/data/directory_diagnostic_files.dart`。固定v65 `AppFileLogger` 实际为含当天15个本地自然日、5MiB单文件轮转，不是整机logcat，也不是最近256条。归档共享Dart实现，不复制旧任意文本/正文日志；现有 `DiagnosticEvent` 白名单继续约束字段。

- `append`：不可变新分片→flush→原子替换索引为提交点。同日未满时最多重写一个分片，跨日/满片新开；单批超限直接失败，不截断。提交后不再执行会抛错的回收，避免已保存却报告失败导致重复追加。
- `snapshot`：按本地日期清过期索引、验证大小/SHA256/序号/事件，再返回未确认事件及水位；不接受丢失/损坏索引或分片为“空日志”。UTC事件时间不决定写入日期，时钟回退不删除未来日期分片。
- `acknowledge`：先持久确认水位，再删完全过期/已确认分片；部分分片仅过滤旧序号，之后写入不复活旧事件。清理失败可重试，不包含HTTP调用。清空、过期和重启不重用序号。
- 目录适配只访问调用方私有根目录内的SHA256(scope)子目录；严格文件名、不递归删除、不清未知文件。相同规范路径在当前isolate跨实例串行，不保证跨进程/isolate写入。临时文件flush+同目录rename不是突然断电时目录fsync的保证。
- 21条新增、日志相关共58条定向通过（测试阶段约4秒），包括真实4万条跨5MiB轮转、15日边界/跨年/时间回退、UTC与归档日分离、并发、索引/分片写失败、真实pending路径阻塞、清理失败/重试、损坏/丢失、scope/未知文件和脱敏。全部使用Windows新建临时目录，结束仅删除这些测试目录；没有修改或删除手机日志。

**正式App仍为最近256条。** 本子批没有改变Journal/provider/ZIP、UI、插件或原生端口；不需要重打手机包或重跑全量。下一子批2.1b2b仍须完成平台私有目录保护、旧Flutter结构日志衔接、Journal缓冲接线、ZIP/接口大小上限处理及双端构建/设备验证；归档文件当前未加密，不能直接接生产替代原安全存储。原生崩溃和音频诊断仍属开发缺口，不是仅待人工收件。

## 2026-09-20：共享运行时异常补齐

正式`main.dart`在ProviderScope内装配`RuntimeDiagnosticsHost`，由独立`RuntimeDiagnosticHooks`观察Flutter框架及主isolate未处理异常。新增`operation=flutterFramework/dartUnhandled`、`result=failed`及可选`failureKind`（framework/platform/missingPlugin/timeout/format/state/argument/assertion/other）。旧事件无此字段仍可读取；不调用异常toString、不保存message/details/stack，固定分类只能定位故障类别，不能单独证明根因。

原错误处理器仍收到原对象和堆栈，其返回值和抛错不改变；没有原平台回调时返回false，不伪装已经处理。宿主卸载停止记录，只恢复自己仍拥有的钩子，不覆盖后来的接管者；当前项目未创建额外错误Zone，此装配不新增Zone。独立preview入口不接全局钩子。

异常发生时同步选定当前账号journal，立即尽力串行flush，不等待500ms；存储失败不引出第二个未处理异常，内存事件仍可随后准备/保存。**不是同步崩溃落盘保证**：宿主挂载前的初始化、子isolate、Android/JVM/Swift原生崩溃和系统强杀不在此捕获范围，15天归档/音频诊断仍需开发。

- 新增13条测试：类型及隐私白名单、原处理器/返回/抛错、重入/释放/接管、即时保存/关闭、真实Provider账号切换与安全存储、实际ZIP准备不上传、保存失败及正式main登录页接线。
- 日志+登录/会话+共享首页/开发者连续流程共46条定向通过（测试阶段11秒）；analyze最终无问题，初轮两处冗余import已移除。未全量、未新增依赖或原生构建/安装、未上传真实日志。
- 后续集中验收：含本批版本出现实际Flutter错误后，在保持原报错行为的同时核对ZIP固定类型和时间；不要通过令App原生崩溃来声称验证本批，也不要添加真实错误触发按钮到生产设置页。

## 状态与来源（2026-09-17）

已实现跨平台采集、账号隔离存储、真实ZIP压缩、上传协议和设置页面；本批没有向真实服务上传日志，没有新设备安装或iOS构建。Web合成演练通过不等于服务端收件已验收。

行为参考Android v65 `4c781e3` 的 TaskApiService / TaskRepository / AssistantLogUploadRuntimeController：`POST api/logs/upload`，multipart字段`file`、`accountId`、`deviceInfo`，成功后清理。后端 ClientLogService/ClientLogDtos 返回账号、文件名、大小、SHA256和上传ID。未复制旧App任意文本/对话正文日志。原型没有完整上报页面，本轮复用Flutter语义控件与既有竖屏容器；视觉后续校准。

## 实现及边界

| 位置 | 职责 |
| --- | --- |
| `core/diagnostics/diagnostic_event.dart` | 固定operation/result枚举、UTC时间、状态码/耗时、合法UUID关联；不接收任意文本 |
| `diagnostic_journal.dart` | 最近256条，500ms批量写入，串行加载/快照/清理；读取失败不覆盖旧数据，写失败保留内存 |
| `app/diagnostics_providers.dart`、`app_logs/data/secure_diagnostic_store.dart` | 环境/API/账号命名空间；同账号进程内复用Journal；现有安全存储插件，无新原生实现 |
| `core/network/account_api.dart`、`conversation/data/stream/dio_agent_gateway.dart` | 账号请求结果及Agent流开始/信号/错误/结束；采集异常不改变业务返回，不记录正文、号码、URL、凭据或异常全文 |
| `app_logs/data/zip_log_repository.dart` | 快照压缩为ZIP内的`diagnostics.jsonl`；multipart上传与返回校验；清理只确认快照watermark |
| `app_logs/presentation/controller/log_report_controller.dart` | 准备→待上传→上传→成功/失败/清理失败；防重复，关闭页面不发布晚到状态 |
| `app_logs/presentation/pages/` | 正式Route和共享页面；独立内存合成Preview，无真实网络或账号存储依赖 |

ZIP依赖固定为[archive 3.6.1](https://pub.dev/packages/archive/versions/3.6.1)，使用纯Dart `archive.dart`，Web/Android/iOS共用，不引入原生压缩插件。

正式页打开只在本地准备快照，点击“上传诊断日志”才发送。沿v65使用`X-Account-Id`和表单账号，不新增Bearer；沿用AccountApi的登录世代检查，不自动重传POST。返回的正数ID、账号、文件名、大小、SHA256全部匹配才确认成功。上传中产生的新事件保留；清理失败只重试本地清理，不重复上传。网络结果未知时明确提示重试可能产生重复报告，未伪称服务端幂等。

与旧实现差异：固定v65 AppFileLogger导出App自行写入的15天轮转文件，并非采集整机logcat。当前仍为最近256条结构化事件，不导入旧日志；覆盖账号请求、Agent流及上方共享运行时异常，尚无登录请求、完整工具类型、native crash、SIP/ASR/TTS/媒体诊断。`deviceInfo`为Flutter平台/编译版本说明，不读取硬件标识。结构化ID仍可能关联用户会话，因此真实上传保留显式操作，不后台自动发送；不能声称绝对匿名或完整故障诊断已完成。

## 自动与浏览器证据

- 新增27项：有界/重建/账号命名空间、读写失败、watermark并发、未知字段过滤、真实ZIP解压、multipart/响应校验、跨账号禁发、上传/清理失败、单飞/关闭、Agent日志异常不影响输出；320/390/430宽页面、返回与MOCK失败→成功。
- 全量907项通过；`flutter analyze`无问题；Web dev和Android Debug构建通过。纯Dart依赖没有新增原生通道，但本批未做iOS编译与设备验证。
- 浏览器复用既有登录，正式设置→日志页本地准备4条/271字节；未点击正式上传。进入MOCK后1条合成日志真实压缩，第一次模拟失败，显式重试成功。页面无明显溢出，非像素级视觉验收。

## 集中人工验收（尚未执行）

1. 安装含本批的测试包，保留登录，在测试环境操作一次正常查询/文字对话，再从设置进入日志页；应有条数和ZIP字节，页面打开不得产生`/api/logs/upload`请求。
2. 明确同意向测试环境发送这份诊断数据后点击上传。管理后台核对时间、accountId、originalFileName/fileSize/checksumSha256和正数id；下载ZIP只有`diagnostics.jsonl`，事件字段限定为time/operation/result/statusCode/elapsedMs/sessionId/traceId及可选固定枚举failureKind。禁止正文、token、手机号码、身份证、整本通讯录、原始异常及堆栈。
3. 对照后端会话UUID和UTC时间窗排查；无合法UUID的事件不输出对应字段，不补造。`succeeded`表示请求/流传输完成，不代表任务/电话成功；业务错误信号有failed事件。
4. 断网上传应显示结果未确认并保留快照；不自动循环重试。恢复后用户决定是否重试，允许服务端出现重复报告，不计为幂等通过。
5. 上传期间制造另一条查询：上传成功仅清旧快照，新事件下次仍可见。模拟存储清理失败时必须显示“已上传，本地清理失败”，重试不得出现第二次POST。
6. 关闭页面、切账号/环境后旧结果不得污染新页面，旧快照不得以新账号发送。MOCK压缩/失败/成功不产生真实服务记录，也不清正式日志。
7. 双端核对安全存储、应用重启后最近事件恢复；最后统一校准字体/间距/安全区。原生崩溃与音频采集后另补相应日志验收，不把此批当作完整日志迁移结束。
