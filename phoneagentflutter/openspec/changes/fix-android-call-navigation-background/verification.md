# Android通话导航区域修复验证

记录时间：2026-10-28 19:02:09 CST

## 实现与保留边界
- 当前test_v1.8.0_fix@f285726b，本轮仅修改presentation三源码文件：新增lib/core/design/android_call_surface.dart，接入任务CallSessionPage与TranslationCallPage。没有改Controller、接口、音频、全局主题、Activity或插件配置。
- Android可见通话期间临时启用edgeToEdge；任务页获得局部深色Scaffold，翻译页保留原Scaffold并指定Android底色。原NativeSystemChrome.dark仍透明导航栏/浅色图标/不强制对比度。原SafeArea仅一次，按钮和AI说明20dp底距保持；iOS/Web返回原child，不新增Scaffold或模式调用。
- 复用PageRouteVisibilityObserver，PopupRoute不释放；其他业务页覆盖释放，返回重新获取，最后owner退出恢复FlutterActivity既有系统栏可见基线。串行队列按revision防旧释放覆盖新owner，空闲释放Future引用。
- 相关回放ENTRY-05、STOP-01、VOICE-01仅验证页面、控制和回调边界，未执行真实电话。主线程align-ai-content-notice-reference未提交变更完整保留；两页面原DecoratedBox内容树在归一化格式和尾随逗号后与本次修改前快照相等。

## 自动证据
| 范围 | 结果 |
|---|---|
| 修改前底色回归 | Android两项失败，iOS两项通过 |
| 最初页面+AI说明布局 | 20通过 |
| 系统栏生命周期 | 任务/翻译弹层、其他页覆盖/返回、旧release/新owner交错3通过 |
| 页面/安全区/底部像素/非Android模式 | 与生命周期合并19通过 |
| 最终定向集合 | 83通过，0失败，6秒 |
| flutter analyze | 无问题，9.4秒 |
| openspec validate --all | 270通过，0失败 |
| git diff --check、手写500行上限 | 通过，源码最高203行 |

最终83项命令包含：
- test/core/design/android_call_navigation_background_test.dart
- test/core/design/android_call_surface_lifecycle_test.dart
- test/core/design/android_call_surface_insets_test.dart
- test/features/calls/call_pages_test.dart
- test/features/calls/call_monitor_pages_test.dart
- test/features/calls/conversation_call_flow_test.dart
- test/features/translation/translation_session_pages_test.dart
- test/features/translation/translation_controls_accessibility_test.dart
- test/features/translation/translation_finished_pages_test.dart
- test/core/design/call_ai_content_notice_test.dart
- test/core/design/ai_content_notice_page_layout_test.dart

覆盖0/24/48逻辑像素系统inset、0/34旧页面用例、大字/短屏、底部Flutter像素深色、原挂断回调、弹层时深色样式/模式保持、其他页面恢复浅色样式、返回通话与退出、iOS不调用模式。Flutter像素与mock平台调用不能替代OEM系统导航栏实机截图，不宣称实机白条已验收。

## 邻接基线失败
扩大集合加入test/features/translation/translation_pages_test.dart：71通过、3失败。三个用例为：
1. leaving during async preparation disposes late controller without start（准备次数期望1实际0）；
2. formal translation action respects offline without system fallback（未找到无网络连接文案）；
3. empty number opens presets then rejects without any call（未找到号码提示）。

将当前lib/test/assets及package配置复制到本次独立临时目录，再恢复本轮修改前两个页面快照，使用固定Flutter --no-pub仅运行该文件，同样7通过、3失败，失败名称与断言一致。未在主工作区回退、改业务或删断言。临时复现根目录登记于/tmp/phoneagent-android-call-nav-20261028/replay-root.txt，错误输出/tmp/phoneagent-android-call-nav-baseline-tests.log。不把邻接集合记为全绿；本次没有全量回归。

## 工具故障与有限恢复
- 新包装翻译页首次格式化缺一个闭合括号：重新读取实际尾部后补齐，格式化/编译回归通过，无业务副作用。
- 生命周期首轮两项失败为静态Future在旧fakeAsync zone保留，清理空闲队列引用后3项通过；保留原断言。
- 三处测试大括号lint已按实际行修正，最终analyze无问题。
- 内容保持校验最初错误期待翻译页内联onHangup（实际通过controls端口），以及未归一化formatter尾随逗号；读取真实diff重新建立校验，最终原内容树保持一致，不以修改业务迎合校验。
- 搜索未找到可用systematic-debugging/verification-before-completion技能文件，不声称已加载；按仓库独立规则先重现再回归。

## 设备与待验
仅只读ADB：当前连接设备Android API34；com.vvtech.aiassistant.test实际1.0.54(47)，首次安装2026-10-19 17:32:57，最后更新2026-10-28 16:37:59。没有覆盖安装、卸载、清数据、切换系统导航设置或发起外呼。手机尚无本次代码的新包，因此手势导航/三键导航的系统白条消失、弹层与结束返回实机视觉待同版本安装后验收；不以当前旧包检查冒充通过。
无原生、依赖或构建配置修改，未额外构建双端产物。iOS通过共享页面对照与原结构验证，没有iOS原生变更。未提交推送，不归档。
