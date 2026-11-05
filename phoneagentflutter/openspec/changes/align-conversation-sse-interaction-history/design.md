# Design: 统一 SSE 编排会话的事件、交互与历史投影

## 当前有效范围

现行规则由本 change 的有效 delta 及用户批准的 `task-orchestration-v1` 定义，完整合同入口见仓库 AGENTS。道歉使用专用 Consent 覆盖普通后台欢迎语，旧卡失活且保留，本地与账本按真实身份协调；首页 / 联系人完整快照和任务列表 / 详情跨入口一致性按共享合同验收。

## 历史设计记录（不作为现行规则）

下文全部日期式取舍、实现说明和测试数字保留为追溯材料。其中后台 opening 与 Consent 共存、按旧方案清理本地历史等相反描述已经失效；不能因日期更晚或已勾选就覆盖上面的有效来源，也不能以历史测试签收本轮新竞态。

## 2026-10-20 本地确认覆盖后台欢迎语及就绪文字补齐

用户最新明确撤回后台统一确认文案方案：继续使用 ApologyVoicePolicy.consent；道歉入口只显示本地确认提问，覆盖 entry.opening，普通 Skill 仍使用后台 opening。本节覆盖下文“后台 opening 与 Consent 共存”的历史决定；Java 目录与接口保持原状。确认当前模型的音色成功后，Ready 提示必须同时进入文字列表和语音 prompt，后续 initial-opening 回填只能保留一份，并保持旧卡选中失活及原顺序。

## 2026-10-19 当前分支纠偏

用户本轮要求按已确认的原生画面，在最新 `xiaosy/dev_v1.7.0` 上再次修复道歉交互。该当前指令覆盖下方集成阶段“保留远端道歉 UI”的历史取舍。新会话的配置 opening 必须在 Consent 之前展示，点击后两者继续留在实时历史；旧卡保留选中样式但失活，随后显示独立用户回显和新结果卡。历史恢复仍只从账本重建，不回放本地卡。

当前分支的直接故障是 `_present` 无条件清除全部 `local:apology:` transient，以及 `ConversationPage` 只在消息列表为空时渲染配置 opening。修复限定于道歉选择生命周期与页面投影，模型切换的独立记录和普通选项样式继续保留。

## 2026-10-19 合并优先级更新

用户在本次提交合并时明确功能和 UI 均以最新远端 `origin/codex/dev` 为主。因此本次保留远端道歉流程及选项卡的布局、交互与对应回归，不合入本地 Consent 保留、独立提问气泡和道歉点击回显的替代实现；这些修改完整保留在来源提交 `4bb88d5c` 中。下文相关 UI 决策及旧测试结果属于此前方案，不作为本次集成结果。普通选项提交、active options 和 durable 类型接收沿用远端实现；本地仅有 6 类事实的白名单会拦截远端已支持的 CALL_* 事实，故不接入 committed 接收路径，也不替换原有 superseded 历史过滤集合。同身份事实替换、跨轮排序、恢复投影以及通话结果和计费修复继续合入。

## Context

### 2026-10-20 V66.0.3 对照与连续事实回填回归

用户明确以 `D:/project/aiassistant` 的 `test/v66.0.3`（a0bedb12）为原始行为来源。其 ApologyVoiceCoordinator 在 Checking 只清除 agentOptions，不生成查询 prompt；PureVoiceThreadList 从紧随旧卡的 isUserActionEcho 恢复选中项，禁用与高亮分开处理。不得用较早的 D:/aiassistant/chaken-aiassistant-app 代替该来源。

本轮验证必须包含真实 ConversationController 的连续回放：本地确认及模型选择 → initial-opening 提问/选择/就绪事实逐条到达 → 首次用户事实 → 最终响应及 committed。初始本地交互先于 initial-opening 中的就绪提示；同角色同文案的替换只允许限定在对应初始开场事实内，不能跨任务轮次去重。Checking 不保留可由语音宿主延迟播报的 prompt。原始截图只能证明正确样例，自动回放不代替手机验收。

现场证据来自 `D:\project\aiassistant\android` 的道歉会话和当前 Flutter 代码。Android 的 `ApologyVoiceCoordinator.onOption()` 会停止播报、追加 `isUserActionEcho` 的用户步骤、清空当前 options 引用，但不删除旧 `clarificationSteps`；后续 `present()` 追加新的 assistant prompt，`activeShowOptionsStepIndex` 只让最新有效卡可点击。`AssistantConversationRestoreUiStateReducer` 从 durable timeline 恢复步骤并清除本地 options，说明本地开场白和点击回显不是服务端账本事实。

Flutter 的 `AgentEventKind` 定义了 `text`、`thinking`、`signal`、`finalResponse`、`committed`、`error`、`done`、`toolStart`、`toolComplete` 等实时类别；`LedgerEvent.type` 目前承载 `USER_TURN_ACCEPTED`、`ASSISTANT_TURN_COMMITTED`、`TOOL_REQUESTED`、`TOOL_RESULT_RECORDED` 等 durable 类型。`ConversationMessageStore` 明确维护 facts 和 transient messages，`ConversationRestoreFlow` 恢复 ledger 后清空本地消息再投影。当前 `apology_conversation_binding.dart` 创建 transient 本地 prompt 并维护 `activeOptionsId`，但 `choose()` 没有公共的用户操作回显路径；这会使道歉和已有普通 call confirmation 的反馈规则分叉。

## Goals

- 固定四层对象的职责和可转换边界：transport event、业务子类型、durable ledger fact、presentation message。
- 让所有 Skill 共享选项卡 active/失活、用户回显、原位更新、去重和历史恢复规则。
- 明确开场白、Consent、工具轨迹和临时覆盖何时保留、何时收起、何时在恢复时清除。
- 以真实身份合并实时与历史副本，保留跨 command/turn/tool 的独立消息。
- 保持现有普通通话确认、批确认、权限和文件卡的既有身份兼容性。

## Non-Goals

- 不重新设计 SSE wire 协议，不新增供应商事件，不改变服务端 ledger schema。
- 不把道歉 Skill 变成独立的事件通道；它只用于验收公共规则。
- 不在本变更中修改原生 Android；原生代码只作为行为证据和对照实现。
- 不把 transient 用户点击直接写入 durable ledger，也不通过历史恢复重播播报。

## Decisions

### 1. 事件分类矩阵

| 层 | 当前对象 | 典型值 | 是否 durable | 责任 |
| --- | --- | --- | --- | --- |
| 实时传输 | `AgentEventKind` | `thinking`、`signal`、`toolStart`、`finalResponse`、`error`、`done` | 否 | 描述 SSE 生命周期和到达时机 |
| 业务子类型 | `eventName` / `payload.type` | `ASK_USER`、`MAKE_CALL_REQUEST`、`BATCH_CALL_RESULT` | 仅随其所属事实决定 | 决定交互/结果语义，不替代 transport kind |
| 服务端事实 | `LedgerEvent.type` | `USER_TURN_ACCEPTED`、`ASSISTANT_TURN_COMMITTED`、`TOOL_REQUESTED`、`TOOL_RESULT_RECORDED`、运行终态 | 是 | 恢复、审计和权威时间线 |
| 展示投影 | `ConversationMessage` | 正文、选项卡、确认卡、思考、回执 | 默认否 | 将 facts 与 live overlay 合成为 UI |

`committed` 只有在携带合法 `LedgerEvent` 时才进入 facts；`done`、`heartbeat`、思考完成和工具进度不自动生成 ledger fact。未知值进入诊断/失败路径，不猜测为业务成功。

### 2. 身份和去重优先级

合并键按以下顺序取可用字段：sessionId + eventId/sequence（账本事实）、toolCallId 或 pendingToolCallId、callAttemptId、commandId/turn、最后才是同轮且双方均无身份时的受限内容指纹。文字相同不能跨 command/turn 或跨工具合并；明确不同身份永不合并。更新使用首次建立的时间线位置，迟到的同身份事实原位更新。

### 3. 选项卡状态机与用户回显

每个 options/confirmation message 保留稳定 message id，并记录其 command/turn 和 tool identity。选择动作执行四步：停止当前播报资格；追加 transient 的 user-action echo；清除旧 `activeOptionsId`；等待/接收后续 assistant prompt 后将 active 指向新卡。旧卡仍在 `messages` 时间线中，渲染层以 active identity 判断 enabled，因而只失去操作权而不消失。没有后续卡时，旧卡仍是历史快照，不重新激活。

普通 Skill、道歉 Skill、通话确认和批确认都调用同一投影路径；Skill-specific controller 只负责提供业务 payload 和动作，不定义另一套卡片生命周期。

### 4. 开场白和临时层的消失规则

当前实时会话中，配置 opening/Consent 在用户选择、首次提交和 done 后仍保留；选项只失去操作资格。不得把它们当作进度清理。所有配置了 opening 的 Skill（包括道歉）先展示后台配置开场；道歉再展示本地 Consent 提问与选项。进度型 thinking/tool/batch overlay 按对应生命周期处理，不据此删除原提问或用户回答。

2026-10-19 18:05 用户确认截图和 XML（D:/Caches/apology-correct-20261019_180516.*）支持：原提问 → 旧卡（选中高亮、两项 disabled）→ 用户确认使用 → 无音色结果 → 新卡（enabled）。原生 AssistantSessionClarificationStepHandler 按列表追加；Flutter 本地回答必须使用独立动作身份，不复用被回答的提问 commandId，否则 merge 会按普通用户新轮规则把回答移到提问前。文本/语音识别成选项也走相同选择入口。原生 queryVoices 仅更新 Checking 和清除 active options，不追加查询正文；Flutter 查询状态也不得写入对话消息。原生 SingleFlowNativeEntryEffects 的专用入口 return 在 peekOpening 之前，只说明旧原生入口分支；用户 2026-10-19 明确要求 Flutter 道歉保留并使用后台配置开场，该要求覆盖先前“道歉只显示 Consent”的推断。

历史恢复先清空 transient message，再用 session 对应 ledger 投影；因此 opening、Consent、未提交 user-action echo 和上次进程的工具进度都不重播。若 ledger 有未完成的 `TOOL_REQUESTED`，只恢复其 durable pending identity，不恢复本地点击状态。

原生 `assistant_pure_voice/PureVoiceThreadList.kt:345` 明确区分道歉与普通 options：道歉单独显示提问气泡并传入 `showTitle=false`，普通卡继续显示内部标题。Flutter 只对本地道歉消息应用此布局。道歉选择索引保存在本地消息快照，避免文本选择或组件重建后丢失高亮；该字段不进入 wire 或 ledger，不代表跨重启持久化。

### 5. 实时/恢复共用 projector

将展示归一化集中在 conversation domain 的 projector/merge 层：SSE handler 只把 transport event 解码为事实或 overlay，restore 只提供 ledger snapshot，二者都调用同一身份、排序、替换和 active 计算。`ConversationMessageStore.facts` 继续作为事实缓存；`messages` 只承载 transient 或已投影 UI 快照，不能反向修改服务端 facts。

已复现的补充缺陷：merge 从 durable 列表开始，未匹配 command 的本地开场和选择被追加到后续任务事实之后。修复在临时列表中查找后续 command 对应的 durable 事实，把无同轮位置的 transient 插在它之前；没有该位置才追加。此规则用于公共合并，不限定 skill，不改变 durable 之间的顺序。分别覆盖首次本地开场和已有上一轮事实时的交互。

### 6. 终态事件处理

`toolStart`/`toolComplete` 只管理对应工具轨迹；`signal` 的业务类型决定是否显示 options、question、permission 或 tool card；`finalResponse` 产生当前 turn 的临时/候选正文，匹配的 committed 负责权威化；`error` 结束当前 run 并保留可诊断失败；`done` 只结束传输，不制造正文、opening 或确认。`heartbeat` 只刷新存活状态。

## Risks / Trade-offs

- 引入统一身份键后，缺少 tool/command 身份的旧 SSE 可能无法安全合并；宁可保留重复卡并记录诊断，也不按文字跨轮删除。
- transient 用户回显会在实时会话中增加一条消息，但这是 Android 已验证的时间线语义；恢复时清除可避免把本地意图当成事实。
- 旧 call confirmation、batch confirmation 和 apology 可能已有局部去重逻辑，迁移时需要保持兼容并删除重复归一化，避免双重替换。
- `finalResponse` 与 `ASSISTANT_TURN_COMMITTED` 的到达顺序可能变化；必须用 content fingerprint 和身份合并，不能假定固定顺序。

## Migration Plan

1. 先落地事件/类型映射和身份契约，补充纯 domain 测试，不改变 UI。
2. 把 transient overlay、用户操作 echo、active options 和同身份原位更新收敛到公共 projector；普通 call confirmation 与 apology 接入同一路径。
3. 更新 restore/merge，使 transient 清理、durable 重建和 pending identity 恢复与 live projector 共用规则。
4. 增加跨 Skill、跨 turn、同名不同工具、迟到 committed、错误/done 和重启恢复的定向测试；完成后再运行 `openspec validate --all` 与受影响 Flutter 验证。
5. 验收通过前不归档 change；实施过程按项目规则同步根 `tasks.md` 和 `docs/codex_issue_log.md`。

## Open Questions

本次实现未改变 SSE wire 契约；下列问题缺少真实后端 fixture，因此按“待确认”保留，不能当作已验证事实。实现侧按当前 decoder、ledger projector 和已有测试采取保守行为。

- 当前后端对本地选项点击是否总会产生 `USER_TURN_ACCEPTED`，还是部分 Skill 只产生工具请求；实施前需用真实 SSE fixture 或接口契约确认。
- 所有 `payload.type` 的业务子类型是否已有稳定白名单，尤其是 `signal`、`finalResponse` 与 `toolCard` 的重叠场景；若没有，需要先建立解码表。
- `finalResponse` 与 committed 正文冲突时，服务端哪一个字段是权威内容，需用现有历史/实时 fixture 验证。
- opening 是否存在服务端 durable 版本；当前 Android/Flutter 证据只支持本地 transient opening，不能据此扩大为所有入口的永久规则。
