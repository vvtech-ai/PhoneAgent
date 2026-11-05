# 设置交互生成与验证摘要

## 追加：诊断日志准备与上报

普通入口现接LogReportRoute/Page：本地准备快照→用户手动上传→成功，失败保留重试，清理失败仅重试清理；另有合成预览，不产生真实服务记录。复用既有AppBar/按钮/ListView和竖屏容器，无新位图或原生页面。页面外边距22，短屏可滚动；原型缺少该完整状态页，行为沿v65上传契约，样式尚未统一校准。

27新增/907全量测试、analyze及Web/Android Debug构建通过，320/390/430宽返回/失败重试覆盖；浏览器从设置本地准备4条/271字节，进入合成演练失败→重试成功→返回正式快照。正式上传未点击，无新设备安装。核心状态/控件细节与真实边界以docs/engineering/LOG_REPORT_VALIDATION.md为准；下方原“能力未接入说明/共用日志演练”是历史记录，日志入口现已替换。

## 追加：版本检查页面

共享AppUpdatePage和Controller承载未检查/处理中/最新/新版本/重要版本/失败重试；Android薄通道+正式Repository，Web Debug独立MOCK，iOS无入口。实现契约见update-check-contract.json；复用既有ShellTokens卡片/按钮/滚动，不新造HTML播放器或截图热点。

新增23项、830全量/analyze/19项OpenSpec通过，Web和Android Debug构建通过；320/390/430短屏交互与下载演练返回通过，浏览器新版本→失败→重要版本重试已确认。页面暂代v65最终更新弹窗，最终尺寸/强制关闭/安全区仍待统一校准；未完成下载、安装、无缝升级或真机验证。

## 来源与范围

- 行为：Android v65 `4c781e3` 的 FinalSettingsHomePage、DomesticTranslationAudioSettingsCard、TranslationCallSettingsRepository、AssistantDeveloperToolsPage、AssistantRootSettingsPreferenceState 和拨号串处理。
- 视觉：设计 `0cd58de9` 的 `memory/index.html` settingsPage / translationOriginalAudioPage，复用 ShellTokens。用户 2026-09-17 允许先用静态 HTML/CSS 和现有组件完成交互，之后统一视觉校准。
- 原型新增记忆、可信来电和已废弃入口不迁移；原型缺少的原音音量/增益滑条按 v65 补足。
- 不依赖原型运行态截图作为本阶段前置门禁；本记录不构成像素级验收。

## 实现产物

`lib/features/settings/` 包含 7 个页面/路由文件、退出确认组件、2 个 Controller，以及原音 domain / storage。`lib/app/settings_providers.dart` 负责注入与进程状态；Shell 只挂路由。拨号 Controller 的解锁回调不访问 UI 或存储。

页面：设置首页、原音设置、能力未接入说明、日志/OTA 共用演练页、开发者演练、固定号码演练。页面状态与跳转分别记录在 PageStateGraph / RouteGraph；控件、条件入口和影响记录在 ActionableControlInventory / InteractionMap。不是 HTML 播放器，也不是截图背景叠透明按钮。

## 资源和视觉差异登记

| 区域 | 本阶段实现 | 后续校准 |
| --- | --- | --- |
| 首页卡片 | 既有 ShellTokens，外边距22、卡片内边距16、间距12、圆角24 | 字体、阴影、留白与长文案折行 |
| 返回/开关/滑条/弹层 | Flutter 现有语义组件；不新增图片，不引用未使用SVG | 双端安全区、系统组件差异、键盘与可触摸面积 |
| 原音 | v65 开关、音量0–100、增益0–50、10步进 | 原型未含完整滑条，按代码行为验收后做视觉统一 |
| 演练提示 | 持续显示MOCK及真实能力未接入边界 | 不伪装成正式业务成功；最终能力接入时替换端口 |

## 验证证据

- 全量436项自动测试通过，新增设置22项；320/390/430宽页面、条件显隐、读写失败、并发保存、退出互斥、开发者/OTA/日志隔离测试。
- `flutter analyze` 通过。Web共享回归329项、Chrome流式2项、Node代理1项通过。
- 浏览器已验证真实本地原音修改→刷新保留→恢复原值、退出确认取消、日志MOCK失败→重试→成功。
- 构建、真实/模拟边界及人工验收见 `docs/engineering/SETTINGS_VALIDATION.md`；自动测试不代替真机音频与OTA验证。

OpenSpec `settings-interactions` 保持 active，真实端口/真机/视觉/用户验收未完成，不归档。
