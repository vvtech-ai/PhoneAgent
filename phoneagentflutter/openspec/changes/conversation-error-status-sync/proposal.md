## Why

固定 Android v65 在执行异常退出和恢复确认时同步任务状态；Flutter 只有本地错误提示及历史恢复，缺少对应写入和失败重试，会使任务列表停留在旧状态。本变更补齐有效行为，不新增普通退出中断或外呼控制。

## What Changes

- 共享 Dart 识别未恢复错误与明确业务回复，仅同步 execution_error_exit / execution_error_recovered。
- 按环境、API、账号持久化待同步命令，失败保留、重复请求合并、晚到响应不得删除较新命令。
- 对话退出/恢复、任务刷新及网络恢复接线；异常待同步列表显示遵循 v65，终态仍可恢复。
- 单路/批量通话的流错误保持独立边界；不把心跳、文本增量或 done 当作业务恢复。

## Capabilities

### New Capabilities

- `conversation-error-status-sync`: 执行异常状态同步与账号隔离补偿。

### Modified Capabilities

无。补充 conversation-history-core 已批准的普通退出边界，不改变其页面或输入规则。

## Impact

涉及 conversation domain/data/controller、任务列表和 provider 接线、本地安全存储及受保护 POST 接口。复用现有鉴权和安全存储，不改后端、数据库、提示词、SIP、ASR/TTS。日志仅记录稳定操作与结果，不含对话文本或凭据。按策略/存储/API/控制器连续流程定向验证；平台监听发生变化时补对应构建。旧未绑定账号的 Android 待同步集合不直接导入当前账号，遗留兼容风险单独记录。
