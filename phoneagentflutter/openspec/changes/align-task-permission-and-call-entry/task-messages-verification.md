# 消息展示任务验证记录

日期：2026-10-16。范围：本 change 的 1.3、2.2，以及权限设置提示的 Page 回调接线。基线为 Flutter 仓库 `8756f449`，固定 Flutter 3.32.0 / Dart 3.8.0。本记录不表示整个 change 或设备验收完成。

## 源码依据与实现边界

- 已阅读仓库 AGENTS、迁移需求基线、根任务、AI 工作流 spec、本 change 四类工件及知识库导航。知识库导航描述 Chaken-OMS，未作为 Phone Agent 的模块事实。
- 只读核对原生 `8f235920` 的 `PureVoiceStepPresentationPolicy.kt`：普通工具过程在结束时收起；权限等交互工具保留；针对 askUser 的明确交互展示进行去重，不能用同工具的任意普通文本统一替代权限卡。
- 只读核对 Java `InitialAssistantOpeningApplicationService`：权威开场白先于首个用户事实提交，commandId 为 `initial-opening:<sessionId>`。展示 helper 识别这个身份，也兼容起始位置的同文权威消息。恢复入口 `restore=true` 没有历史开场时不补一条新开场。
- 只读核对 Java `TimelineApiMapper.safeToolResult`：requestPermission 的结果体被隐藏为空对象，`resultStatus=completed` 无法证明允许或拒绝。因此没有在客户端伪造 ledger 或从 completed 推断授权成功。`ConversationPermissionPresentation` 只使用本次权限协调器返回的真实 status/message，保留请求卡的 body 和身份，生成本地展示更新；ActionFlow 的调用由权限任务负责接线。
- 现有 thinking 增量、结束及历史保留机制未修改；通过原测试和连续流程测试确认真实 thinking 结束后若轮次仍 sending，generic 等待反馈继续显示，完成后收起。
- `ConversationPage` 仍为单一时间线。开场展示规则放在独立 presentation helper，权限结果规则放在纯 Dart domain helper，Page 未新增第二套消息状态机，当前为 345 行。

## 实际修改

1. `conversation_message_merge.dart`：仅有同工具的明确结构化展示才替代工具卡，普通说明不吞卡。普通 search 的 `finishTools` 结束收尾规则保持。
2. `conversation_permission_presentation.dart`：真实系统结果更新既有权限卡的本地展示，未知状态/缺消息/缺工具身份不生成结果。
3. `conversation_entry_opening.dart`：新入口开场白在后续消息存在时继续保留，权威起始开场去重，恢复入口不补新开场。
4. `conversation_page.dart`：接入开场规则，并提供可选 `onPermissionSettings`；仅收到定位设置 notice 时展示“去设置”，sending 时禁用。Route 和设置回读由入口/权限任务接线。
5. `conversation_message_tile.dart`：权限等待、拒绝、需设置不使用绿色成功勾选；明确 OK 才以成功样式展示。非权限工具样式保留。
6. 5 个相关测试文件新增/更新验收，分别覆盖短屏双主题开场、连续流程、合并、真实权限续接结果和权限状态展示。

## RED → GREEN

- `.local/task-messages-opening-red.log`：4 个 Android/iOS、1x/2x 字体场景都明确失败于“发送首句后开场白必须留在时间线起点”；不是编译失败。此前第一轮日志含不存在节点的滚动异常，随后先断言时间线内容，重新观察了明确 RED。
- `.local/task-messages-red.log`：3 个权限卡结果场景及 1 个普通文本不能替代搜索过程场景失败，实际可见工具卡数为 0。
- `.local/task-messages-result-red.log`：2 个真实 granted/denied 回调场景明确失败，卡片实际仍为“等待用户授权”。接入本地真实结果 helper 后通过。
- `.local/task-messages-permission-ui-red.log`：等待/拒绝使用成功勾选的断言明确失败，修复状态样式后通过。

## 定向验证

以下均使用 `D:/tools/flutter-3.32.0/bin/flutter.bat test <paths> --reporter expanded`，不是全量测试。

### 消息模块与连续流程：31 项通过

日志：`.local/task-messages-green.log`。

- `native_conversation_opening_test.dart`
- `conversation_opening_continuity_test.dart`
- `conversation_permission_presentation_test.dart`
- `permission_result_presentation_flow_test.dart`
- `native_tool_card_ui_test.dart`
- `conversation_message_merge_test.dart`
- `conversation_tool_lifecycle_test.dart`
- `conversation_thinking_ui_test.dart`
- `conversation_thinking_stream_test.dart`

覆盖：新开场、首句、搜索、权限等待、结果到达后的顺序；权威 opening 去重与配置变化；恢复无伪造；权限卡与真实成功/拒绝续接；普通搜索结束收起；thinking 增量连续、结束保留与 generic 反馈切换；设置按钮的提示/回调/ready 门禁；短屏与放大字体。

### 直接调用方回归：69 项通过

日志：`.local/task-messages-callers.log`。

- `conversation_controller_test.dart`
- `conversation_widget_test.dart`
- `conversation_question_history_merge_test.dart`
- `conversation_questions_flow_test.dart`
- `conversation_viewport_test.dart`
- `conversation_visual_contract_test.dart`
- `native_conversation_tail_test.dart`
- `native_conversation_ui_test.dart`
- `task_160_projection_test.dart`
- `restaurant_option_revision_test.dart`
- `batch_confirmation_test.dart`
- `conversation_tool_card_test.dart`

### 静态与文本检查

- `flutter analyze` 已执行，消息组文件无问题。该次工作区分析发现同时开发中的入口任务 3 项 lint：`task_entry_permission_guard.dart` 35/39 的异步 BuildContext、`task_microphone_entry_test.dart` 38 的花括号。已交主任务处理并统一重验，本记录不将该次分析声明为全绿。日志 `.local/task-messages-analyze.log`。
- 10 个消息组 Dart 文件已使用严格 UTF-8 解码重新读取，无 U+FFFD；中文文案和测试内容正常。
- `git diff --check` 通过。未执行 git add/commit/push、打包、安装或真实业务。
- `openspec validate align-task-permission-and-call-entry --strict` 通过；`openspec validate --all` 168 项通过、0 失败，日志 `.local/task-messages-openspec.log`。

## 未覆盖项

实际 Android/iOS 系统授权弹窗、设备设置返回、TTS 和真实后端连通由主任务后续按授权验证。合成平台状态和 Widget 测试不作为这些运行态验收证据。历史中被服务端隐藏的权限结果没有补造；已真实展示的新入口开场在同一新任务内继续保留，切到历史恢复入口时以历史为准。
