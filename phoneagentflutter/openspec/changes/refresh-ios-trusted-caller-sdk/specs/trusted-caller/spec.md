## ADDED Requirements
### Requirement: iOS可信SDK交付更新必须保持环境隔离和工程自包含
工程 MUST 使用用户指定交付件分别替换工程内test/pro的KXSDK.framework，保留Debug/Profile测试与Release正式映射，并记录每个供应方文件的SHA256。版本号相同 MUST NOT 视为二进制相同。构建 MUST 不依赖交付源目录；只有副本完整、配置无源目录依赖且编译验证通过后才删除源目录。

#### Scenario: 同版本不同交付件
- **WHEN** 新交付件版本为1.8.0/18但文件字节不同
- **THEN** 按环境完整替换并更新校验记录，保留既有公共依赖及业务行为，按新SDK签名完成必要的桥接兼容

#### Scenario: 交付源目录清理
- **WHEN** 工程副本与交付件逐文件一致且iOS编译验证通过
- **THEN** 删除用户指定可信被叫SDK源目录并复核工程自包含
- **AND** 若编译受阻则保留源目录并记录未验证项

#### Scenario: 设置初始化新增APNs token参数
- **WHEN** 供应方设置页面初始化接口新增非空deviceToken参数
- **THEN** 桥接复用现有注册模块的最新APNs token，尚未获得时传空字符串
- **AND** 不新增授权提示，不改变账户绑定生命周期、Flutter界面或共用控件
