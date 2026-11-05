# 实施与验证（2026-10-13）

本批仅给translation_dialer_route.dart已有自动预设条件增加_setup.snapshot.enabled；手动打开、预设确认后的继续、prompt持久化、UI文件及平台电话调用均不变。普通呼叫保留号码/权限准入，不调用翻译准备。拨号页498行，职责仍为入口编排，无新例外。

## 实际验证
- 双平台enabled/prompt四组合8项新页面测试：自动提示只在两者开启，普通呼叫直接系统端口；每种组合手动打开和确认保持可用、确认不二次弹出、取消无呼叫、偏好保留。
- flutter test定向44项全部通过：translation_preset_auto_prompt_test、translation_pages_test、translation_dial_flow_pages_test、translation_dial_summary_flow_test、cross_border_translation_dial_test、shell_translation_dial_boundary_test。包括页面连续流程及跨境/账号/退出保护；非全仓回归。
- flutter analyze：无问题（8.7秒）。
- openspec validate --all：106项通过，0失败。
- git diff --check：通过。

## 待验
- [ ] Android/iOS新包实际点击普通呼叫及手动预设交互验收。

未改平台/插件/依赖或构建链，按增量策略未重打包/安装。未授权真实外呼/收费测试，不执行。现有iOS SDK及其他业务改动保留；不切分支、不提交推送，未验收不归档。
