## ADDED Requirements

### Requirement: 国内模型可读取用户授权的参照部署配置
国内翻译 SHALL 通过工程内私有配置读取指定原生模型参数及凭据，替换默认空来源；Android有效本地配置优先，凭据缺失时采用固定iOS同服务默认值。敏感值 SHALL NOT 提交Git、输出日志或错误，不复用账户token，不发明短期凭据接口。

#### Scenario: 两端工程已部署有效模型配置
- **WHEN** 当前环境API配置有效且原生通道返回匹配模型配置
- **THEN** 国内factory可继续原有音频/积分/SIP准备流程，配置就绪不等同已接通

#### Scenario: 配置缺失或无效
- **WHEN** 私有输入缺失、平台/provider不匹配、配置畸形或平台不支持
- **THEN** 在音频和SIP前拒绝，错误不含凭据且不自动拨号

### Requirement: 豆包默认字段沿Android且协议保持原生
共享豆包模型配置 SHALL 默认voice=Nofish、输出16k，Qwen SHALL 输出24k；豆包请求 SHALL 保持原生字段，不因配置voice存在而新增未知音色参数。SIP SHALL 继续采用服务端租约。

#### Scenario: 装配豆包配置
- **WHEN** 读取豆包私有部署参数
- **THEN** voice为Nofish，协议不额外发送音色字段，不导入静态SIP密码
