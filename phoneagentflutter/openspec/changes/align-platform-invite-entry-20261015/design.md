## Context
2026-10-15侧会话用户确认执行。本地codex/dev_zys，主线程有tasks/issue/integrate-commerce三份未提交文档。保持原工作树与分支，无commit/push。

## Decisions
- 使用纯Dart分平台策略工厂；Android以环境批准host/scheme接收，iOS保留agent.vvtech.tech/phoneagent-ioslink.vvtech.tech与www.chaken.ai/ioslink.chaken.ai。仅信任批准HTTPS API主机且默认端口，保留旧iOS环境兼容，不自动切环境。
- Android入口Activity从Manifest元数据读取环境，验证链接、生成UUID、NEW_TASK/CLEAR_TOP/SINGLE_TOP转交MainActivity；SharedPreferences记录最后入口UUID，历史标志拒绝，消费Intent后向Dart传URL。
- 原生去重识别系统重放，Android仅原生凭据去重避免误吞新的同码点击；iOS保留1秒URL去重防御重复回调。PendingInvite新增仅内存入口序号，不持久化欢迎页；每次接收生成新序号，欢迎页provider按(code,entry)隔离。切换入口时dispose旧controller，mounted拒绝迟到响应。
- iOS平台回调和Universal Links地址不改；通过现有initialLink与stream接收，恢复会话前只保留最新邀请；本次无必要修改Swift。
- resolve使用sdkApiBaseUri优先，兼容既有未配置SDK的同源环境；不带Bearer，不跟随重定向。通过纯合成网络测试确认服务路径。
- Android欢迎页业务错误不放行继续按钮，已打开的邀请码填写页优先于欢迎页（与原生AssistantAuthGate一致）；iOS保留原白名单与原页面优先级；返回登录保留邀请，提交期间新邀请不覆盖。已有注册ID重试/登录清理逻辑复用并回归。
- 每业务微批最多3手写文件；规格及工作记录为文档批次。无UI重排、无签名/App身份/服务器关联配置变更。

## Validation
固定Flutter3.32.0/Dart3.8.0；OpenSpec全校验、analyze、邀请/auth直接调用方定向及连续流程；Android debug构建与原生策略JUnit。iOS未改原生仍核对配置不变，共用测试覆盖iOS规则。设备唤起、AASA/assetlinks系统关联、真实注册奖励独立待验，不安装/卸载设备，不用真实短信替代测试。

## 已登录邀请提示宿主修复
InviteEntryHost位于MaterialApp.router builder中、Navigator/Overlay上方，不能用自身context查找后代Overlay。使用现有router navigatorKey取得根OverlayState，并由showNativeNotice可选显式overlay参数插入原共用提示。保持已有普通页面调用兼容，不创建第二套提示UI。分别覆盖iOS/Android、冷入口队列/热入口、重入提示和页面导航可用性。日志仅显示通用请求，无邀请入口事件，无法据日志断言iOS系统投递成败；本批不复现真实邀请码注册。

## 原生回调签名与可观测性
Flutter3.32 FlutterPlugin.h导入要求launchOptions为非可选[AnyHashable: Any]、restorationHandler为([Any])->Void；UIKit UIApplicationDelegate的对应Swift签名不能直接作为FlutterPlugin协议实现。修复仅InviteChannel的两个签名。增加工具在固定SDK编译LLVM IR、验证实例方法表真实含cold/openURL/continue三个ObjC selector，拒绝near-match警告；不靠Dart模拟证明原生接收。Dart入口以固定枚举诊断记录received/rejected/queued/existingAccount/registration/saveFailed/streamFailed，不写URL、码、手机号、token或任意字符串。保持journal现有账号隔离，不watch诊断provider以免重建入口。

## 公开解析业务成功码
PublicInviteResolver与现有AccountApi/AuthGateway保持数字0或字符串000000成功契约，其他类型/码不宽泛转整数。成功后先核对邀请码，再处理ACTIVE/业务状态；ACTIVITY_RETIRED不要求activity字段、应走已有INVITE_ACTIVITY_RETIRED文案和iOS继续规则。合成回归覆盖双成功码、活动结束/过期/额度耗尽和非成功码，不能把真实用户码写入fixtures。只读匿名GET不会注册/领取/上报事件。

## 双原生欢迎错误对齐
参考AIAssistant1/test/v66.0.3的InviteRegistrationBridge/WelcomeState/Screen，以及AIAssistant/iOS/pro/v1.0.46的AIInvitePolicy/WelcomeViewController。错误文案使用已核对原生内容：活动结束详细说明、过期需有效码、名额耗尽、活动更新原码失效；不改其他邀请页面的全局InviteFailure.message。欢迎页独立纯Dart策略提供文案和继续白名单；Android所有错误重试，iOS业务失效白名单继续，CONFIG_NOT_PUBLISHED/网络/未知错误重试；返回登录保留待处理码。
公开resolve ACTIVE缺失activity按原生CONFIG_NOT_PUBLISHED，错误响应提取白名单业务码，非法结构/未知状态归INVALID_RESPONSE，Dio网络归NETWORK。已完成0/000000和SDK路由保持。
新增DiagnosticInviteResolveDetails固定枚举outcome/apiCode分类，DiagnosticOperation.inviteResolve，记录HTTP/耗时但不记录真实码、URL/query、原文或凭据。每次请求捕获起始账号journal，切号不得转投新账号；诊断异常不能阻断解析。Provider只在请求时read，不watch journal避免重建resolver。
验证：缺活动/未知结构/HTTP错误/网络/业务状态、两平台按钮/返回/重试/奖励隐藏、诊断脱敏和账号切换；定向invites/auth/app_logs、analyze/OpenSpec/diff。纯Dart批次，不重复平台构建和安装，真实后台期次与设备仍待验。
