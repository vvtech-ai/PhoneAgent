# 设计和修改登记

状态 owner：SDK commerce 负责到期、订单锁及支付事实；Flutter PurchaseController / IosPaymentRuntime 负责展示和账号生命周期。影响会员/积分购买、继续支付、取消补报、订单详情以及启动/前台/网络恢复。身份沿用账号、环境、订单、稳定 appAccountToken 和 Apple transactionId；接口复用原查单、close、Apple verify 及通知入口。

仅 APPLE_IAP 的 PENDING/PROCESSING、履约 NOT_STARTED、无已记录付款、有效租约及已到 expiresAt 订单可以本地关闭。短事务重新检查，已知交易先在事务外查询；已记录成功优先。本地 CLOSED 配合 safeErrorCode=APPLE_PURCHASE_TIMEOUT 区分渠道关闭，独立事件保存到期及关闭时间，不产生 trustedClosed 证据。释放本单会员占用，不修改原 token。取消晚到正常返回当前终态。

付款成功可推进 CLOSED；成功后清除超时展示原因。旧新两单都付款则分别记账和幂等履约，既有会员规则版本和冲突恢复保留，旧单不得抢新单占用。无 transactionId 不能按 merchant order 查询 Apple；这类关闭单依靠未完成交易和服务端通知，不能无限空查。有交易号的关闭单按独立较长间隔查询，不改变其他渠道恢复频率。

Flutter 复用原 CommerceAction/Card，关闭原因及查询入口仅对 Apple 生效。不自动轮询永久关闭历史；主动查询和生命周期交易恢复继续有效。取消待办终态清理与 Apple 交易恢复分开；在途/待确认尝试关闭后转为不占用购买入口的已关闭阶段，保留原身份直到已知交易完成，明确取消可清理。30秒超时仍不自动取消，启动静默及恢复边界不变。不改 finish 规则。

文件职责：取消事务服务增加本地超时转换；operations 协调查询与本地关闭；fact service 清理成功后的超时标记；mapper/lease 限定恢复范围和频率；Flutter domain 提供 Apple 状态规则，runtime 保存关闭尝试，presentation 仅投影及原按钮条件。测试按 IOS-EXPIRE-01～08 和 IOS-WAIT 原回放验证。

本机未发现 systematic-debugging / verification-before-completion 技能文件，不声称加载；按实际源码、重现测试及交付前验证执行。部署、真实扣款、安装、分支切换和推送不在此次执行范围。
