## ADDED Requirements

### Requirement: 发布目录非空权益必须正确解析
Flutter SHALL 将已发布目录的非空 benefitsByLevel 解码为明确类型的不可变 Map<String,Map<String,Object?>>，保留商品与四档权益，不因容器泛型推断显示加载失败。坏权益结构 SHALL 继续拒绝，HTTP404、500、鉴权与协议错误 SHALL 不变成空目录成功。

#### Scenario: 四档权益网络 JSON
- **WHEN** 成功目录响应经 jsonDecode 得到非空四档权益和会员/积分包商品
- **THEN** 解析和目录控制器加载成功，所有商品及每档数值保留，营销选择不改变真实身份

#### Scenario: 权益值不是对象
- **WHEN** benefitsByLevel 任意档值为数组或 null
- **THEN** 严格拒绝并保持失败可重试，不造默认权益
