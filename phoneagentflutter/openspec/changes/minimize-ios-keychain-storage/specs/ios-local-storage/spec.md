## ADDED Requirements

### Requirement: iOS钥匙串最小化
系统 MUST 仅将认证Token及必要加密密钥保存在钥匙串，普通偏好存沙盒，含隐私业务数据存加密沙盒；不迁移历史iOS业务钥匙串数据。Android存储参数、迁移与业务接口 MUST 保持不变。

#### Scenario: 保存草稿和偏好
- **WHEN** iOS保存草稿、通话归档或普通偏好
- **THEN** 写入受文件保护且排除备份的沙盒，隐私正文使用认证加密，服务器资产不受影响

### Requirement: 安装生命周期与登录恢复
系统 MUST 在恢复iOS登录前检查排除备份的安装标记；缺失时定向清除本应用登录Token，成功后才提交标记。Token与辅助会话 MUST 分开存储并一致验证，异常不得恢复旧登录。

#### Scenario: 重装或初始化失败
- **WHEN** 标记缺失或初始化失败
- **THEN** 不恢复旧登录；失败允许后续重试，成功的新安装进入未登录状态

#### Scenario: 覆盖升级与平台隔离
- **WHEN** 正常重启、覆盖升级或Android启动
- **THEN** iOS已有标记不清会话，Android不调用iOS存储及清理端口，StoreKit交易验证不变
