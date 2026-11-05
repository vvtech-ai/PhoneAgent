## ADDED Requirements
### Requirement: iOS启动必须申请系统通知授权
系统 SHALL 在iOS启动时申请alert、badge、sound通知授权，每进程只调用一次启动申请；结果 SHALL 重新读取系统settings。账号同步和前台恢复 MUST NOT 主动重复申请。
#### Scenario: 首次启动未决定权限
- **WHEN** iOS宿主完成插件启动回调
- **THEN** 发起系统通知授权申请，完成后同步实际授权状态
#### Scenario: 已拒绝后恢复前台
- **WHEN** 用户拒绝通知后返回应用
- **THEN** 只读系统状态，不循环弹窗，不进入账号绑定
### Requirement: APNs注册必须独立于账号恢复
系统 SHALL 在通知允许且APNs环境匹配构建环境时注册APNs，无需已登录owner或SDK链接；服务端绑定 MUST 保留owner、有效token、权限及SDK门禁和串行解绑补偿。
#### Scenario: token先于登录
- **WHEN** 未登录时APNs返回token
- **THEN** 只在native内存保存，登录后才按当前owner绑定
#### Scenario: 退出后token迟到
- **WHEN** 当前owner为空时收到token
- **THEN** 不重新绑定旧账号，不更改通知解析及Android逻辑
