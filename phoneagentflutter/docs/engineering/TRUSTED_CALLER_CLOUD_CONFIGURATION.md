# Android / iOS 可信来电统一根目录配置

## 唯一凭据来源

真实凭据集中保存在工程根目录 `local.properties`，与 `.local/` 同级。不要写入 `android/local.properties`，后者仍只供Android SDK/Flutter工具链使用。

```properties
trustedCaller.android.dev.appKey=<由维护者填写>
trustedCaller.android.dev.appSecret=<由维护者填写>
trustedCaller.android.test.appKey=<由维护者填写>
trustedCaller.android.test.appSecret=<由维护者填写>
trustedCaller.android.pro.appKey=<由维护者填写>
trustedCaller.android.pro.appSecret=<由维护者填写>
```

上面只说明字段，不能将占位符用于真实构建。Git中的脱敏示例使用空值，必须补齐真实值。根目录文件被精确 `/local.properties` 规则忽略，实际文件权限600，禁止提交或输出值。

| PHONEAGENT_ANDROID_ENV | 根文件字段前缀 | cloud业务配置APP_ENV | SDK环境 |
| --- | --- | --- | --- |
| dev（缺省） | trustedCaller.android.dev | dev | test |
| test | trustedCaller.android.test | test | test |
| pro | trustedCaller.android.pro | prod | pro |

Android 三个环境各保留两个字段；iOS 对应使用 `trustedCaller.ios.dev/test/pro.appKey/appSecret`，完整十二字段见 [示例](examples/trusted-caller-local.properties.example)。允许供应商实际登记值相同。缺所选字段不会改读其他环境，也不回退cloud JSON、历史源码、父工作区或android/local.properties。

## 编码与构建读取

文件按UTF-8读取，遵循Java Properties语法。值中的反斜杠写成 `\\`，需要保留的前导空格写成 `\ `，支持Unicode转义。回车、换行和NUL不允许出现在解码后的可信凭据中；解析错误只显示安全摘要，不附原文件内容。

Gradle从根文件选择两个值，继续注入原有BuildConfig字段及main源集唯一Kotlin读取器。App不在运行时读取开发电脑目录，不将完整Properties/JSON作为资源打包。每次配置重新读取文件，环境切换或参数更新使用当前值。

Python测试构建入口和准备工具共用Java兼容的Properties解析器；Windows及Docker入口先检查根文件存在且非链接，实际构建由Gradle统一完成可信字段校验，Windows无需新增Python运行时。Windows PlanOnly只检查根文件路径和既有业务/签名输入，不代表可信字段内容已通过Gradle验证。

业务SDK/Agent字段、服务地址和APP_ENV仍分别位于既有 `.local/cloud-*/device-defines.json`，不与可信凭据混用。Gradle保留cloud业务APP_ENV与Android选择、显式Dart APP_ENV的一致性校验。当前本机cloud-pro原有APP_ENV=test，仍拒绝生产环境；不能仅更改APP_ENV就认定其余服务参数为生产配置。生产 Release 门禁、签名、版本和 UI 不变；iOS 新配置规则见下方。

## 迁移与准备工具

2026-10-19先从三份cloud文件迁入六个字段，逐环境核对Properties解码值与原值完全一致，再仅删除JSON中的TRUSTED_CALLER_APP_KEY/SECRET，其余业务字段保留。此前cloud来源实现见read-trusted-caller-cloud-configuration，当前唯一来源以centralize-trusted-caller-local-properties为准。

`PHONEAGENT_ANDROID_ENV=test python3 tool/prepare_trusted_caller_credentials.py --android-only` 仅校验根Properties及所选业务APP_ENV，不写源码、不访问原生Git、不触碰iOS或旧私有清单。默认准备会同时校验 Android 并生成所选 iOS 配置；iOS 不再读取原生参考项目。

隔离构建需安全准备其自身源码根目录的local.properties和所选cloud业务配置；不回退父工作区，不复制无关私有输入，沿用run-test-build.py生命周期，不扩大清理范围。

## 验证

- `python3 -B -m unittest discover -s scripts -p test_trusted_caller_properties.py -v`
- `python3 -B -m unittest discover -s scripts -p test_android_build_inputs.py -v`
- `python3 -B -m unittest discover -s tool -p test_prepare_trusted_caller_credentials.py -v`
- `python3 -B -m unittest discover -s tool -p test_trusted_caller_cloud_gradle.py -v`
- Windows：`scripts/test-apk-policy.test.ps1`
- Android：`:app:testDebugUnitTest --tests 'com.vvtech.phone_agent.TrustedCaller*'`

合成用例覆盖特殊字符/Unicode/续行与真实Java解析一致、环境选择、缺失字段/文件、链接、禁止旧来源回退及安全错误。真实设备SDK/来电及生产发布验收独立进行。

## 2026-10-20 iOS 三环境适配

iOS 的 `PHONEAGENT_IOS_ENV` / `APP_ENV` 使用 dev/test/prod，prod 对应 Properties 中的 pro。Debug/Profile 缺省 dev，Release 缺省 prod；test 显式覆盖，沿用 [邀请构建环境规则](IOS_INVITE_ENVIRONMENT_CONFIGURATION.md)。dev/test 使用测试 SDK，prod 使用正式 SDK；不根据 Debug 猜测 test，不改变应用身份和签名门禁。

```bash
python3 -B tool/prepare_trusted_caller_credentials.py --ios-only --ios-environment dev
```

准备时仅依赖根 Properties。未显式传环境时，以 PHONEAGENT_IOS_ENV 或 Flutter Generated.xcconfig 的 APP_ENV 选择；无 APP_ENV 时仅准备 dev。CocoaPods 在收集源文件前准备 ignored 的 Generated 源码；Pod 编译前 `--ios-build` 强制重读当前配置、校验 APP_ENV 与实际 SDK 环境，再生成单环境源码。APP_ENV 未提供时仅允许既有 dev 不签名编译。切换业务环境需同步 Flutter defines 与 Xcode 环境，不能只切换构建模式。

生成文件权限 0600，输出只含所选环境，使用后仍不提交；值不变时不改文件时间。根配置不复制到资源、不依赖 Android 私有 JSON、历史原生 Git 或其他工作区。旧字段不兼容回退。独立验证和未验收项见 [本次 tasks](../../openspec/changes/adapt-platform-trusted-caller-properties/tasks.md)。历史迁移记录不代表当前配置合同。

## 2026-10-22 iOS 签名与 APNs 交付合同

SDK 环境、根凭据作用域与 APNs 签名环境分别校验。APNs 不由 SDK test/pro 推导。

| 入口 | APP_ENV / PHONEAGENT_IOS_ENV | SDK | local.properties 前缀 | 主 Bundle ID | 签名 / APNs |
| --- | --- | --- | --- | --- | --- |
| dev | dev | test | trustedCaller.ios.dev | com.chaken.phoneagent.test | Apple Development / development |
| test | test | test | trustedCaller.ios.test | com.chaken.phoneagent.test | Apple Development / development |
| pro（prod 别名） | prod | pro | trustedCaller.ios.pro | com.chaken.phoneagent | Apple Distribution / production |

两个 extension 的 ID 分别为主 Bundle ID + `.KXPushServiceExtension`、`.KXLiveActivityExtension`。完整构建检查 Runner 依赖和 Embed，最终包检查两个扩展都存在、ID/Team/版本一致及各自 profile 授权，不将主包 profile 直接用于其他 ID。扩展无 APNs 声明时不强行授予；主包 plist 的 TrustedCallerAPNSEnvironment、最终签名 aps-environment 和 profile 必须与上表一致。

入口：`python3 -B scripts/build-ios-package.py --environment test --build-name 1.0.52 --build-number 45 --device <USB设备UDID>`。版本均须用户指定。dev 默认 Debug，test 默认 Profile，prod 默认 Release。入口复用 run-test-build.py 隔离快照和校验后导出/清理，只读取对应环境的 ios-device-defines.json 与根 local.properties，复用锁定依赖，不从 Android 取参数。匹配 UUID 的原生 dSYM 保留在 IPA 的 Symbols/ 中，不进入 App 资源。

pro 文件由用户确认仍暂存 test 参数；保留原样。入口对 APP_ENV 和路由不匹配拒绝正式交付，不自动改地址、密钥或环境。未准备正式参数前不打正式包。dev/test 共用既有 Bundle ID，不能同时共存，不新增身份。真机 Token、SDK 绑定回调、推送送达分别验收，安装/启动不代表三者成功。

## 配置回归 CI、构建清单与安装前门禁

`.gitlab-ci.yml` 在分支/Merge Request 流水线执行两个非 allow_failure 任务：Python 合同回归，以及 macos 标签 Runner 上的原生/真实扩展接线检查。无生产凭据、无 SDK/APNs 请求，不自动签名或发布。macOS Runner 需要 Xcode 命令行工具、Python 3、Ruby/CocoaPods xcodeproj；缺失工具链失败，不静默跳过。本地同入口：

```bash
python3 -B scripts/run-ios-contract-checks.py
python3 -B scripts/run-ios-contract-checks.py --native
```

每次新构建同时导出 `<IPA文件名>.build.json`。清单严格白名单包含：schema、时间、环境/SDK/模式、版本、源码 HEAD/快照摘要、配置路径及文件 SHA256、凭据字段前缀、目标设备摘要、主包/扩展 ID/团队/版本/APNs、profile UUID/文件摘要、实际签名证书摘要，以及 IPA SHA256/大小。没有 appKey/appSecret、Token、账号、完整 profile 或设备清单。清单记录不替代签名校验；未知字段、重复字段、超限/链接、错包或错设备拒绝。历史包不补造来源。

IPA 与清单在同一工作空间生成、验证并成对导出；公共 run-test-build.py 拒绝未声明清单的 IPA。完整产物摘要一致后才清理本次目录；旧交付保留。

安装统一使用下列入口，显式输入本次构建输出的 IPA SHA256、环境、版本和设备；可额外用 `--source-sha256` 指定源码快照。默认读取相邻清单。先固定临时副本，检查字节摘要、清单、实际签名/profile、主包和两个扩展、版本以及 USB 设备授权，失败不安装、不换包、不清数据。去掉 `--verify-only` 才执行覆盖安装；增加 `--launch` 才启动。

```bash
python3 -B scripts/install-ios-package.py --ipa <本次IPA绝对路径> --environment test --build-name 1.0.52 --build-number 45 --sha256 <本次IPA的SHA256> --device <本次设备UDID> --verify-only
```

安装验证通过、系统安装成功、启动、APNs Token、SDK 绑定、推送送达各自记录，不相互替代。GitLab 远端执行结果仅以真实流水线为准；本地通过不代表已触发远端。

## 通讯通知权限（2026-10-22）

主 App 的 Debug/Profile/Release entitlements 均声明 `com.apple.developer.usernotifications.communication=true`。主包 profile 选择、签名生成和最终 IPA 验收均要求实际授权为 true；不能只在源文件中声明后被签名白名单丢弃。此要求不改变 SDK/APNs 环境映射，不将主包能力复制给未授权的 NSE 或 Live Activity 扩展。真实通讯通知/头像展示仍单独验收。
