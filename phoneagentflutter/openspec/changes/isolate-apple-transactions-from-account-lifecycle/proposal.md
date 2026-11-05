# Apple 交易与账号生命周期隔离

用户于 2026-10-30 确认执行。解决切换账号/注销后原 Apple 交易无法完成、过早 finish 以及支付材料与注销并发窗口。继续既有 auth_epoch，不恢复旧凭证。

保留原 Flutter UI、共用控件、无恢复购买入口、Apple 原单绑定与金额、两代会员及积分履约、退款合同和 Android 回调。注销不等待支付，原单财务事实继续处理，最终注销不恢复账号。新增接口仅用于已有 Apple 交易补单，不授予账号访问权。

当前机制证据：AppleTransactionVerifier 仅按 paymentState finish；账号 runtime 会在退出后停止处理；CommercePaymentAttemptService 在钱包锁后未核验账号/认证代次。属于源码机制确认，尚无真实设备复现证据。
