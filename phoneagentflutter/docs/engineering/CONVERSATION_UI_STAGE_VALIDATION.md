# 统一页 UI 与工具展示阶段验证（2026-09-16）

## 实现与来源

- `conversation_header.dart` / `conversation_composer.dart`：固定设计运行态快照中的 Header、阶段条、状态区、输入 dock；使用原 SVG。标题、按钮、间距有契约断言。
- `conversation_message_tile.dart`：共享消息/只读工具展示组件，依据固定 memory/css/style.css 750–769 的用户/AI 气泡和工具卡规则。不是第二套 HTML 页面；无直接网络访问。
- `conversation_tool_card.dart`：v65 客户端显示载荷的类型化解析、条件格式化、身份键、完成后保留规则。
- `ConversationController`：同轮工具原位更新，不覆盖普通 AI 文本；done/断流/错误收起普通工具，交互工具被同 ID 的持久消息替代；退出/恢复清理临时卡。
- 源依据：固定 v65 的 AgentStreamSseEventParser、AgentStreamToolStepReducer、PureVoiceStepPresentationPolicy、TimelineApiMapper。普通工具参数/结果在历史响应中被清除，因此不补造历史工具卡。

## 验证证据

- `flutter analyze`：通过。
- `flutter test`：181 项通过；新增条件解析、去重、顺序、完成/中断/退出/恢复、候选点击、消息宽度/颜色和可访问语义测试。
- Web Debug 和 Android Debug 构建通过；Node 代理测试、2 项 Dart Chrome 流适配测试、15 项 Web 相关 widget/controller 回归和 15 项 OpenSpec 校验通过。
- Web 普通入口刷新保持现有登录；真实任务列表恢复先前安全文字会话，10 条消息可读；切换文字后更新后的蓝色用户气泡、白色 AI 气泡和底部输入区实际渲染正常。
- Android 本批普通 Debug APK 覆盖安装成功、登录保留、动态首页正常，从任务列表恢复同一安全测试会话；UI hierarchy 与 `.local/android-conversation-ui-stage.png` 确认新版 Header/气泡/默认语音 dock。截图未进 Git，不以恢复文字证明真实语音已完成。
- 新工具卡的确定性生命周期与布局证据为合成测试，不声称真实服务已触发每一种工具。
- 8ae1fcb 的 iOS 阶段验证已补录至 WEB_VALIDATION.md：构建/签名/安装/调试器自动启动到新版登录页。该 iOS 证据不包含本次未提交 UI 代码，也不包含登录后流程。

## 仍未完成

- 普通气泡/工具卡当前按固定 CSS 实现，尚未完成对应设计运行态全状态视觉对照。浏览器阻止本地 file 页面，不绕过；等待可访问设计地址，已有参数/缓存截图继续用于已覆盖区域。
- 阶段条已接入现有文字/候选/请求/回执投影（下方当前阶段批次）；完整通话页及语音状态仍待协调器接入，不能将展示阶段当完整通话状态机。
- 附件、单路确认/批量确认、完整回执、评分、真实音频与通话编排还需后续实现。只读工具卡不含新增执行按钮，不发起真实外呼。
- 字体、系统键盘和安全区还需双端全页面最终核对；自动布局通过不代表像素完全一致。

## 当前阶段接线批次（2026-09-16）

- 固定 v65 `SingleFlowPolicy.kt:sfRealRestaurantStage` 及 `SingleFlowStagePolicyTest.kt`：统一页不使用首页规则，结果优先于执行/确认，继续新一轮时不能被旧结果锁定。`MAKE_CALL_REQUEST` 对应执行阶段，不等于实际已拨通；现有未拨号提示保留。
- `domain/conversation_progress.dart` 纯 Dart 投影，`ConversationState.progress` 只读派生；普通/窄高度两处 Header 使用同一值。阶段不持有新任务状态，不发请求，不修改输入门禁；当前项补 selected 和“当前阶段”无障碍语义。非当前阶段沿用已缓存样式，本批没有臆造完成态新样式。
- 14 项新增回归覆盖四阶段、单路/批量失败及取消不等于业务成功、旧结果后的新轮次、当前结果先于 done、历史 CLOSED、真实 Controller 到页面连续过程、恢复回执零命令、720/268 高度滚动和语义。全部合成数据，无真实通话、计费、短信。
- `flutter test` 305 项、`flutter analyze` 无问题、`flutter build web --debug` 成功、`openspec validate --all` 17 项通过。
- 普通 Web 热重启/刷新后登录保持；实际进入订餐厅统一页，看到“当前阶段：任务下达”，默认语音可切换为文字且仍同一页。未发送新的真实对话。其余阶段本批通过共享 widget/controller 测试验证，不冒充线上真实外呼截图。
- 本批无原生改动/依赖；未重装 Android/iOS。既有安装策略拒绝不绕过；设备最近安装版本与未完成项按 `MIGRATION_ACCEPTANCE.md`/`CONTACTS_VALIDATION.md` 保持原记录。
- 仍缺未接入媒体的 ASR/TTS/实际通话页状态输入，以及全部动态设计视觉对照；这些不能用当前 4 个阶段的测试代替。

## 人工验收边界

本批不需要短信/麦克风/电话人工配合。后续真实媒体与通话按总验收清单集中验证；不要为了重复展示清除 Web/Android 登录数据。本阶段不归档、不宣称迁移完成。

## 后续确认卡批次

- 实现：`domain/call_confirmation.dart` 共用实时/持久模型，过滤内部摘要字段；`ConversationMessages` 持久投影/工具拒绝移除；`conversation_message_merge.dart` 防止确认卡、工具卡、普通回答互相覆盖；`call_confirmation_card.dart` 只读共享 UI。批量此处仅是 makeBatchCalls 联系人摘要，不是 confirmBatchTask 大任务快照卡。
- 自动回归：192 项 Flutter 测试通过、analyze 无问题、普通主入口 Web build 通过。包括实时→持久去重、拒绝/序号缺口恢复移除、恢复不提交命令、窄屏大字号、内部字段隐藏。
- 普通主入口 Android Debug 构建、15 项 OpenSpec 校验通过；本确认卡批次未重复真机安装，最近 Android 布局真机证据是上一批 1c670e8，不混淆验证版本。
- 浏览器：独立离线预览实际显示单路目标/电话/目的/人数/时间，多路联系人摘要无电话行，工具条件/结果；文字切换生效。首帧 Web 中文字体异步加载曾出现缺字，加载完成后截图确认完整；不是正式接口或全设计状态验收。
- 本批未发送 confirm_call/电话请求，当前主入口仍明确提示“通话执行能力尚未接入，当前仅显示任务信息，未拨号”。计费提示、准入、自动执行、通话页与回执仍待实现，不以确认展示替代这些能力。

### 可重复离线预览

```powershell
E:/dev/flutter/bin/flutter.bat run -d web-server --target=tool/previews/conversation_preview.dart --web-hostname=127.0.0.1 --web-port=8091
```

打开 `http://127.0.0.1:8091` → “打开统一页确认卡样例”。顶部始终显示 MOCK，不读取会话存储、不连接后端；发送只修改临时列表，模型固定。预览入口是验证工具，不进入正式 App 导航，Release 明确拒绝运行。验证后本次预览服务/标签已关闭，普通 8080 调试入口和登录状态保留。

## 单路回执数据与可读文本批次

- `domain/receipts/`：同 session + callAttemptId 聚合，首次请求锚定顺序；终态、语义 outcome、结构字段、逐字稿和计费摘要逐步更新。无 attempt 的旧终态独立归属，不按 taskId 合并不同尝试。
- `call_receipt_status.dart`：固定 v65 语义优先规则，COMPLETED/断流不等于业务完成；显式成功、失败、取消、未知和运行态分开，技术异常与业务失败不混用。
- `call_dialogue.dart`：双方角色及全/半角冒号解析，保留同句重复，不将总结/未知说话者伪造成对话。`ReceiptBilling` 保留返回的费率/时长/积分，缺失或非法数值不补零。
- 实时 final 与历史共用模型；持久回执按身份替换临时卡，普通回答仍保留；显式 attempt 不一致时禁止按 callId 兜底合并。
- 专用转写卡/结果卡还未完成设计运行态采集。根据 Design2App 门禁暂不生成新布局；`call_receipt_text.dart` 仅把已知数据送进现有消息组件作为临时可读呈现，不是最终 UI 还原。不得把此批当完整单路/批量结果验收。

### 验证

- `flutter analyze` 无问题，208 项 Flutter tests 通过；正常 `lib/main.dart` Web Debug 与 Android Debug 构建通过，15 项 OpenSpec 校验通过。
- 独立预览新增“打开单路回执文本样例”，固定成功/失败/未确认三条合成结果，顶部 MOCK；浏览器实际核对三种状态、人数、双方转写、12 秒、费率、扣除 5、余额 12,345。滚动可读，关闭后回到预览入口已观察确认。样例不连接网络，不是实际扣费或外呼。
- 本批 Android 普通入口 APK `adb install -r` 成功，启动后 UI hierarchy 为已登录动态首页/Seeduplex/六个动态入口；原 App 未覆盖，未清数据、未重发短信。不把首页启动证据算成回执真机全流程。
- 本批 iOS 未再次安装；最近 iOS 仍是 8ae1fcb 的登录页阶段证据。完整结果卡、录音、赞踩/条件评分、实际单路与多路编排继续待办。

## 批量快照后续批次

- `batch_receipt.dart` / `batch_receipt_projector.dart`：读取直接及嵌套 batchCallResult，以 session+batchId 原位更新完整快照；无 ID 事件隔离。保留每项状态、呼叫身份、转写、结构字段和多次结算。零尝试且积分不足的批次不伪装执行。
- `receipt_message_mapper.dart` 统一实时单路/批量到消息的映射，Controller 不累积新解析分支；`receipt_overlay.dart` 保留同身份实时终态直到持久终态到达。历史本身不被重写。
- 后端批量失败也通过 task_completed 发送；自动测试覆盖该真实路径，task_failed 没有变更。逐项 call_status_changed 进度编排和活动流退出例外仍待后续。
- 当前可读文本显示 3/3 已产生结果，同时分别列出 1 路完成、2 路需关注；不把收到结果等同于成功，不新增拨号按钮/通话页路由。
- 221 测试、analyze、正常 Web/Android 构建与 15 项 OpenSpec 通过；浏览器实际查看上述 MOCK 混合结果和各项中文状态，未触发电话/计费/账号接口。动态卡的正式运行态设计仍待接入，不以文本布局充当最终卡片。
- 独立预览入口按钮现为“打开单路/批量回执文本样例”。本次预览服务和标签使用后关闭，普通 Web 保留。
- 上述单路阶段的 iOS 同步已追加完成到 121015a（构建、签名、安装、调试启动），详见 WEB_VALIDATION.md；不能把该版本当成本次批量增量的设备证据。
