# conversation-error-status-sync 规范

## Purpose

补齐固定 v65 执行异常退出和业务恢复后的任务状态同步，不改变普通退出及通话控制边界。

## Requirements

### Requirement: 异常退出与恢复确认必须遵循有效业务事实
系统 MUST 在存在未恢复执行/网络异常时退出对话，记录 execution_error_exit；正常退出不得调用后台 interrupt。MUST 仅在明确有效业务回复后记录 execution_error_recovered；通话上下文中的流失败不改为普通任务异常。

#### Scenario: 异常后普通退出
- **WHEN** 当前对话存在未恢复错误或恢复中的错误并退出
- **THEN** 持久化待同步异常，停止本地普通流，不发送挂断或重新执行需求

#### Scenario: 明确恢复与终态
- **WHEN** 出现 TEXT_REPLY、ASK_USER、SHOW_OPTIONS、REQUEST_PERMISSION、IMPORT_DOCUMENT_REQUEST、LOOKUP_CONTACT_REQUEST、LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST、MAKE_CALL_REQUEST
- **THEN** 仅有未恢复错误时清除该错误并同步 recovered；CALL_RESULT/BATCH_CALL_RESULT 只清除错误，不提升 RUNNING
- **AND** delta、heartbeat、done、历史恢复本身不算新的恢复业务确认

### Requirement: 待同步状态必须持久化且隔离账号
系统 MUST 按环境、API 与账号隔离 pending 命令，登录变化后停止旧租约续发；同会话最新命令取代旧命令，旧响应不得移除新命令。MUST NOT 在存储或请求失败时伪装同步成功，损坏的队列不得当空队列覆盖。

#### Scenario: 请求失败和重启
- **WHEN** 已持久化命令请求失败或进程重建
- **THEN** 保留命令，后续相同账号刷新/网络恢复可重试，不自动重放需求或外呼

#### Scenario: 并发恢复与退出
- **WHEN** 旧命令正在发送，新命令已产生
- **THEN** 旧回执只确认同一命令身份；新命令保留并串行发送，旧账号不得改写新账号队列

### Requirement: 任务列表必须保留后台终态与异常补偿
系统 MUST 在任务列表刷新前尝试同步，失败保留 pending exit 的异常提示；MUST NOT 因 pending recovered 乐观显示 RUNNING，或因任务终态取消恢复入口。

#### Scenario: 后台已经完成任务
- **WHEN** 异常同步响应为 COMPLETED
- **THEN** 接受后台完成状态，删除匹配的旧 pending，不再强制覆盖成异常

#### Scenario: 网络恢复
- **WHEN** 网络重新可用且当前账号有待同步命令
- **THEN** 有界重试并刷新列表，失败保留待同步，不无限轮询
