# 设计

以旧仓库指定分支的 monetization-demo/js/monetization.js 为展示来源。旧仓库只读。当前实现分支 codex/story1837-membership-commerce，基线 6d1dc1bc，与远端一致；保留既有 account_protocol_diagnostics.dart 改动。

第一微批只修改 MembershipBalanceCard、MembershipPage、MembershipRoute：路由读取已有 pointsBillingProvider 和钱包字段；小组件复用 PointsPresentation.estimatedMinutes 做展示估算。未知费率不猜 100，过期钱包不显示今日已到账。保留积分流水可达，不展示预占及内部积分桶。

后续微批处理订单表与小型联系方式组件，统一轻量邮箱文案，继续使用已发布目录 supportEmail，不能硬编码覆盖运营配置。订单会员等级/周期使用历史字段，不按当前目录重新解释旧订单；单次购买不照搬 Demo 连续自动续费。未实现渠道不添加可购买入口。

每批最多三个业务文件。以窄屏/大字截图与 widget 测试验证；不调用支付、开票或数据库写操作。
