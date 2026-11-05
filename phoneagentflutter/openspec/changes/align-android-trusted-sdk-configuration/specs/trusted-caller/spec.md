## ADDED Requirements
### Requirement: Android可信SDK凭据必须对齐固定原生参考
Android SHALL 在所有合法构建模式中使用aiassistant_app固定参考的同一组SDK凭据，不因test/pro标签不同拒绝读取。未知环境和包名仍 MUST 拒绝；凭据 MUST 仅存于Git忽略的本地输入。业务API环境和iOS配置 MUST 保持不变。
#### Scenario: 登记测试Release
- **WHEN** 测试Release请求test配置
- **THEN** 使用与原生参考相同的凭据，不因生成时默认为pro而返回空
#### Scenario: Android-only生成
- **WHEN** 重新准备Android配置
- **THEN** 不读取或重写iOS生成文件及私有清单中的iOS数据

### Requirement: Android准备诊断必须反映SDK可用性
Android SHALL 复用Application进程级初始化并允许失败重试；prepare SHALL 对SDK未链接、凭据缺失及初始化失败提供固定安全错误码，configured=false MUST NOT 记录成功。iOS既有行为 MUST 保持不变。
#### Scenario: 通道返回但能力不可用
- **WHEN** Android prepare返回linked或configured为false
- **THEN** 诊断记录失败并阻止打开SDK，不输出凭据或原生任意消息
