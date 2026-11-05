# 当前原生接口与业务差异台账

## 固定来源与适用范围
Flutter 92ad00fe / aiassistant_app a87c95b / AIAssistant1 a0bedb12a；当前工作区codex/dev_zys本地实施。用户本轮批准新增有效业务补齐，覆盖此前仅非任务修复的限制。参考仓库与后端只读，保留签名与账号隔离。接口声明清单见interface_inventory.tsv；声明存在不等于正式入口启用，不把旧runtime入口/未使用upload接口当新增业务。

## 核对与处理
| 能力 | Flutter依据（相对lib） | 本轮处理 |
|---|---|---|
| SDK/Agent路由、网关前缀与C1 | core/network/service_routes.dart、signing | 保留，不切回原生保留的旧v2类 |
| Bearer、刷新单飞、账号epoch | core/network/account_api.dart | 保留；新增请求沿用相同所有权 |
| 普通HTTP、SSE及耗时请求 | core/network/account_transport_policy.dart | 普通90秒读写，连接20秒；SSE握手90秒有界、流内不限空闲，取消令牌终止 |
| HTTP业务错误与SSE拒绝 | core/network/account_error_mapping.dart、account_transport_policy.dart | 保留调用方白名单；握手补模型错误固定码映射，不显示任意message |
| 批量进度接口 | features/conversation/data/stopping/api_conversation_stop_repository.dart | 新增GET batch/{batchId}/progress，session/batch/account作用域校验 |
| 空文案逐路事实 | features/conversation/domain/receipts/batch_progress_tracker.dart | 不依赖text非空；现有卡片接收事实，不新增聊天或TTS |
| phase、版本、重拨顺序 | features/conversation/domain/receipts/batch_progress_order.dart | 物理状态不冒充业务结果，版本与attempt防回退 |
| 停止确认与部分失败 | features/conversation/domain/stopping/conversation_stop_coordinator.dart | 保留确认、显式重试；受理后保留流和结果 |
| 活动批次新进程恢复 | features/conversation/data/history/api_conversation_history_repository.dart、conversation_stop_binding.dart | 可选activeBatchId/activeCommandId保留，投影后只读恢复、不重发；已有终态优先 |
| 停止/断流只读恢复 | features/conversation/domain/stopping/batch_progress_recovery.dart | 5秒起步、12轮后60秒退避，旧owner/命令失效停读；仅持久回执收敛完成 |
| 挂断未知结果 | features/calls/presentation/controller/call_session_controller.dart | POST失败只读核实；ENDING/CANCELLING锁住重复操作；NOT_FOUND不作为挂断证明 |
| 单路物理结束和业务结果 | features/calls/domain/call_session.dart、conversation_call_controller.dart | 保留现有awaitingOutcome、回执同步和账号/attempt校验；结束后慢速核实 |
| 旧确认卡与新交互 | features/conversation/presentation/controller/conversation_signal_flow.dart | 不同pending身份取消原延迟准备，旧卡只保留历史展示 |
| 恢复任务模型选择 | features/conversation/presentation/pages/conversation_route.dart、app/call_admission_providers.dart | 已使用当前catalog.current；保留历史确认快照，不回退历史模型 |
| 语音短按停止/300ms长按输入 | features/conversation/presentation/widgets/speech_stop_hold_control.dart | 复用NativeTaskSubmitButton；任务/通话占用不启动ASR，释放/取消成对 |
| 零音频合成 | features/conversation/data/voice/task_tts_session.dart | 新连接最多重试一次，第二次无音频失败，旧连接回调隔离 |
| 多句播报失败 | features/conversation/data/voice/conversation_tts_stream.dart | 已有failures累计，保留早期句子失败，不以后续成功覆盖 |
| 隐藏页及晚到最终字幕 | features/calls/presentation/controller/call_session_controller.dart | 保留当前attempt字幕，无页面可见门禁；物理终态后当前观察尚在时可合并最终段 |
| 批次总结播报 | features/conversation/domain/voice/committed_reply_narration.dart | tool_terminal带batch结果可关联同sequence文本，只播一次；只读恢复有明确批次marker |
| outcome unclear与取消事件 | features/conversation/data/stream/agent_event_decoder.dart | 补task_outcome_unclear；task_cancelled保留command身份、取消本地准备及晚到交互，不重放 |
| 任务产物下载鉴权/类型/大小 | features/conversation/data/artifacts/api_task_artifact_repository.dart | 既有同源有界下载保留；补CSV伪装JSON/HTML内容拒绝，不写文件 |
| 模板和回执查看 | features/conversation/presentation/widgets/task_artifact_card.dart | 保存后现有按钮可查看；Android按保存MIME打开，不固定CSV |
| 文件删除后的状态 | features/conversation/presentation/controller/task_artifact_download_controller.dart | 双平台exists端口；返回前台/打开前只读检查，失效后允许显式重下载 |
| 克隆modelId、动态价格、预期价格头 | features/voice_clone/data/api_clone_verification_repository.dart、api_clone_candidate_repository.dart | 前轮已同步，保留 |
| 克隆准入刷新、失败重入、晚到READY | features/voice_clone、features/call_models | sync-non-task-native-repairs、fix-model-scoped-clone-voice-selection已同步，保留 |
| 模型级系统/克隆选择 | features/call_models/data/api_call_model_repository.dart、api_clone_voice_repository.dart | 已按公开modelId activate/deactivate/重读，保留 |
| 翻译创建兼容、服务身份、节点/语言/跨境确认 | features/translation、features/dialer | 既有active changes已同步，保留；独立HTTP30秒不随账号请求变为90秒 |
| 积分usage-session与授权版本 | features/translation/data/sip/api_domestic_points_repository.dart | 既有创建/连接/心跳/终态/authorize-next与版本校验保留 |
| 评价资格、回执锚点、幂等提交 | features/feedback/data/api_task_rating_repository.dart | 已有CALL/BATCH锚点检查与真实clientVersion，保留 |
| 联系人拼音候选 | features/contacts/domain/contact_name_matcher.dart | 已有pinyin_fallback即使一项也MULTIPLE_CANDIDATES，不自动外呼，保留 |
| 任务列表分页、置顶/已读/删除及恢复 | features/tasks/data/api_task_repository.dart、api_task_detail_repository.dart | 既有统一列表与恢复原session，保留 |
| 记忆、邀请、身份、设置、录音与更新 | features/memory、invite、identity、settings、conversation、app_update | 已迁移正式入口保留；本轮未发现上述新增修复之外需新增页面的依据，完整回归覆盖 |

## UI与平台依据
保留Flutter主题、布局、字体、颜色及共用控件。AIAssistant1/android的PureVoiceInputDockControls.kt、PureVoiceArtifactCard.kt作为必要按钮/交互参考；新增业务按aiassistant_app有效逻辑补齐，仅保存按钮文案改“查看文件”，进度状态文案随事实变化。两端使用同一Dart规则；文件系统权限/安全作用域由原生薄适配处理。

## 不等同于验收的证据
接口清单与静态核对不证明现网服务已经部署对应路径。双端编译不等于设备运行；实际媒体可听、ASR、文件选择器/预览、服务器停止与外呼/计费、生产升级均需设备或已授权联调验收。无真实请求、短信、认证、外呼、收费，不提交推送、不归档。
