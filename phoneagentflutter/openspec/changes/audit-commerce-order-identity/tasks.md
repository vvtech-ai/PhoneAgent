# 任务
- [x] 补订单 A 请求繁忙时打开 B 的 RED 路由测试。
- [x] 限定详情身份并在共享请求结束后查询 B，验证错误重试。
- [x] Apple PENDING 原单真实价格必经确认，PROCESSING/未知保护与取消/切号回归。
- [x] 同步协议测试并执行 commerce/points 完整集合、analyze、OpenSpec。
- [x] 交付覆盖矩阵、签名调查及明确运行态待验项。

完整commerce/points 614通过、0跳过；最终源架构/价格/账号签名/权限/调用方集合287通过、0跳过，analyze无问题（54.8秒），OpenSpec144通过和本change strict通过。完整集合和定向集合有重叠，不相加。详细矩阵与RED/GREEN、签名公开摘要及未执行渠道动作见docs/engineering/COMMERCE_DELIVERY_AUDIT_20261015.md。合入最新codex/dev及APK构建由主代理执行，本change未运行真实支付/开票、不归档运行态验收。

独立复核追加纠正：上述614使用无prepare副作用fake，不能证明价格拒绝不占槽。补模拟PROCESSING的两项RED后改只读原单nullable platformProductId→StoreKit→确认→唯一prepare。最新完整commerce/points/architecture621通过、0跳过；最后stale服务端PROCESSING反例等25项定向通过（13原单+4DTO+8反馈），analyze62.0秒无问题、OpenSpec145通过。只读SKU字段由Java代理配套投影，不能从当前目录猜测，后端未发布时缺字段只安全拒绝原单续付。

跨设备竞争追加回归：确认回调期间模拟另一设备将原单prepare成PROCESSING，本端payment抛MEMBERSHIP_PAYMENT_UNKNOWN；14/14原单测试通过，断言0launch/0create、一次被拒prepare、三次读取（初读/只读SKU/失败后查询）并展示原单PROCESSING及安全提示，重试被保护。客户端源码未改，复用既有_launch catch→_query；后端锁内拒绝Apple PROCESSING由Java代理配套实现，Alipay复用保持。
