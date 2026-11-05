## ADDED Requirements
### Requirement: 联系人查询结果必须回传Agent服务
客户端 MUST 将姓名和号码查询结果回传到Agent服务，并使用该服务对应C1凭据；保留已有授权与拒绝状态及会话身份。

#### Scenario: 独立服务部署
- **WHEN** API与SDK配置不同网关前缀，回传api/assistant/agent/contact-lookup-result或device-contacts-lookup-result
- **THEN** 请求使用API的Agent基址与Agent签名凭据，不进入SDK服务

#### Scenario: 查询无读取权限
- **WHEN** 当前会话查询通讯录但用户拒绝或系统限制读取
- **THEN** 既有PERMISSION_DENIED结果仍经Agent服务回传，不误判为网络路由故障，也不自动重复任务
