# 平台会员与积分新购开关

本批在 story1837-flutter 的 22a80a06 上接续未提交的待处理购买/发票服务提示，保留前批内容。主任务批准后台分别控制 Android/iOS 的会员与积分购买；Java/Web 由其它代理实施。本批不操作设备、构建 APK、提交、推送或修改原生支付与 StoreKit 价格规则。

## 冻结契约

CatalogResponse 顶层 `membershipEnabled`、`pointsPackEnabled` 为当前认证客户端平台的非空 boolean。服务器取可信 identity.channel，不读取客户端 OS header。Flutter 对历史缺字段兼容 true，对显式 null、字符串或数字拒绝协议。新服务端未发布返回 false/false，关闭类型从 products 过滤但保留已发布版本、权益和协议。

Flutter 不消费后台的嵌套 platformAvailability，也不自行判断另一平台开关。新开关只限制新购；余额、会员权益、流水、原订单查询/继续支付/取消、发票及 Apple 原交易恢复不受影响。

## 入口盘点与实现

- 当前正式入口：HomePage 的 PointsBalanceBadge → ShellRoute._wallet → MembershipRoute。它是钱包总入口，未隐藏或改动。
- SettingsRoute 没有会员/积分购买入口；GoRouter 只有根路径 `/`，没有商业化深链；当前购买积分路由仅在 MembershipRoute 内部创建。
- CommerceCatalog/CommerceDto 保存独立开关；CatalogState 在 purchasable 中加入按商品类型的准入，MembershipCheckout 报价前也校验。
- MembershipBalanceCard 的加购回调可空，隐藏积分购买按钮但保留真实余额/通话估算/今日赠送/流水。会员开关关闭后 MembershipPage 隐藏营销 tabs、周期价格、购买和付费协议，复用 MembershipOffer 的只读模式展示 MembershipCurrent 真实当前权益，不用营销选中档的权益覆盖。
- PointsPurchasePage 即使已经打开也会在积分关闭时移除商品、协议和付款控件，保留返回能力。MembershipRoute 的异步 current 校验读取最新目录，升级确认或材料等待期间关停后旧回调不得继续新购。
- 前批新增待处理购买弹层保持可达；它的原单支付重试不使用新购开关。iOS 恢复购买仍可滚动访问。

生产代码按三个微批各三个文件实施；没有扩大巨型页面或增加重复状态机。旧响应和现有构造夹具默认开放，仅后端显式关闭字段决定隐藏。

## 验证记录

- 首轮新测试 18 项：3 通过、15 失败，复现独立开关未生效、非法字段未拒绝、购买 UI 未隐藏和直接 checkout 仍报价。修复后 18/18 通过。
- 追加异步边界：升级弹窗期间更新目录关闭，在原路径实际 RED 1 项（仍显示升级成功/产生购买）；最新目录门禁后通过。
- 追加覆盖：未发布显式双关闭、iOS 恢复、双关闭仍可原单重试。三文件首轮 34 通过/1 失败为恢复按钮在 ListView 屏外未构建；测试改为实际滚动查找，没有改生产恢复规则。
- 四开关组合分别验证购买区隐藏与余额/真实权益/订单/流水/待处理入口保留；夹具故意保留关闭类型产品，证明 UI 不只依赖后端过滤。
- 新 change strict 通过，全仓 `openspec validate --all` 为 131/131。
- `flutter test test/features/commerce --concurrency=2 --reporter expanded`：330/330 通过，0 失败/跳过，84 秒，包含前批待处理购买与发票服务提示。不是全项目回归。
- 最后补目录加载边界：catalog 尚未返回时不短暂显示积分加购。该用例实际 RED 后收紧一行显示条件；随后五文件 56 通过/3 失败为旧三宽夹具只填会员、未提供加载完成目录却断言加购存在。夹具补合法已加载旧兼容目录，保留原布局断言；没有放宽未知开关门禁。
- 加载边界收尾后五文件最终 59/59 通过（与 330 项重叠，不累加）。analyze 首轮仅原 if 因格式化展开产生花括号风格提示，补 block 后无问题；最终再次 analyze 无问题，15.4 秒。UTF-8 严格解码/中文回读与 git diff --check 通过。

日志保留在 D:/Temp/story1837-platform-purchase-*-20261014.log。合成仓库/HTTP 字段与 widget 测试不代表真实支付渠道、设备视觉或部署验收；本批未发真实付款或开票请求。
