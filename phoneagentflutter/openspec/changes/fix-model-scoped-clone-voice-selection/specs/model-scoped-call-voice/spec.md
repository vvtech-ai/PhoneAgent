## ADDED Requirements

### Requirement: 通话音色必须按弹窗模型读取和切换
客户端 MUST 使用弹窗的公开modelId读取音色及选中模式；激活已有克隆 MUST 使用带modelId的专用activate端点并重读同模型，不使用全局音色接口提交CLONE。
#### Scenario: 当前模型与目标模型不同
- **WHEN** 当前模型A而音色操作目标为模型B
- **THEN** 所有音色读写和激活均绑定B，不采用A的选中状态，不把数字modelId替换为内部cloneModelId

### Requirement: 系统音色切换必须同步实际状态
客户端 MUST 在目标模型使用克隆时按同模型deactivate并重读，再按需更新系统音色。结果不明 MUST 只读同步，不自动重发激活、停用或更新，不宣称原选择必然保留。
#### Scenario: 停用或更新返回失败
- **WHEN** 停用或更新请求失败
- **THEN** 仅在同模型状态明确确认停用或目标选择已生效时继续或成功，否则显示刷新提示并阻止重复写入

### Requirement: 音色选择必须保持生命周期隔离
客户端 MUST 保留busy/generation/账号隔离；候选确认独立于已有克隆激活，不改变现有布局或创建删除流程。
#### Scenario: 并发和候选
- **WHEN** 操作进行中重复点击、旧模型响应迟到或确认新候选
- **THEN** 不重复写入，不发布到其他模型，候选只调用其确认流程
