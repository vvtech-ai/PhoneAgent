## Context

v65 4c781e3：TaskApiService、SmsLoginController/SmsLoginDtos、ApiResponse、AccountIdentityProvider。用户选择agent.vvtech.tech测试环境。API_BASE_URL必须保留/aiassistant-api/前缀，鉴权接口为相对api/auth/sms/...；不自动发送旧账号令牌或重试POST。

## Goals / Non-Goals

目标：短信登录、邀请挑战、安全会话存取、成功状态交接、实际App验证。非目标：首页复刻、首次身份三步引导、积分页面、自动激活赠送、受保护业务API刷新策略、OTA旧Android数据迁移或音频。这些不被删除，后续接入。

## Decisions

- Dio只负责认证传输/严格DTO；处理HTTP错误和HTTP200业务错误，不输出响应、密码或token；不跟随跨站重定向。
- 服务结果字段accountId/phone/displayName/voiceCloneAccessToken/points/grantEvents映射为类型；邀请结果不保存为认证会话。成功缺账号/令牌等必需字段时失败，不伪造身份。
- 安全存储使用固定flutter_secure_storage9.2.4（文档https://pub.dev/packages/flutter_secure_storage/versions/9.2.4），Android禁用备份避免密钥恢复错配；iOS用设备本地钥匙串。认证数据按环境及规范化baseURL隔离，单JSON记录，不保存短信码/邀请码/challenge。
- Android NDK固定为本机已安装的27.0.12077973，与安全存储/path_provider插件声明一致；Flutter仍为3.32.0，不升级SDK。
- SessionController独立管理启动恢复和持久化，AuthController调用成功回调后才能完成；存储失败保存待重试结果于内存，不重复消费已成功短信码。退出邀请码产生的晚到结果仍被丢弃。
- 先保留现有工程状态页作为登录后暂存页面，明确已登录但首页仍未迁移；不以假首页冒充产品实现。启动加载失败明确提示并可重试，不能误判未登录而覆盖已有会话。
- 真实验证通过普通App表单和ADB输入自动操作，不增加调试认证接口。真实值不进入dart-define/源码/日志；不读取完整响应到工具输出。设备显示/安全存储是本次授权登录的预期落点。

## Risks / Trade-offs

短信不可重放 -> 不自动重试发送/登录；持久化失败只重试写入。进程终止前未保存凭据 -> 需重新登录并明确报告。iOS本批如未构建需记录，不能借用B0结果。真实用户验证仅限授权号码/测试环境，不触发外呼或身份采集。

## Microbatches

1. auth_gateway.dart、auth_session.dart、dio_auth_gateway.dart；静态检查。
2. DTO/HTTP测试、session_store.dart、session_controller.dart；定向测试。
3. secure_session_store.dart、pubspec.yaml、AndroidManifest.xml；依赖/构建。
4. auth_controller.dart、app_providers.dart、auth_providers.dart；测试。
5. auth入口、工程状态页、app路由；Widget/集成测试。
6. 自动离线回归、用户验证码弹窗、真实登录/重启验证；记录并commit/push。
