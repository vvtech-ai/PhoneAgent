# Android v65 认证录音升级导入

2026-09-20：实现及定向自动验证完成；真实同签名升级未验收。没有读取真实录音、安装设备包、发送短信或认证/生成请求。iOS 不参与 Android OTA。

## 来源与实现

固定 v65 `4c781e3ccfcd148c1f205921534907ee0c5aa864` 的 `CertifiedRecordingStore.kt` 与 `AssistantVoiceCloneModelRuntime.kt`：旧文件为 `noBackupFilesDir/voice_clone_certified/certified_recording.bin`，账号使用 `AccountIdentityProvider.accountId`。旧读取失败会删源，本实现不继承该副作用。

| 层 | 文件 | 职责 |
|---|---|---|
| Android | [LegacyCertifiedRecordingChannel](../../android/app/src/main/kotlin/com/vvtech/phone_agent/LegacyCertifiedRecordingChannel.kt) | 同生产包名，只读固定文件与已有旧 Keystore 密钥；不创建旧密钥、不接受路径、不删源；11MiB 外层限制 |
| Android 纯格式 | [LegacyCertifiedRecordingPayload](../../android/app/src/main/kotlin/com/vvtech/phone_agent/LegacyCertifiedRecordingPayload.kt) | 版本1、5个 Java modified-UTF 字符串、音频长度及字节；10MiB 音频上限，禁止尾部数据 |
| Dart 来源 | [DeviceLegacyCertifiedRecordingSource](../../lib/features/voice_clone/data/device_legacy_certified_recording_source.dart) | 非 Web Android + 精确正式 API 门禁；当前账号、字段、SHA-256 校验 |
| Dart 存储 | [MigratingCertifiedRecordingStore](../../lib/features/voice_clone/data/migrating_certified_recording_store.dart) | 新数据优先、导入、持久空标记；复用 Repository 同槽位串行队列 |
| 正式装配 | [certified_recording_providers](../../lib/app/certified_recording_providers.dart) | 当前登录代次/销毁门禁；仅符合条件时包装现有加密存储；Dev/iOS/Web 保持原行为 |

旧加密格式：一字节 IV 长度、12–16 字节 IV、AES/GCM 密文，别名 `voice_clone_certified_recording_v1`，无 AAD。新存储使用独立密钥、槽位 AAD 及 AtomicFile，不改变旧文件。

## 状态与失败

1. 新槽位已有录音：直接读新数据。新槽位损坏或暂不可读，也不回退旧源掩盖问题。
2. 新槽位不存在：读旧源 → 核对账号/摘要/元数据 → 新 codec 编码 → 新加密槽位原子写成功 → 才返回可复用录音。当前身份指纹仍由现有 Repository 读取参数校验。
3. 清理：同一个原子加密槽位写绑定空标记；重启返回 absent，不重新导入。无旧源也写标记，避免反复查询；以后新保存原子覆盖标记。
4. 另一账号旧源不导入；仅在当前账号槽位写空标记，不删除旧文件/密钥，另一账号仍可按自己的槽位处理。
5. 密钥暂不可用、未知旧版本、目标写失败：显式失败，不假称成功，可以重试。明确损坏经现有 invalid 清理路径写空标记，但不删除旧文件。
6. 旧读取期间账号变化或 provider 销毁：不继续落盘。已交给原生的原子写不能撤回，但只能进入原账号槽位。
7. 新保存、导入及清理由同槽位队列串行；失败清理重试不能删除后续成功保存的录音。

空标记是防 Flutter 重新导入的逻辑清理，**不是旧加密源的物理擦除**。旧版不认识标记，不能承诺安全降级。后续不能简单移除迁移包装器；正式回滚/旧源擦除另行审核。

## 本批验证证据

- 24 条新增 Dart 测试，与现有存储、codec、平台通道、复用、完成流程、身份清理及正式 provider 合计 **80 条定向通过**；没有全量回归。
- **6 条原生 JVM 测试通过**：Java modified-UTF 中文/NUL/补充字符、音频独立副本、未知版本、空字段、长度/截断/尾部/外层超限。结果 XML 位于本地 `build/app/test-results/testDebugUnitTest/`，不提交。
- `flutter analyze --no-pub` 无问题；首轮 3 个冗余 import 提示已清理后复查。
- JBR 下 `:app:testDebugUnitTest` 成功；仅新增测试依赖 JUnit 4.13.2，无运行依赖。Gradle 既有弃用提示不在本批扩展处理。
- 测试环境 Android Debug 构建通过（14.3秒），未安装。Dev 构建不能证明生产包名路径可用；未改 iOS，不重复 iOS 构建或 Web 截图。Release 门禁保持。
- 仅合成数据/内存槽位/模拟 MethodChannel；不是硬件 Keystore、系统 IO、生产签名或断电恢复证明。

## 集中人工验收（以后统一执行）

前提：获准的专用账号/录音、旧 v65 正式包、相同生产签名/包名和合法递增版本；使用可恢复测试设备，不拿真实用户数据做损坏实验。当前 `.dev` 不是升级产物。

1. 旧版明确保存认证录音；记下账号和可复用状态，不导出音频、receipt 或密钥。保留数据升级至获准新包。
2. 同账号进入模型克隆创建，检查已保存录音复用；导入不自动采集、认证或扣费。真正生成只按既有明确操作触发。
3. 重启再进，预期复用新槽位；新保存成功后重启应使用新内容。
4. 经正式身份删除/录音清理流程完成清理，再重启、重进；预期旧文件不复活，不重复 DELETE。该步骤本身需要账号删除授权。
5. 切换专用第二账号，不能看到第一账号录音；切回后遵守各自保存/清理状态。
6. 仅专用测试构建模拟旧密钥不可访问、新槽位写失败；预期失败可重试且旧源不变。模拟损坏应 invalid，不跨账号复用。
7. 检查日志无音频/receipt/身份指纹/令牌；记录版本、设备、结果与脱敏错误类别即可。

上述未执行前不归档 `android-legacy-recording`，不宣称 OTA 无缝升级完成；本机通话记录迁移及发布/回滚门禁仍属后续范围。
