# 实施任务

- [x] 1. 阅读只读demo与当前付款契约，建立弹窗/默认渠道/协议/小屏RED。
- [x] 2. 分拆明细和支付操作，完成居中白卡布局与唯一有效渠道默认选择。
- [x] 3. 接入真实会员入口，保留StoreKit金额、全价暂停排队及防重。
- [x] 4. 定向widget/controller测试、analyze、截图、小屏和OpenSpec检查。
- [x] 5. UTF-8回读、根任务/issue日志和交付报告；不提交推送或安装。

2026-10-14：最终相关56项通过（含架构），额外蓝色按钮态截图5项通过，无missed-tap警告。当前only-platform渠道默认选中，协议仍false；真实route取消/遮罩/back不创建单，旧闭包双调用只提交一次。截图位于build/test-results/membership-confirmation-dialog；analyze无问题，change strict通过。未构建安装、提交推送或真实支付。
