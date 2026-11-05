## ADDED Requirements
### Requirement: iOS 更新检查必须沿用 Android 登录后时机
系统 MUST 仅在登录成功或恢复登录后自动检查，未登录不检查。普通检查成功 MUST 按本地日节流，已记录强更 MUST 绕过日节流，失败 MUST NOT 写入成功日期或新增定时重试。手动检查 MUST 不受日节流限制。
#### Scenario: 未登录或失败后重新启动
- **WHEN** 用户未登录启动，或一次自动请求失败后保持当前会话
- **THEN** 不发起未登录检查或会话内定时重试；下次重新启动并恢复登录可再次检查。
### Requirement: iOS 更新必须使用服务端平台契约和指定商店兜底
系统 MUST 在 SDK 版本检测请求中为 iOS 传 sourceType=1、Android 传0，并保留已有签名。iOS MUST 使用 iosSourceUrl，空值 MUST 回退 https://apps.apple.com/app/id6813455647，MUST NOT 用 apkUrl 作为兜底或进入 APK 安装链。
#### Scenario: 更新链接为空
- **WHEN** 服务端返回 hasUpdate=true 且 iosSourceUrl 为空
- **THEN** 更新动作打开固定 App Store 链接；无更新不因默认链接而弹窗。
### Requirement: iOS 更新入口必须复用 Flutter 样式及提示规则
iOS 关于页 MUST 显示末项版本更新，复用共用列表、提示和更新弹窗；普通更新 MUST 可稍后处理，强更 MUST 不可返回或遮罩关闭。系统 MUST 隔离退出/切号后的旧响应。
#### Scenario: 强更打开或重查失败
- **WHEN** 强更打开链接失败，或离开商店返回后的重新检查失败
- **THEN** 保留更新弹窗，提供失败提示及重试；仅成功打开链接不解除拦截，服务器确认无更新时解除。
