## ADDED Requirements

### Requirement: 线路忙失败必须恢复输入

App MUST 将 `PHONE_CAPACITY_UNAVAILABLE` 呈现为固定线路忙提示，并 MUST 在当前 SSE 轮结束后恢复 `ready` 输入状态。

#### Scenario: 线路忙失败事件

- **WHEN** 收到没有 `callResult` 的结构化 `task_failed`
- **THEN** 完成思考态、取消未注册的拨号请求并清空活动提示
- **AND** 麦克风可以开始下一轮输入

#### Scenario: 线路忙批量终态

- **WHEN** 批量结果中没有 running 成员
- **THEN** 当前轮正常完成并恢复输入
- **AND** 不根据结果文本自动发起重试
