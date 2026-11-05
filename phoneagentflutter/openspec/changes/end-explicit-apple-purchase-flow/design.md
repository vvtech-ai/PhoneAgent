# 设计

用户目标是 iOS 结束一次明确取消的购买后可以再买。成功路径已有服务器验单后 acknowledge/finish，源码未发现缺 finish；Pending 和未知结果不能当成取消。

复用 repository.closeOrder，不伪造 Apple 关单成功或清掉本地订单。共享原单规则允许 APPLE_IAP 未收款 PENDING/PROCESSING 结束；服务端须在订单锁内复核。已支付或履约开始不结束。请求丢失保留原单供本人重试结束；不同账号的迟到响应由现有 revision/mounted 检查隔离。

本次不允许对 PROCESSING/未知 Apple 原单盲目再次付款。历史占用通过明确结束后重新选择商品解决，新购买沿用现有 StoreKit 价格确认；原 token 不换。保留默认未知交易恢复逻辑，不扩展原单续付流程。
