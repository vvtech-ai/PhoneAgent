## ADDED Requirements
### Requirement: 普通后端翻译节点对齐原生有效入口
客户端 MUST 按当前环境及Default/US/JP区域配置选择普通后端翻译节点；语言目录、创建、拨号及挂断 MUST 使用同一冻结节点。options仍控制国家、模型和语言能力，模拟国家 MUST 不绕过真实媒体。
#### Scenario: 模拟美国或日本
- **WHEN** 用户模拟主叫国家后准备后端实时翻译
- **THEN** 正式快照按有效主叫国家映射区域（US/JP，其余DEFAULT，国内强制海外US），请求使用对应环境区域节点而非options.nodeEndpoint；目录门禁及账号隔离保留
### Requirement: 语言兼容匹配与错误反馈
客户端 MUST 按原生标准化代码、原始代码及名称匹配语言，并提供分阶段安全错误提示，保持UI风格。
#### Scenario: 目录返回短代码
- **WHEN** 语言目录返回en而输入en或英语
- **THEN** 可通过适用代码或名称匹配，不因只匹配en-US失败
#### Scenario: 准备失败
- **WHEN** 语言、创建、媒体或拨号失败
- **THEN** 现有UI显示对应原因，清理不确定性仍明确提示，不泄露原始响应或凭证
### Requirement: 媒体与会话契约保持原生兼容
客户端 MUST 支持SDK使用的安全https/wss LiveKit地址及查询参数；缺省provider回退到原请求；保持双就绪、备用媒体、取消清理及有界兼容重试。
#### Scenario: HTTPS房间地址
- **WHEN** 会话返回有效https LiveKit地址
- **THEN** 交给SDK连接，媒体就绪后才允许一次商户呼叫
#### Scenario: 媒体或创建失败
- **WHEN** LiveKit失败或首次创建IO失败
- **THEN** 分别只按已有备用媒体或去capabilities兼容规则处理，不引入重拨
