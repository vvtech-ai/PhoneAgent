## ADDED Requirements

### Requirement: 海外服务身份与真实账号分离
客户端 MUST 对齐aiassistant_app的海外x-user-id固定mobile-app-user，覆盖创建/merchant/hangup/清理及兼容重试。真实登录校验、账号隔离、归档和记录 MUST 保持原账号。UI及国内接口 MUST 不改变。
#### Scenario: 海外三个操作
- **WHEN** 已登录账号发起海外HTTP操作
- **THEN** 请求头使用原生服务标识，诊断仅记录固定来源类别
#### Scenario: 账号切换
- **WHEN** 通话准备期间登录失效或账号切换
- **THEN** 原有runtime门禁生效，固定服务身份不绕过账号校验，不归档到其他账号
