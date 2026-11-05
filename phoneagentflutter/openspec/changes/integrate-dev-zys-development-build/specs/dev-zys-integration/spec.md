## ADDED Requirements

### Requirement: 双分支三方集成保持有效功能
系统 MUST 从核对后的两方提交三方合并，保留任务修复与dev_zys最新功能；不得将历史规则覆盖用户本次明确合并授权，且不得更新origin/codex/dev。

#### Scenario: 共享文件出现冲突
- **WHEN** 公共请求、任务展示、翻译归档、账号或平台工程发生冲突
- **THEN** 合并双方有效行为，验证直接调用方和全量回归，不整页覆盖丢弃某方功能

### Requirement: 开发包配置及交付可追溯
Android开发包 MUST 固定Flutter3.32.0，HTTP/Runtime使用chakenai-dev.vvtech.tech各服务前缀；包与凭据不得进入Git。

#### Scenario: 合并后构建交付
- **WHEN** 合并验证通过并构建开发包
- **THEN** 记录版本、来源提交、SHA及包内三基址，真实电话/SDK/媒体/iOS未验证时明确待验，不以合成测试替代

### Requirement: 双端使用正式PhoneAgent应用图标
客户端 MUST 使用已有PhoneAgent正式声波品牌资源替换默认Flutter图标；Android包含各密度普通和圆形图标、自适应前景及背景，iOS覆盖现有AppIcon目录全部尺寸，不改变应用包身份。

#### Scenario: 构建或保留数据覆盖安装
- **WHEN** 使用批准的开发配置构建并覆盖安装
- **THEN** 启动器资源引用正式品牌，模型签名配置和安装身份保留；iOS仅完成资源与尺寸验证时不得宣称真机图标验收
