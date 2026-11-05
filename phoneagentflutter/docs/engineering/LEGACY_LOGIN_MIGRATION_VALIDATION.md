# Android v65 旧登录迁移：实现与验收

日期：2026-09-20。仅覆盖生产 Android 同包升级的旧登录；不是整个 OTA、全部旧数据或真机升级完成证明。Web 页面继续复用 Flutter 现有交互与组件，视觉校准后置。

## 来源与准入

固定 Android v65 `4c781e3` 的 `AccountIdentityProvider` 使用私有 SharedPreferences `account_identity`：`phone` 与 `voice_clone_access_token`；accountId 由规范化手机号构造为 `phone-<phone>`。`expired_login_phone_hint` 不是有效登录来源。没有旧 refresh token 可导入，也不能从本地值判断服务端是否仍接受该 token。

旧 Gradle 中生产包是 `com.vvtech.aiassistant`，生产接口是 `https://chaken.ai/aiassistant-api/`；旧 `.dev` 是可变地址的 local flavor，远程测试 dev 实际是 `.test`。因此不能把目前 Flutter `.dev` 的测试环境凭据和旧 `.dev` 直接合并。

同时满足以下条件才启用导入：

- Flutter 运行于 Android，APP_ENV=prod，精确 HTTPS 主机 chaken.ai、443端口及 `/aiassistant-api[/]` 路径；配置不能带用户信息、query、fragment。
- 原生再次检查实际包名严格等于 `com.vvtech.aiassistant`。无文件路径、包名或任意 key 入参，只读当前应用自己的固定旧文件。
- Flutter 新安全存储为空；旧手机号与 token 同时存在且格式有效。

Web/iOS、测试环境与其他 API 均不调用该通道；非生产包的原生 read 返回空。它**不**提供跨包复制登录或免除服务端过期认证的能力，也不改变原有8080浏览器凭据。

## 数据流和状态

| 操作 | 顺序 | 失败边界 |
|---|---|---|
| 恢复已有 Flutter 登录 | 安全存储读取 → 持久封闭旧导入 → 返回会话 | 新数据损坏或读取失败，不回退旧账号 |
| 首次导入 | 安全存储为空 → 固定旧源读取/规范化 → 写入安全存储 → 持久封闭旧导入 | 安全写入失败不消费源；标记失败则保持恢复错误，重试优先读已写入的新目标 |
| 新登录 | 持久封闭旧导入 → 写新会话 | 标记失败不替换会话；写入失败也不能重新复活旧源 |
| 退出 | 持久封闭旧导入 → 清安全存储 | 失败可见、可重试；不能先清再使旧源可读 |
| 旧源缺失 | 返回空 → 既有登录表单 | 不自动发短信，不根据提示手机号伪造会话 |

`MigratingSessionStore` 按 `SecureSessionStore.keyFor(config)` 共用进程内串行队列，同作用域 provider 重建仍只有一个写入顺序；不同作用域不阻塞。队列完成即清理，不保存凭据结果。并发恢复先排队时，退出等它完成再清理，因此迟到读取不能覆盖退出。此保证覆盖当前单 Flutter isolate 的正式装配，不宣称支持多个进程同时写同一登录槽位。

`DeviceLegacySessionSource` 只做通道映射和旧规范化；Android `LegacySessionChannel` 在专用单线程执行文件读取和同步 `commit`，在主线程回应。消费标记存放于 `phoneagent_flutter_migration/v65_auth_consumed`。原始异常内容、手机号、token 不进入日志，通道返回固定错误码。

恢复仍走 SessionController 的既有恢复状态，不调用登录 API，不产生新登录奖励事件。此批无 HTTP、SMS、身份认证、权限申请、音频或外呼行为。

## 旧文件与回滚限制

旧 `account_identity` 不删除、不覆盖，安全目标写入及标记可失败重试。注意：**保留旧文件不等于安全的自动降级**。旧 Android 不认识 Flutter 的消费标记，若在 Flutter 退出后降级回旧包，旧包可能再次读取旧凭据。正式发布前必须将降级/退出策略纳入专门验收；本批没有执行降级、清旧文件或解除 Release 保护。

偏好、身份/录音文件、本机记录、草稿等尚需各自格式盘点与导入；不能用登录子项代替所有旧数据兼容。最终同生产证书、合法 versionCode、安装来源及数据保留仍需真实升级测试。

## 自动化证据

- [迁移顺序与并发测试](../../test/features/auth/migrating_session_store_test.dart)：14项，安全目标优先、失败重试、退出封闭、同实例/跨实例并发、不同作用域独立、重复恢复和无奖励事件。
- [原生通道映射与装配测试](../../test/features/auth/device_legacy_session_source_test.dart)：6项，合成手机号规范化、缺失/损坏值、标记失败、精确作用域，以及 Android/iOS/dev 的正式 provider 装配。
- 跨实例迟到读取用例先执行失败（退出后安全目标仍有会话），修复后通过；不是只按实现写一个恒通过的断言。
- 认证模块58项通过。全量、分析与构建最终结果见[当前状态](MIGRATION_CURRENT_STATUS.md)本批证据。
- 使用合成账号与 MethodChannel mock，证明共享状态/映射/装配，不证明真机私有 XML 或 Keystore 的真实行为。Android Debug 构建证明原生注册可编译，但调试包刻意不具备生产导入资格。

复验：`flutter test test/features/auth`、`flutter analyze`、`flutter test`、正常 `lib/main.dart` Web 构建及 Android Debug 构建。无需真实短信。

## 集中人工验收（尚未执行）

在允许升级的专用生产同签名测试设备执行，使用受控账号，先确认数据备份和回退策略，不在用户日常安装上盲目覆盖。

1. v65 正式包已登录，记录脱敏账号标识；通过批准签名/versionCode 的 Flutter 包原位升级，不能卸载再装。首次恢复进入同账号；不出现自动 SMS，不产生新登录奖励。
2. 结束进程再启动仍读取新安全存储；服务端 token 失效应走既有过期处理，不能把本地导入当在线鉴权通过。
3. Flutter 退出后结束进程再启动：保持未登录，不重读旧源。新账号登录后不得恢复旧账号；新旧数据失败路径使用受控测试构建注入，不手工损坏真实凭据。
4. 单独验证旧数据为空、仅过期提示、缺少token、无效格式；确认没有手机号提示自动获得会话。记录预期恢复错误或登录表单。
5. Dev测试包、iOS和Web保持各自原登录行为，不触碰生产旧文件；测试账号凭据不得导入生产API。
6. 单独验签、版本、其他旧数据和降级风险；这些未通过前仍不能发布“OTA无缝升级已完成”。证据只记包名、版本、场景及结果，不上传原始 token/XML。
