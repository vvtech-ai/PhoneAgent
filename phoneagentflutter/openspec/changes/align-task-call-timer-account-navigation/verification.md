# 任务通话计时与账号导航验证

## 范围

2026-10-22，Flutter codex/dev，基线 `6f0fcec0`。本批仅修改任务通话接通事实的客户端投影、计时与展示/监听接线，以及设置/关于/账号导航。1.5 秒准备期、余额刷新、轮询间隔、结果同步窗口、翻译通话、后端和计费保持原实现。按用户要求，不打包、不部署、不发起真实外呼。

## RED

- calls 首轮 19 项中 5 条预期失败：等待时间仍显示、等待期提前启动时钟、CONNECTED 推送先到时页面没有 00:00，以及下一通仍显示等待秒数。测试使用真实 ConversationCallController、CallSessionController、CallSessionPage、ConversationCallHost 与 CallMonitorController；外部通话、音频和时间使用合成端口。
- settings 首轮 9 项中 4 条预期失败：关于页最后仍是版本更新、设置首页仍有账号入口；覆盖 Android/iOS 与两种字体大小。

## GREEN 与状态边界

新增连续测试验证：等待不显示/累计通话秒数；错 session/command/attempt 的 CONNECTED 不启动计时；合法推送先于 DIALING 快照即显示 00:00，并放行用户已经请求的监听；后续旧 DIALING/重复 CONNECTED/页面重建不归零；查询先接通同样有效；物理终态停表，下一通用新身份重新从零开始，无挂断副作用。

账号 shell 两平台已通过：设置首页没有账号行；关于页进入账号管理；取消注销保留登录；页面返回与生产路由的系统返回均回到关于页；确认后回登录并移除账号页。复用 RouteProviderScope 传递原容器；原账号控制器和确认逻辑未改。

## 基线失败核对

扩大验证不能表述为全量通过：

- 第一组扩大验证 276 通过、7 失败。将全部本批跟踪修改临时保存，回到基线 `6f0fcec0` 执行同样失败文件，4 通过、相同 7 失败：voice_transport_preview_test 三种宽度的 PCM 文案 3 条；shell_settings_platform_back_test 的 iOS 两种字体测试存在未清理计时器 2 条；原 settings_account_shell_test 的两平台注销测试 2 条。
- 账号注销的测试缺少本地存储平台替身；复用既有 installLocalStorageChannelFake 和 FlutterSecureStorage 内存替身后，两条均通过。没有改产品注销流程或放宽回登录断言。迁移导航新增系统返回场景通过生产 routerDelegate 派发，避开预览工作台的外层导航。
- 进一步运行完整 calls 模块及直接设置调用方：347 通过、9 失败。基线相同四个失败文件重复验证为 47 通过、相同 9 失败：continuous_task_orchestration_test 3，conversation_outcome_thinking_test 2，conversation_structured_failure_test 3，task_160_call_test 1。均未为本批修改既有业务期望。
- 上述临时保存均按精确 stash SHA 恢复；本地 output/ 及其他检出的构建脚本不纳入提交。

## 最终交付检查

- 最终定向验证：7 个直接相关 calls 测试文件（含新增接通连续回放）、settings 功能目录除已核实的 voice_transport_preview_test，以及 settings_account_shell_test，共 **274 项全部通过**。该选择覆盖 CallSessionController、计时、实际页面、短屏大字、关于页更新/版本/日志、账号确认和返回，不将前述基线失败算作通过。
- 更广的完整 calls 及设置直接调用方结果为前述 347 通过、9 条基线失败；完整设置及系统返回扩大验证另有前述 5 条基线失败。未宣称全量通过。
- `flutter analyze --no-pub`：No issues found。使用固定 Flutter 3.32.0 / Dart 3.8.0，无依赖或锁文件变更。
- `openspec validate align-task-call-timer-account-navigation --strict`、`git diff --check` 通过；本批文本按 UTF-8 读回，中文正常，无替换字符。
- 推送前重新 fetch，codex/dev 与 origin/codex/dev 的基线均为 6f0fcec0；本批采用中文提交，推送后独立读取远端分支 SHA 核对。只包含本次文件，不包含本地 output/。

## 独立复核

只读复核无新增 Critical/Important/Minor 问题。检查了身份和代次、终态门禁、已接通事实不被 DIALING 撤销、计时与监听一致，以及路由容器与返回路径。

额外发现的旧边界：已经接通过的通话若进入可撤销的非 primaryClosed 失败 closure，再由 CONNECTED 恢复，计时可能仍停止；查询先接通的基线已有此机制，不属于本批新增问题，未扩展到恢复策略修改。

本批自动验证不能代表真机画面、运营商接通或实际音频验收。用户新提供的慢呼叫样本另行只读分析，带账号运行证据不进入本变更。PMReport 本地资格检查返回 git_context_invalid，未上报。
