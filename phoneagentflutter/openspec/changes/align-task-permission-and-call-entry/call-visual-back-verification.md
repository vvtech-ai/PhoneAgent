# 通话图标与返回行为验证（任务 3.1 / 3.2）

## 范围与依据

- Flutter 源码基线：`8756f449`，固定 Flutter 3.32.0 / Dart 3.8.0。
- 只读原生参考：`D:/work/04phoneAgent/aiassistant-app` 的 `8f235920`（`feature/test_v1.6.0`）：`FinalAiCallPage.kt`、`SingleFlowNativeDemoScreen.kt` 及六个 `ic_agent_call_*.xml`。
- 原生按钮为 52dp、图标为 24dp。挂断 XML 使用横置白色填充路径；原 Flutter 以电话轮廓旋转 135 度，既改变形状又超出视口。听筒原先使用 SVG rect，与原生 arc path 在 3 倍像素对照下存在差异。
- 原生 `BackHandler` 在 `showAiCallPage` 时直接返回。Flutter 的 `canPop: !show` 已拦截路由返回，但 blocked 回调又调用 `returnToConversation()`，导致收起通话及停止可见通话监听。

## 实现与职责

- `lib/features/calls/presentation/widgets/call_icons.dart`：挂断使用原生填充路径，听筒使用原生 arc path；其余四种图标已与原生像素一致，保留现有路径。继续使用 24×24 视口和既有颜色过滤，不放大、不关闭裁剪。
- `lib/features/calls/presentation/pages/conversation_call_host.dart`：仅移除返回被拦截时主动收起通话的回调。已有 `PopScope` 决定通话显示期间不能返回，子音源弹层拥有独立路由，物理结束与成功挂断沿用原流程。
- `CallControls` 保留现有 52×52 按钮与居中 24×24 图标，无需修改；未新增控制器或第二套状态机，未修改真实电话状态。
- 回归测试在现有 `calls` 与 Shell 测试归属内扩展；未修改共享任务清单，由主代理统一记录任务完成状态。

## RED → GREEN 证据

1. 更新正式 Host 导航及历史旧预期后运行三个文件：`.local/call-visual-back-red.log` 记录 16 通过 / 6 失败。其中五项复现返回收起问题，另一个为新增显式挂断测试的语义查找歧义，已改为既有按钮 key。
2. `native_call_icons_test.dart` 将六个独立原生 XML 路径转为测试参考，在相同颜色过滤、24×24 大小下进行 3 倍分辨率完整 RGBA 比较；`.local/call-visual-back-icons-red.log` 为 5 通过 / 2 失败，失败为挂断与听筒。
3. 最小生产修复后六种图标与 52/24 布局均通过；正式 Host 的双平台和显式挂断三个测试通过，见 `.local/call-visual-back-route-green.log`。
4. 通话模块首轮扩大回归为 214 通过 / 1 失败，唯一失败 `task_160_call_test.dart` 仍要求系统返回收起。直接调用方首轮 41 通过 / 1 失败，唯一失败 `shell_call_workbench_test.dart` 仍要求 `maybePop()` 收起并关闭媒体；两项均同步批准后的新预期后补验。

## 已覆盖的可观察行为

- 正式 `ConversationCallHost` 处于可返回父路由之上；系统返回不收起、不退页、不挂断，活动请求和任务保持，轮询继续。
- Android 通过 `flutter/backgesture` 的 start/commit 事件，iOS 通过页面边缘滑动，验证通话仍显示。
- 开启监听后返回，原 socket 与 output 不关闭、不重复读取票据，下一段 PCM 继续接收。
- 打开音源 sheet 后系统返回只关闭 sheet；通话与监听保持。
- 物理结束后回到原任务内容，停止监听，未发送挂断；随后系统返回可正常回父路由。
- 显式挂断只发送一次并按既有逻辑回到会话；Shell 流程继续覆盖挂断后结果、历史恢复及后续补充输入。

## 验证结果

- `flutter analyze --no-pub`：最终无问题（`.local/call-visual-back-analyze-final.log`）。首轮分析曾读取到并行修改中的 `conversation_page.dart`，报三项临时问题；该文件由对应代理修复后复验通过，本批未改该文件。
- `openspec validate align-task-permission-and-call-entry --strict`：通过（`.local/call-visual-back-openspec.log`）。
- `openspec validate --all`：168 项通过、0 失败（`.local/call-visual-back-openspec-all.log`）。
- 本批源码和测试严格 UTF-8 解码、中文读回、`git diff --check` 通过。
- `flutter test --no-pub test/features/calls --reporter expanded`：最终 215 项全部通过，含新增图标像素对照和正式 Host 导航用例（`.local/call-visual-back-calls-final.log`）。
- `flutter test --no-pub test/shell_call_workbench_test.dart --reporter expanded`：最终 3 项全部通过，含 320/430 宽度与活动通话返回分支（`.local/call-visual-back-shell-final.log`）。`shell_call_ports_test.dart` 在前一批直接调用方集中也已通过（`.local/call-visual-back-final-green.log`）。

本批没有生成包、暂存、提交、推送、安装或执行真实外呼。自动测试使用隔离端口，不能代表真实双端设备或电话媒体验收。
