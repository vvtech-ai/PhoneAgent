# 验证记录（2026-10-21）

基线 `ee1d309fe365476bd9175acbc9aa1f492f414ac8`，Flutter 3.32.0，Windows。当前诊断实现尚未完成 iOS 发布验收。

- 首轮新增回放失败：iOS provider 未启用、摘要被识别为 Android、缺少 iOS 明细仍被接受。修复后新增 5 项通过。
- `flutter test --no-pub test/features/app_logs --reporter expanded`：114 项通过，包含既有 Android、上传、账号隔离、持久化和新增 iOS ZIP 回放。
- `flutter test --no-pub test/features/app_logs test/features/voice_clone --reporter expanded`：650 项通过、3 项失败。
- 单独执行 voice_clone：536 项通过、相同 3 项失败。
- 未修改基线导出到独立临时目录，执行 `clone_entitlement_route_test.dart`：4 项通过、相同 3 项失败。失败用例为 account change while upgrading、return without upgrade、upgrade opens membership；均为退出时残留 500ms Timer，来源 `PurchaseController.dispose → CommerceDiagnostics.event → DiagnosticJournal.record`。不属于新原生诊断路径；本次不改变会员业务或删断言。
- `flutter analyze --no-pub`：无问题。初次 3 条花括号 lint 已修正后重跑。
- 认证 SDK Vendor、IdentityCapturePlugin、认证控制器、克隆控制器和音频租约业务源码没有修改。

## Mac 仍需完成

1. CocoaPods 实际解析并更新锁文件，原生测试编译执行，Debug/Release 真机架构构建；Windows 没有生成或伪造 Pod 锁文件。
2. 独立测试构建在无调试器情况下制造可捕获故障，重启后使用原日志入口验证实际报告；认证 SDK 初始化后再次验证处理器共存。
3. 真机正常认证、跟读、取消/失败重试、前后台和音频释放回归；不得以 Flutter 模拟通道通过代替这些证据。
4. 按 UUID 验证对应 dSYM 可符号化；检查最终隐私清单与许可证。
5. 认证 SDK 2.3.53 目前仅完成官方发布说明评估，没有下载替换、二进制兼容或真机验证；继续保留 2.3.50。

此批只补诊断能力，不声称已经修复此前的跟读闪退，也不能补采旧版本的原生堆栈。没有提交、推送或打包。

## 2026-10-22 原生时序扩展

本轮基线为 `668ffca7c1a7e27c6110bf8fc14ab1e0626c013a`。收到 `phoneagent-ios-root-cause-mac-evidence-20261021.zip`：Mac 为 `4901807539192d1b13258fd90ad24edcf6144021`，尚未接入此前原生采集补丁；没有事故对应 Runner UUID/dSYM、没有实际认证/克隆复现。静态证据增加了主线程计时器读取 RecordWriter.recordTime 的路径，但没有运行期并发访问或对象释放证明。因此不把竞争或释放时机当作已确认根因，不升级 SDK、不加锁、不 swizzle。

本轮将 IdentityCapturePlugin 的阶段观察接到独立 IdentityCaptureTrace、PAIdentityTrace 和 PAIdentityTraceStore；只新增技术观察，保持原有 guard、SDK 参数、业务返回、权限请求和音频配置。SDK 返回码在原有过期回调 guard 之后、复用原 payload 读取；诊断不提前读取被丢弃的 SDK 返回对象。供应商 Vendor、认证音频配置、试听音频实现、Flutter 认证/克隆业务控制器未修改。前述 10 月 21 日“IdentityCapturePlugin 未修改”只描述前一批，本轮明确新增观察点。

### 本机已执行

- 新时序解析先以未实现状态验证失败（1 失败 / 2 通过），实现后通过；再补持久化失败和 ack 失败连续回放。
- `flutter test --no-pub test/features/app_logs --reporter expanded`：**118 项通过**，涵盖新时序导入、重新读取、ZIP、敏感字段剔除、错误重试、已有 Android 和上传流程。
- 扩展执行 app_logs + voice_clone：**653 项通过、3 项失败**（随后新增的第 4 个时序用例已在上述 118 项中单独纳入）。单独复核 clone_entitlement_route_test.dart：4 通过、相同 3 失败，仍是会员页面退出残留 500ms Timer，与前批基线证据一致。本次不修会员业务、不删断言。
- `flutter analyze --no-pub lib/core/diagnostics lib/app/native_crash_host.dart lib/app/log_report_providers.dart lib/features/app_logs test/features/app_logs`：无问题。
- `git diff --check` 通过；中文文档按 UTF-8 读取核对。

### 需要 Mac 执行，尚未通过

- 原生生产存储测试已经加入读取后追加、旧水位 ack、账号隔离、重启、环形覆盖和 IO 失败；Windows 未执行 Objective-C 测试。
- 尚无本次 CocoaPods 锁文件、Debug/Release 编译和正常认证/跟读/克隆真机证据。
- 尚无实际 crash → 重启 → 原入口 ZIP 的证据；需要先验证采集器与 SDK 共存，再投放给测试。LLDB 下跳过 Mach 处理器，不得在附加调试器时误判不能捕获。
- 原生队列持久化耗时、尾部空缺和迟到回调 scope 隔离仍需设备验证。不宣称一定能捕获全部 SDK 内部访问或保证下次直接锁定根因。

### 提交前复核与远端整合

- 用户授权本机校验后提交推送，由 Mac 后续拉取构建；不再交接待手工应用的代码补丁。
- 远端新增 7 个提交，已快进到 `6689ec495069e55a2568d26f47acd47ddc2cf14d`。保留最新试听音频交接修复和 `canPrepare` 弱引用门禁；本批相对该基线不改 Android 源码、供应商二进制、认证音频配置、试听音频控制和 Flutter 认证/克隆业务文件。
- 独立审查发现并修正真实原生 session 不是 UUID、试听异步操作账号归属、WARN/ERROR 过滤后误 ack、bind 经慢 IO 队列后执行导致账号错归。仅修诊断身份、持久化和账号绑定，不修改业务 session。
- WARN/ERROR 两个回放先失败再通过；完整时序测试 6 项通过。原生测试源码覆盖真实 session 格式、A→B 迟到回调、未绑定不猜账号、晚发布 reporter 应用最新账号、A→B→A 和退出清空；原生执行仍待 Mac。
- 完成上述远端整合后的 `app_logs + voice_clone + auth`：**795 通过、3 失败**。失败仍是相同会员页面计时器用例，没有新增失败；Android/iOS 平台变体、认证参数/取消释放、正常克隆、试听和诊断回放均在本次套件内。此次没有真实认证或付费克隆。
- 诊断范围静态检查再次通过。提交不会把原生编译及真机验收标成已通过；OpenSpec 中对应任务继续未完成。
- 最终推送前又同步 2 个无重叠的来电批次展示提交，基线为 `168be837700ae0756dc7c962e963d774d8f5bedf`；诊断、认证、克隆及其回归文件未被这两个提交修改。独立复审确认没有剩余必须修复项，保留原生验证缺口。
