# 设计

这是现有商业化 presentation/domain 的小范围修复。CommerceOrder 分开可支付、可请求取消及服务端取消处理中；PurchaseController 只调整关闭准入，仍由接口返回决定状态。新增小型待处理购买弹层负责查询、确认及支付反馈，不扩展已有技术结果页。MembershipPage/Route 提供直达入口、换套餐引导与关闭后的刷新。

ALIPAY 的 PENDING/PROCESSING、NOT_STARTED、cashPaidFen=0 可请求服务端关闭；canPay 保持原义。精确安全码 PAYMENT_CANCELLATION_PENDING 表示服务端已持久化取消意图，此时不能再次支付，显示“取消处理中，请稍后查看”，保留查询与返回。可信已支付优先，不受旧错误码覆盖。旧材料未知未打该码，仍允许原单受控重试。客户端不以超时、原生失败或本地倒计时释放位置。

待处理入口显示用户可理解的购买状态和操作，不显示订单号；确认取消后仅调用原单 close。取消处理中不说成功；可信结束后关闭弹层并刷新会员摘要和购买控制器。SDK 等待隐藏全部购买操作，返回复用 PurchaseFeedbackSheet，只显示结果和完成。离页、切账号、重复点击保持现有保护。

按每批不超过三个生产文件实施：领域/控制器，弹层，再页面与路由。先执行可编译的 RED 控制器与路由测试，后受影响商业化测试、analyze、OpenSpec；不构建 APK、不操作设备或真实支付。
