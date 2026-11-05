## Context

行为源 4c781e3ccfcd148c1f205921534907ee0c5aa864，AssistantAuthRuntimeController、SmsLoginSubmission、FinalContactMethodPolicy 和 V88AuthPages。视觉源 0cd58de9bb578845517aeb54bef8ab6970392b81 的 memory/index.html。设计原型模拟成功和 6 位验证码限制不是产品规则。

## Goals / Non-Goals

目标：实现可交互的登录/邀请码页面，保留验证码 4–8 位、按手机号冷却、后端触发邀请码及 challenge 重用、返回登录。离线自动覆盖错误、重复提交、异步晚到、销毁和键盘。

非目标：本批不声明认证/会话持久化完成，不调用真实短信，不实现身份采集、首页、音频。正式成功后的会话交接留给下一接口批次；当前未接入适配永不返回成功。

## Decisions

- feature-first；AuthGateway/结果为纯 Dart，Controller 只管理表单与请求状态，Widgets 不访问数据源。Riverpod 负责生命周期和依赖注入。
- 布局使用 SafeArea + 可滚动自适应居中表单，不绘制原型系统栏，不把 793px 内容 viewport 固定为运行时高度。横向 page18+container24，表单最大320，Logo107x98。
- 返回登录保留号码和邀请码草稿，但重新登录必须有短信验证码，不能把旧 challenge 用到其他手机号。请求晚到不能复活已经退出的邀请码页。
- 数据层未接入时明确提示，不制作可混入正式 App 的演示账号。测试中注入网关响应，并标注为合成数据，不能作为线上 API 验证证据。
- 返回登录控件来自 v65，有意补足 HTML 未画的功能；允许因此导致邀请码页居中位置变化。两端字体按系统差异接受，不拿 Android 像素作为新的视觉基线。

## Microbatches

1. 规格三文件，再 delta spec / design artifact generator；运行 OpenSpec/生成器。
2. domain/auth_gateway.dart、controller/auth_controller.dart、test/auth_controller_test.dart；analyze + 定向 test。
3. auth_tokens.dart、auth_widgets.dart、auth_page.dart；analyze。
4. auth_provider.dart、phone_agent_app.dart、pubspec.yaml；pub get/analyze。
5. widget_test.dart、integration_test/auth_flow_test.dart（及测试依赖机械锁更新）；自动测试、模拟器、截图。
6. 报告、tasks、issue log 小批更新；全量校验与提交推送，未验收不归档。

## Risks / Trade-offs

首次设备验证发现 Flutter 3.32 PluginHandler 将 App buildTypes 复制至 plugin library，导致 `.dev` applicationIdSuffix 在 integration_test 的 profile 库变体上非法。仅将项目 debug/profile 包名改为 androidComponents variant.applicationId 设置；最终包名不变，release 门禁不变，不修改 SDK。构建后核对 APK manifest，补静态防回归。

认证后页面和真实服务尚未接入，用户不能把本批当成可登录的完整 App。验证码错误等暂用安全通用提示，不将未知异常或凭证输出到 UI/日志。样式只针对两张 auth 页面验证，不宣称全项目 UI 完成。

## Validation

### 2026-10-23 验证码长度修正

用户确认将 Flutter 验证码从固定 6 位改为 4–8 位数字。当前 `isSmsCode` 的六位正则与输入框最大六位均偏离本规格；只修改 domain 校验及 presentation 输入限制，沿用 AuthController 状态 owner、AuthGateway 请求身份与现有样式/共用控件。发送、冷却、邀请码 challenge、重复请求与迟到响应保护均保持，不新增接口字段或修改后端。任务编排回放不受影响。

验证覆盖 3/4/5/6/7/8/9 位、非数字、控制器合法提交与非法拦截，以及 Android/iOS 输入框数字过滤和最大八位。运行认证模块测试、定向 analyze、OpenSpec 与 diff 检查；不调用真实短信、不构建或安装。

openspec validate --all；flutter analyze；flutter test；Android debug build；Android emulator integration_test。记录真实执行证据与未验证项，不要求用户手工点登录/短信。
