## 2026-10-19 工程内私有输入（当前约定）

用户批准配置和签名保存在本工程；按用户纠正复用既有 cloud-dev/cloud-test 配置，不另建 config 副本。当前测试配置为 `.local/cloud-test/device-defines.json`，开发配置为 `.local/cloud-dev/device-defines.json`；登记签名为 `.local/android/signing/registered.keystore`，属性为同目录 `signing.properties`，使用相对 `signingStoreFile=registered.keystore`。上述目录受 Git 忽略，不提交材料、口令或配置内容。外部原件和历史构建快照仅保留追溯，不再是构建输入来源。

Windows：`scripts/build-task-test-apk.ps1 -BuildNumber <用户批准值>`。macOS：`python3 scripts/build-task-test-apk.py --build-number <用户批准值>`；macOS 使用现有 Flutter 3.32.0 和 JDK17，可通过 FLUTTER/JAVA_HOME 指定已安装工具链。默认 Release/ARM64/--pub；`-PlanOnly` 或 `--plan-only` 只校验输入并输出无凭据的计划。显式 Debug 分别使用 `-BuildMode Debug`、`--build-mode debug`。入口临时设置 test 签名环境，退出后不影响调用者；缺失或越界不得回读外部原件。

新克隆工程需维护者安全配置这些忽略文件；将目录放在工程内不代表将凭据提交到 Git。登记证书指纹、版本确认、生产门禁、运行配置与保留数据安装规则继续遵循 AGENTS.md。研发迁移见 `openspec/changes/localize-android-build-inputs/`；下文为历史证据。

# Android 测试 Release 交付

> 更正：2026101505 仅通过成包和安装启动核验，实际登录被旧 AppConfig 的 prod-only Release 门禁拒绝，不能视作可用测试交付。修正版递增为 2026101506，必须验证运行配置和登录接线。下方1505结果保留作历史证据，不继续分发该版本。

用户要求测试环境 Release，并安装到当前连接的实体手机。来源为最新 codex/dev a9312dfb 加本批构建策略，不改业务流程或服务端配置。构建期间发现远端新合入邀请修复，已通过临时保存本批改动、安全快进及恢复合并，保留双方内容；test Release 邀请 host 使用最新 chakenai-test.vvtech.tech 策略。

交付命名遵循用户示例：`Phone_Agent_TEST_1.0.51_2026101505_test_YYYYMMDD_HHmmss.apk`。文件名和 APK 内版本一致；应用包名仍为 com.vvtech.aiassistant.test。

## 构建职责

- android/test-environment.gradle：test 下 Debug/Release 登记签名和 .test 身份；Release 仅 ARM64，关闭 Java 混淆与资源裁剪，保留 SDK 反射兼容性。
- android/app/build.gradle.kts：仅允许显式 test 通过 Release 任务图门禁，默认生产 Release 保留原拒绝。
- scripts/build-task-test-apk.ps1：默认 Release，显式 BuildMode Debug 可用；测试地址及私有输入守卫、finally 恢复临时环境变量保持。

签名 MD5 必须等于 ebd4c931de412bf5d9c3716815389097，外部签名属性只读，材料和私有 defines 不进入 Git。APK 包名 com.vvtech.aiassistant.test；测试 URL 为 chakenai-test.vvtech.tech 下 aiassistant-api、aiassistant-sdk-api、aiassistant-runtime。

## 验证

脚本默认 Release 计划先 RED（Invalid test build plan），实现后 18 项输入、计划、环境恢复通过。同步最新 dev 后架构与邀请定向 18 项通过，OpenSpec 152 项通过。实际构建、成包和设备验证结果完成后追加。

Release 构建另定位到原 `--no-pub` 跳过 Flutter 模式对应插件注册生成，残留 integration_test 导致 compileReleaseJavaWithJavac 失败。先为入口必须携带 `--pub` 添加 RED，再改入口使用标准 Flutter 生成流程，18 项脚本回归再次通过。临时离线构建先运行 Flutter Release config-only（启用 pub）生成注册文件，并断言不再包含 integration_test，随后执行 Gradle。未手改自动生成注册文件，pubspec/lock 未发生版本变化。编译器历史错误日志使用系统编码，未将其乱码写入源码。

临时本地 Maven 仓库只补官方校验通过的精确引擎版本，首次 init 对 Flutter included-build 注入仓库被拒，已按 rootProject 绝对目录限制为本应用，不修改 Flutter 工具链或关闭仓库保护。引擎文件 38,966,274 字节、MD5 1aaa39d14c306b0d794123e77dae26f8、SHA1 a73c3151904ffbc50773883d2f23508efa50dcc6。

本机采用固定 Flutter 3.32 / JDK17；首次离线构建因缺 Release 引擎依赖失败，在线补齐时引擎 JAR 下载停滞，按进程身份核对后停止本次 Gradle，再从同一官方地址补齐并校验 Google Storage 官方 MD5 响应头。该仓库不提供 .jar.sha1（404），未忽略下载内容校验。私有 defines 以 Base64 Gradle 属性传入，不输出属性或凭据。构建版本 1.0.51+2026101505。当前实体手机 e2e5aa93，安装前为 1.0.49-test（43），首次安装时间 2026-09-10 15:15:18。只做 adb install -r，不卸载、不清数据。

未进行真实支付、开票、外呼或账号重置。

## 最终结果

- Gradle assembleRelease 成功，2分29秒，476任务（95执行、381缓存）；保留现有供应商 SDK D8 stack-map 警告、Gradle弃用警告，未通过改变供应商代码绕过。
- APK：Phone_Agent_TEST_1.0.51_2026101505_test_20261015_151957.apk，78,909,024字节（78.9MB）；相对Debug的220,308,858字节缩小约64%。
- SHA256：fd9db0cd8498b7c67a80174d1208dbe431c34509ff08e1ddcb287680cd83589b。
- apksigner验签通过，登记MD5匹配；AOT、仅ARM64、无debuggable/调试kernel/Vulkan校验库；11个受保护原生库与AAR/JNI来源哈希一致；3个测试URL及4项SDK/Agent凭据在AOT中比对通过（不记录凭据值）。
- 邀请Manifest host为chakenai-test.vvtech.tech、scheme为phoneagent-test；无私钥或defines文件进入APK。
- 小米24117RK2CC/e2e5aa93：adb install -r成功，启动Status ok、526ms、PID29304；读回版本1.0.51/2026101505，无DEBUGGABLE标志，firstInstallTime仍2026-09-10 15:15:18。安装后再次确认PID存在，未验证登录态。
- 本地产物和不含凭据值的验证记录在 D:/work/04phoneAgent/deliveries/test-release-apk-20261015/。本次未修改数据库、后端或进行真实付款。

## 运行反馈根因与修复 2026101506

用户报告“登录服务尚未接入”。实际 APP_ENV 和测试URL均已写入AOT，但 main.dart 传入 kReleaseMode=true 后，AppConfig.parse 在验证URL前拒绝非prod，返回insecureRelease。DioAuthGateway因此持有null baseUri，在发HTTP前抛AuthFailure.unavailable；这不是测试服务器未部署或误连开发环境。之前只检查AOT字符串和PID，漏掉运行配置的拒绝分支。

仅修改AppConfig环境门禁为test/prod可用于Release，原有HTTPS、凭据/查询/片段非法地址、未知环境和dev/local Release保护保留。API/SDK/Runtime仍各自递归验证。配置职责保持单一，无新增抽象或修改登录核心。

两项RED分别复现isConfigured=false和真实DioAuthGateway抛AuthFailure.unavailable；修复后配置/路由/完整auth及最新OTA签名定向146项通过，analyze44.7秒无问题，OpenSpec153通过。独立Dart AOT product可执行探针使用与main相同dart.vm.product参数，实际输出release=true、environment=test及三个批准URL，验证配置可用；不发送短信。

构建修复期间保留其他任务新推送9316643c的OTA/邀请更新，与本批策略合并为96f80ceb；冲突仅两份追加文档，双方内容已保留。最终APK以该合并源加本修复构建，沿原项目签名和覆盖安装边界。

最终修正版 Phone_Agent_TEST_1.0.51_2026101506_test_20261015_153428.apk：assembleRelease 1分56秒通过，78,909,028字节；SHA256 766d5b08bcd84f6276e84b71962f460e1e34068ac818c5275828dc3c7fc3cf11。与1505的libapp.so哈希不同，避免误用旧缓存；签名、三个测试URL、四凭据、ARM64及11个保护库全部通过。同一小米覆盖安装Success、启动789ms/PID31637，读回1.0.51/2026101506，firstInstallTime不变。截图核验登录表单已渲染，未代发短信或测试真实短信登录。

修正版独立保存于 D:/work/04phoneAgent/deliveries/test-release-apk-20261015/fixed-2026101506/，含README、SHA256SUMS、test-release-verification.json和登录页截图；1505保留历史证据，README及验证记录标为已废弃和运行配置不可用。
