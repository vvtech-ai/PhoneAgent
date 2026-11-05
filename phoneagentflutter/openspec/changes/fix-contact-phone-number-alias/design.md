# 设计

在 `ConversationMessages` 增加通用的首个非空文本别名读取函数，集中处理 `phone`/`phoneNumber` 的历史字段差异。选项的展示详情和 `ConversationOption.phone` 复用同一解析结果，保证展示、尾号去重和点击续接使用同一号码；当两个字段同时存在时保留现有 `phone` 优先级。

号码联系人查询续接复用同一别名函数，仅在 `phone` 和 `phoneNumber` 都为空时保持原有缺失上下文错误。设备通讯录读取、姓名匹配输出（仍以 `phoneNumber` 为候选契约）以及服务端协议不变。

先以合成 `phoneNumber` payload 复现客户端号码为空，再执行定向 Flutter 测试、`flutter analyze`、OpenSpec 校验和 diff 检查；不以无现场日志替代真机复验。
