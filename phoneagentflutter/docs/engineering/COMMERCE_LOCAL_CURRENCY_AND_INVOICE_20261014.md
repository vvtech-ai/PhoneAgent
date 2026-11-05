# StoreKit 当地价格、购买取消与开票提示交付

用户最新规则：Apple 实际币种/价格以 StoreKit 为准，不与后台人民币参考报价比较；合格 Apple 人民币订单由我方开票，不新增开票销售开关。其他币种正常购买和到账，当前不自动换汇开票。

实现分开承担职责：原生和购买控制器只校验当前 StoreKit 报价变化、商品身份和交易；PlatformPaymentAmount 精确格式化可信 milliunits；order_payment_amount 展示真实原币，缺可信 Apple 凭证显示“以 Apple 账单为准”；invoice_availability_notice 说明已有事实，不臆造退款。申请表优先 invoiceAvailableFen，可开净额由服务端计算和提交时重算；已开/开票中继续查原申请。

验证证据：

- 最新远端 iOS 恢复/诊断/商品价格改动已合并，保留 7c2bf24c 祖先；Apple 价格客户端回归 391 项通过。
- 开票说明商业化集合 405 项通过；净额三文件微批先 RED 后相关 67 项通过；最后 Apple 缺凭证不回落人民币先 RED 后 76 项通过。上述集合重叠，不相加冒充总测试数。
- 最终 analyze 无问题，OpenSpec 137 项通过；原生 XCTest/美国 StoreKit 本地案例未在 Windows 执行，仍待 Mac/Xcode 和真实地区验收。
- 用户确认的统一 NativeConfirmationDialog 保留，取消未知/网络异常及迟到付款恢复由 Java 配套处理，不以界面通过代替业务成功。

## 历史 Android 开发包 1406

- 产品源码提交：`f13ecd5c8d33ad76d2031382726cb8dc691846c0`。使用私有 dev defines，SDK/API 指向 `chakenai-dev.vvtech.tech`，未读取或输出凭据内容，不绕过工程 release 禁止。
- 最终 `1.0.51-dev.1406` / `2026101406` / `com.vvtech.aiassistant.dev`。线上依赖 HEAD 等待使首次 Flutter 命令停滞，已仅取消本次构建；复用同一私有参数和已有缓存，以显式 JDK17 `assembleDebug --offline` 构建成功，未升级依赖。
- APK SHA-256：`39b9f07fab19cf6bb731c3dee220cf9bc96962db2fbdc7758c800ee0787d351d`。签名摘要与原 1404 一致；项目本地 SDK 53 文件/竖屏声明校验通过，APK 中 12 个 arm64 供应商库与原包逐字节相同。
- 物理手机覆盖安装成功，保留数据，16:21:38 读回版本 1406；冷启动 MainActivity `Status: ok`，进程存在。未操作模拟器、付款、发票申请或真实取消。
- 产物：`D:/Temp/PhoneAgent-dev-1.0.51-2026101406.apk`；构建日志：`D:/Temp/story1837-dev-signed-1406-offline-build-20261014.log`。本机私有参数及 APK 不进入 Git 或公开发布资料 ZIP。

后端由用户构建部署。本次手机安装只证明包身份与启动，不代表新 Java 逻辑已上线、原订单已取消、外币真实付款或税航开票已验收。部署后按同一原单进行取消/重试、Apple CNY 开票净额与状态同步联测，避免另建订单冒充原单恢复。

## 最终最新开发包 1407

远端最新 `origin/codex/dev` 的90db9e82已通过b31d4aa3三方合入，保留定位和语音首句修复；最终产品源码 `84319ac6f3e6a18b4b76d1cac5a177f2ffc4e69e`。商业化/定位/权限/语音相关459/459，未知Apple凭证开票提示追加45/45，analyze无问题、OpenSpec138/138；不同测试集合重叠不相加，Mac原生与真实支付仍待验。

- 私有dev参数只读，以JDK17/固定Flutter3.32缓存离线ARM64 Debug构建；没有绕过release锁，源和参数前后摘要一致。
- APK：`D:/Temp/PhoneAgent-dev-1.0.51-2026101407.apk`，`com.vvtech.aiassistant.dev` / `2026101407` / `1.0.51-dev.1407`。SHA256 `a6b23795caa24af9dfbaab8bd715a353176ba84067ed108837b00ed45ebf482c`。
- 签名与1406一致，12个arm64供应商库逐字节一致，19类DEX与Manifest校验通过。
- 指定物理机一次 `adb install --no-incremental -r` 返回Success；16:48:09更新，读回1407。firstInstallTime仍为2026-10-10 12:36:18，未卸载/清数据；实际MainActivity启动Status ok，PID16732。未验证登录态专项，不宣称业务验收。
- 安装回执：`D:/Temp/story1837-build-1407-verification.json`。没有生成临时私有JSON或复制原defines；构建原始日志仅留原私有目录。Java/Web/Flutter功能已分别提交推送，后端由用户自行构建部署，不代表实际原单已取消或发票已申请。
