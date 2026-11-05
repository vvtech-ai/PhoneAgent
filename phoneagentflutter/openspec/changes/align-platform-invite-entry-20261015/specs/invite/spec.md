## ADDED Requirements

### Requirement: 邀请入口必须分别遵循平台配置
Flutter Android MUST按dev/test/prod接受chakenai-dev.vvtech.tech/chakenai-test.vvtech.tech/chaken.ai的精确/aiassistant-api/invite/路径及phoneagent-dev/phoneagent-test/phoneagent Scheme。Flutter iOS MUST保持现有Universal Links域名和路径，不因API迁移变更跳转地址；可信cloud-dev/test API配置MUST NOT使既有iOS入口失效。

#### Scenario: iOS使用新API环境打开既有链接
- **WHEN** iOS使用批准的新dev/test API并收到phoneagent-ioslink.vvtech.tech的既有Universal Link
- **THEN** 保持链接地址不变并正常解析邀请码，生产链接不跨环境接收

#### Scenario: Android从浏览器进入App
- **WHEN** 浏览器打开当前环境有效邀请
- **THEN** 独立入口转交App任务并结束，历史Intent和同一入口凭据不重复消费，新的点击可以重新进入欢迎页

### Requirement: 欢迎页必须绑定本次邀请入口
客户端 MUST在会话恢复后处理最新邀请；新入口MUST隔离旧欢迎页响应，提交期间MUST NOT覆盖邀请；Android错误继续按钮必须重试，iOS保留既有业务错误放行规则。Android已有邀请码填写页MUST保持优先显示，新链接仅更新非提交状态下的邀请码；iOS页面优先级保持原逻辑。页面布局与Flutter共用控件MUST保持现状。

#### Scenario: 同码新的邀请点击
- **WHEN** 用户已返回登录后重新点击有效邀请，且非注册提交中
- **THEN** 新入口重新读取邀请详情；旧入口完成结果不覆盖新状态

#### Scenario: 已登录或提交中收到邀请
- **WHEN** 账号已登录或注册请求进行中
- **THEN** 已登录只提示新用户限制；提交中保持当前归因与注册请求ID

### Requirement: 公开邀请解析必须使用SDK路由
客户端 MUST优先使用配置的SDK base调用api/invite/public/resolve，不带登录Bearer；未配置SDK时保留既有同源兼容。分享网页及iOS Universal Links地址MUST NOT随接口路由迁移。

#### Scenario: 配置独立SDK服务
- **WHEN** Agent与SDK有不同网关前缀
- **THEN** 欢迎页解析只请求SDK前缀，仍按原Universal Links和分享链接进入

### Requirement: 全局邀请反馈必须能跨导航显示
客户端 MUST在应用全局邀请入口位于导航器外层时使用有效的根Overlay显示原共用提示，MUST NOT因查找不到祖先Overlay而静默丢失已登录邀请或存储失败反馈。既有Universal Links和页面布局MUST保持不变。

#### Scenario: 已登录账号收到有效邀请
- **WHEN** iOS或Android的冷入口排队完成或热入口收到有效邀请
- **THEN** 在现有页面显示“本次邀请奖励仅限新用户”，不绑定邀请码且页面导航仍可操作

### Requirement: iOS邀请回调必须实际注册到Flutter生命周期
邀请插件 MUST精确实现固定Flutter SDK的生命周期协议，编译产物的Objective-C实例方法表MUST包含application:didFinishLaunchingWithOptions:和application:continueUserActivity:restorationHandler:，不能将近似签名或Dart模拟视为原生入口验收。邀请接收与分发MUST记录固定枚举诊断，MUST NOT记录邀请码、URL/query、手机号或凭据。

#### Scenario: Universal Link唤回已登录App
- **WHEN** iOS向Flutter生命周期代理投递浏览活动
- **THEN** 邀请插件实际接收并向Dart分发，诊断可区分收到/拒绝/会话等待/已有账号反馈

### Requirement: 公开邀请解析必须兼容服务成功码并保留业务状态
客户端 MUST接受公开解析响应的数字0或字符串000000作为业务成功码，MUST NOT将其他码宽泛转为成功。成功响应中的ACTIVITY_RETIRED、EXPIRED、EXHAUSTED等状态MUST使用已有业务文案，不因非ACTIVE时缺少activity而误报服务不可用。

#### Scenario: 活动结束响应使用字符串成功码
- **WHEN** HTTP200且业务code为字符串000000、邀请码匹配、status为ACTIVITY_RETIRED
- **THEN** 欢迎页显示本期邀请活动已结束，保持iOS既有继续登录规则而不虚构奖励

### Requirement: 欢迎页错误策略必须保留双原生差异
客户端 MUST按AIAssistant1 Android与AIAssistant iOS的已核对规则显示明确业务原因并隐藏奖励。Android任何错误MUST提供重新加载或返回；iOS仅明确邀请码失效/过期/耗尽/替换/活动结束的白名单错误允许继续登录，配置未发布、网络及未知响应MUST重试。ACTIVE缺少活动对象MUST分类为CONFIG_NOT_PUBLISHED，MUST NOT显示零奖励或通用服务不可用。

#### Scenario: iOS活动已失效
- **WHEN** 解析确认活动结束
- **THEN** 显示活动结束及已有账号返回登录说明，不显示奖励，允许进入登录但不改变邀请码有效性

#### Scenario: 网络或活动配置缺失
- **WHEN** 双端遇到网络失败或ACTIVE缺少活动配置
- **THEN** 使用网络/配置分类文案及重试，不放行奖励或注册结果

### Requirement: 公开查询诊断必须可分类且隔离
公开resolve MUST记录固定枚举阶段/成功码类别/HTTP状态/耗时，MUST NOT记录邀请码、URL/query、响应原文或凭据。请求诊断MUST绑定请求开始时的账号命名空间，不因账号切换重建resolver，诊断异常MUST NOT阻断邀请流程。

#### Scenario: 查询期间登录状态改变
- **WHEN** 查询开始后账号发生变化
- **THEN** 响应诊断仍归原请求命名空间，不流入新账号日志
