## Why
用户批准分别对齐Flutter Android与aiassistant_app的邀请打开链路；iOS继续使用现有Universal Links地址。当前Dart把邀请入口绑定旧API host，cloud-dev/test会拒绝邀请，公开解析仍走Agent。

## What Changes
- Android按dev/test/prod声明App Links和Scheme，独立路由到App任务，拒绝历史入口重放。
- iOS原有Universal Links、entitlements、路径和Scheme不变，可信新API环境允许原有入口。
- 公开resolve迁移SDK，保留未配置SDK的既有同源兼容。
- 共用层维护本次邀请入口身份、欢迎页请求隔离及注册保护；Android错误需重试，iOS保留既有业务错误可继续规则。
- 保留Flutter所有页面布局和共用控件，不将示意图作为改版稿。

## Capabilities
### Modified Capabilities
- invite: 分平台入口和共用归因。

## Impact
邀请feature、auth路由装配和Android薄适配；参考仓库/后端只读，当前codex/dev_zys保持分支，不提交推送，不覆盖主线程未提交文档，不执行真实短信/注册/收费。

## 2026-10-15 iOS无提示反馈
用户提供diagnostics.jsonl 21并反馈既有Universal Link可打开App但无提示。1503包记录包含本change，不能归因为未安装旧修复。定位到应用builder外层InviteEntryHost使用自身context查Overlay，需在现有授权范围修复通知宿主并补真实树结构回归；不改变链接、登录态或邀请UI。

## 2026-10-15 1504仍无提示：修复原生投递
新日志435条仍无入口事件，安装记录确认1504含Overlay修复。固定SDK实际Swift编译发现冷启动与continueUserActivity签名不匹配FlutterPlugin可选协议，生成ObjC实例方法表缺少二者。修正协议签名、增加实际Swift编译验证和不含URL/邀请码的分段诊断，保持Universal Links及UI。

## 2026-10-15 未登录欢迎页通用不可用
用户反馈现可进入欢迎页但提示服务暂不可用。匿名GET当前dev公开resolve成功返回HTTP200/业务code字符串000000及活动退休状态；Flutter仅接受数字0，先于状态映射误报不可用。本轮兼容既有AccountApi/AuthGateway同样接受的0/000000，不改服务器活动或真实邀请码数据。

## 2026-10-15 双原生欢迎错误对齐执行
用户确认计划后明确要求切换codex/dev_zys；两个分支均a9312dfb，已安全切换，原四份未提交文档哈希不变。基线已含前六节修复，本轮仅补欢迎页详细错误文案、缺失活动/网络/未知响应分类和公开resolve脱敏诊断，继续保持双平台按钮差异与现有Flutter UI。后台仅已有只读证据，不调整活动/码，不提交推送或自动安装。
