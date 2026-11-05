# 1870 Flutter 验证记录

## 双端设备日志增量（2026-10-26）

用户明确功能同步 Android/iOS，后续指定版本 1.0.53（46），已更新共享版本源与现有 Android 构建脚本。普通日志与反馈的 ZIP 新增 device-environment.json，包含实际安装 App 版本/构建号、OS 版本、品牌/厂商/型号/硬件机型，摘要写入既有 deviceInfo 字段；Android API level，iOS uname.machine。读取失败保留包、不填假值，重试固定设备快照，账号隔离保留。iOS 相册用途加入反馈截图。

兼容性检查发现 readC1 整个 map 会进入签名，Java 严格白名单拒绝新增硬件字段。新增 readEnvironment 专供诊断，旧 readC1 字段完全不变；先取得新增方法预期失败回放，再修改双端原生和 Dart 适配。真实 Java ClientContext 探针验证原字段接受、额外硬件字段拒绝，未放宽服务端协议。

- 固定 Flutter3.32.0/Dart3.8.0，`flutter test test/features/support_feedback test/features/app_logs test/features/app_update/installed_app_channel_test.dart test/core/network test/core/audio/audio_focus_diagnostics_test.dart test/core/audio/media_diagnostics_test.dart --no-pub --reporter expanded`：243项通过；`flutter analyze --no-pub` 无问题；本 change strict 通过。
- Android AppInfoChannel.kt 使用缓存 Kotlin2.1.0、API35 与匹配 Flutter embedding 独立编译成功；完整 Gradle 缺本检出 `.local/cloud-dev/device-defines.json` 未完成。没有伪造或改用其他环境输入。
- Mac 登记主机 DNS 解析失败，无 iOS 原生编译/IPA。Windows iOS contracts 45项中1失败2错误，属既有符号链接权限/路径期望，未修改相关脚本。双端真机、相册、实际原生值及真实后台收件缺证据；自动平台回归不能代替。
- 证据：工作区 `deliveries/story1870-1872/mobile-platform-20261026/`。本批不修改数据库、共享SQL、私有输入或签名；版本由用户指定为 `1.0.53+46`。
- 未参与实现的独立角色重新读取最新禅道、附件及 Git Demo，231项测试、最终analyze、当前Android适配器编译、真实Java C1探针及1.0.53（46）合成构建参数通过。含版本/脚本的受验源码patch SHA256为 `a3ff2bb088bec3ec9fbb5957775dbe888d2ea4f90b3d766fe53eeb77e6cdc01f`；详细结论与缺口见 `independent/REPORT.md`。
- PowerShell打包政策检查通过；Python构建输入全套9项有7通过、1失败1错误（Windows假shebang执行及符号链接权限），从HEAD提取旧脚本同样复现，未弱化断言。独立1.0.53（46）release/debug参数检查通过；这不是成包证据。

## 环境与范围

## 2026-10-26 集成目标分支复查

用户授权复查后推入 feature/test_v1.8.0；先合入目标最新 fff1ef3f，保留对话输入区 AI 生成说明。独立相邻回归发现 shell_log_report_workbench_test 的原生夹具只支持 read，未适配正式日志 readEnvironment；仅补齐测试环境字段，保留原 ApiFailure.unavailable 和安装版本断言，3项自验通过。未改产品行为、签名字段或版本 1.0.53（46）；独立复验和最终交付身份记录于工作区 integration-20261026。

- 工作树：`_isolated/story1870-flutter`，分支 `codex/story-1870-1872-support-downloads`，开发基线 `f06c236c`。
- Flutter 3.32.0 / Dart 3.8.0；测试进程 JDK17。未更改全局 SDK、应用版本、签名或私有配置，未安装设备。
- 增加纯 Dart `image 4.3.0`，兼容既有 `archive 3.6.1`；锁文件只有新增 image，无既有依赖升级。
- 需求与接口：批准 PDR v1、共享接口合同 v1。视觉源：`5b644bf8:design/demos/user-feedback/{js/user-feedback.js,css/user-feedback.css}`，只读 Git 源码；渲染图只证明本地 Widget 布局，不代表设备验收。

## 失败回放与修复

1. 原实现 `api/feedback` 不在账号认证保护表、设置缺少反馈入口：首次测试失败；新增账号保护与入口后通过。
2. 设备元数据读取失败阻断未勾日志的反馈：新增失败测试后，按可选 deviceInfo 合同允许不附元数据；勾日志时仍保留失败与重试，避免填造安装版本。
3. 页面覆盖后捕获的旧回调仍可提交：先观察实际多出反馈请求的失败，再加入页面当前性与控制器身份校验；页面销毁后回调亦保持无效。

## 自动验证

- `flutter analyze --no-pub`：No issues found，退出0。
- `flutter test --no-pub` 定向121条通过，0失败。范围：`test/features/support_feedback`；settings下about_route、about_update、native_settings_presentation、settings_update_entry；auth下auth_web_flow、native_auth_presentation；app_logs下log_zip_api、log_report_controller、log_report_version_provider；core/network下account_api、service_routes；shell_log_report_workbench与home/shell_navigation。
- `openspec validate add-user-feedback-and-website-downloads --strict`：通过。
- 36个修改/新增文本文件UTF-8解码与U+FFFD扫描通过；中文已读回。29个Dart文件格式检查无修改，`git diff --check`通过。

新增用例覆盖 Unicode 码点边界、联系方式原文、空白描述、6图上限、图片处理中禁提交、处理失败不回退原图、原图10MiB、最终2MiB、GIF转JPEG、PNG原样保留与压缩、multipart顺序与Bearer、错误回执拒绝、重试同UUID/同快照、编辑新UUID、成功后ack、清理失败不重提、账号变化、旧页面回调、默认不附日志、整行点击、离页确认。

本地 Widget 渲染：320/390/430×844，载入本机中文字体与MaterialIcons，核对单卡片顺序、图片虚线区、日志16px/8px间距及无溢出；临时截图位于忽略的 `.dart_tool/feedback-render-<width>.png`。

## 扩大回归发现的基线失败

首次扩大运行涉及 auth、settings、app_logs、网络与壳导航；本次导致的测试变更已修正：大字菜单新增反馈操作、关于/日志入口迁移、更新入口滚动后对齐实际可点击区域。

以下4条在恢复 HEAD 原源码的同一工作树复验仍失败，随后已恢复本次实现，未修改相关业务：

- `test/features/settings/voice_transport_preview_test.dart`：320/390/430 三尺寸的 `gateway interaction without native media`，原有 PCM 预览文案断言失败。
- `test/features/auth/auth_session_widget_test.dart`：iOS `login and restore reach home and tasks without initialization`，原有 IosPaymentRuntime 恢复流程残留计时器。

## 未验证边界

- Android/iOS 真机画面、相册授权、HEIC 等设备特有解码及原生生命周期未取得证据。
- 未执行真实后端提交、私有对象存储失败与真实账号切换联调；网络测试使用真实 AccountApi 配合隔离传输适配器。
- 未构建 APK/IPA、未安装、未升级版本、未推送。

## 独立审查与按钮视觉修正

- 主任务独立审查结论：APPROVE；主任务对照真实 Demo 补充发现按钮颜色差异。
- 用户随后明确选择“提交反馈的按钮颜色保持app的默认颜色蓝色吧”。本轮以现有 `ShellTokens.accent` 为准，已核对其值为 `#0A84FF`，与 `5b644bf8:design/demos/user-feedback/css/style.css` 的 `.auth-btn.primary` 一致。
- 当时只将反馈提交与成功完成按钮局部接入该 token；本轮根据用户补充要求，日志复选框的选中背景和边框也接入同一 token。
- 两条渲染后的 Material 按钮表面颜色测试先失败，再修正后通过；反馈特性26条及临时渲染用例1条通过。
- 本轮 `flutter analyze --no-pub` 无问题，OpenSpec严格校验、三份Dart文件格式与UTF-8/diff检查通过。
- 已重新生成表单/成功页的320、390、430×844六张渲染图，并复制到 `deliveries/story1870-1872/flutter`；图片为 Widget 渲染，设备缺口仍保留。

## 2026-10-26 勾选框颜色回归

- 新增 Android/iOS 选中颜色用例先失败；两处选中颜色接入 `ShellTokens.accent` 后反馈35项测试通过，analyze无问题。
- 未参与实现的测试角色独立复跑35项，并用2项临时渲染/交互测试验证两平台：实际像素与按钮均为RGBA(10,132,255,255)，16×16px、8px间距、默认未选、整行可点及处理中/提交中禁用均通过。
- 独立证据：工作区 `deliveries/story1870-1872/cms-audit-fix-20261026/checkbox-independent/report.md`；Widget证据不替代真机、实际日志上传或iOS构建验收。
