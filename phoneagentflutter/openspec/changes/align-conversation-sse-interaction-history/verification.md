# 公共编排会话纠偏：证据、复现与验证

## 历史证据的适用范围

下文为不同批次的历史验证记录，保留输入、断言与实际结果，不作为当前行为说明或待执行设备步骤。当前依据是本 change 已修订 delta 和用户批准的 `task-orchestration-v1`（入口见仓库 AGENTS）；与其相反的“道歉后台 opening 与 Consent 同时显示”等期望已被替代。历史 26 / 93 / 120 等通过数不证明共享合同新竞态或真机修复，本轮规范校验见 `freeze-task-orchestration-contract/verification.md`。

## 2026-10-20 本地确认覆盖欢迎语、就绪提示补文字

最终范围以用户最新要求为准：恢复本地 ApologyVoicePolicy.consent，撤回把确认文案迁到后台的全部修改；Java 工作区 `git status --short` 无输出。本地确认覆盖道歉 entry.opening，普通 Skill 开场保持。只修改 ApologyConversationBinding 的 Ready 文字分支与 ConversationPage 的道歉 entry-opening 判定。

失败证据：新增普通确认用例在修前只能得到 Consent 与“确认使用”，voice.prompt 已是“好的，使用您的克隆音色。您想向谁道歉？发生了什么事？”，文字列表缺少第三项。原代码仅为 selectionSummary 非空的切模路径添加文字。补齐后使用相同 prompt.text 写入现有 voice-ready 身份；不另建排序/持久化协议。双平台页面覆盖后台欢迎语的期望也先观察到失败（旧页面各显示一份后台欢迎语），再增加仅限道歉的屏蔽条件。

验证命令（Flutter 3.32.0）：

```powershell
$tests = @(rg --files test/features/conversation -g 'apology*_test.dart')
$tests += @('test/shell_apology_precheck_test.dart','test/features/conversation/native_conversation_opening_test.dart','test/features/conversation/conversation_message_merge_test.dart','test/features/contacts/contact_skill_opening_parity_test.dart','test/features/call_models/apology_task_model_sheet_test.dart')
& 'D:/Tools/flutter-3.32.0/bin/flutter.bat' test --no-pub $tests
& 'D:/Tools/flutter-3.32.0/bin/flutter.bat' analyze --no-pub
```

14 文件 67 项通过；analyze 无问题。当前 OpenSpec change 有效；全仓 213 通过、3 个既有 change 失败（incremental-validation-policy、login-presentation、native-feature-parity-audit）；git diff --check 通过。真实控制器的普通/切模分支在 initial-opening 事实逐条到达、首条用户事实与最终回复后仍保持完整序列、一份 Ready 和旧卡选中禁用；Android/iOS Widget 重建验证后台欢迎语不存在、Ready 单份及消息坐标顺序。既有语音宿主用例验证本地确认播报、普通后台开场未变。没有执行手机测试、构建或安装；这些结果不证明手机验收完成。下文为历史记录。

## 2026-10-20 initial-opening 事实回填与查询播报

本轮基于 Flutter `1f57bf18` 开始，执行期间同分支的会员拒绝历史修复独立提交为 `867b8afa`，该提交不属于本轮修改。原始 Android 依据为用户明确指定的 `D:/project/aiassistant`、`test/v66.0.3`、a0bedb12；相关源文件无未提交修改。其 ApologyVoiceCoordinator:171/216 证明选择先回显、查询不生成提示；PureVoiceThreadList:390 从紧邻的操作回显恢复旧卡选中索引；PureVoiceConversationStepProjectorTest:357 已有多张旧卡选择保留用例。本轮只读这些 Android 文件，没有执行原生测试。

### 失败复现

新增 `test/features/conversation/apology_committed_timeline_test.dart`，使用真实 ConversationController、内存音色端口和 AgentGateway，按当前 AgentCommand 的 initialAssistantPrompt、initialUserSelection、initialOpening 生成顺序连续的合成账本事实，不使用真实用户 fixture。

- 原源码上 3 项失败：Checking 的 voice.prompt 非空；普通确认收到 initial-opening 时首条实际变为 ReadyPrompt；切换模型收到 initial-opening 时首条实际变为模型提示，均违反原 Consent 在先的顺序。
- 失败条件不需要等首次用户事实到达：旧 anchor 仅锚定首次用户 command，initial-opening 事实已先占据列表前部；后续到达用户事实也不能把本地记录放回这些初始事实之前。旧的全局同文案替换进一步将部分模型记录直接接管到初始事实的位置。
- 首次测试 fixture 因未订阅流等待 close 而挂起，已中断并改为 broadcast fixture 后重跑；以上 3 项失败均来自实际断言，非加载/语法错误。

### 修复和验证

仅修改 ApologyVoiceController、ApologyConversationBinding、ConversationMessageMerge：查询启动独立通知，不创建可供语音宿主读取的 prompt；本地前置交互按照原序列插入/接管 initial-opening，正文替换限定为初始开场身份，旧卡继续使用原 ID、选中索引和禁用状态。

新增用例覆盖每条初始事实分别到达、首次用户事实、finalResponse、最终 committed 和 done；普通/切模两路检查完整文本序列、全部旧卡索引与禁用。Android/iOS Widget 场景使用真实控制器最终投影，强制销毁并重建页面，检查配置开场保留、提问/卡片/回答/就绪/最终结果的实际纵坐标，选中蓝底/蓝框及禁止再次点选。

验证命令：

```powershell
$testPaths = @('apology_committed_timeline','apology_voice_flow','apology_voice_api','apology_cancellation','apology_task_model_scope','apology_precheck_lifecycle','apology_opening_speech','apology_provider_initialization','apology_entry_controller','conversation_message_merge','conversation_message_tile','native_conversation_opening','conversation_question_history_merge','confirmation_interaction','conversation_tool_lifecycle','native_presentation_parity','native_policy_alignment_review','terminal_receipt_overlay_parity') | ForEach-Object { "test/features/conversation/${_}_test.dart" }
& 'D:/Tools/flutter-3.32.0/bin/flutter.bat' test --no-pub --reporter expanded $testPaths
& 'D:/Tools/flutter-3.32.0/bin/flutter.bat' analyze --no-pub
openspec validate align-conversation-sse-interaction-history --type change
openspec validate --all
git diff --check
```

18 文件 120 项测试通过；Flutter 全仓 analyze 无问题（13.8 秒）；当前 change 有效；全仓 OpenSpec 213 通过、3 项既有失败（incremental-validation-policy、login-presentation、native-feature-parity-audit）。首次 analyze 的唯一问题为新测试冗余导入，移除后重新执行通过。不运行全量 Flutter 测试或 APK 构建：本轮不改平台/依赖，影响限定于道歉前置交互，已覆盖直接调用方及公共合并相关用例。

尚未对用户手机取得本次失败的完整 SSE/账本样本，本回放只证明上述已复现条件得到修正；未构建、安装或进行手机同输入验收，不宣称真机效果已验收。下文旧轮结果不替代本轮证据。

## 2026-10-19 最新 `xiaosy/dev_v1.7.0` 再次修复

本节为本轮当前证据；下文 `codex/dev` 和旧轮测试数字仅是历史记录。`D:/aiProject/phoneagentflutter` 在拉取 `origin/xiaosy/dev_v1.7.0` 后，HEAD 与远端均为 `1684c08038a8c30e18980c9f4bd2790ddc2592f4`（`git rev-list --left-right --count` 为 `0 0`）。工作区起点只有既有未跟踪安装包和 `deliveries/`，本轮未触碰它们。

用户确认的原生截图仍是 `D:/Caches/apology-correct-20261019_180516.png`：旧提问和选中卡留在前面，用户“确认使用”回显在其后，再出现无可用音色说明和新卡。当前 Flutter 起点的 `apology_voice_flow_test.dart` 明确断言查询时消息列表清空；`apology_conversation_binding.dart` 的 `_present` 在状态切换时删除所有 `local:apology:` transient，`command()` 又删除一次。`conversation_page.dart` 只在 `state.messages.isEmpty` 时展示 `entry.opening`；道歉 Consent 一出现，后台 opening 即被隐藏。

本轮先改回归断言再运行，观察到旧卡测试实际列表 `[]`、opening 在有消息时缺失、道歉提问未独立成气泡。修复后对照同一用例，并检查模型选择、普通选项样式、历史恢复和消息合并。真实 Flutter 真机同输入画面、后端完整 SSE 样本仍待验证；源码/Widget 测试不能替代现场验收。

修复内容：选择时先冻结旧卡并记住选中索引，追加独立身份的用户回答；查询状态不向时间线写提示，也不清除历史卡；首次任务提交只为已展示的道歉记录设置后续轮次锚点。页面在新会话保留后台配置 opening，并在有权威开场事实时避免重复；道歉问题放在卡外，旧卡只保留所选行高亮，普通锁定卡仍用原中性色。恢复入口不重播本地 opening。

验证回执：14 个当前存在的 `test/features/conversation/` 相关文件共 **93 项通过**；`flutter analyze --no-pub` 全仓无问题；`openspec validate align-conversation-sse-interaction-history --type change` 通过；`git diff --check` 通过。`openspec validate --all` 为 **213 通过、3 失败**，失败项仍是 `incremental-validation-policy`、`login-presentation`、`native-feature-parity-audit` 的 MODIFIED 场景缺失，与本次文件无关。第一次扩大测试清单误含已不存在的 `conversation_opening_continuity_test.dart`，清单修正后 14 文件重跑通过。本轮未构建或安装 APK，未进行 Flutter 真机视觉/点击验收，也未改后台、生产配置或数据。

2026-10-19；Flutter 工作区 D:/aiProject/phoneagentflutter，分支 codex/dev，基点 cd4bfc37；原生只读对照 D:/project/aiassistant/android，基点 a0bedb12a。源码有未提交修改，以上 HEAD 不是已交付修复版本。

## 旧结论撤回与证据范围

此前“entry-only opening 在首次提交后隐藏”和“道歉入口只显示专用 Consent”的结论都已撤回。用户明确要求道歉使用后台配置 opening；当前实时会话应先显示配置 opening，再显示专用 Consent，选择后两者继续留在历史中。关闭后从服务端账本恢复是不同生命周期，不能把 transient 清理解释为选择时隐藏。

已确认的是旧 App 指定画面、相应原生源码和下列 Flutter fixture 行为。尚未收齐真实后端全部 payload 子类型和事实提交规范，不能宣称“全部 SSE 规范已验证”。

## 旧 App 证据

- 历史记录的用户确认画面路径为 `D:/Caches/apology-correct-20261019_180516.png` 与同名 `.xml`；本机目前未找到这两份旧主机缓存，不能作为本轮可复查附件或设备通过证据。旧记录的包名为 com.vvtech.aiassistant，设备 OPPO PDKM00；保留历史出处，不猜测重建或提交真实用户 fixture。
- 顺序：专用提问 → 确认使用/不使用旧卡 → 用户“确认使用” → 无可用克隆音色说明 → “暂不使用”新卡。旧卡选中高亮；XML 旧选项父节点 enabled=false，新卡 enabled=true；没有查询消息。
- 原生源码根：D:/project/aiassistant/android/app/src/main/java/com/vvtech/aiassistant/features/。

| 源码入口 | 支持的结论 |
| --- | --- |
| assistant_apology/ApologyVoiceCoordinator.kt，onOption / queryVoices | 停止播报、追加回答、清 active，再查询；Checking 不 present 查询正文 |
| assistant_session/AssistantSessionClarificationStepHandler.kt，appendClarificationStep | 列表末尾追加，区分用户操作回显 |
| assistant_singleflow/SingleFlowNativeEntryEffects.kt，onBeginSkillVoiceEntry | 专用入口成功后提前 return；普通入口才读取 peekOpening |
| assistant_pure_voice/PureVoiceThreadList.kt:345 | 仅道歉卡拆分提问气泡，普通 options 保留内部标题 |
| 同文件 pureVoiceActiveShowOptionsStepIndex / pureVoiceSubmittedShowOptionIndex | 当前操作权与旧卡选择显示分离；从后续用户步骤取得选中项 |

## 已复现的缺陷与修复

| 触发 | 修改前问题 | 修复 |
| --- | --- | --- |
| 点击道歉确认 | echo 与提问复用 commandId，merge 将 user 排到 assistant 前 | 回答使用独立本地动作身份 |
| 等待音色查询 | _show 将“正在查询”写入对话 | Checking 单独通知，清 active，保存 pending 恢复快照 |
| 文本“确认使用” | 绕过 binding.choose，缺少回显 | 识别后的选择统一入口，一次回显 |
| 道歉有配置 opening | 旧推断把后台开场隐藏 | 先显示后台 opening，再显示专用 Consent；点击后仍保留 |
| 本地道歉选项 | 提问与选项同卡 | 单独提问气泡，仅道歉 showTitle=false |
| 文本选择后重建旧卡 | Widget 局部状态丢失高亮 | 本地消息保存 selectedOptionIndex，不改 wire |
| 后续轮次 committed 到达 | 本地交互被追加到未来回复之后 | 以临时列表的后续 command 对应事实定位插入，保持账本相对顺序 |

## 自动化复现与实际覆盖

1. apology_timeline_order_test.dart：真实 ConversationController + 延迟音色端口。点击旧卡，断言提问在首位、回答在其后；查询未返回时仅两条消息且无查询正文。返回空列表后检查 assistant/user/assistant；再选新卡后检查 assistant/user/assistant/user，旧卡不可重复选择。
2. 同文件：文本“确认使用”重复输入，回显仅一次；重建旧卡组件，selected=true、onTap=null。这里测试识别后的文本入口，不是真实麦克风/ASR。
3. 同文件：真实 ConversationPage 验证道歉配置 opening 和 Consent 均显示，点击后仍可见；旧卡高亮失活、回答位于旧卡与新结果卡之间，新卡可操作。普通入口已有输入时仍显示 opening；MessageTile 验证道歉提问在卡外、位于卡上方。不是设备或像素级视觉验收。
4. conversation_message_merge_test.dart：本地 prompt/choice/下一轮 provisional user，加该轮 accepted/reply 事实，有/无前一轮事实分别断言完整顺序 [earlier?, prompt, choice, accepted, reply]。其余测试覆盖同轮权威替换、不同轮同文案隔离及工具卡合并。
5. conversation_event_contract_test.dart：分别断言 signal/ASK_USER、合法 committed、done、unknown 分类和身份；不是连续 SSE 实测或完整后端协议验证。
6. 其他相关测试覆盖普通 options、开场连续性、pending 恢复、问题合并、回执/产物顺序、批流程和工具生命周期。具体输入以测试文件为准，不拼成未运行过的端到端流程。

旧轮的 23 文件 123 项通过已因源码回退失效。2026-10-19 本次重新观察到旧卡选中、回显、查询正文、页面保留和公共顺序断言失败；模型切换 pending tool 回归在首轮失败后修复。本次最终 23 个相关测试文件 125 项通过、定向 analyze 无问题、当前 change 校验通过；全仓 OpenSpec 177 项通过、3 个其他 change 的既有错误。用户随后明确取消打包；构建已中止，旧 APK 时间戳未变，本次未生成、导出或安装新包。

## 可重复命令

仓库根执行；固定 Flutter 3.32.0 / Dart 3.8.0，受控端口无需真实登录、短信或外呼。

```powershell
$flutter = 'D:/Tools/flutter-3.32.0/bin/flutter.bat'
$caseNames = @(
  'apology_timeline_order', 'apology_voice_flow', 'apology_cancellation',
  'apology_task_model_scope', 'apology_entry_controller',
  'apology_precheck_lifecycle', 'apology_opening_speech',
  'apology_provider_initialization', 'conversation_message_merge',
  'conversation_message_tile', 'conversation_opening_continuity',
  'conversation_controller', 'native_option_title', 'native_conversation_ui',
  'restaurant_option_card', 'conversation_question_history_merge',
  'batch_artifact_order', 'receipt_overlay', 'pending_tool_restore',
  'conversation_event_contract', 'batch_conversation_lifecycle',
  'confirmation_interaction', 'conversation_tool_lifecycle'
)
$casePaths = $caseNames | ForEach-Object { "test/features/conversation/${_}_test.dart" }
& $flutter test --no-pub @casePaths
& $flutter analyze --no-pub lib/features/conversation lib/features/apology test/features/conversation/apology_timeline_order_test.dart test/features/conversation/conversation_message_merge_test.dart
openspec validate align-conversation-sse-interaction-history --type change
openspec validate --all
git diff --check
```

OpenSpec 与 diff 最终回执见交付报告；本 change 通过不等于全仓通过。

## 设备验收步骤（本次未执行）

1. 批准版本的 Flutter 测试包进入道歉，记录完整画面：后台配置 opening 在专用 Consent 之前，两者都可见。
2. 点击“确认使用”：旧卡保留，回答在卡下方，无查询气泡；无音色结果时严格复现五段顺序，仅新卡可点击。
3. 滚动离开旧卡再返回，确认高亮和失活；以文字/语音识别文本重复场景，不漏回显、不重复。
4. 普通 Skill：配置 opening 保留、选项仍有卡内标题；收到真实 committed 后本地交互不跳到未来回复下方。
5. 关闭重开单独录制，与服务端 ledger 对照，不要求未提交本地快照凭空持久化。

尚缺 Flutter 真机同输入画面、真实后端完整事件样本及双端运行证据。未打包、安装或修改后台；设备验收 checkbox 保持未完成。
