## ADDED Requirements

### Requirement: 正常音色页不得展示演练入口
正常音色选择页 MUST 不显示“创建克隆交互演练（MOCK）”或其他演练入口，不得直接导航到ClonePreviewScenariosPage；该规则 SHALL 同时适用于Android/iOS、Debug/Release以及演练编译开关显式开启的情况。

#### Scenario: 用户打开正常音色弹层
- **WHEN** 用户从通话模型打开音色页，当前克隆为空或已就绪
- **THEN** 只显示有效业务，真实克隆创建/选择/删除/试听保持既有行为，不出现MOCK入口

#### Scenario: 独立工作台演练
- **WHEN** 开发者从独立tool演练工作台显式进入克隆测试场景
- **THEN** 该场景继续明确标注MOCK且不依赖正常音色页提供入口
