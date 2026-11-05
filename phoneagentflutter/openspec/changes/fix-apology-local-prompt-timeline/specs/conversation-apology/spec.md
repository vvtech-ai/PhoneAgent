## ADDED Requirements

### Requirement: 本地道歉提示身份不得冒充后端任务身份

本条已按用户批准的 `task-orchestration-v1` 修订，替代原“checking / ready / 提交时清空全部本地道歉消息”规则。本地交互 ID MUST 区别于后端任务 `commandId`；当前会话已经显示的提问、选中旧卡、用户回显和就绪提示 MUST 保留原顺序，同身份权威事实可原位接管，不能通过删除历史解决错序。

#### Scenario: 查询或音色就绪

- **WHEN** 道歉音色查询进入 checking 或 ready
- **THEN** checking 仅更新查询状态，不新增或播报查询正文；旧卡失活保留，ready 将当前操作的就绪反馈追加在原交互之后，不用 modelId 覆盖旧操作

#### Scenario: 提交道歉任务

- **WHEN** 用户确认后提交真实 AgentCommand
- **THEN** 真实任务使用独立 commandId，前序已显示交互继续保留；仅在匹配权威事实存在时协调为一份，不批量删除 `local:apology:*`，也不把本地 overlay 伪装成已落账事实

### Requirement: 联系人回传必须保持同轮展示身份

联系人查询回传可能由后台产生新的 continuation command。客户端 MUST 将当前 thinking 段绑定到该续接 command，并为只返回 `SHOW_OPTIONS` 的回传补齐同一 `pendingToolCallId` 的 `showOptions` 工具卡。

#### Scenario: 联系人回传后展示候选

- **WHEN** 联系人回传返回 `SHOW_OPTIONS` 和非空 `pendingToolCallId`
- **THEN** thinking 位于候选卡之前，候选卡与 `showOptions` 工具卡使用同一 command/tool 身份
