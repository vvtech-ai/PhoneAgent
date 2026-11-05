# Flutter 商品目录隔离验证（2026-10-16）

> 当前验收规则（用户2026-10-16最新决定）：后端正价积分包合法折扣后实付保底1分、允许正常购买且不阻止发布；APP直接展示最终金额，会员价与StoreKit实价保持。下方首批隔离/隐藏及RED/GREEN保留为历史证据，不能据此将合法1分包当成不可售。最新补充验证见文末。

## 范围与实现

- 实际仓库 `D:/work/04phoneAgent/_isolated/phoneagent-task-flow`，分支 `codex/dev`，起点 `ba2b85c4`。只修改 commerce 读取、展示与相关测试，不修改金额、DTO、支付状态机、平台配置、版本号或 `pubspec.yaml`。
- `CatalogReadResult` 只负责捕获独立读取结果；控制器并发发起目录/会员读取，保留每路成功结果，并保留 mounted/revision 与原账号 Provider 生命周期隔离。刷新清空旧结果；任一路失败均关闭新购，重试重新读取。
- `CatalogState.visibleOffers` 统一按 `available` 与类型销售开关筛选，会员周期选择回退到实际展示的可售周期；积分页同样按筛选结果回退选中项。不因支付渠道或 StoreKit 临时失败将商品当作正常隐藏。
- `CommerceReadRetry` 为页面底部轻量重试；目录失败仍显示成功读取的当前会员/权益、余额、流水与订单入口。原 Apple 恢复入口不受目录错误或销售开关阻挡。
- 现有控制器与页面分别约 250 行，保留原状态编排/展示职责；独立读取结果和通用重试控件分别拆文件。新增业务微批不超过 3 个手写文件，格式化单独执行。未来商品类型继续复用目录开关和可售筛选，不往页面增加金额计算。

## RED / GREEN 证据

1. 部分读取回归：修正测试夹具构造参数后，实际 RED 为 4 失败/1 通过；最小修复后连同既有 controller 与 iOS loading 共 10 通过。
2. 不可售周期/选中回退：3 个实际 RED；最小修复后 3 通过。全不可售仍显示权益，没有价格卡、空商品错误、协议或购买按钮。
3. 会员页目录失败/会员失败：2 个实际 RED；轻量底部重试与保留会员信息后 2 通过，包含克隆关闭仍正常显示权益与恢复购买可点击。
4. 混合积分包与刷新回退：3 个实际 RED；最小修复后连同既有 points page 共 8 通过。两个不可售积分包隐藏，可售积分包直接显示后端 2700 分（¥27），未二次折扣。
5. 正常全不可售仍暴露购买积分入口：1 个实际 RED；入口复用筛选后会员页/平台开关相关 29 通过。

## 扩展复验与限制

- 首轮完整 `flutter test test/features/commerce --reporter expanded`：586 通过、25 失败，共 611 项。失败全部来自本次明确调整的旧预期：不存在的三月选择应回退到实际月度（1）；空目录不再显示空商品错误卡（3）；几何布局测试默认不可售夹具却要求展示价格卡（15）；会员读取失败时应保留成功目录（6）。
- 更新四份旧测试，未改共享夹具：iOS/controller/未发布目录 26 通过；geometry 15 通过，所有等高、价格和多尺寸几何断言保留，另明确不可售隐藏。
- 最终 commerce 集合、analyze、严格 UTF-8 与 diff 检查结果见下方最终回执。OpenSpec 已通过 164 项。
- 本轮仅合成夹具与 Flutter 自动测试；未访问真实账号、触发支付、部署服务、推送代码、构建 APK、安装或操作设备。iOS/macOS/真实 StoreKit 与 Java 部署联调仍待验。
- 不修改既有无关国内翻译倍率基线失败；本次 commerce 集合不包含翻译测试，不宣称全仓测试通过。独立复核及签包由主任务继续，未勾选对应交付项。

## 最终回执

- `D:/tools/flutter-3.32.0/bin/flutter.bat test test/features/commerce --reporter expanded`：612 项全部通过，90 秒。增加了 14 项定向回归；首轮 25 失败均在最终集合中复验通过。
- `flutter analyze` 首轮 2 项静态提示（冗余 `?.`、测试 if 花括号），机械修正后 `No issues found`（15.4 秒）。机械修正涉及的 controller/points 13 项再次通过。
- `openspec validate --all`：164 passed、0 failed；严格 UTF-8 解码和替换字符检查覆盖全部 22 个变更文件，中文提示和文档读回正常；`git diff --check` 通过。
- 证据日志保存在工作区外 `D:/work/04phoneAgent/.local-data/logs/membership-catalog-20261016/`：`flutter-commerce-first.log`、`flutter-commerce-final.log`、`flutter-analyze.log`、`flutter-analyze-final.log`、`flutter-mechanical-final.log`、`flutter-openspec.log`。
- 页面测试实际验证成功中级会员/当前权益/克隆关闭说明仍可见，错误没有 CommerceCard 祖先且位于权益/购买预览之后；本轮未新增截图文件，不把测试布局断言描述为真机视觉验收。

## 追加：声音克隆正常不支持提示（2026-10-16）

- 基点 `d513118480be867a980d395d135e96c03feaa3a1`，仅调整 clone gate/dialog 两份生产文件及直接测试。当前有效 `enabled=false` 后，可选目录异常只降级说明，不改变拒绝结论；当前等级明确展示，主操作改为“查看会员权益”，取消仍拒绝。可信已发布目录仅筛选高于当前等级且真实 enabled=true 的等级；无结果或目录异常使用通用权益说明。UI 不承担权限判断，既有路由、返回重读与账号守卫保持。
- 实际 RED：`published_clone_membership_test.dart` 11 通过/6 失败，捕获异常分支、当前等级文案、操作及推荐范围；最小 GREEN 后 gate/route 联合 24 通过。最终增补缺失字段/畸形对象回归，gate 文件 21 项通过。
- `flutter test test/features/voice_clone test/shell_clone_entitlement_entry_test.dart test/features/commerce/published_entitlement_visual_test.dart test/core/config/test_environment_test.dart test/features/auth/dio_auth_gateway_test.dart --reporter expanded`：514 项全部通过（增补四项字段回归之前）。覆盖真实失败重试、非法 enabled、FREE/null 已发布/未发布/无法证实、当前有效权益与排队权益区分、会员页返回重读、双入口取消与导航、迟到目录成功/异常的账号失效保护，以及配置/登录网关。
- 中文字体截图测试 8 项通过；通过 FontLoader/RepaintBoundary 对真实 gate 生成 390×844/1 倍与 320×568/2 倍字体截图。窄屏正常不支持：`.dart_tool/clone-entitlement-20261016/upgrade-320-2x.png`；真实当前读取失败：`.dart_tool/clone-entitlement-20261016/read-failure-320-2x.png`。已读取图像核对中文、换行及操作可见；截图为合成数据与测试宿主页，非真机、非真实账号、非像素级全产品验收。图片不提交。
- 最终 `flutter analyze` 无问题（12.5 秒），本 change `openspec validate ... --strict` 有效，`openspec validate --all` 164 通过/0 失败；12 个变更文件严格 UTF-8 解码/替换字符检查及 `git diff --check` 通过，中文文案和记录读回正常。
- 本地日志：工作区外 `D:/work/04phoneAgent/.local-data/logs/membership-catalog-20261016/clone-*.log`。所有本任务测试进程已正常退出；10月8日/10日遗留的四个同工作树 tester 并非本任务创建，已告知主任务，未停止历史进程。本子任务交接后不继续运行 Flutter 测试。
- 本轮不推送、打包、安装、读私有凭据或真实账号；1.0.52(45)由主任务统一复核签包。没有改 commerce 实现；独立复核发现的积分页重试边界由后续单独处理，不代表已在本批验收。PMReport 内置 registry 未登记实际 remote 仓库 `phoneagentflutter`，无需上报，不以旧 `aiassistant` 猜测匹配。

## 独立复核 P2 修复：销售关闭与会员错误同时发生

- 实际新基点 `46992c597db7d86f6c812f1d3e8cee276a128ad6`。复核确认 PointsPurchasePage 的销售关闭提前返回分支遮挡真实会员错误，仅修改该页面及直接测试，不改克隆入口、控制器、金额或价格策略。排查页面内其余返回路径，正常购买分支已有相同错误重试，无需扩展修复。
- 在既有 points page 测试补两种组合：目录成功/积分关闭/会员失败时，关闭说明后仍有错误和可点击重试，同时无价格、协议、购买动作；正常关闭且无错误时无重试。实际 RED 为 1 通过/1 失败，失败是会员错误文本不可见。
- 最小修复将关闭分支改为可滚动说明区，并按 state.error 复用 CommerceReadRetry。points page、catalog partial load、points available selection、platform purchase availability 共 36 项全部通过；不重复先前 612 项集合，也不将其作为本批重新运行证据。
- `flutter analyze` 无问题（15.4 秒），本 change `openspec validate isolate-unavailable-commerce-products --strict` 通过；6 个本批变更文件严格 UTF-8/替换字符检查、中文读回与 `git diff --check` 通过。测试无真实账号或支付，没有构建、安装、推送或私有配置访问。
- 日志位于工作区外同一证据目录：`flutter-review-fix-red.log`、`flutter-review-fix-green.log`、`flutter-review-fix-analyze.log`。本批所有测试执行完毕后交接；新基点后的正价积分折后实付保底 1 分规则由主任务另行实施，本批不修改相关规格或金额。

## 最新补充：最低实付1分展示（2026-10-16）

- 起点 `fc4285d00b9f321100b42520fe6ecef05fc18177`，分支 `codex/dev`。先同步本change proposal/design/spec/tasks为用户最新口径：后端正价积分包合法折扣后最低1分、正常购买、不阻止发布，覆盖早期折后零分拒绝。APP未修改任何lib文件，不新增金额计算；会员配置价与StoreKit实际SKU价格保持。
- 只在现有 `published_points_price_widget_test.dart` 增加直接 `PointsPurchasePage` 用例：目录包含9折权益和后端最终1分/标价1分，显示¥0.01、购买回调仍为1分，没有¥0、虚假9折、会员专享节省或划线价。先出现1个夹具失败（Apple通道按钮误找支付宝），修正为专用ALIPAY夹具后通过；这是测试夹具纠正，不将其记作产品RED。业务RED由Java唯一计价入口真实测试提供。
- 固定Flutter3.32.0/Dart3.8.0，`flutter test test/features/commerce/published_points_price_widget_test.dart --reporter expanded`：4项全部通过，含新增页面与既有Android/Apple真实价格、SKU保持断言；无需修改APP生产逻辑。`flutter analyze`：No issues found（20.0秒）。不重复已通过commerce或克隆集合。
- `openspec validate isolate-unavailable-commerce-products --strict`有效；`openspec validate --all`：164通过、0失败。日志为外部证据目录下 `minimum-payable-flutter-page-final.log`、`minimum-payable-flutter-analyze.log`、`minimum-payable-flutter-openspec.log`；UTF-8/diff与提交回执见同目录 `minimum-payable-task-report.md`。
- 当前本任务测试/分析进程全部正常退出，不再运行Flutter。10月8日/10日四个历史tester不属于本任务，未停止。本补充不推送、签包、部署、安装、不访问私有凭据或真实账号；不宣称设备/StoreKit运行验收。PMReport registry不含实际remote仓库phoneagentflutter，无需上报。

## 统一复核、推送与签包交付（2026-10-16）

- 两仓完整差异与最低实付1分任务的独立规格/质量复核通过，无待修P1/P2；Flutter销售关闭重试P2、克隆正常不支持提示均已有独立复核。后端当前10类Surefire XML由主任务再次核对为67项、0失败/错误/跳过。
- 已正常推送Java `feature/test_v1.7.0` 实现提交 `4e80e1547fb837e03f288156774bb85d9169ce9d`，Flutter `codex/dev` 实现提交 `a8e80a42ccb17f377d3ec94ec5219ed475bc29f7`，并以ls-remote读回。Web本批无代码改动。随后本交付记录为纯文档提交，不改变包内源码。
- Flutter源码冻结且本轮测试全部结束后，按登记入口校验参数并使用既有Release config-only/pub与校验过的离线引擎路径构建；Flutter3.32.0/Dart3.8.0/JDK17.0.20.1。Gradle BUILD SUCCESSFUL，实际APK为 `1.0.52 (45)`，严格按用户指定。
- APK：`deliveries/catalog-isolation-20261016-45/Phone_Agent_TEST_1.0.52_45_test_20261016_110052.apk`（工作区根目录下）；SHA256 `4a244f6bfda2a94d9a942cde5c4c56a07037d2e58aed6594e35d4eeab246ded2`；大小78974560字节。实际包名 `com.vvtech.aiassistant.test`，原登记证书MD5 `ebd4c931de412bf5d9c3716815389097`。
- 成包核验通过：签名、版本、三个测试HTTPS服务与邀请host/scheme、Release/ARM64/Dart AOT、无debuggable/调试kernel/校验库、11项受保护原生库字节一致；真实product/AOT配置守卫通过，当前SDK/Agent凭据只读C1正反检查通过。详细回执位于上述交付目录的test-release-verification.json、SHA256SUMS.txt、build-receipt.json和pushed-branches.json；私有参数和APK不入Git。
- 用户需要构建/部署Java对应分支的SDK服务，后端最低一分和目录修复才在测试运行态生效。本次没有部署、修改真实配置/数据、手机安装或真实登录/支付，不把本地回归/合成截图当运行验收。设备此前误设的大版本不用于自动升号、卸载或清数据。Java全量OpenSpec唯一既有缺delta问题仍按上方记录保留，当前change strict通过。
