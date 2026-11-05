## ADDED Requirements

### Requirement: iOS最低系统版本
Flutter iOS App MUST 要求iOS16.1及以上；Runner、Flutter framework声明、通知和Live Activity扩展以及本地Pod的部署声明MUST保持16.1。Pods低于16.1的部署值MUST提升至16.1，高于此值的依赖要求MUST保留。

#### Scenario: 构建及扩展重生成
- **WHEN** 解析Pods、生成通知扩展或构建Debug/Profile/Release
- **THEN** App及两扩展最低版本为16.1，不恢复旧15.5或12.0声明

#### Scenario: 使用16.2专有Activity状态
- **WHEN** 在iOS16.1运行来电身份展示
- **THEN** iOS16.2专有stale状态仅在版本判断之后访问
