## ADDED Requirements

### Requirement: 模型读取必须遵循当前 SDK 契约
App SHALL 按当前 SDK 的模型配置契约读取并映射真实模型，不把接口失败显示为空成功，不伪造模型或渠道可用性。

#### Scenario: 本地开发真机读取模型
- **WHEN** 已登录用户打开模型选择且 SDK 返回合法配置
- **THEN** App 展示返回的真实模型并沿用服务端可用性

#### Scenario: 诊断交付边界
- **WHEN** 已完成模型失败定位并构建交付包
- **THEN** 临时回环采集源码已移除且用户凭据和响应正文未进入日志或 Git
