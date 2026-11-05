## ADDED Requirements

### Requirement: 描述文件分发用途一致
工具 MUST 为 dev/test 选择 Development；prod 指定设备时选择 Ad Hoc，未指定设备时选择 App Store。主包及两个扩展 MUST 使用同一类型，并保留原有团队、身份、证书、有效期和权限门禁。

#### Scenario: IOS-PROFILE-01 正式环境直装与上架分离
- **WHEN** 本地同时有 Store、Ad Hoc 和 Enterprise 描述文件
- **THEN** prod 有设备只选择 Ad Hoc，无设备只选择 App Store，其他类型拒绝

#### Scenario: IOS-PROFILE-02 扩展不能混签分发用途
- **WHEN** 任一扩展只有其他分发类型或未授权目标设备
- **THEN** 构建选择失败，不混用其他类型补齐

### Requirement: 新设备配置优先且可核验
相同分发用途的有效候选 MUST 优先选择覆盖设备更完整的描述文件，再比较精确身份和创建时间；本次配置更新 MUST 核验主包和两个扩展均覆盖已登记16台及新增三台。真实设备标识 MUST 不写入源码与构建白名单清单。

#### Scenario: IOS-PROFILE-03 缓存同时有13台和16台
- **WHEN** 两个配置均授权同一目标且证书/权限合法
- **THEN** 选择16台配置，不因文件名或旧精确扩展配置而选13台

#### Scenario: IOS-PROFILE-04 新设备尚未授权
- **WHEN** 所有合格候选均不含指定设备
- **THEN** 明确失败，不伪造授权或改用 App Store 类型
