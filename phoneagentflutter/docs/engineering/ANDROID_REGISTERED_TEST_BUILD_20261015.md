# Android 已登记测试包构建入口

## 2026-10-15 测试 Release 扩展

用户后续明确要求测试环境使用 Release，并覆盖安装到当前手机。本节覆盖下方历史 Debug 限制：`scripts/build-task-test-apk.ps1` 现默认 Release，可传 `-BuildMode Debug`。显式 test 的 Debug/Release 均使用 `.test` 和已登记原项目签名；Profile 保持 `.dev`，默认 dev 的生产 Release 门禁仍拒绝。

test Release 仅保留 ARM64，采用 Dart AOT；Java 混淆和资源裁剪暂不启用，以保留供应商反射调用。受保护供应商原生库保持原字节。版本、APK 大小、签名、环境、真机结果见 `ANDROID_TEST_RELEASE_20261015.md`，不以构建成功代替真实支付验收。

本批只实现并验证构建配置，未生成APK、未安装、未改后台。主代理在合入最新codex/dev后的同一提交构建开发包和测试包。

## 文件职责

- `android/test-environment.gradle`：读取显式环境与外部签名属性、核验登记证书、仅覆盖Debug测试身份；无全局flavor。
- `android/app/build.gradle.kts`：在原Debug/Profile变体配置后单行apply；原默认包名、Profile和Release门禁保留。
- `scripts/build-task-test-apk.ps1`：校验私有test参数和签名属性、固定Flutter3.32/ARM64/Debug/main、关闭迁移预览，临时环境变量在finally恢复。
- `scripts/test-apk-policy.test.ps1`：合成输入/PlanOnly及假Flutter编排回归。测试用假进程覆盖成功和失败恢复环境，真实Flutter路径必须精确替换后才执行，不能误打真实包。

## 使用方式

只校验输入和命令计划（不会校验Gradle实际签名配置或生成APK）：

```powershell
.\scripts\build-task-test-apk.ps1 -BuildNumber 2026101501 `
  -DefinesFile 'C:\Users\wuxiwen\.aiassistant-secrets\commerce-delivery-20261015\device-defines.test.json' `
  -SigningPropertiesFile 'D:\work\04phoneAgent\aiassistant-app\local.properties' `
  -PlanOnly
```

实际构建由主代理以同样参数移除`-PlanOnly`执行；版本号由最终交付选择。脚本校验APP_ENV=test、API/SDK/runtime三个URL分别为chakenai-test.vvtech.tech下aiassistant-api/aiassistant-sdk-api/aiassistant-runtime，SDK/Agent四字段均为非空字符串。外部签名属性需含`signingStoreFile`、`signingKeyAlias`、`signingStorePassword`、`signingKeyPassword`；文件和密码只读不复制、不输出。

`PHONEAGENT_ANDROID_ENV=test`与`PHONEAGENT_TEST_SIGNING_PROPERTIES`仅在脚本执行期间设置。未设置或dev沿原开发行为；其他环境值直接拒绝。Gradle使用外部keystore验证别名私钥可读和证书DER MD5，必须为`ebd4c931de412bf5d9c3716815389097`；没有debug签名回退。仍然禁止任何Release任务。

## 实际无APK验证

| 检查 | 实际结果 |
| --- | --- |
| 脚本初始RED | 新入口未实现时合法PlanOnly调用失败；随后实现并执行输入/编排回归 |
| `scripts/test-apk-policy.test.ps1` | 17项通过：缺defines/签名、8项环境/地址/凭据、4项签名字段、正确计划、假Flutter成功/失败环境恢复；无真实Flutter执行 |
| 最终id2私有defines与原生签名属性PlanOnly | 通过，输出目标.test和固定工具路径，没有输出配置值 |
| 非法环境`invalid`，Gradle `help --offline` | 配置期退出1，明确环境拒绝 |
| test缺外部签名，Gradle `help --offline` | 配置期退出1，不回退debug签名 |
| test使用默认Android debug证书 | 配置期退出1，登记MD5不匹配 |
| 默认环境，只读变体探针+Gradle help | 退出0；debug/profile均com.vvtech.aiassistant.dev、release为生产；Debug signingConfig=debug |
| 显式test，真实登记签名，只读变体探针+Gradle help | 退出0；debug=.test、profile=.dev、release仍生产；Debug signingConfig=registeredPhoneAgentTest |
| test下` :app:assembleRelease --dry-run --offline` | 退出1，仍为Foundation debug-only生产签名/OTA原门禁；不执行编译 |
| `flutter test --no-pub test/architecture_test.dart` | 4项通过，不放宽身份/分层/500行限制 |
| OpenSpec | 全仓145/145，本change strict通过 |

Gradle配置验证固定JDK17 `D:/tools/phoneagent-jdk17/jdk-17.0.20.1+1`、现有wrapper8.12和offline缓存，不构建App。首个JAVA_HOME错误层级、探针对Flutter included-build错误查找`:app`、PowerShell未给`-Dfile.encoding`加引号导致Gradle误识任务均属于验证命令/探针问题，已核对当前状态后修正；上述成功回执来自修正后的命令，不掩盖首次失败。初次help编译了Flutter自带Gradle插件，不是APK或业务App构建。

## 配置与运行边界

最终defines由主代理只读核对测试环境启用id2的已有凭据后生成；旧dev-worktree cloud-test文件实际为id1/.local，不能只因URL和非空就认为可用于最终测试包。本脚本只验证参数边界，服务端C1的APP/Android/包范围另由主代理核对，并交付`.aitest`→`.test`精确guard配置SQL。本子任务未修改任何后台记录。

实际APK后须读取包名、版本、证书DER MD5及APK SHA256，核对第三方SDK完整性及test环境；未生成前没有APK成功声明。密钥、私有defines和APK均不进入Git，当前手机不安装/卸载、不重置数据、不真实支付或开票。
