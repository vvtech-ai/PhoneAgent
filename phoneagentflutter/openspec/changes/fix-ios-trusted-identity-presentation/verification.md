# 验证记录

## 自动验证
- `flutter test test/features/trusted_caller/ test/architecture_test.dart --reporter expanded`：143项通过。覆盖普通路由、SDK入口、展示协议、旧回调、清空竞态、真实Provider在主Flutter暂停且无帧时转发、身份页复用及架构。非全仓回归。
- `flutter analyze`：无问题。
- `openspec validate --all`：205项通过，0失败。
- `xcrun clang -fobjc-arc -fblocks -Wno-nullability-completeness -framework Foundation -I tool/trusted_identity_overlay_stubs tool/trusted_identity_overlay_surface_test.m -o /tmp/phoneagent-trusted-overlay-test` 后执行产物：通过。直接编译生产协调源码；UIKit/Flutter为替身，不能代替设备UI验收。覆盖SDK不关闭/重建、连续更新、旧关闭拒绝、账号失效、后台/过渡延迟、首帧门禁、动画中关闭及关闭不重开。
- 真实iPhoneOS SDK+Flutter3.32头文件 `clang -fsyntax-only -Werror`：通过。
- `flutter build ios --debug --no-codesign --no-pub`：最终成功，Xcode11.9秒。未安装，无签名编译不作为发布产物。

## 恢复记录
- 2026-10-19本轮：新增生命周期测试误await void，首轮129通过/1加载失败；按实际API修正后通过。
- Provider无帧订阅断言均通过，但testWidgets虚拟时钟内等待Stream关闭挂起；核对本轮测试进程并中止，改为真实异步test保留相同断言，最终通过。
- 原生替身首轮辅助函数名sync与POSIX冲突，确认未生成可执行文件后更名；复验通过。
- 首轮iOS构建在pod install阶段失败（post_install hook），核对工作区/Flutter SDK/进程，有限重试pod install成功。随后两次iOS无签名构建成功（28.5秒、最终11.9秒）。未修改工具链、SDK或依赖版本。

## 待真机验收
- MCP服务页来电实际覆盖显示，关闭后仍为原SDK页且设置状态保留。
- 连续来电、身份验签更新、前后台/系统来电界面往返、账号切换。
- 独立Flutter引擎首次启动耗时、内存及SDK兼容性。

真实来电测试待专项授权，本轮未安装或操作设备；不归档、不提交推送。
