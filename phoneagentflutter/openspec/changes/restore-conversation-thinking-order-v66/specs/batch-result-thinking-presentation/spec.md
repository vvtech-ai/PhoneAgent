## ADDED Requirements

### Requirement: 思考提示必须覆盖执行阶段和实际思考内容
系统 MUST 在执行中的有效阶段展示当前提示；空提示使用既有技能 fallback。MUST 保留收到的思考增量并响应结束，不以固定文案决定是否显示。思考增量 MUST 按原生追加语义处理：`thinking_delta` 取嵌套 `data.text`，缺失时回退顶层 `text`，并遵循 `append`/`start` 的行分隔语义；`thinking_done` 只结束当前段。思考卡 MUST 对齐原生 AI 思考过程标题、进行中/完成状态及最近三物理行自动滚动。同一轮 MUST 最多展示一张思考卡，位置在本轮 assistant 文本之前，且 MUST NOT 因思考增量而新增多卡或重排既有消息。

#### Scenario: 多路执行阶段
- **WHEN** 多路执行仍在进行且收到可展示阶段文字
- **THEN** 显示该阶段；进入完成、恢复核对或关闭后不保留占位动画

#### Scenario: 思考内容追加及结束
- **WHEN** 收到 thinking_delta 与 thinking_done
- **THEN** 按原生追加语义更新内容并保留结束内容，完成后停止该内容动画；未收到的内容不得伪造

#### Scenario: 流式思考与占位卡互斥
- **WHEN** 当前轮存在进行中的思考内容
- **THEN** 不显示阶段占位卡；思考结束后按发送状态与技能 fallback 决定占位卡

#### Scenario: 思考卡位置与数量
- **WHEN** 同一轮先后收到思考增量与 assistant 文本
- **THEN** 该轮只出现一张思考卡并保持在文本之前，既有消息相对顺序不变
