# 设计与冻结契约

CatalogResponse 顶层 membershipEnabled、pointsPackEnabled 为当前可信平台的非空 boolean。历史响应缺字段兼容 true；显式 null/非 boolean 拒绝为协议错误。未发布目录由新服务端显式返回 false/false；关闭类型从 products 过滤，但已发布 configVersion、benefits、协议等保留。客户端不根据 OS header 推断另一个平台开关。

CommerceCatalog/DTO 保存开关，CatalogState 提供按商品类型的准入并复用到 purchasable。MembershipPage 隐藏关闭会员销售时的营销等级 tabs 和价格/协议/购买动作，复用 MembershipOffer 只读模式呈现真实 MembershipCurrent 权益，不用未选中营销数据替代。余额卡的加购回调可空，仅隐藏按钮；总余额与流水不变。

PointsPurchasePage 在关闭时即使直接进入也不展示商品/付款/协议。MembershipCheckout 在报价前检查商品类型开关，MembershipRoute 在异步确认/唤醒前的 current 检查读取最新目录，阻止旧 UI 回调新购。已有订单的继续支付、取消、查询、发票与恢复不接新购门禁，Apple 原交易恢复不受影响，不修改原生 SDK。

三个生产微批各不超过三个文件：catalog/DTO/state；余额卡/只读权益/会员页；积分页/checkout/route。OpenSpec 和真实 RED 先行，随后定向协议、四组合 UI、直接调用及异步回调回归，商业化受影响集合与 analyze；不构建 APK、不操作设备/真实支付。
