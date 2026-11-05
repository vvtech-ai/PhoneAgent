## 实施与验证

- [x] 1. 记录现有 PROCESSING 不可取消、取消处理中可重付及会员入口缺失的真实 RED。
- [x] 2. 分离取消请求资格与取消中重付门禁，保留服务端终态权威。
- [x] 3. 接入简洁待处理购买弹层及会员入口、换套餐引导和状态刷新。
- [x] 4. 验证确认取消、未知保留、跨刷新禁付、可信成功优先、支付等待与返回不泄漏订单详情。
- [x] 5. 受影响测试、analyze、OpenSpec、UTF-8 回读及任务记录。

2026-10-14：商业化 308 项通过，analyze 无问题，OpenSpec 全仓 130 项和本 change strict 通过。初始业务 RED、追加安全门禁 RED 及最终范围见 docs/engineering/PENDING_MEMBERSHIP_AND_INVOICE_SERVICE_20261014.md。未操作设备、提交或真实支付。
