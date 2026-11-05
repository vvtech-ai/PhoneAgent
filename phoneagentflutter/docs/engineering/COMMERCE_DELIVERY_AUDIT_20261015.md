# 会员、积分购买、订单与发票交付审计

审计基点：`7310d369`，工作树 `story1837-flutter`；保留进入本轮前的 Apple 明确取消结束流程和会员外层协议移除。规则为根 docs 的《1837 PDR》及 v1.3《会员权益暂停恢复与排队购买 PDR》，后者覆盖旧折价规则。本次不操作生产签名、业务后台、支付、发票申请、安装、卸载或账号重置。

## 覆盖矩阵

下表的“通过”是源码及离线自动化证据，实际渠道、部署状态和手机效果不在此结论中。

| 需求与边界 | 源码证据（相对仓库根） | 测试证据（test/features/ 下，除注明外） | 结果 |
| --- | --- | --- | --- |
| 同 SKU 续购、同/低级排队、高级暂停旧权益 | commerce/domain/membership_entitlements.dart；commerce/data/membership_v2_dto.dart；controller/membership_checkout.dart | commerce/membership_contract_v2_test、membership_checkout_test、membership_confirmation_v2_test | 按服务端类型确认，不在客户端折价换天数 |
| ACTIVE 身份和营销选择分离 | controller/catalog_controller.dart；widgets/membership_entitlement_sections.dart；domain/membership_access_hint.dart | commerce/membership_queue_test、membership_access_hint_test、membership_route_v2_test | 当前/保留/队列分区，选择卡片不赋权 |
| 积分包折扣及多待付独立购买 | data/commerce_dto.dart；controller/membership_checkout.dart；purchase_controller.dart | commerce/points_repurchase_test、points_pending_route_test、pending_membership_controller_test | PACK 读取服务端报价；不占会员支付位置 |
| 会员协议每次主动确认；积分协议默认未选 | widgets/membership_confirmation_payment.dart；commerce_agreement.dart；controller/membership_checkout.dart | commerce/membership_single_agreement_test、membership_confirmation_route_test、direct_checkout_route_test | 会员外层重复协议移除，必经弹窗门禁保留；积分未勾选仅提示 |
| 报价/下单/原生价格/取消慢请求和连点 | purchase_controller.dart；pages/membership_route.dart；points_purchase_page.dart；pending_membership_purchase_sheet.dart | commerce/purchase_busy_test、checkout_owner_lifecycle_test、membership_confirmation_dialog_test、apple_original_retry_test | busy、防重、失败恢复；离开页面不拉起支付 |
| Android 支付宝真实环境和结果安全 | android/.../CommercePaymentChannel.kt、AlipayPaymentEnvironment.kt；data/device_payment_launcher.dart | commerce/native_payment_launcher_test、native_attempt_status_test、original_order_retry_test | 原单材料给环境；SDK状态不作为已付款事实，支付宝失败/未知不造本地成功 |
| Apple 原币/真实商品价/确认时锁价 | ios/Runner/CommercePaymentChannel.swift；domain/confirmed_payment_material.dart | commerce/apple_local_price_contract_test、apple_locked_material_integration_test、ios_checkout_price_test | 不与CNY参考价等值门控，传确认数值/币种/类型供原生二次核验 |
| Apple 可信验单后 finish，恢复及重复事件 | controller/apple_transaction_verifier.dart、apple_recovery_subscription.dart；app/commerce_providers.dart | commerce/ios_transaction_recovery_test、ios_repeat_purchase_test、purchase_controller_test | 服务端可信 SUCCEEDED 才 finish；处理中不重付，重复验单串行，切号不 finish |
| 历史可付款 PENDING Apple 原单继续支付 | controller/apple_original_price_confirmation.dart；widgets/original_apple_price_dialog.dart；两处原单入口 | commerce/apple_original_retry_test（14项） | 只读原单锁定SKU、明确确认真实价后唯一一次prepare；拒绝/取价失败/切号不占位置；跨设备已占用查询原单，PROCESSING/未知不能重付 |
| 支付/履约/权益三种状态及排队后激活 | domain/commerce_order.dart；membership_result_feedback.dart；widgets/purchase_completed_summary.dart | commerce/commerce_order_test、membership_result_v2_test、membership_contract_v2_test | 已付待履约显示处理中；QUEUED履约成功不当支付失败，后续用当前投影 |
| 订单详情身份、分页和原单动作 | pages/purchase_result_route.dart；controller/orders_controller.dart；widgets/commerce_order_action.dart | commerce/order_route_identity_test（3项）、original_order_action_test、original_order_retry_test | 本轮修复：共享A繁忙/完成时打开B，不显示或操作A；失败仍重试B |
| 账号切换/迟到响应/钱包缓存隔离 | app/commerce_providers.dart；core/network/account_api.dart；points/data/secure_points_wallet_cache.dart | commerce/checkout_owner_lifecycle_test、ios_transaction_recovery_test、invoice_controller_test；points/*cache*；core/network/account_api_test | loginEpoch销毁控制器；钱包按环境/URL/账号；草稿销毁清空；迟到响应不渲染 |
| Apple CNY净额开票与外币/凭证缺失说明 | domain/platform_payment_amount.dart；presentation/invoice_availability_notice.dart；pages/invoice_route.dart | commerce/invoice_availability_test、apple_receipt_amount_test、invoice_availability_notice_test | 服务端资格和invoiceAvailableFen；外币/无可信凭证不造CNY金额；已有发票继续查 |
| 发票草稿、企业专票、重试及文件 | domain/invoice.dart；controller/invoice_controller.dart；data/api_invoice_repository.dart、device_invoice_file_destination.dart | commerce/invoice_draft_test、invoice_controller_test、invoice_sheet_test、invoice_tax_login_test、invoice_keyboard_layout_test | 校验、幂等请求、失败重填、账号过期不打开文件；仅PDF/OFD/XML，20MiB/MIME白名单 |
| 退款仅联系客服、无自助操作 | widgets/membership_confirmation_payment.dart；commerce_support_contact.dart；结果页 | commerce/commerce_support_contact_test、membership_confirmation_v2_test | 保留contact@vv.tech文案，不添加自助退款或改权益入口 |
| 模型/并发/批量/克隆权限与异常回复 | domain/membership_access_hint.dart；现有calls/voice_clone/conversation准入链路 | commerce/membership_access_hint_test；calls/*admission*；voice_clone/clone_fresh_admission_test；conversation/membership_denial_reply_test | 真实服务端权益裁决，模型提示不授权，已运行通话不由此打断 |
| 375/390/430、长队列和2倍字 | 会员/订单/发票widgets | commerce/commerce_visual_test、membership_confirmation_visual_test、purchase_card_geometry_test、invoice_keyboard_layout_test | 合成UI测试，不能冒充真机像素/操作验收 |

表中 commerce 源码前缀为 `lib/features/commerce/`；`controller/`、`pages/`、`widgets/` 位于 `presentation/`。测试名称省略 `.dart`，不代表本次新建了全部测试。

## 本轮问题与修复证据

1. **订单A状态泄露到B详情**：初始query遇busy直接返回，详情原先直接显示共享控制器状态，A完成后计时器也不会查B。两个路由测试真实RED（找到禁止出现的`order-A`），随后修复身份显示和轮询，追加查询失败后重试B，共3项通过。
2. **重启后Apple PENDING原单无法续付**：旧`appleAttemptPending`对所有恢复原单封死，且缺确认价。真实RED为期待一次launch、实际0；新增独立价格读取和确认组件，只有明确PENDING且本会话无未知尝试才可确认，PROCESSING及原生Pending/未知继续保护。10项新回归覆盖接受/拒绝、两处入口、连点、页面/账号失效及不建新单。
3. **外层协议移除后的测试残留**：完整集合首轮599通过/2失败；两失败均在direct_checkout_route_test仍点击已删除外层Checkbox。修正测试步骤，保留积分包勾选和会员弹窗勾选断言，相关9项通过。
4. **独立复核纠正价格确认副作用**：初版helper在确认前调用payment，服务端prepare会先改PROCESSING；fake未模拟该副作用，导致原10项和614集合未发现。补上真实状态变化后两项RED：接受实际2次prepare（应1）、拒绝实际1次（应0）。最终helper改只读订单platformProductId，确认后唯一一次prepare；接受/拒绝、取价失败、缺SKU、页面/账号失效、两入口及本地旧PENDING/服务端已PROCESSING共13项及DTO契约回归通过。需要服务端配套字段先发布；不从当前目录猜SKU，旧单缺字段安全拒绝续付。

每个业务微批不超过3个手写源码文件。领域材料校验提取到`confirmed_payment_material.dart`，价格发现、确认UI、支付编排分责；PurchaseController保持500行，未放宽架构测试。中间首次扩展到507行的架构校验失败被真实记录，提取校验后复验，不用放宽阈值隐藏失败。

## 验证记录

- 首轮完整commerce+points：599通过、2失败（上述旧协议测试）。随后身份修复+协议步骤同步完整604/604通过。
- 新增Apple原单保护后的完整commerce+points：614/614通过，0跳过、0失败，日志`D:/Temp/commerce-points-audit-20261015-final-v2.log`。该集合运行期间最后提取了无行为变化的领域材料校验，最终源另用架构/锁价/恢复/权限/账号集合验证，具体回执追加下方；不将重叠集合相加。
- 纯校验提取前analyze无问题；纯校验提取后的最终analyze、架构及跨模块验证见下方回执。
- 最终源补充验证：`flutter test --no-pub test/architecture_test.dart`、Apple原单/锁价/地区价/原生桥/恢复/页面归属、`core/network`账号/签名/路由、克隆准入/会员拒绝播报和完整`test/features/calls`合计287/287通过，0跳过，日志`D:/Temp/commerce-audit-security-final-20261015.log`；该集合包含完整商务集的重复测试，不能与614相加。
- 最终源`flutter analyze --no-pub`退出0，无问题（54.8秒）。`openspec validate --all`144/144，本change `--strict`通过；diff检查通过。仅业务源码最后提取的纯校验另验，没有重跑无关全仓测试。
- **独立复核修正后的最新回执**：只读SKU完整`commerce + points + architecture`621/621通过（商业化/积分617、架构4），0跳过/0失败，日志`D:/Temp/commerce-audit-readonly-sku-final-20261015.log`。随后最后新增“本地旧PENDING/服务端已PROCESSING”反例及明确NOT_STARTED/零实付守卫，原单13+DTO4+反馈8共25/25通过。最新analyze退出0无问题（62.0秒）；最终OpenSpec145/145，两个新change均strict通过。以上集合重叠不相加，旧614回执不代表已验证prepare无副作用。
- **跨设备确认期竞争**：另补“确认框期间另一设备先prepare同原单”的服务端拒绝响应回归。fake prepare在PROCESSING抛MEMBERSHIP_PAYMENT_UNKNOWN；当前客户端既有异常路径继续查单并显示原单PROCESSING与安全提示，0launch、0create、一次被拒prepare，重复点击继续被保护。最新原单14/14通过；本批analyze无问题（11.5秒）、change strict/diff/UTF-8检查通过。此批只加测试/文档，无client lib修改，后端锁内PROCESSING拒绝由Java代理配套。没有将其伪装为已取消，也未另跑无关完整集。
- 不进行APK构建、安装或真实渠道动作，由主代理在合入最新origin/codex/dev后统一构建。该远端已到`8902587962676569a263fd68f0af14b625e8310d`，7310d369是其祖先；无commerce源码交叉，tasks/issue日志均须保留；account_api新增录音流部分需要集成后保留并回归账号签名。

## 测试签名与私有配置只读调查

- 当前Flutter Gradle仅为Debug/Profile设置`com.vvtech.aiassistant.dev`，Release生产签名门禁仍在。本轮未修改Android构建文件。
- `D:/work/04phoneAgent/aiassistant-app/local.properties`引用`D:/work/kexin_ai/aiassistant/aiassistant2.keystore`，alias为`vvtech`；签名密码存在但未输出、未复制。
- 公钥证书DER MD5：`ebd4c931de412bf5d9c3716815389097`，与用户支付宝AppID `2021007109657286` 登记值完全一致。SHA1：`38:74:B9:FF:D9:DD:E2:63:06:B6:8D:35:27:74:89:C8:7E:A6:80:3C`；SHA256：`15:47:86:09:EF:2C:9A:26:8F:15:4D:34:5C:DC:C4:D1:CE:F1:72:04:DD:AC:3E:25:F0:D2:2A:11:E0:FE:D6:C7`。只用环境传密码给keytool，不将密码放命令实参或日志。
- 既有受控`D:/work/04phoneAgent/_isolated/phoneagent-task-flow/.local/signing-audit/phone-installed-test.apk`的aapt身份为`com.vvtech.aiassistant.test`、44、`1.0.50-test`；它是历史身份参考，不是本次交付产物。
- 初读旧私有test参数`D:/work/04phoneAgent/_isolated/phoneagent-task-flow/.local/cloud-test/device-defines.json`仅证明地址和非空，主代理进一步核对它实际对应id1/.local，不能用于最终test包。最终私有参数改用主代理只读导出的`C:/Users/wuxiwen/.aiassistant-secrets/commerce-delivery-20261015/device-defines.test.json`；本子任务PlanOnly校验APP_ENV=test、三个testURL和四字段非空通过。主代理确认其对应已启用id2/.aitest，拟交付精确package迁移guard SQL，本子任务不修改后台。实际clientContext仍来自原生readC1，不把地址或非空等同凭据范围已匹配.test。
- 生成test包使用新增独立test环境策略，仅显式`PHONEAGENT_ANDROID_ENV=test`时修改Debug为.test及登记签名；默认Debug/Profile为.dev，Release原门禁保持。构建脚本、17项回归和Gradle无APK配置验证见`ANDROID_REGISTERED_TEST_BUILD_20261015.md`。不静默将`.aitest`后台绑定改成`.test`，本报告不以历史JSON或证书匹配证明当前.test凭据授权。
- 最后产物须独立核对package=`com.vvtech.aiassistant.test`、版本、test路由、证书DER MD5、供应商SDK文件完整性及APK SHA256。密钥、私有defines、APK均不进入Git。

## 运行态边界

服务端权益推进、价格/折扣和净额资格依赖实际部署。真实支付宝支付/取消/迟到到账、税航登录/开票文件和Apple沙箱/finish仍需专门环境证据。本次用户交付只要Android APK，不生成iOS包；静态审计iOS现有能力不等于iPhone验收。没有真实付款、开票、外呼、安装/卸载或账号重置。
