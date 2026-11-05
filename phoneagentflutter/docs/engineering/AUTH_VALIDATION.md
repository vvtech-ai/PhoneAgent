# 登录/邀请码展示批次验证（2026-09-16）

## 范围

无需人工介入优先。交付两页 UI、表单状态和离线自动回归；本批没有短信/认证 HTTP、会话存储、首页、音频实现。普通入口不是演示登录，服务尚未接入时明确提示。

## 结果

- `scripts/verify.ps1`：Flutter3.32.0、锁依赖、格式、OpenSpec、analyze、55项单元/Widget测试、Android debug构建全部通过。
- `flutter drive --driver=test_driver/auth_driver.dart --target=integration_test/auth_flow_test.dart -d emulator-5554 --no-pub`：通过连续表单测试（含测试框架tearDown显示2项）；覆盖2页和7个关键控件。
- 手机号/+86粘贴、4–8位验证码、按手机号发送冷却、邀请码challenge复用、不带challenge时保留验证码、显式与系统返回、返回后再进入、晚到响应/销毁/异常均有离线测试。
- 390×793设计内容尺寸下，Logo107×98，表单x42/w306，CTA高49/top约568等断言通过；320×568、2倍字、240px键盘占位测试可滚动且无overflow。
- 设计元数据使用本机 Design2App schema 校验；13份JSON可通过 `scripts/design/validate-auth.ps1 -SkillReferences <技能references目录>` 复核。
- 普通main入口重新构建、安装和启动成功，不留测试替身包。APK包名com.vvtech.aiassistant.dev，versionCode1，minSdk26，targetSdk35。
- 普通APK SHA256：BA5A76DC5A1DF3D0367BB11BBD1BBD98B6A66759724488E377956465351396A2。
- 普通进程PID3024的AndroidRuntime:E/flutter:E过滤无输出；不代表整个设备无警告。集成日志有图形buffer格式探测警告，但截图和交互正常。

## 证据与复跑

设计/交互/视觉差异见 `design/auth/`。截图仅留 `.local/design-auth/previews/` 和 `.local/auth-validation/`，不提交临时图片；哈希索引见 AutoValidationResult。

复跑设计提取需先从固定源提交导出memory到`.local/design-auth/source/`，执行capture-auth.cjs（Playwright/Chrome）、prepare-auth.cjs。report-auth.cjs是已执行检查的结构化摘要生成器，不能替代实际verify/drive或截图检查。

模拟器集成网关为test-only合成数据，验证码发送1次/登录提交3次均只调用内存替身，零真实业务请求。系统返回通过Flutter平台返回事件自动执行；不宣称已验证所有Android手势系统差异。

## 修正记录

首次build因Flutter3.32复制App buildTypes至library导致applicationIdSuffix不合法，改为App variant ID配置，包名未变化、release保护未变化、未修改SDK。首次集成脚本未等待输入后的enabled重建，增加pumpAndSettle后通过。

## iOS

本批没有在Mac同步/编译/安装页面。已有B0 iOS成功仅证明当时基础环境，不能替代本批UI验证。保持共享签名会话不动，后续跨平台验证按需执行，不要求人工配合当前主线。

## 后续

首页/导航/设计组件 → 登录/模型/动态首页真实适配及会话交接 → 统一页文字链路/任务恢复 → 任务结果/设置 → 音频与平台能力 → OTA。真实短信/身份/音频整体联调后置记录，不把这份离线通过报告当作业务完成。
