## ADDED Requirements

### Requirement: 对话异常恢复入口只展示一次
客户端 MUST 在顶部显示简短可操作的恢复状态，且 MUST NOT 在时间线中重复显示同一异常长文案和重试区域。

#### Scenario: 网络异常需同步历史
- **WHEN** 对话处于 recoveryRequired 或 restoreFailed
- **THEN** 顶部展示简短恢复提示并调用已有历史恢复入口
- **AND** 不自动重发输入或外呼，不改变历史事实

### Requirement: 批量确认可见提示与当前提问一致
客户端 MUST 使用当前批量确认 ASK_USER 的提示作为对应确认卡的可见回复，并保留独立业务回复和其他轮次的内容。

#### Scenario: 确认卡前言与空问卷标题不同
- **WHEN** 已存在批量确认卡且收到相同工具身份的批量确认 ASK_USER
- **THEN** 卡片展示 ASK_USER 标题，与既有语音提示一致
- **AND** 不重复展示同轮准备前言，不改变确认快照或触发执行

### Requirement: 空问卷提问与原生思考提示保持一致
客户端 MUST 保留空 items ASK_USER 的标题和工具身份，并使用正式原生语音入口的思考卡文案。

#### Scenario: 空问卷前存在已提交前言
- **WHEN** ASK_USER 标题与同轮准备前言不同
- **THEN** 展示提问标题，仅折叠与来源原文相同的前言
- **AND** 独立回复继续可见，后续自然答复携带原 pendingToolCallId

#### Scenario: 批量技能等待响应
- **WHEN** 会议通知、活动邀请或销售推荐等待响应且无其他显示状态
- **THEN** 思考卡标题为 Phone Agent，回退提示为正在理解任务...
- **AND** 普通技能的回退提示为 AI 思考中...

### Requirement: final 互动与 signal 共用处理和身份门禁
客户端 MUST 将 final 中的有效互动交给现有处理器，且 MUST 按轮次、互动类型和 pendingToolCallId 去重 signal/final，不重复执行或播报。

#### Scenario: 服务只返回原始 final 互动
- **WHEN** final 携带 ASK_USER、SHOW_OPTIONS 或 MAKE_CALL_REQUEST
- **THEN** 复用现有提问、选项或确认卡处理器并保留工具身份
- **AND** 不把准备前言当作独立最终回复

#### Scenario: 已停止后到达 final 互动
- **WHEN** 当前轮已接受停止且迟到 final 请求互动
- **THEN** 不执行、不播报且不恢复旧互动

#### Scenario: 错误包含明确业务含义
- **WHEN** 当前为确认卡同步失败、通话状态核对或任务保存失败
- **THEN** 顶部短提示保留对应业务含义而非统一显示连接中断
