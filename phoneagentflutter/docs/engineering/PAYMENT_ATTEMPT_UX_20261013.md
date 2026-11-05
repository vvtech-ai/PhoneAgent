# 支付尝试反馈与当前页购买交互

## 本批结果与边界

依据用户七张 Demo 与后续“非成功不显示支付结果确认中”“支付前后不要显示订单相关”的明确要求完成客户端。普通支付宝会员/积分包在接受协议后内部报价、创建、原生拉起、静默查询原单，反馈留在购买页。升级保留真实报价确认；金额、折算天数、预计到期来自服务端（秒数只内部使用），不使用 Demo 的补发差额、自动续费或到期不变假设。当前实际等级与周期一致时只显示已开通信息，不重复下单。

客户端没有执行真实支付、短信、外呼、奖励确认、克隆、数据库写入、手机安装或数据清理，也未读取私人凭据/账户夹具。本批不构建、不提交、不推送，最终 APK 与真实沙箱尝试由主任务负责。

## 分层与安全状态

- Android AlipayResultStatus 仅输出 ASCII 四位 numeric resultStatus。桥忽略 memo/result/orderString，不打印 SDK 返回对象或签名材料；既有后端可信 environment 选择保持。
- NativePaymentResult / DevicePaymentLauncher 严格接收可空安全码，坏类型/文本拒绝。PurchaseController 保存与原单号绑定的本次尝试；6001 为本次取消，4000 为本次失败，其他未知/超时/9000 未确认显示本次未完成。内部 PAYING 保留，前台 label 为“未完成支付”。
- 服务端 SUCCEEDED 优先覆盖 native 取消/失败；履约 SUCCEEDED 才显示支付成功或升级成功，已收款未履约只显示权益处理中。query 失败保留原单，未支付状态不释放槽位、不造 FAILED/CANCELED、不自行加分。
- MembershipCheckout 是独立协调器，普通支付宝不调用预览；升级与 StoreKit 仍确认。确认后再核对展示 quoteId/productId。创建/材料等待期间离开购买路由，owner current 与登录 epoch 校验阻止自动拉支付，已创建原单保留。
- MembershipUpgradeDialog / MembershipActiveSheet / PurchaseFeedbackSheet 只渲染真实信息；PurchaseFeedbackHost 只在当前前台弹窗静默查询原单。支付反馈只有图标/标题/安全一句话/完成，不显示商品、实付、原单号或订单操作；完成不受后台query busy禁用。完成或关闭重新请求真实会员与余额；历史详情由正常订单入口进入，支付反馈不提供次要跳转。
- 原订单 productName 历史兼容保留；可选 membershipLevel/membershipMonths 显示真实“等级会员·包月/包季/包年”，ALIPAY 显示“支付宝”。订单操作不再以无操作横杠掩盖未支付原单。

## 受控原单重试

与 Java agent 冻结的现有 material(orderNo) 契约一致：正常历史订单详情内，本端 ALIPAY 原单 PENDING/PROCESSING + NOT_STARTED + cashPaidFen=0 显示显式“重新支付”，这是请求服务端核验，不代表客户端判定可收款。点击后等待与反馈期间隐藏旧详情的订单号/关单/查单，返回只有支付反馈+完成；完成后才恢复正常阅读。自动创建后的拉起仍必须 PENDING、相同 quoteId、相同 channel。跨端原单隐藏本端不可执行的支付动作，查询保留。

服务端负责官方 NOT_EXIST、过期、lease、锁内状态与签名实际截止；客户端不据 OrderResponse.expiresAt 推断支付期限、不创建替代订单。material 明确业务错误不再吞掉，保留安全中文后仍查询原单；成功支付事实覆盖尝试错误。新增 allowlist AC0006 / CONFIGURATION_CONFLICT 只映射安全中文；未知供应商码和任意 message 仍不暴露。Java 对原单材料限频/次数的运行部署由主任务验收，本客户端测试不是渠道资金证明。

## 实际 RED → GREEN

| 微批 | 修复前真实失败 | 最终结果 |
| --- | --- | --- |
| 原生数字码投影 | 新 JUnit 2 项中 1 失败 | status2 + environment6，8/8，无 skip/error |
| Dart 安全码桥接 | 2/2 失败，安全码丢失/坏码未拒绝 | 与既有 bridge 共5通过 |
| attempt/服务端优先 | 9项中8失败 | 9通过，原单未终态/无重复创建 |
| checkout 协调器 | 初始7/7失败 | 后续11项全部通过，含 StoreKit、替换quote、旧单升级标签边界 |
| 升级/已开通 UI | 2/2失败 | 2通过，协议未接受不能确认 |
| 当前页 route | 3条流程失败 | 3通过，普通会员/积分包/升级不跳结果页，真实读取刷新 |
| 原单 retry/安全错误 | 初始3项中2失败，另UI入口1失败 | 原单不替换、错误可见；跨端UI另RED1修复 |
| 离页等待边界 | create/material等待2/2失败 | 2通过，不拉支付且保留原单 |
| retry wire error | 3项中2失败 | 3通过，AC0006/CONFIGURATION_CONFLICT中文；未知不泄露 |
| 大字升级日期 | 375×2日期断行1失败 | 大字纵排，默认双列保留；36几何通过 |

前一冻结版本固定 Flutter3.32.0/Dart3.8 验证（252在后述最新UI覆盖之前完成，不冒称覆盖后再次全模块通过，也不把重叠批次数相加）：

```powershell
# 原生，JDK= D:/android_studio/jbr，GRADLE_USER_HOME= D:/gradle-home
android/gradlew.bat :app:testDebugUnitTest --tests com.vvtech.phone_agent.AlipayResultStatusTest --tests com.vvtech.phone_agent.AlipayPaymentEnvironmentTest --offline -Ptarget-platform=android-arm64 --console=plain --max-workers=2
# 直接调用方完整商业化模块，252/252、35秒；不是全工程测试
D:/tools/flutter-3.32.0/bin/flutter.bat test --no-pub test/features/commerce
# 36几何、39合成图，已查看关键小屏与大字
D:/tools/flutter-3.32.0/bin/flutter.bat test --no-pub test/features/commerce/payment_feedback_geometry_test.dart --dart-define=COMMERCE_CAPTURE_DIR=output/commerce1837/payment-feedback-20261013 --dart-define=UI_PREFLIGHT_FONT=C:/Windows/Fonts/msyh.ttc --dart-define=UI_PREFLIGHT_ICON_FONT=D:/tools/flutter-3.32.0/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf
D:/tools/flutter-3.32.0/bin/flutter.bat analyze --no-pub
openspec validate --all
```

analyze 无问题13.1秒，OpenSpec102/102。首次 analyze 发现本次协调器使用 StateNotifier 受保护 state 和 async context/lint 问题，改为只读 snapshot 接口及显式 owner.mounted/braces 后通过，不使用 ignore 掩盖。Dart format 为仅本批文件的机械批次。既有全工程 Windows 两个 symlink 环境失败边界没有重复运行或修改无关测试。

安全日志在 D:/Temp：story1837-alipay-status-{red,green}.log、story1837-native-attempt-{red,green}.log、story1837-payment-feedback-{red,green}.log、story1837-checkout-{red,green}.log、story1837-direct-route-{red,green}.log、story1837-original-retry-{red,green}.log、story1837-checkout-owner-{red,green}.log、story1837-retry-error-{red,green}.log、story1837-upgrade-date-red.log、story1837-feedback-geometry-green.log、story1837-payment-ux-{commerce-green,analyze,openspec}.log。JUnit XML 在 build/app/test-results/testDebugUnitTest（不提交缓存）。

## 视觉与待验

39张合成PNG：output/commerce1837/payment-feedback-20261013，最终UI覆盖后已全部重绘。375/390/430、1×/2×包含升级确认、已开通、支付成功、失败、取消、未完成；2×升级另保存滚动到底部的确认操作。追加实际看过390取消1×/2×、390升级1×/2×及底部、390成功1×、375未完成2×；取消浅粉感叹号+支付已取消+完成，非成功不声称未付款或权益未变化，成功无订单商品/实付。大字升级日期完整、无技术秒数且确认按钮可滚动到达，字体缩放未关闭。图使用合成2099期限和固定商品，不是用户订单/实际手机/资金证据。

## 用户最终UI覆盖与尾批验证

用户撤销“可留一个次要重试”后，购买反馈严格只留完成，query只后台收敛；重试能力留历史订单详情。删除本批产生的查询/查看/重试回调和次要路由分支，去除原单说明/商品与实付明细，不展示售后动作。Controller财务状态/安全错误仍保留，弹窗只用不含订单信息的中文投影；普通点击支付若被占位阻塞，提示“暂时无法发起支付，请稍后重试”，不自动新建或关闭旧单。正常catalog的pending导航未扩范围修改。

尾批实际RED：初次Demo校正5项中2通过3失败；仅完成追加3项中2通过1失败；原单等待与SDK返回路线2/2失败（先有一处测试括号编译问题，修正后才记录真实RED）；无商品/实付明细及busy不禁用完成3项中1通过2失败；阻塞notice1/1失败。最小presentation修复后最终20项定向通过，另36几何通过，39图重绘并实际查看。与前一252有重叠，不相加；按主代理要求未重复全252，也没有新增网络查询或支付动作。

```powershell
D:/tools/flutter-3.32.0/bin/flutter.bat test --no-pub test/features/commerce/purchase_feedback_sheet_test.dart test/features/commerce/original_payment_feedback_route_test.dart test/features/commerce/direct_checkout_route_test.dart test/features/commerce/membership_checkout_dialog_test.dart test/features/commerce/payment_attempt_feedback_test.dart
# 几何命令沿上方，最终36/36，39张图
D:/tools/flutter-3.32.0/bin/flutter.bat analyze --no-pub
openspec validate --all
openspec validate streamline-payment-attempt-feedback --strict
```

安全尾批日志：D:/Temp/story1837-feedback-demo-red.log、story1837-feedback-only-done-red.log、story1837-original-feedback-route-{red,green}.log、story1837-feedback-no-details-red.log、story1837-blocked-notice-red.log、story1837-feedback-final-targeted.log、story1837-feedback-demo-geometry.log、story1837-feedback-demo-analyze.log、story1837-feedback-demo-openspec.log。最终analyze无问题12.4秒、OpenSpec102/102与本change strict通过；首次尾批analyze有一处if braces提示，已补明确block，不ignore。尾批仍不build/install/commit/push。

admin_commerce 独立只读审查指出 quote 替换、owner 等待及历史跨端按钮边界，已逐项写实际回归修正；最后只读复核结果交主代理记录。最终 APK（1311或更高）、关闭diagnostics、保留数据安装、当前原单渠道查询与真人自愿沙箱支付仍待主任务。真实模型已由 Java 修复、1310 HTTP200/providers4 验证，Flutter 不需模型业务改动；最终无探针包不能以1310替代。
