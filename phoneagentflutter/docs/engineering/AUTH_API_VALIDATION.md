# 登录接口与会话验证（2026-09-16）

## 本批结果

普通 Flutter App 已连接用户确认的测试环境，完成真实短信登录、安全保存和强制结束进程后的会话恢复。没有使用测试替身或调试登录旁路完成真实验证。后台本次未要求邀请码；邀请码分支仅有离线契约/交互验证，不能视为真实邀请码验证通过。

登录后暂时显示明确标识的工程验证页，不是产品首页；首次身份引导、模型、动态首页及其他业务仍需后续接入。本批不连接音频、身份采集或外呼，不修改后端、提示词、数据库。

## 实现边界

- 行为参考固定 v65 提交 `4c781e3ccfcd148c1f205921534907ee0c5aa864`。测试 API base 为 `https://agent.vvtech.tech/aiassistant-api/`，相对路径 `api/auth/sms/send-code`、`api/auth/sms/login`。不使用正式环境。
- Dio 适配处理 HTTP 错误及 HTTP 200 内的业务错误，保留 base 路径前缀；不自动重试 POST、不跟随重定向、不输出请求或响应凭据。
- 登录结果映射账号、令牌、积分与赠送事件；邀请结果不建立会话，成功结果缺少必要字段则失败。积分/赠送事件暂留内存，尚未展示，不在重启时重复播放。
- AuthController 只负责表单与登录；SessionController 负责启动恢复和持久化。保存成功后才交接登录状态，保存失败重试只写存储，不再消费短信验证码。
- 安全存储按环境及规范化 baseURL 隔离；仅保存版本、账号、手机号、显示名、令牌，不保存验证码、邀请码或 challenge。恢复失败明确提示，可重试，不覆盖旧记录。
- 固定 `flutter_secure_storage 9.2.4`；Android 使用加密存储并关闭应用备份，iOS 配置设备本地钥匙串。平台机制参考 [插件文档](https://pub.dev/packages/flutter_secure_storage/versions/9.2.4)。本轮仅验证 Android 真实存取，不能用配置代替 iOS 实测。
- Android NDK 从 Flutter 默认 26 对齐到插件要求的 `27.0.12077973`（本机已安装）；Flutter 3.32.0 / Dart 3.8.0 保持不变。

## 已执行验证

| 检查 | 结果 |
| --- | --- |
| OpenSpec 全量校验 | 8/8 通过 |
| 锁依赖、格式与 flutter analyze | 通过，无分析问题 |
| flutter test | 72 项通过；比上一批新增 17 项 |
| 模拟器离线集成 | 2 页、7 个关键控件、返回及邀请码挑战通过；零真实请求 |
| 配置测试环境的普通入口 APK | 构建、覆盖安装、启动通过，无 NDK 版本不匹配警告 |
| 实际短信发送 | 普通页面点击一次，显示已发送及倒计时 |
| 实际登录 | 使用用户弹窗提供的验证码，显示登录成功；未进入邀请码页 |
| 进程重启 | force-stop 后正常启动，新进程恢复已登录及脱敏手机号，不重复发短信 |
| 当前进程错误日志 | 重启后 PID 4864 的 AndroidRuntime:E / flutter:E 过滤无输出 |
| 截图复核 | 重启后状态页可见，环境 dev、会话就绪；无溢出 |

自动测试新增覆盖 HTTP 字段与 URL 前缀、HTTP/业务错误、无配置及坏响应、环境隔离存储、恢复/保存失败、邀请结果拒存、晚到恢复保护、保存重试不重复认证、Widget 登录交接与重启恢复。

本次真实操作只记录页面观察结果，未保存或打印真实响应/token。没有通过后台获取验证码。用户提供的真实手机号、邀请码、验证码不写入源码、fixtures 或 Git。

## 复跑命令与产物

```powershell
./scripts/verify.ps1 -SkipAndroidBuild
flutter drive --driver=test_driver/auth_driver.dart --target=integration_test/auth_flow_test.dart -d emulator-5554 --no-pub
flutter build apk --debug --no-pub --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=https://agent.vvtech.tech/aiassistant-api/
```

离线集成之后必须重新安装普通入口包，不能留集成测试入口。真实短信不纳入自动重放，复跑需要相应用户授权和新的验证码。

- APK：`build/app/outputs/flutter-apk/app-debug.apk`，SHA256 `D77E1FE937B42120AD12AEA7C9EBBFC87F8CF323576BDE87FE4BC00ACBAA740C`。
- 身份：`com.vvtech.aiassistant.dev`，versionCode 1，versionName 1.0.0-foundation；仍为调试包，不是 OTA 升级产物。
- 离线证据：`.local/auth-validation/result.json`；重启截图：`.local/auth-validation/auth-restored.png`。本地证据不提交 Git。

## 未完成项及下批顺序

1. 首页/导航/模型与动态首页接口，首次身份引导按既有 v65 逻辑迁移，不新增产品行为。
2. 接受保护的业务接口前，补齐 v65 对应鉴权头、401 刷新/失效策略；本批恢复本地会话不代表服务端令牌永不过期。
3. iOS 新依赖的编译、钥匙串读写与登录页面尚未实测，不能借用 B0 结果。本轮未操作 Mac 共享签名会话。
4. Android 原生旧数据/签名/OTA 无缝升级、音频与平台能力继续独立验证。

OpenSpec `auth-api-session` 保持活动状态，等待用户验收后再归档同步；没有提前将完整业务标为完成。
