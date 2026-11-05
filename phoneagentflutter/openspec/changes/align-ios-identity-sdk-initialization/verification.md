# 验证记录

## 已确认范围
用户批准只对齐 iOS 初始化生命周期，随后再次明确 Android 不变。实施基线 test_v1.8.0_fix@d678e713。生产修改仅 IdentityCapturePlugin.m 与新增 IdentityCaptureSDKInitialization.h/.m；Dart、Android、UI、业务参数、采样率、音频配置、线程及供应商文件不变。

## 自动回归
- RED：先让保护器沿用逐次执行 initializer 的旧策略，原生回归失败于 `new sessions and callers reuse process initialization`。
- GREEN：`python3 tool/voice_clone/run_identity_sdk_initialization_test.py`，两个独立进程各 7 断言通过。执行生产保护器，覆盖启动不初始化、异常原样传播、异常后显式重试、调用线程保持、25 个调用方复用、后续业务异常不清标记、新进程重新初始化；未调用供应商 SDK 或音频 API。
- `flutter test --no-pub test/features/voice_clone test/features/app_logs/ios_identity_trace_test.dart`：544 通过、3 失败。失败均为 clone_entitlement_route_test.dart 中会员导航结束后的 500ms 遗留计时器；单文件复验 4 通过、3 失败。
- 隔离快照恢复 HEAD 原版 IdentityCapturePlugin.m 后，同一个会员导航测试文件仍 4 通过、3 失败，名称和 pending timer 断言一致。Dart/测试代码未修改，未放宽断言、未改变 UI 来消除此既有失败。
- `flutter analyze --no-pub`：无问题（40.6 秒）。
- OpenSpec 本 change 严格校验通过。
- 现有 `tool/voice_clone/run_identity_audio_test.py` 在本次独立创建的 iOS 26.3 模拟器执行，10 断言通过；完成后已关闭并删除该测试设备。只使用假音频会话，没有访问真实麦克风或 SDK。

## 编译与依赖边界
主工作区 `pod install --deployment` 在依赖一致性检查退出：已安装 Pods/Manifest.lock 包含既有 PhoneAgentCrashDiagnostics，但版本化 ios/Podfile.lock 缺少它。没有修改主工作区 Podfile.lock 或引入依赖升级。

构建使用独立、哈希核对的当前工作区快照，快照 SHA256：2179a274e348c428de9127d418aea0b058c63c4112ae2cacffaa88a7e744ac43。仅快照内按现有安装 Manifest.lock 准备依赖，Dart 锁文件依照既有打包脚本做镜像 URL 转换，无版本升级。隔离 CocoaPods deployment 准备通过。该例外不代表根仓锁文件已修复。

- 隔离快照 iOS Debug 无签名 arm64 真机架构构建通过（Xcode 58.1 秒）。首次 Release 误沿用 dev 参数，既有环境一致性门禁拒绝；未修改门禁，随后使用已有 prod 构建输入完成 Release 无签名 arm64 构建（Xcode 41.9 秒）。仅编译，不连接业务服务或发布。
- 实际构建版本为源码中的 1.0.54（47），不是用户手机已安装构建的替代证据。新增保护器方法在 Debug 和 Release 链接产物及 dSYM 中均可定位；三个生产文件与构建快照逐字节核对一致。
- Debug 实际代码位于 Runner.debug.dylib，UUID `4FDF4312-1EF6-30A2-883C-9932626761AE`；Runner 启动壳 UUID `EE7AB58A-CEB0-3C7F-BC7B-C93D89CF58DE`。Release Runner UUID `1FF67521-D3D6-38CD-96FA-921959A77E63`。已保留代码镜像/匹配 dSYM 和构建证据于本次隔离工作目录的 debug-symbols / release-symbols。供应商预编译库存在缺失调试模块警告，不能承诺完整供应商私有符号。
- 最终差异核对：原插件除新增 import 和包裹原 initSDK/前后诊断外，其他字节与 HEAD 一致；android、lib、test、pubspec/锁、Podfile/锁及 Vendor 均无修改。新增初始化保护仅持有 BOOL，无账号或认证内容。
- 没有覆盖安装或启动用户真机 App，没有认证、上传个人音频或触发收费克隆。

## 真机待验回放
| 编号 | 场景 | 验收要求 |
| --- | --- | --- |
| IOS-INIT-01 | 冷启动后首次发起认证采集 | 本进程首个 prepare 有一次 sdk.init.enter/exit，仍有本次 sdk.meta.enter/exit 与服务端认证身份 |
| IOS-INIT-02 | 跟读失败后重新开始、取消后重进、插件重建 | 不重复 init；每个新会话重新获取 MetaInfo 并传递本次 certifyId；相机、麦克风及租约沿用原释放条件 |
| IOS-INIT-03 | 切换账号、旧回调迟到 | 初始化状态不携带账号数据；新旧会话/结果隔离，旧回调不得污染新账号 |
| IOS-INIT-04 | 试听→采集→试听、语音输入/TTS/通话交接及前后台 | 每次实际采集仍做原录音配置，既有音频与 UI 交互保持；关联 VOICE-01/03，不改变播报规则 |
| IOS-INIT-05 | App 进程重启、诊断共存及授权的独立崩溃测试 | 新进程首次 prepare 重新初始化；报告回放/账号隔离不变，保存匹配 UUID 的符号，不把无报告视为无崩溃 |

真机正常 SDK、实际音频与崩溃重启回放尚无本次新构建证据。自动测试、模拟器及无签名构建不能代替，change 保持 active，不声称声音克隆失败已经解决。

## 本地证据位置
- 构建/基线复验/符号：`.local/voice-clone/ios-init-validation-vlzx719_/`（隔离快照与本任务独立产物，未提交）。
- 相关 Dart 回归：`.local/voice-clone/ios-init-flutter-tests.log`；会员路由复验：`ios-init-entitlement-recheck.log`。
- analyze：`.local/voice-clone/ios-init-analyze.log`；原生音频回归：`ios-init-audio.log`。
- 原仓 deployment 失败：`.local/voice-clone/ios-init-pods.log`；没有顺带更改根仓依赖锁或 Android 配置。
