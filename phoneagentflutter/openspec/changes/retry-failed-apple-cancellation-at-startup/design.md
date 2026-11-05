# 最小设计

状态owner仍为原 PurchaseController；新增 outbox 只持有待补报(orderNo,requestId)，不创建第二套订单状态。存储复用 AppLocalStorage 和 PreferenceOperationQueue，scope包括环境/API/账号并校验同一登录。固定请求ID按scope+order派生；同单回调合并进行中请求、同键写入保留原ID。

只有原 helper 收到 Apple userCancelled 才用 outbox。即时请求成功且返回已取消/已关闭/支付成功清待办；失败保留原错误并安全保存唯一记录。手动closeOrder路径不接outbox。

outbox provider 按loginEpoch持有启动once标记。既有controller.restore先照常运行，不等待补报；完成后启动outbox快照处理。每项先查原单，终态直接清理；非终态只提交一次关闭请求。失败不循环、不定时；重复启动入口/监听/页面重建不能在同登录会话再重放。对当前仍显示同一原单的终态结果，复用原query刷新；不覆盖正在进行的报价/确认/恢复。

保留后端支付成功优先、真实验单及finish合同。没有Apple或后端同单现场证据时仅报告机制验证；DEVICE-01涉及iOS平台边界，真实沙盒仍独立验收。每微批最多3个业务文件；手写文件小于500行。
