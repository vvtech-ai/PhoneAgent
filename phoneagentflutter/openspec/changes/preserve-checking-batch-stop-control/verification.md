# 验证与问题记录

## 基线与机制

独立检出基于 9d35f0eb8e643ddf31b77519b5fc1f10e8fb9244（本次 fetch 后最新 origin/codex/dev），未修改其他 Flutter 检出、忽略的私有输入、交付目录、平台或依赖。pubspec.lock 与前次 168be837 相同，使用既有匹配的 package_config 和固定 Flutter 3.32.0 / Dart 3.8.0，全部 Flutter 命令带 --no-pub。

源码机制为断流保留 BatchProgressTracker.active 并进入 ready，而 ConversationStopBinding.available 仅允许 sending 或已有停止恢复状态。页面因此收不到 onStop，显示不可用麦克风。仅调整该绑定的门禁；Controller、Page、Composer、Coordinator 与真实停止端口均沿原路径。未取得现场 APK 的完整事件链，不将机制确认称为真机验收。

## RED / GREEN

- RED：在修改生产代码前，增强的 interrupted_batch_execution_ui_test 四项均因 ready 核对中找不到 stop-current-processing 失败（Android / iOS 各两项）。
- 最小生产修复：仅在原 available 表达式增加 ready && batch.active，保留 awaitingAggregate 排除、busy、awaitingSettlement 和 retryBatchId。
- 补强汇总断言时发现原测试端口把逐路 SUCCESS 与 phase=ENDED 同时传入；当前 BatchProgressOrder 仅无 phase 的业务终态或 FAILED phase 标记逐路完成。将合成端口按既有业务终态形状去除该 phase，使 awaitingAggregate 测试真实覆盖原门禁；未修改生产状态规则或放宽断言。
- GREEN：最终同文件 8/8。双端各覆盖当前页前后台 / 路由中断、网络断流后核对、进度恢复执行、逐路结果齐 / 等汇总和终态；核对与恢复执行两种 ready 状态均通过底部真实点击，同 session / batch 仅 stopBatch 一次、确认一次，Agent.start 始终一次。请求在途和受理后按钮禁用并显示三点，重复 UI 点击与直接 controller 调用不重发；临时卡 element 保持，可信终态后消失并恢复麦克风与输入。停止进度没有 TTS。五分钟为测试虚拟时间，耗尽后静态 VERIFYING 不重新开放停止，也不重新执行。

## 最终定向验证

命令前缀为 D:/tools/flutter-3.32.0/bin/flutter.bat。

- `test --no-pub --reporter expanded`，17 文件 **135/135 通过**：interrupted_batch_execution_ui、stop_reentry_recovery、stop_transient_header_status、conversation_stop_coordinator、conversation_stop_late_event、task_160_stop、stop_button_dots、batch_foreground_resume、batch_progress_recovery、batch_progress_tracker、batch_progress_refresh、batch_conversation_lifecycle、tts_composer_control、v66_conversation_composer、voice/voice_input_page、voice/conversation_pause_page、voice/conversation_speech_controller。
- `analyze --no-pub` 检查 stop binding、controller、page、composer、batch activity、voice host 和本次回放，共 7 文件，No issues found。
- `openspec validate preserve-checking-batch-stop-control --strict` 通过。
- 两个变更 Dart 文件格式检查、严格 UTF-8 读回与中文检查、`git diff --check` 通过。其他文件中的既有日志和真实账号不复制进本变更。

## 范围和未验边界

仅一个手写生产文件，符合三文件微批门禁。未改变共享任务编排合同，因此不修改三端共同 AGENTS 区域。知识库补充停止绑定与原批次事实的职责关系；当前问题、失败和验证证据保存在本变更，不归档尚无真机验收的 change。

未打包、安装、运行真实后端、真实来电或外呼，未验证实际可听音频；Android / iOS 一致性为共用 Dart 与两套主题的受控回放证据。未声称全仓测试或原生构建通过。提交、推送与独立复核由父任务协调。
