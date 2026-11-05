## ADDED Requirements
### Requirement: iOS身份详情必须在SDK页面上方展示
iOS停留于可信来电MCP服务页面收到当前账号身份事件时 SHALL 在SDK页面上方展示复用的Flutter身份详情，MUST 保留SDK控制器及导航状态，不得关闭或重建SDK页面。
#### Scenario: 详情打开和关闭
- **WHEN** SDK设置页面显示期间收到有效来电身份并在前台
- **THEN** 身份详情覆盖SDK页面，关闭详情后露出同一个SDK页面，原设置请求保持未完成
### Requirement: 展示必须保持单一身份状态和生命周期隔离
独立展示引擎 SHALL 仅接收现有身份快照，不重复验签或绑定账号；更新和关闭 MUST 校验当前presentationId和账号代次，清除后释放引擎及敏感展示数据。
#### Scenario: 连续事件及旧回调
- **WHEN** 新身份替换旧身份后旧关闭回调到达
- **THEN** 新身份保持显示，更新复用同一容器
#### Scenario: 后台或账号失效
- **WHEN** 应用后台或账号失效
- **THEN** 后台不新增展示，账号失效清除详情且旧回调不生效
### Requirement: 平台展示修复必须保留现有UI及其他路径
实现 MUST 复用现有Flutter身份页、资源和共用控件，Android及普通Flutter页面的身份展示路径 SHALL 保持现有行为。
#### Scenario: 无SDK遮挡
- **WHEN** 当前没有SDK页面
- **THEN** 通过原Flutter路由展示详情
