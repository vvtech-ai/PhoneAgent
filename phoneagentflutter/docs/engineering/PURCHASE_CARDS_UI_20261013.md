# 会员与积分购买卡片 Demo 对齐

## 来源与展示职责

已实际查看用户两张Demo截图（仓库外clipboard原图）及只读7e7bd38会员/积分参考图。目标为包月/包季/包年并排等高、积分数量/基础赠送左和实价右。用户后续明确卡片不显示原因码或额外不可售标签。旧原型微信按钮/自动续费不搬入，后台发布及销售准入规则由主代理修后端，本侧不改变可售事实。

- `membership_price_options.dart`：对当前真实等级商品按周期横排，以IntrinsicHeight及stretch共享最大内容高度，不固定高度或关闭字体缩放；只发布一个周期则只呈现一张卡。
- `membership_period_card.dart`：周期局部包月/包季/包年、实际价及自身合法原价/折扣，缺原价隐藏；内容纵向居中，不显示协议原因码/额外状态。
- `membership_offer.dart`：组合上述价格组与原购买入口，购买仍由state.purchasable决定；订单全局periodName未改。
- `points_offer_card.dart`：独立商品选中态与左数量/基础赠送、右实价，使用真实数据；页面保留选择和确认支付状态，不新增微信。

## 失败证据与验证

新几何/语义回归先跑旧源码：14项中6通过、8失败。六组会员等高失败（普通字体115/126差11，2×最大差50），局部周期名/卡片原因码语义两项失败；积分左右构图六组原本通过，提取后保留。日志 `D:/Temp/story1837-purchase-cards-red.log`。

修复后第一次运行几何12项通过，两个语义测试因测试句柄在验证后才释放而失败；将句柄在try/finally内及时释放，未调整产品行为来掩盖测试问题。用户明确取消状态标签，因此旧原价回归对应断言同步为“保留价格、无额外标签”。

- 36项直接定向通过：新15项几何/语义/单周期、原价、布局、积分交互和Demo保真。
- 同一新15项带字体绘图复跑通过，与上组重叠，不能相加为51项。
- 8个本批UI/test文件定向analyze无问题（2.4秒）；按主代理要求未分析/格式其临时模型诊断文件。
- OpenSpec全量100/100、本change strict通过；中文UTF-8回读/diff通过，仅已有LF→CRLF提示。

实际命令：

```powershell
D:/tools/flutter-3.32.0/bin/flutter.bat test --no-pub test/features/commerce/purchase_card_geometry_test.dart test/features/commerce/membership_reference_price_test.dart test/features/commerce/membership_product_price_layout_test.dart test/features/commerce/points_purchase_page_test.dart test/features/commerce/demo_fidelity_test.dart
D:/tools/flutter-3.32.0/bin/flutter.bat test --no-pub test/features/commerce/purchase_card_geometry_test.dart --dart-define=COMMERCE_CAPTURE_DIR=output/commerce1837/purchase-cards-20261013 --dart-define=UI_PREFLIGHT_FONT=C:/Windows/Fonts/msyh.ttc --dart-define=UI_PREFLIGHT_ICON_FONT=D:/tools/flutter-3.32.0/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf
D:/tools/flutter-3.32.0/bin/flutter.bat analyze --no-pub lib/features/commerce/presentation/widgets/membership_price_options.dart lib/features/commerce/presentation/widgets/membership_offer.dart lib/features/commerce/presentation/widgets/membership_period_card.dart lib/features/commerce/presentation/widgets/points_offer_card.dart lib/features/commerce/presentation/pages/points_purchase_page.dart test/features/commerce/purchase_card_fixture.dart test/features/commerce/purchase_card_geometry_test.dart test/features/commerce/membership_reference_price_test.dart
openspec validate --all
openspec validate align-commerce-purchase-cards --strict
```

## 绘图与未验边界

12张合成PNG在 `output/commerce1837/purchase-cards-20261013/`，文件名 `{membership,points}-{375,390,430}-{1,2}x.png`。已独立查看375普通/大字两页、390会员普通/大字和积分大字、430两页大字，卡片等高、文字不重叠/截断、无原始原因码。边界用长合成年价¥1234.50，2×时自动换行，保留完整数值；未强缩字号或造示例可售。

会员截图是隔离MembershipOffer几何，不是整页或真实发布目录；合成夹具故意省略营销权益，截图里的“权益暂未配置”不代表运行环境。积分夹具仅一个包，购买按钮禁用场景用于验证真实禁购，不代表后端已发布目录数量。原截图未覆盖，未读实际账户数据。

本批未构建、安装、提交或推送，Flutter窗口已释放给主代理诊断包。目录DTO小修复、模型诊断、签名/会话、支付金额和积分来源规则均不修改。真实已发布商品、设备字体与支付可用性须由主代理后续包复验，不把合成绘图当作真实购买或设备验收。
