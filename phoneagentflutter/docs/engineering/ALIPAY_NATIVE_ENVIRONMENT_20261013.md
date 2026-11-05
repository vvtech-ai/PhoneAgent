# Android 支付宝可信环境选择验证

## 范围与实现

本轮变更为 `configure-alipay-sandbox`，只处理 Android 支付 SDK 的环境选择。固定依赖 `com.alipay.sdk:alipaysdk-android:15.8.42` 不变。本机缓存 AAR 的 EnvUtils 类确认默认 ONLINE，提供 SANDBOX/ONLINE 与 setEnv。

- `AlipayPaymentEnvironment.kt` 严格把后端材料 SANDBOX 映射为 SDK SANDBOX、PRODUCTION 映射为 ONLINE；缺失、空串、大小写变体和其他值均拒绝，不猜 APP_ENV。
- `CommercePaymentChannel.kt` 在接受 pending 前验证环境，在现有单线程支付任务内设置 SDK 环境后调用 payV2。每次明确设置，防止此前沙箱状态被后续生产调用沿用。
- 共享 Flutter DTO 与 launcher 无生产修改，原样透传 parameters。新增 JSON→MethodChannel 合成边界回归。
- 原生成功、取消、异常和超时仍由购买控制器查询签名原单；不本地产生到账、履约成功或释放订单。

## 失败回归与验证

测试先建立编译安全的旧 ONLINE/no-set 行为占位策略，以真实 SDK 的内存状态观察断言；此 RED 不调用旧桥或 PayTask。实际 6 项中 1 通过、5 失败，随后替换为最终策略，6 项全部通过。测试没有读取商户材料或调用供应商。

| 验证 | 实际结果 |
| --- | --- |
| Android AlipayPaymentEnvironmentTest | RED 6/5失败；GREEN 6通过，0失败/错误/跳过 |
| Flutter native_payment_launcher/purchase_controller/commerce_dto | 14通过，保留原单查询与未知结果语义 |
| Flutter analyze --no-pub | 无问题，24.4秒 |
| debug ARM64 APK | 初次默认配置编译82.3秒；批准的本地私有配置重建24.8秒，均成功 |
| OpenSpec validate --all | 97通过、0失败 |
| 当前 change strict | 通过 |
| git diff --check、中文回读 | 通过；仅既有Git LF→CRLF提示 |

实际命令（Flutter 3.32.0/Dart 3.8；Android JBR21）：

```powershell
$env:JAVA_HOME='D:/android_studio/jbr'
# 在 android 目录；RED/GREEN分别执行相同命令
./gradlew.bat :app:testDebugUnitTest --tests com.vvtech.phone_agent.AlipayPaymentEnvironmentTest --offline -Ptarget-platform=android-arm64 --console=plain --max-workers=2
# 在仓库根目录
D:/tools/flutter-3.32.0/bin/flutter.bat test --no-pub test/features/commerce/native_payment_launcher_test.dart test/features/commerce/purchase_controller_test.dart test/features/commerce/commerce_dto_test.dart
D:/tools/flutter-3.32.0/bin/flutter.bat analyze --no-pub
D:/tools/flutter-3.32.0/bin/flutter.bat build apk --debug --no-pub --target-platform android-arm64 --build-name 1.0.51 --build-number 2026101308
# 主代理核验并追加授权后，使用既有私有文件重建，不输出文件内容
D:/tools/flutter-3.32.0/bin/flutter.bat build apk --debug --no-pub --target-platform android-arm64 --build-name 1.0.51 --build-number 2026101308 --dart-define-from-file=D:/Temp/story1837-local-device/device-defines.json
openspec validate --all
openspec validate configure-alipay-sandbox --strict
```

本机证据前缀为 `D:/Temp/story1837-alipay`，后缀分别是 `-native-red.log`、`-native-red.xml`、`-native-green.log`、`-flutter-tests.log`、`-analyze.log`、`-android-build.log`、`-local-android-build.log`、`-openspec.log`。最新 JVM XML 位于 `build/app/test-results/testDebugUnitTest/TEST-com.vvtech.phone_agent.AlipayPaymentEnvironmentTest.xml`。

## 编译产物与未验边界

最终本地 APK：`D:/Temp/story1837-local-device/phoneagent-local-alipay-sandbox-1308.apk`（仓库 build 输出的独立副本）；aapt 确认包名 `com.vvtech.aiassistant.dev`、版本 `1.0.51/2026101308`。SHA256：`95DD676E6AD529CBA6035580FBDB3D96452BFC41BA87B001A201824BF88E32EC`。apksigner 验证成功，签名证书 SHA256：`45655392a9295955d0d651eb7d1ff3f3edb1d15f8a62d74f201dfbc3789cdb4b`。此前默认配置编译的中间哈希为 `8B3DA8C98B36D6E872821AFAB4558C81F93616DEE53805C6215F4093A444952D`，不作为最终本地包。

最终重建使用主代理指定的既有私有参数文件，只在内存核验 APP_ENV=local 和 SDK_API_BASE_URL=http://127.0.0.1:18082；不输出/提交私有内容，不把环境文件放进版本库。主代理已独立核验源码，并追加精准中文提交及指定分支推送授权。本轮没有手机操作、登录/清数据、支付、外呼、短信或数据库写入，没有访问用户支付宝私钥/证书。未运行无关全量；既有 Windows 全量环境失败的边界不改变。后端增加 materials.environment 的来源验证由主代理负责；实际 SDK/原生沙箱付款与到账未验，不能以编译及本地端点配置宣称付款成功。
