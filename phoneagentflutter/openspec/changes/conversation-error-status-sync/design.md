## Context

行为依据固定 v65 4c781e3：TaskConversationExitResetController、TaskErrorRecoveryConfirmController、TaskErrorRecoveryPendingSyncUseCase、TaskConversationListLoadUseCase、AgentStreamSimpleResponseStatePolicy。后端 ConversationInterruptTransitionPolicy 将两个 reason 映射为 RunFailed / ConversationResumed，ApplicationService 对已 COMPLETED 的旧异常请求保留终态。

## Goals / Non-Goals

Goals：补完整的异常退出→待同步→任务列表→恢复业务确认链路，跨账号和进程重建不串数据。

Non-Goals：不新增暂停任务按钮、不挂断电话、不自动重试用户需求/外呼；不把 pending recovered 直接显示为 RUNNING；不迁移旧未绑定账号的 pending 集合。

## Decisions

1. domain/TaskErrorRecoveryPolicy 仅拥有“尚未恢复错误”事实，不复制 UI 状态。restore 读取详情状态；普通流失败标记错误；有效 signal/final 的八种业务 type 清除并请求 recovered；CALL_RESULT/BATCH_CALL_RESULT 只清除；delta/done/历史工具不触发恢复请求。流 generation 检查由现有控制器负责。
2. domain/TaskErrorStatusSync 拥有账号租约内待发送队列。命令按 session 最新覆盖，以随机 commandId 区分同 reason 的不同发生次序；重复同步 single-flight，有界一轮；失败不自旋。存储成功后才 POST；成功匹配当前 commandId 才删除。新命令在旧请求期间出现，不由旧回执清除。
3. data 安全存储按 environment/API/account 分槽并带 schema；逐次 read-modify-write 串行，损坏/未知格式不当空队列覆盖。只保存 ID/reason，无用户文字/token。API 严格限制路径 ID 与两个 reason，校验响应 session/status；复用 AccountApi 登录 epoch 和一次鉴权刷新。
4. 对话控制器仅调用 restore/failure/accept/close 钩子；对话通用提交或通话边界不改变。若超过 500 行，先按职责提取，或有证据的单一编排器例外记录；不得机械删空行。
5. 任务列表加载先尝试同步，再叠加仍 pending exit 的异常状态。recovered 不乐观升级。成功响应（包括 COMPLETED）权威；同 session 更晚退出优先。网络恢复另以共享触发器及薄平台观察接线，不轮询后台。
6. 网络事件复用已有 NetworkAvailabilityChannel，额外 EventChannel 仅发送 available/unavailable/unknown：Android 默认网络回调读取 validated capability，iOS NWPathMonitor。Dart 对连续 available 去重，先恢复账号队列再同步；监听期间再次断开/重连合并为下一次有界尝试。列表接收“已做状态补偿”的刷新事件并跳过重复 beforeRefresh，不因一个网络回调连续补发同一失败 POST。无监听/账号退出时注销，晚到平台事件不发到新监听。Web/不支持的平台默认无真实网络证据，演练显式注入合成事件。
7. 已登录 ShellRoute 首次挂载即建立同一账号监听，不等待进入对话或任务页，保证进程重建停在首页时也能尝试恢复持久队列。对话/任务页只复用同一 Provider，登录变化仍使旧租约失效；不把任务列表 GET 强制搬到首页。

## Risks / Trade-offs

- 断电发生在持久化前：无法保证异步写入完成；持久化失败保留内存并记录失败，不能谎报 durable。真机杀进程窗口需集中验收。
- 请求成功后本地删除失败：同一命令身份重试；不宣称跨后端版本 exactly-once。
- 旧 Android pending 未绑定账号：不直接重放，保留旧数据且列入升级风险，后续只在有归属证据时讨论导入。
- 底层网络可用不代表后台可用：一次有界重试，失败保持 pending。账号退出停止续发，旧已发请求不可能撤回服务器。

## Migration Plan

先规格和纯策略/持久化/API，后正式 controller/provider/任务列表接线与合成连续流程；平台监听和真实断网恢复按单独微批验证。无依赖升级或后端部署。可回滚本 change；新 key 不影响现有历史与登录。

## Open Questions

无产品决策阻塞；旧未绑定 pending 的升级处理及真实断网/杀进程结果在验收报告中明确保留。
