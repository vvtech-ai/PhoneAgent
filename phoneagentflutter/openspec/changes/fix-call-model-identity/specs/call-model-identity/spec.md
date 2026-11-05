# 通话模型身份

## ADDED Requirements
### Requirement: 模型身份必须区分用途
客户端 MUST 独立保留模型ID、provider和展示名称，不通过数字或名称猜测克隆能力。

#### Scenario: 数字模型ID
- **WHEN** 目录返回数字字符串modelId及明确provider与displayName
- **THEN** 展示名称使用目录名称，模型切换保留modelId，克隆使用公开modelId，能力取supportsVoiceClone；内部cloneModelId不得替代公开请求ID

#### Scenario: 旧目录
- **WHEN** 目录仅返回provider
- **THEN** 保持旧字符串标识流程可用
