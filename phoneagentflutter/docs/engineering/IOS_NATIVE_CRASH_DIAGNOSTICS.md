# iOS 原生崩溃诊断合同

## 采集与上传

独立本地 Pod 使用固定 PLCrashReporter 1.12.0，Mach 异常模式、关闭即时符号解析。App 启动请求初始化；初始化在串行后台队列完成。原生采集器只安装一次，不随页面、认证或账号重复安装，不调用认证 SDK、相机、麦克风或音频会话 API。

崩溃由库写入原生报告，下一次启动正常线程解析。customData 只附加当前诊断 scope 哈希和进程 runId，不包含账号原文。未完成账号绑定的报告不归给后来登录的账号。正常登录、恢复前台和用户准备日志 ZIP 时导入；上传准备只读取所属账号，不改变当前绑定。沿用原上传入口和 API，不新增第三方上传。LLDB 已附加时不安装 Mach 处理器，避免争抢调试异常；生命周期观察仍可工作。

账号变更在合法 bind 通道接收时直接投递时序队列，不能绕过崩溃 IO 队列后才更新，避免后续 prepare 先绑定旧账号。崩溃库 customData 由主线程独占的 `PACrashAccountBinding` 更新，只做内存赋值；初始化、恢复及 enable 在后台完成后才发布 reporter，发布时应用最新绑定。禁止增加第二个后台 setter 或重复初始化已发布实例；未发布期间保持未绑定，不沿用旧账号。

先将脱敏摘要写入独立原生存储，再删除库的原始报告；Flutter 日志持久化成功后才确认删除摘要。原生摘要最多 32 条、七天保留，最多 128 个去重身份；写失败不伪装成功。跨进程在持久化与确认之间中断可能重投，保留同一身份供关联，不宣称 exactly-once。私有文件采用首次解锁后的数据保护、原子写及备份排除。

## 可导出的字段

新报告 `iosNativeCrash` 携带 `iosCrash.schema = 2`，兼容已有 schema 1。包含崩溃时 App 版本和 build、系统版本、设备型号、CPU 架构、信号、signalCode、faultAddress、异常名白名单、runId、原始线程/帧数量及截断标志。最多 1024 帧，优先异常来源栈（48 帧）和故障线程（每线程 64 帧），其余线程每线程最多 32 帧。帧包含线程号、是否故障线程、镜像 basename、UUID、加载基址、指令地址和偏移；线程号 -1 表示 Objective-C 异常来源栈。faultAddress 是异常访问地址，不能当作代码 PC；调用者帧的返回地址也不能当作故障指令。

禁止导出原始异常 reason、寄存器、完整文件路径、内存内容、认证 token、身份证和录音数据。原生投影和 Dart 解析分别控制字段。现有 Android 原生摘要不要求新增 platform 字段，旧格式仍可读取。

## 认证与跟读前后时序

独立 `IdentityCaptureTrace` 观察器只在已经开始的原生认证会话内监听系统通知；`PAIdentityTrace` 负责技术事件，`PAIdentityTraceStore` 负责持久化。认证薄适配只添加阶段记录，不改变参数、通过条件、SDK 调用顺序、回调分发或音频控制。不会 swizzle、读取 SDK 私有成员、给 recordTime 加锁，也不会为了日志启动 ReplayKit。观察器只读取音频 category、mode、采样率、输入/输出端口类型，不修改音频状态、不保存音频或设备名称/UID。

每条 `iosIdentityTrace` 是正常生命周期证据，不是崩溃事件。其字段如下：

| 字段 | 用途 |
| --- | --- |
| runId、runnerUUID | 区分进程重启和同版本的不同二进制；与崩溃报告关联 |
| appVersion、appBuild、osVersion、deviceModel | 使用当前进程实际安装信息 |
| configuredSdk | 当前工程固定的供应商版本声明；不是运行二进制校验结果，升级时必须同步核对 |
| session、actor | session 为真实原生会话字符串的稳定 SHA-256 派生 UUID，兼容 `identity-时间戳-序号`，不改业务 session；actor 关联插件实例，不代表 SDK RecordWriter 实例 |
| seq、time、monotonicUs、queueLagUs | 持久化顺序、UTC 毫秒、单调时间和日志排队耗时；跨线程用时间与线程一起判断，不把落盘顺序当成业务执行因果 |
| thread、main | 原调用线程 ID 和是否主线程；SDK 原始回调与派发主线程后的记录分开 |
| flags、code | 阶段状态位、SDK 数字返回码或阶段结果，不包含认证载荷 |
| dropped、writeFailures、unbound | 环形覆盖/排队丢弃、写入失败和未绑定账号事件数；缺失日志不能当作业务未发生 |

覆盖阶段：prepare 进入/复用/占用/就绪；SDK 初始化与 metainfo 前后；capture 接受、页面显示、权限进入/结果、音频准备前后；SDK verify 调用前/返回、原线程回调/主线程回调/过期回调、已有异常分支；finish/重复完成/是否回复、关闭页面、abort/过期取消、reset、等待释放、engine detach、插件释放；试听音频准备及返回。通知覆盖前后台、失去/恢复活跃、终止通知、内存告警、音频中断/恢复选项、路由变化、媒体服务丢失/重置。系统终止通知不保证发送。

薄适配 `note` 的 flags 位：1=当前持有者、2=inFlight、4=cancelled、8=detached、16=finishing、32=dismissing、64=有 captureHost、128=有 pending 回复。后台 `sdk.callback`、插件释放和试听返回不读取插件状态，flags=0 表示未采样，不能解释为全部状态为 false。系统音频中断的 flags 独立表示系统 interruption options，code 表示 interruption type；路由变化 code 表示系统 reason。权限结果 1/0 表示合并授权结果；preview.result 的 code 1 表示有错误回复；SDK 异常 code 1/2 分别为准备/执行阶段。

事件异步写入专用串行队列，不在主线程执行文件 IO。每个账号与进程的文件保留最新 128 个事件，队列最多 256 个待处理事件；全局最多 32 个文件、七天保留，每文件最多 256 KiB。单次读取优先最近的最多 28 个进程快照，加最多 4 份崩溃报告，符合现有通道 32 条上限。剩余记录在下次恢复或上传准备时继续导入。运行快照每次内容变化产生不同身份；确认旧快照只能删除该快照水位及之前的事件，之后的新事件必须保留。

账号范围由独立 `PAIdentityTraceScope` 在首次 prepare 时绑定；试听音频准备有独立诊断操作身份，异步结果继承开始时账号。换账号后的旧会话回调仍属于旧账号，缺失绑定或超出会话映射容量的记录不转归新账号。原生文件受系统数据保护且不备份；导入后沿用现有 Flutter 诊断存储。已经保留的原生快照不受 WARN/ERROR 对普通实时日志的裁剪，必须真正写入后才能 ack，不能伪装崩溃来提高日志级别。崩溃可能中断尚未落盘的尾部事件，磁盘满、系统强杀也可能留下空缺；本实现不声称无损记录全部 SDK 内部访问。卸载/清数据会删除未上传证据，复现后应先重启并从原入口上传。

## 可诊断范围与符号

采集只对安装新实现后、处理器已启用且账号绑定后的可捕获崩溃生效。不能补采历史事故，不能保证记录 OOM、系统强杀、用户划掉、初始化之前或其他 SDK 接管后的故障。无报告不能推断没有崩溃；有报告也不等于已确认业务根因。

每个交付构建归档匹配的 Runner 二进制、dSYM、Git SHA、版本和 build、依赖锁文件。用 `dwarfdump --uuid` 校验 UUID 后，按相应架构和镜像基址执行 `atos`。同一版本号重复构建也必须按 UUID 匹配。静态认证 SDK 的地址可能归入 Runner；供应商未提供符号时，保留 UUID/偏移并申请相应符号，不猜测函数名。

## Mac 验证

先按项目既有方式准备被忽略的构建输入和 Flutter 3.32.0。运行 CocoaPods 安装并核对新增依赖锁，仅接受本地诊断 Pod 与固定 PLCrashReporter 的必要变化，不执行全量升级。

`tool/run_ios_crash_native_tests.py --framework <PLCrashReporter-1.12.0 的 macOS CrashReporter.framework>` 编译并执行生产投影/存储代码。用真实库 live-report 验证解析，另覆盖账号隔离、重启持久化、重复确认、保留期、容量、IO 失败、快照读取后追加事件、旧快照确认保留新事件及环形覆盖计数。它不是 iOS 插件链接或真实崩溃验收的替代品。

iOS 需完成 Debug 与 Release 真机架构构建、Pod/Swift 链接、隐私清单/许可证打包检查。独立测试构建脱离调试器运行，覆盖认证 SDK 初始化前后、主线程和后台原生异常，重启后从原入口生成日志 ZIP，检查实际堆栈、UUID、身份和重传。主动崩溃只能在独立测试宿主或明确的本地测试编译条件内，不能合入正式用户入口。

正常流程验证：认证成功、认证拒绝、主动取消、跟读失败重试、前后台/权限变化、退出后音频释放、克隆生成与试听。不得通过修改音频锁、供应商回调、认证判定或计费来让诊断测试通过。采集器失败不得阻塞原流程。实际认证使用测试环境和授权的测试身份，不自动触发付费克隆。

## SDK 升级评估边界

当前认证 SDK 为固定 AliyunIDPro 2.3.50。本次不替换其二进制、资源、认证薄适配或音频配置。

截至 2026-10-21，[阿里云官方发布记录](https://help.aliyun.com/zh/id-verification/financial-grade-id-verification/product-overview/sdk-release-notes)列出 iOS 2.3.53（2026-10-16），包含偶发崩溃和存证上传修复、异步 metainfo、安全组件及 iPad 窗口适配。官方包 MD5 为 `a7d7dd1c34d21c248b4f1c1b60344ed8`。没有具体故障栈对应说明，不能据此宣布修复了本次跟读闪退。

推荐作为单独候选验证：先核对官方包及完整 framework/resource/privacy manifest，再对比公开 API、支持架构、依赖符号、取消语义及 metainfo。保留当前公开 API 调用和服务端核验合同，不能仅替换一部分关联 framework。先在当前 SDK 验证采集共存，再单独验证升级；取得真机正常流程和故障证据后决定是否采用，保留 2.3.50 可回退基线。

采集库依据：[PLCrashReporter 1.12.0](https://github.com/microsoft/plcrashreporter/tree/1.12.0)。处理器共存是必须实测的集成约束；Mach 模式不代表所有第三方处理器组合天然兼容。
