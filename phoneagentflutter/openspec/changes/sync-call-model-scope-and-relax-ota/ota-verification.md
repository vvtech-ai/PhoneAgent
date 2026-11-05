# OTA 客户端版本交接验证（2026-10-16）

## 范围与实现

- Flutter `app_update` 数据解析、启动恢复和包证据取消“目标版本必须较大”及“后台版本必须与 APK 内相同”的客户端拦截；继续要求版本字段格式合法。后台 `hasUpdate`、发布/发现规则与接口字段不变。
- 保留包名、兼容签名、大小、SHA256、scope/job 归属及系统安装权限校验。安装前 Android 仍重新读取并校验 APK，不能凭 Dart 调用传入任意文件路径。
- 新增 Android-free `UpdatePackageEvidence.kt`，承载 APK 身份/完整性与实际安装回执规则；`UpdatePackageInspector.verifiedFile` 使用该规则，不比较当前、后台和 APK 版本大小或相等性。
- `UpdateDownloadStore.peek` 不再按目标版本 `<=` 已安装版本清任务。通过原生复核后记录安装前 `lastUpdateTime` 与候选 APK 摘要；后续只有安装时间推进、当前安装 APK 摘要与回执完全相同时清本 scope 任务。取消/失败、安装其他 APK、缺少旧回执均保留恢复入口。旧记录没有回执时保守恢复，不猜测安装成功。
- 不改变权限授权、显式下载/安装、账号晚到保护、强制更新提示和安装器返回不代表成功的既有状态流。

## RED

先修改测试，未修改实现时运行：

```powershell
D:/tools/flutter-3.32.0/bin/flutter.bat test test/features/app_update/app_update_api_test.dart test/features/app_update/device_update_install_port_test.dart test/features/app_update/update_install_controller_test.dart --reporter expanded
D:/tools/flutter-3.32.0/bin/flutter.bat test test/features/app_update/startup_update_controller_test.dart --reporter expanded
```

分别为 45 通过/6 失败、17 通过/3 失败。失败明确来自 API/peek 对同号及低号拒绝、安装前清任务而未交接、启动恢复丢失或 manual 抛版本错误。旧低号/元数据差异拒绝用例改为允许交接，同时保留包名、签名、大小、摘要及非法版本格式负例。

第二微批补版本格式保护测试，先复现 27 通过/1 失败：空后台版本仍被证据接受；补回非空及正数格式检查后通过。日志：`.local/ota-dart-red.log`、`ota-startup-red.log`、`ota-format-red.log`。

## GREEN 与编译检查

| 验证 | 结果 |
| --- | --- |
| `flutter test test/features/app_update --reporter expanded` | 最终 145 项通过，覆盖 API、启动/手动、peek、恢复、安装交接、权限及页面 |
| `flutter analyze lib/features/app_update test/features/app_update` | 无问题 |
| Kotlin 2.1.0 / JDK 17 / JUnit 4.13.2，执行 `UpdatePackageEvidenceTest` | 6 项通过：版本交接、安全负例、取消/不同 APK 不清理、安装时间推进且同摘要清理、缺/坏证据不清理 |
| Kotlin 编译 `UpdateRelease.kt`、`UpdateDownloadStore.kt`、`UpdatePackageEvidence.kt`、`UpdatePackageInspector.kt`，classpath Android SDK 35 `android.jar`，JVM target 11 | 退出 0；覆盖新增规则到原生检查与持久化的实际接线 |
| 定向 Dart 格式化、UTF-8 中文读回、`git diff --check` | 通过 |

Kotlin 使用本地已缓存编译器与 JUnit，复现脚本 `.local/ota-native-check.ps1`；输出 `.local/ota-native-final.log`。Flutter 最终输出 `.local/ota-dart-final.log`、`ota-analyze.log`。

曾启动 `android/gradlew.bat :app:testDebugUnitTest --tests '*ota.UpdatePackageEvidenceTest' --offline --console=plain`，进入 `compileFlutterBuildDebug` 后按主线程协调终止（退出 1），避免与其他代理 Flutter 测试争用注册器；该命令未取得单测结果，不作 RED/GREEN 证据。随后采用上述独立 Kotlin/JUnit 与 Android jar 编译检查。没有生成 APK；整包构建由主线程冻结源码后统一执行。

## 未覆盖边界

没有安装设备、读取私密构建参数、访问真实账号、触发外部业务或修改后台发现规则。Android 安装器仍可依据系统限制拒绝同号或低号；本次仅保证客户端身份与完整性检查通过后允许交接，不宣称绕过系统限制。真实安装后 `lastUpdateTime` 与已安装 APK 摘要清理需设备验收；旧版无回执任务保守恢复。OpenSpec 总体验证、共享任务/问题日志和最终签包由主线程集成。
