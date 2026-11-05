# PhoneAgent Flutter

Android / iOS 独立客户端。当前 B0 工程基础，**尚未完成登录／首页／统一对话的设计与业务复刻**。

## 入口

2026-10-10用户授权集成`origin/codex/dev_zys`（df5e7097）到`codex/refactor-conversation-task-flow`；此前不合入该分支的限制已覆盖，`origin/codex/dev`保持9a8d4e64。当前集成与开发包验证见[集成变更](openspec/changes/integrate-dev-zys-development-build/tasks.md)。下方B0说明保留基础阶段背景，当前能力以迁移记录和源码为准。

- [批准范围](docs/requirements/MIGRATION_BASELINE.md)
- [工作记录](tasks.md)
- [当前 OpenSpec](openspec/changes/bootstrap-flutter-foundation/tasks.md)
- [AI 协作规则](AGENTS.md)

## 工具链

Flutter 3.32.0、Dart 3.8.0；依赖锁定在 pubspec.lock。Android 模板 Gradle 8.12 / AGP 8.7.3 / Kotlin 2.1.0，本机使用 JBR 21 执行 Gradle。iOS 初始 deployment target 15.5，插件未全部接入；Mac 开发测试使用已配置 Xcode 15.2，不代表当前 App Store 发布工具链就绪。

```powershell
flutter pub get --enforce-lockfile
./scripts/verify.ps1
flutter run --debug
```

默认不配 API，启动验证页会明确提示，不请求业务服务。需要测试配置时使用本机未入库的参数文件：

```powershell
flutter run --debug --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=https://your-agent.example --dart-define=SDK_API_BASE_URL=https://your-sdk.example --dart-define=RUNTIME_API_BASE_URL=https://your-runtime.example
```

示例地址不是实际测试服务；后续登录模块接入现有环境时记录公开配置，不复制密钥。APP_ENV 只允许 local/dev/prod；prod 要求 HTTPS，URL 禁止内嵌凭据、query 或 fragment。无可用配置时不能发业务请求。

当前v71任务ASR/TTS由runtime-netty承载，`RUNTIME_API_BASE_URL`使用HTTP(S)部署根路径，由客户端转换为WS(S)。它独立于Agent/SSE和SDK地址，省略时兼容同域网关（该网关必须实际路由语音请求）。本机联调的28080/28082/28085分别对应Agent/SDK/runtime；Android真机使用各端口USB reverse，密钥继续从忽略的本机参数文件提供。此配置不切换通话媒体、翻译或供应商。

## 平台身份与安全

Android debug=`com.vvtech.aiassistant.dev`，minSdk=26；生产目标=`com.vvtech.aiassistant`。B0 阻止 release 任务：正式签名、OTA 元数据和旧数据迁移未验收，不可覆盖用户正式应用。

iOS Debug/Profile=`com.chaken.phoneagent.test`，Release=`com.chaken.phoneagent`；签名 Team 从本机配置注入。两端仅竖屏，iOS 不做 OTA。当前图标/启动页为 SDK 模板工程素材，不是产品最终资源。

## Mac 验证

加载本机的 Flutter/Xcode/Ruby 环境后执行 `bash scripts/verify-ios.sh`，运行锁验证、analyze、test 和 unsigned iOS debug 构建。签名和真机安装是另外的验证，不由 unsigned 成功代替。

Windows 和 Mac 使用同一 Git 提交与依赖锁；Mac 不能留未记录源码补丁。首次提交前可用有 SHA-256 的隔离源快照验证，不能复制 Windows build/.dart_tool/Generated.xcconfig。

## 开发约束

feature-first，UI → Controller → 领域端口，Data 实现端口；Domain 纯 Dart。手写文件默认 500 行，少量例外记录职责理由和测试；不按 300 行机械拆分。

每个行为变更先 OpenSpec，再实现/验证，及时更新 tasks，验收后归档。关键批次验证后提交并 push 到 origin 当前分支；不 force，不提交签名、凭据、真实用户样例或构建缓存。
