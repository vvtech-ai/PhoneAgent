## ADDED Requirements
### Requirement: Android可信组件必须遵循参考SDK生命周期
Android SHALL 使用参考SDK自身来电组件及系统筛选服务，MUST NOT 在启动、账户恢复或Activity恢复时无条件修改用户SDK开关和组件状态。
#### Scenario: 已开启服务后重启
- **WHEN** 进程重新启动且账户正在恢复
- **THEN** 保持SDK和系统已有设置，不禁用筛选组件导致角色丢失
#### Scenario: 退出或换账户
- **WHEN** 已确认账户变化
- **THEN** 关闭旧surface并清理本工程拥有的号码，不自行撤销系统角色或写SDK全局开关
### Requirement: iOS可信设置必须保持参考原生导航
首次说明 SHALL 使用参考布局和全屏导航，开始push SDK，SDK退出整体dismiss；后续直接呈现SDK，权限与开关UI由SDK承载。
#### Scenario: 首次开始
- **WHEN** 当前账户在说明点击开始
- **THEN** 在同一UINavigationController push SDK，不叠加新的modal SDK层
### Requirement: 启动崩溃摘要必须可安全恢复
Flutter绑定账户前的匿名原生崩溃摘要 SHALL 在后续启动导入且仅包含既有固定匿名字段，MUST NOT 读取其他账户崩溃或异常文本。
#### Scenario: 冷启动早期异常
- **WHEN** NativeCrashRecorder在账号scope未绑定时保存摘要
- **THEN** 后续日志能导入并确认该摘要，保留未确认记录
