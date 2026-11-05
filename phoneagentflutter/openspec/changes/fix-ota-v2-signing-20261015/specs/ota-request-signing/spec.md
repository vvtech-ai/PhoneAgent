## ADDED Requirements
### Requirement: OTA检查保留原生v2协议
Android版本检查 MUST 使用部署SDK凭据签名实际发送的请求字节，采用v2/HMAC-SHA256及完整编码网关路径；其他接口 MUST 保留C1。
#### Scenario: 关于页或启动检查
- **WHEN** 发送SDK api/ota/check
- **THEN** 发送X-Sign-Version、X-App-Key、X-Body-SHA256、X-Sign-Alg、X-Signature，签名覆盖实际JSON字节
- **AND** 不携带Bearer，不改变现有UI和共享检查语义
### Requirement: OTA失败须安全隔离并可诊断
OTA失败 MUST 不刷新或清除账号，不清除已确认的强制升级状态；诊断 MUST 可识别OTA传输与解析结果且不包含凭据或任意服务器文本。
#### Scenario: 签名拒绝或畸形响应
- **WHEN** OTA返回401或响应不符合更新契约
- **THEN** 检查失败并记录固定类别及可用HTTP/耗时，401不分类为signedOut
- **AND** 账号、其他C1请求与既有更新安全约束保持有效
