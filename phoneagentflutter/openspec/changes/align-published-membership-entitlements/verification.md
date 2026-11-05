# Flutter 发布权益对齐验证（2026-10-15）

源码基线 codex/dev `0dbe0fbc`。本 Flutter 实施子任务由主任务统一提交交付；不升级依赖、构建安装、部署服务或触发真实支付。

## 实际改动
- commerce_order_display 以后台六支付态提供文案，详情标题不再被原生尝试覆盖；履约处理中、本次尝试和发票各自展示，原支付状态机及操作门禁不变。
- 会员权益列表显示声音克隆支持/暂不支持。入口只按当前有效 enabled 放行；发布目录只生成非连续支持等级提示，未知/失败重试，返回会员页后再读；排队与切号迟到均不放行。
- ProductOffer/DTO 新增可选 regularPlatformProductId、discountMembershipLevel；CatalogController 查询购买和普通 Apple SKU。独立 points_offer_discount 纯策略与 points_offer_price 展示组件接入既有卡片。
- Android 比较业务原价和实付，iOS 原样显示实际 SKU 价格；同币种精确十进制通过 BigInt 比较，折扣向普通价取整到百分之一折，避免夸大优惠。缺普通价只展示配置等级标签，相同/更高价不显示优惠。原 SKU 购买、预检及协议不变。
- app Provider 在会员可信履约完成后失效翻译目录；正式模型面板每次进入重读，刷新中隐藏旧选项，保留账号/地区/路由防护；preview不刷新，不增加授权推测或通话中轮询。

## RED / GREEN
先编写断言，观察实际失败，再最小实现。初次新增API测试出现编译错误时先补接口形状，再实际观察行为RED，未把编译错误当行为复现。
- 支付 PROCESSING 原文为未完成支付、SUCCEEDED混入履约；独立文案和详情标题原生覆盖均实际RED，最终相关35项GREEN。
- 克隆列表原无声音克隆行、无动态等级、未知权益放行、目录失败仍提示升级；新增6项实际RED/GREEN，保留原入口13项。
- DTO 原丢弃新增字段、目录只查询购买SKU、卡片无原价和折扣；策略10项及目录/展示3项实际RED/GREEN，覆盖金额、币种、缺普通价、相同/更贵、免费与超过double精度的金额。
- 翻译购买后缓存未失效、正式选择入口未重新加载均实际RED，4项新回归GREEN。

## 执行结果与边界
固定 `D:/tools/flutter-3.32.0/bin/flutter.bat`。
1. commerce、voice_clone、Shell克隆入口及受影响translation直接调用方扩大定向：**1096通过、10失败，共1106项**（3分16秒，非全仓）。日志 `.dart_tool/align-published-membership-tests.log`。
2. 其中4条订单旧文案断言按批准需求同步，新增详情原生覆盖及实际排队夹具后，最终订单/调用方/克隆6文件 **35项通过**；日志 `.dart_tool/published-entitlements-final-focused.log`。
3. 其余6条为既有 `domestic_model_sheet_test.dart` 语义断言缺少倍率。临时将本轮涉及的commerce Provider和翻译面板替换为HEAD版本后运行同一文件，**仍1通过、6失败**；try/finally已按原字节恢复本轮代码。日志 `.dart_tool/published-translation-head-baseline.log`。该测试文件及其fixture最终无差异，未混入无关修复。
4. 最终剔除上述既有失败文件后的翻译生命周期/面板、新入口刷新、会员缓存、纯价格和卡片6文件：**39项通过**；日志 `.dart_tool/published-entitlements-final-policy-translation.log`。不存在最终全绿1106项的声明。
5. 最终 `flutter analyze` 无问题；`openspec validate --all` **163通过、0失败**，本 change strict 校验通过；UTF-8严格解码/中文读回及 `git diff --check` 通过。

既有6条失败名称：directory failure is explicit and summary retry recovers；same protocol models have independent selectable IDs；directory choice persists without account setting 的 Android/iOS × 1.0/2.0 四个组合。HEAD的原生摘要语义本已包含 `，×1.0` / `，×1.1`，本轮不改变该展示。

## 组件截图
复用项目FontLoader/RepaintBoundary机制，无新增依赖。执行 `published_entitlement_visual_test.dart`，传入COMMERCE_CAPTURE_DIR、Windows微软雅黑和Flutter MaterialIcons路径，**6项通过**。已亲自查看中文截图：会员声音克隆行、Apple真实US$4.50/原价US$5.00/9折/中级标签、升级长等级提示；390宽1倍和320宽2倍均无溢出，长弹窗可滚动且操作可达。

截图保存在 `.dart_tool/published-entitlement-captures/`，文件为 `{membership,apple-points,upgrade}-{390-1x,320-2x}.png`，仅组件离线证据，不代表整页或真实iOS设备/StoreKit验收。

服务端发布后的实际权益、真实Apple普通/会员SKU配置及当地价格、真实支付履约和双端运行仍待联调。应先部署后端，再更新客户端；缺失当前克隆权益字段按未知处理并提示重试。

主任务最终复验：六个新增支付/价格/会员缓存/翻译刷新/克隆测试文件共31项通过；再次flutter analyze无问题，本change strict通过。主任务已检查Apple优惠与窄屏升级弹窗组件截图。

签包前独立复核发现并修复旧兼容回归：FREE/null、无权益版本且目录实际未发布（configVersionId=0）继续模型级准入；目录已发布但缺权益仍失败关闭。新增0/1目录测试先复现失败再通过，异步目录读回仍校验账号归属。克隆、test Release配置和签名登录路由联合24项通过，analyze无问题；测试APK入口策略18项通过。真实短信与支付未执行。
2026-10-15 签包交付：源码4db7320c，测试Release 1.0.52(2026101513)，com.vvtech.aiassistant.test，原登记证书MD5 ebd4c931de412bf5d9c3716815389097。标准入口校验并生成Release配置后，采用已校验精确引擎的离线Gradle构建；实际JDK17.0.20.1、Flutter3.32/Dart3.8。476任务，BUILD SUCCESSFUL；APK 78,974,564字节，SHA256 c6d40d1166ce53873d82eb7c3c467aa4a247ccf2cbb139e6e348fa7bb9457318。产物位于工作区deliveries/membership-entitlements-20261015-2026101513，不提交二进制。
实际包名/版本/证书、三个测试URL及邀请入口、仅ARM64/AOT/无debuggable和调试kernel、11项受保护原生库字节一致全部核验通过。真实product/AOT接受test三服务且拒绝16项非法配置；签名登录mock路由通过。使用私有构建凭据只读调用测试SDK/Agent，正确C1签名进入账号认证AC0002，错误签名返回AC0009，确认当前验签匹配；未登录真实账号或读取客户数据。未安装设备、部署服务或执行真实支付。指定订单MySQL查询及iOS StoreKit价格仍待用户部署后联调；既有6条翻译倍率测试失败边界保持不变。