# 设计

iOS 原有复合 guard 按原顺序分支，失败仍返回 CHANNEL_UNAVAILABLE。unverified、商品不符、token 缺失/不符、类型不支持分别使用固定 nativeStage。错误详情中只通过内存桥传递交易/商品 ID，Dart 在写日志前使用既有 SHA256 截断算法脱敏，不传递 token 或 JWS。恢复流程已有逐笔 transactionRef，可直接与购买失败的 transactionRef 对照；不对账号不符交易自动 finish。

本次生产微批为 Swift、诊断映射和封闭字段模型三文件；定向测试单独微批。均小于 500 行。保持当前分支，不自动切换或合并远程其他改动；本侧会话不自动提交推送。

验证：Flutter 3.32.0 日志往返/隐私过滤、支付反馈与恢复定向测试，flutter analyze，Swift 语法检查，OpenSpec 全仓校验。真实设备重现仍待新包验收，不归档。
