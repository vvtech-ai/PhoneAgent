## ADDED Requirements

### Requirement: 批次停止绑定当前真实目标
客户端 MUST 对当前实时批次先确认再停止，不依赖可空 UI taskId；确认后必须重新核对 session、batch 与最终整理状态。受理后继续等待原批次最终回执。
#### Scenario: 实时批次及过期确认
- **WHEN** 实时批次已知真实身份且用户点击停止
- **THEN** 先展示确认；会话、批次变化或进入最终整理时旧确认不得调用停止；身份仍有效则调用原批次停止接口
#### Scenario: 旧批次进度迟到
- **WHEN** 已完成批次在新命令期间收到迟到进度
- **THEN** 不重新激活该批次或阻塞当前输入

### Requirement: 结果资产及确认展示遵循身份
客户端 MUST 仅对终态单路回执展示结果、录音、评价；历史恢复的进行态仍可用于只读通话观察。确认展示按 pending 身份去重，新交互使旧确认不可执行。
#### Scenario: 恢复通话中
- **WHEN** 时间线只有 CALL_REQUESTED 或 CALL_STARTED
- **THEN** 不展示结果资产，继续观察同一 attempt，不混入上一通内容
#### Scenario: 同卡跨轮与新待确认
- **WHEN** 同工具卡在历史及实时跨命令投影，或产生同内容的新 pending
- **THEN** 同 pending 只展示一次，新 pending 独立提示，旧 pending 不可执行

### Requirement: 通话关闭与暂定判断不是最终完成
客户端 MUST 在系统返回时保留活动单路通话观察；可信主线路关闭后回到任务页并继续等待最终回执。版本化 call_outcome_preview 必须按 session、attempt 和递增 phoneProgressSeq 过滤，不得作为最终结果或账单。
#### Scenario: 关闭证据和迟到连接
- **WHEN** 当前 attempt 收到可信 primaryClosed 后又读回旧 CONNECTED
- **THEN** 不重开通话页，继续观察最终回执；仅拨号失败观察允许后续有效 CONNECTED 恢复
#### Scenario: 暂定判断与最终回执
- **WHEN** 当前已关闭主线路收到更新的暂定判断
- **THEN** 展示暂定判断和最终回执等待提示，忽略旧身份或旧序号；最终回执到达清理暂定判断

### Requirement: 首页与任务模型状态区分目录和探测
客户端 MUST 使用账号模型目录的原始 modelId 和 available 判断可选择性，首页与任务使用相同契约；延迟请求失败或无有效样本不得假报全部模型不可用。服务端明确未接入的模型不得被客户端强制放行。
#### Scenario: 延迟请求失败
- **WHEN** 模型目录可读取但延迟请求失败或当前模型没有探测样本
- **THEN** 显示延迟暂无数据，仍以目录判断可选性，读屏与视觉一致
#### Scenario: 服务端尚未接入
- **WHEN** Qwen Audio3.1等任意模型的目录返回available=false和当前模型尚未接入
- **THEN** 保持禁选并显示服务端原因，不因任务TTS有声音而推断该通话模型可用
