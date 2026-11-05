## ADDED Requirements

### Requirement: 注销申请信息仅在当前页面内存中保留
客户端 MUST NOT 将注销申请恢复信息持久化到本地，包括operationId、challengeId、queryToken和保存时间。客户端 MUST NOT 读取旧版本恢复记录或以其结果阻止注销入口。申请真实状态 MUST 以服务端为准。

#### Scenario: DEL-LOCAL-01 旧恢复记录存在
- **WHEN** 用户确认入口注销，设备遗留旧恢复记录且旧查询凭证失效
- **THEN** 客户端 MUST 不读旧记录、不查询旧操作，正常准备当前确认与短信验证；服务端状态校验保持

#### Scenario: DEL-LOCAL-02 本地恢复存储不可用
- **WHEN** 用户确认入口或提交最终注销确认，本地存储不可读写
- **THEN** 注销流程 MUST 不访问恢复存储，不因此阻断准备或提交；受理后原session清理屏障仍生效

#### Scenario: DEL-LOCAL-03 同页面提交响应丢失
- **WHEN** 用户提交申请但响应丢失，仍停留当前流程
- **THEN** 客户端 MUST 使用内存中同一operationId和queryToken查询原结果；未知时仅提供查询，不重复提交、不误报受理

#### Scenario: DEL-LOCAL-04 离页后重新进入
- **WHEN** 先前尝试结束或页面销毁后，用户重新进入注销入口
- **THEN** 客户端 MUST 不恢复旧操作，重新通过服务端确认接口校验；不得以本地信息推断已受理、未受理或撤销

#### Scenario: DEL-LOCAL-05 服务端已经受理
- **WHEN** 当前申请成功或当前页面查询确认PENDING/FINALIZED
- **THEN** 客户端 MUST 按原流程阻止业务、退出登录并展示已提交提示；退出不依赖注销恢复存储清理
