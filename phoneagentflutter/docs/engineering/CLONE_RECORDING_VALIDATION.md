# 认证录音下载、加密存储与清理

2026-09-18。完成共享存储核心、双端薄适配及身份删除清理接线；不代表完整克隆创建流程或真机加密已验收。Web 创建演练继续使用显式 MOCK，不读写真实认证录音。

## 来源与边界

- Android/后端固定 v65 `4c781e3`：CertifiedRecordingStore 的 10MiB 音频上限、摘要/身份校验和私有加密存储；CertifiedRecordingController 的受保护 GET、grant 查询参数和 audio/wav 响应。
- 下载固定路径 `api/account/settings/voice-clone/verification/{attempt}/certified-recording`。只在配置的 API 源内构造请求，不接受响应里的任意下载 URL；禁止重定向，沿用账号代际和单次 401 刷新。过期 grant 不发送，超限响应中止。
- 下载、音频、receipt、grant、身份指纹不进入普通日志、页面状态或 Git。合成测试字节仅用于摘要/传输测试，不是可播放 WAV 的证明。
- Android 使用新私有目录及密钥。2026-09-20已增加同生产作用域的旧认证录音只读导入，不覆盖/删除旧源；空标记防清理后复活。实现、80条定向回归和真实升级步骤见[旧录音迁移验证](LEGACY_RECORDING_MIGRATION_VALIDATION.md)，真实同签名升级仍待验。iOS 不做 OTA。

## 共享与平台分工

| 层 | 实现 | 责任 |
|---|---|---|
| Dart data | ApiCertifiedRecordingDownload | 固定路径、短时 grant、有界同源下载 |
| Dart data | CertifiedRecordingCodec | 版本、环境/API/账号绑定、身份指纹、长度、SHA-256；4 字节元数据长度 + JSON + 音频 |
| Dart data | CertifiedRecordingRepository | 同槽位跨实例串行保存/读取/清理，账号代际及销毁保护 |
| Dart data | DeviceCertifiedRecordingStore | 有界 opaque bytes 和 64 位十六进制槽位；不向原生传任意文件路径 |
| Android | CertifiedRecordingChannel.kt | noBackupFilesDir、AndroidKeyStore AES-256/GCM、槽位 AAD、AtomicFile；进程内锁和后台队列 |
| iOS | CertifiedRecordingChannel.swift | Application Support 排除备份目录、Keychain 设备专属密钥、CryptoKit AES.GCM/槽位 AAD、原子文件替换与首次解锁保护；共享串行队列 |
| App | certified_recording_providers.dart / identity_providers.dart | 绑定当前登录；服务器删除身份成功后清理该槽位，同时保存跳过标志、失效模型缓存 |

原生仅加解密和私有文件 IO，不实现认证、计费或候选规则。Web/桌面没有原生录音存储：读取为空、清理无操作、写入明确不可用；没有 localStorage 或明文文件回退。

## 状态及失败处理

1. 保存先下载，再验证不可变音频/元数据，最后原子替换；下载、摘要或写入失败不主动清除旧录音。
2. 同槽位读取/清理排在先前保存之后，包括不同 Repository 实例。不同账号的槽位不会互相覆盖。
3. 下载未结束时退出账号或销毁 Repository，不继续写入。已进入原生原子操作的写入不能取消，但仍只写原账号槽位；不声称能撤回已提交文件。
4. 明确损坏、绑定/身份不符或摘要错误，清除当前槽位并返回 invalid。暂时 IO/钥匙串不可访问返回失败，不把暂时错误当作损坏自动删除。
5. DELETE 失败不清理。DELETE 成功而本机清理或跳过保存失败，保留“身份已删除”事实并提示本地处理失败；不重发 DELETE。清理失败后的专门重试入口仍待完整流程装配。

## 自动验证

- 新增 30 项 VM 测试，1061 项全量通过；包括绑定/版本/边界/摘要、保存与读取/清理顺序、跨实例队列、旧数据保留、账号切换晚到、平台通道、HTTP 401/grant、清理失败仍保存跳过标志。
- analyze 无问题，515 个 Dart 文件格式检查通过；Web Debug 同源代理、Android Debug 测试环境、Mac Xcode 15.2 iOS Debug 无签名构建通过。
- Chrome 5 项流式/二进制传输测试通过，其中本批新增 grant 编码、固定源及禁止重定向测试 1 项；使用项目既有 `dart test --platform chrome`，不是 Flutter 页面截图验收。初次误用 Flutter 测试运行器停滞，结束后改用既有运行器通过。
- MethodChannel 使用合成处理器、文件仓库使用内存替身；这些测试不证明真实 Keystore/Keychain、磁盘故障或断电恢复。
- 无新增 UI，本批没有新增浏览器逐屏截图或设备安装，不用旧截图或旧安装冒作证据。没有真实认证、录音、下载 grant、生成、扣费、身份删除或外呼。

## 后续装配与集中验收

2026-09-18补充：身份删除成功后的本地失败已有专用重试按钮和分步骤任务，录音清理按删除时写入边界保护后来的成功录音；不重发DELETE。实现、8新增/1643全量与8104浏览器证据、真实故障注入步骤见[身份本地处理验收](IDENTITY_CLEANUP_VALIDATION.md)。仅页面生命周期重试，不宣称跨进程恢复；原生存储仍集中验收。

正式创建页面还需将 SDK/后端认证 PASS、每次生成钱包准入、候选控制器和本仓库装配。保存开关必须显式传入；复用前提供当前身份指纹；过期凭据不能自动触发再次认证/付费生成。

前提：用户授权的测试身份、账号及录音，正式入口装配完成；Android/iOS 标准包安装授权和签名可用。按以下步骤集中验收，不要求此刻人工操作：

1. 明确选择保存后完成认证生成，退出重进并复用；预期无需重复采集，摘要/绑定匹配，仅有一次既定生成请求。
2. 不选择保存、取消、下载过期/失败；预期无假保存成功，不破坏原可复用文件。
3. 切账号/环境、替换身份及保存中删除身份；预期不跨账号复用，删除成功后本槽位为空，不因本地错误重复 DELETE。
4. 重启与首次解锁前后、临时钥匙串不可访问；预期不可访问时报告失败而不擦除，恢复可访问后可读。
5. 在专用测试构建注入损坏/磁盘写入失败；预期损坏文件失效、临时失败保留旧数据，不能拿真实用户录音做破坏性测试。
6. 另行验证同签名 Android OTA 的旧格式/密钥导入；本批新存储不是旧数据迁移方案，也不能据此交付正式升级包。

日志/后台只关联时间窗、attemptId、candidateId、modelId、generationRequestId 和脱敏错误类型；不得记录原始下载 URL 查询参数、receipt、音频 Base64、身份证或 token。禁止出现跨账号读取、明文存储、自动重发生成/删除、把 SDK 返回当作服务端认证成功。

平台依据：[Android Keystore](https://developer.android.com/privacy-and-security/keystore)、[AtomicFile](https://developer.android.com/reference/android/util/AtomicFile)、[CryptoKit AES.GCM](https://developer.apple.com/documentation/cryptokit/aes/gcm/sealedbox)、[iOS 备份排除属性](https://developer.apple.com/documentation/foundation/urlresourcevalues/isexcludedfrombackup)、[设备专属首次解锁 Keychain 访问级别](https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly)。这些是实现选择依据，不代替本项目真机验证。
