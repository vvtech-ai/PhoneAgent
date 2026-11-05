## Context

基线为 origin/codex/dev 的 9d35f0eb。前次 preserve-interrupted-batch-execution-display 通过 ConversationBatchActivity 保持 ready 阶段的运行展示，但未修改输入或停止准入。本次用户明确要求核对中的底部仍为可执行停止按钮。源码机制已确认；未获得现场事件链，不宣称现场根因已验收。

## Decisions

- ConversationStopBinding.available 将 ready 且 BatchProgressTracker.active 纳入原准入表达式，保留 awaitingAggregate 排除项。该 tracker 同时产生 ConversationBatchActivity 消费的 transient receipt；绑定使用同一事实 owner，不反向依赖 widget 投影，不另建状态机。
- ConversationPage / ConversationComposer 沿原 onStop 接线选择按钮，点击仍经 Controller.stop → ConversationStopCoordinator → 原 stopBatch 端口，确认与批次身份校验不变。
- accepted / busy 及 awaitingSettlement 保持禁用；观察耗尽会清除 tracker 活跃状态，不能把静态 VERIFYING 回执重新变成首次停止入口；可信终态沿既有清理恢复控件。
- 本微批仅一个手写生产文件。该文件既有停止生命周期职责不变，不为小型门禁修复拆分第二套流程。类似需求继续使用 tracker 与停止协调器扩展点。

## Validation

先在真实 Page / Controller / VoiceHost 回放 inactive / paused、事件流错误、ready 核对、底部点击、stopBatch 单次、三点禁用和终态恢复，证明旧代码失败；再最小修复并跑受影响停止、前台恢复、批次、思考和语音邻居及静态检查。Android / iOS 用同一 Dart 路径与两种平台主题，不用此证据替代真机、真实后端和实际音频。
