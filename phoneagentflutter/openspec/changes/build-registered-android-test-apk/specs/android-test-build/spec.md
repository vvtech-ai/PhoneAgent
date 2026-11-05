## ADDED Requirements

### Requirement: 显式测试Debug身份及登记签名
Android构建 MUST 仅在PHONEAGENT_ANDROID_ENV=test时将Debug改为com.vvtech.aiassistant.test，并读取外部签名属性和校验登记证书MD5；缺配置/非法env必须失败，不回退debug签名。

#### Scenario: 默认开发及显式测试
- **WHEN** 环境未设置或为dev
- **THEN** 默认Debug/Profile沿用.dev，Release原门禁保留
- **WHEN** 环境为test且四项签名属性及证书MD5有效
- **THEN** 仅Debug使用.test及登记签名，Profile及Release不放宽

### Requirement: 测试参数构建入口和环境恢复
测试构建脚本 MUST 校验test环境/三个批准test地址/四个非空C1字段，固定Flutter3.32/Debug/ARM64/main且关闭预览，临时环境变量必须finally恢复，不输出/复制密码。

#### Scenario: 缺配置或构建失败
- **WHEN** 私有配置缺失、目标不匹配或构建失败
- **THEN** 明确失败，不产出伪造成功回执，且原进程环境变量恢复
