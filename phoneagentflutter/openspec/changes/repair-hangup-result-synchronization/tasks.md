## 1. 证据与契约确认

- [x] 1.1 确认 23772、23773、23678 对应的后台环境、结果/SSE 服务、任务历史/积分服务和通话运行态服务；用 sessionId、taskId、callAttemptId 与时间窗口完成一次 API 日志读回，并记录结果写入、SSE/回执和客户端读取的顺序。
- [x] 1.2 将后台日志中已确认的业务失败、积分不足、网络异常和完成状态映射到现有客户端结果模型；若日志仍不可得，保留 `unconfirmed` 分支并在验收记录中列出缺失字段，不修改后端协议。
- [x] 1.3 复核 `ConversationCallController`、`CallSessionSnapshot`、`ConversationOutcomeFlow`、`detachedBatchStreams` 和 `TaskController` 的现有终态、generation、刷新和取消边界，确定不与 `conversation-error-status-sync`、`align-conversation-sse-interaction-history` 重复接线。

## 2. 终态结果观察与状态策略

- [x] 2.1 实现物理终态到业务结果观察的纯 Dart 策略，覆盖正常完成、业务失败/积分不足、transport failure、SSE done 和结果未确认；为 `hangup-result-synchronization` 的每个 Scenario 添加正向与负向测试。
- [x] 2.2 将 sessionId、taskId、callAttemptId 和 generation 纳入结果观察上下文，增加重复结果幂等和旧 generation 事件拒绝覆盖测试。
- [x] 2.3 把现有 1.5 秒/32 次同步上限改造成可恢复的 `unconfirmed` 结束状态；确认超时退出无限 loading，并允许页面恢复或网络恢复复用同一身份继续同步。

## 3. 单路与多路 UI/任务接线

- [x] 3.1 在单路物理终态路径接入统一结果观察；确认结果合并先于 loading 关闭，且业务失败结果也能结束等待并展示对应状态。
- [x] 3.2 在多路 detached batch stream 与最后一路结束路径复用同一结果判定和刷新入口；确认批量回执、各路状态和任务列表不会因音频中断或 transport failure 无限加载。
- [x] 3.3 为单路和多路结果建立 task/session 级幂等 invalidate/refresh，验证重复 finalResponse、batchCallResult 和晚到 hangup 不会重复消息、重复刷新或覆盖已确认结果。
- [x] 3.4 将 `conversation-error-status-sync` 的任务列表补偿扩展到异常挂断结果；确认后台 `COMPLETED`、业务失败和积分不足终态均能刷新列表，pending recovered 不会乐观显示 RUNNING。

## 4. 诊断与定向验证

- [x] 4.10 本地接线来电遮挡后的原页结果补查：同一设备网络源共享原生事件订阅，全部消费者取消后可重新订阅；收到 `available` 即使此前离线事件发生在页面订阅前，仍在当前路由和会话身份有效时复用只读入口；被覆盖路由返回时也补查。未知 502/503 握手失败保留执行不确定性，无 callId 按原确认 command 补读，不重拨；已知 callId 与无 ID 的慢结果请求均由各自独立五分钟截止限制。多路前 12 次未决重读间隔 5 秒，后段 10 秒；五分钟到点即使进度/账本请求仍 pending 也反馈未确认。
  - 单路网络恢复用例在旧接线下预期补读 2 次、实际 1 次，改后本地回放通过；另有网络共享/重订阅、路由返回、后段轮询、慢请求截止与持久结果投影回归。最终 14 个相关测试文件 156/156 通过，`flutter analyze --no-pub` 无问题，34 个改动 Dart 文件格式检查及 `git diff --check` 通过。Agent 握手的受限 HTTP status 与可配置日志级别通过定向回归；OpenSpec 本 change 严格校验通过，`validate --all` 的 241 项中 3 项其他 change 失败，与本 change 无关。
  - 旧诊断 ZIP 只见 HTTP 502/500，未见 503；2026-10-21 当前 dev 来电没有可关联 session，不能推断当次服务端终卡提交/读取时序。实际 dev APK 含厂商电话状态接收器及 `READ_PHONE_STATE` 声明，但当前连接手机的该权限为 `granted=false`，任务页也未桥接接收器；本轮未新增系统电话状态直接监听。dev 新包及真机同故障未验，4.3 保持未完成。

- [ ] 4.9 修复禅道 #23730 本机来电遮挡后的原页恢复：前台回归当前账号与批次的只读进度/账本，观察已停止但仍有临时卡时补读账本；SDK 证据逐路解除笼统待核，准入和缺项继续待核；进度已提交而历史读取抛错时仍展示终卡。连续回放覆盖首次进入、重复恢复、路由/账号失效及不重拨；test 真机同故障回放单独待验。
  - 本地新增前台生命周期与原页恢复回放；逐路物理证据、账本异常、同批单飞和旧回包回归已先红后绿。受影响 8 个测试文件 69 项通过，10 个改动文件定向 analyze 无问题，change 定向 OpenSpec 校验通过。尚未把禅道现场截图严格关联真实 batchId，也未做 test 真机来电回放，因此总项保留未完成。
  - 审查补齐同批恢复请求单飞、历史暂不可读且仍有临时批次卡时的发送门禁，以及已提交结果到达后撤销过期“结果尚未确认”提示；终卡原位替换后恢复发送。轮询耗尽后停止活动观察，前台只读账本；迟到旧状态不复活批次，同批最终回执仍可替换待核卡。新增连续回归先红后绿；最终本轮 5 个定向测试文件 38 项通过，`flutter analyze --no-pub` 无问题，`git diff --check` 通过。这些是本地验证，未代表禅道现场或 test 真机已验收。

- [ ] 4.8 单路 `EXECUTION_ERROR` 回执在当前页和恢复入口显示执行异常终态及公开说明；用状态投影与组件回归验证不再出现“结果确认中”，且未知业务结果不被写成成功或零扣费
  - 本地实时与账本回归已覆盖单路无 attempt 的 `task_failed` 终卡、旧警示清除、未终态账务待核对，以及多路空 `items` / 无 `batchId` 的终卡与已读回执；已提交 `executionStatus=EXECUTION_ERROR` 即使汇总与某条逐路 `status` 仍为 `RUNNING`，也结束批次等待并展示终卡，未决逐路显示“待核对”，已有账务和字幕事实仍保留。新增该边界的领域和组件 RED/GREEN；此前受影响 16 个测试文件 120 项通过，`flutter analyze --no-pub` 无问题。test 真机同故障回放与真实通话账务尚未验证，故总项保留未完成。

- [x] 4.5 回放本次 `PENDING / EXECUTION_ERROR` 已提交回执覆盖本地进行中卡的缺陷；修复后检查 5/5 待核对展示，并补进度回包、历史同步、页面可见状态的脱敏诊断。补充进度接口有已提交回执、独立历史同步不可用的回归；修前超时，修后相关 8 文件 36 项及 analyze 通过，含实际回执组件渲染；真机同故障复测仍属 4.3 待验。
- [x] 4.6 将进度接口的开始、脱敏响应摘要和解析失败记录到同一批次诊断；页面应用进度快照后立即记录可见回执与等待态，解除等待后再次记录。结果序号 27、身份不匹配、实际 provider 日志写入及历史同步未返回时的定向回归先红后绿，相关 3 文件 18 项及 Flutter analyze 通过；尚未安装 test 包，旧 ZIP 不含这些新字段。
- [x] 4.7 结合禅道 #23793：第二次重拨仅在准入阶段被拒时，临时进度撤销“已重拨”计数，显示该路失败并让其余路继续按各自事实显示；零版本准入快照不覆盖更强的同次物理进度。前两项回归均先失败再修复；tracker 与 recovery 两文件 21 项、Flutter analyze 通过。后端对应修复在 `D:/aiProject/aiassistant-java/openspec/changes/isolate-batch-retry-admission-failure/`，均未部署。

- [x] 4.1 在 diagnostics 中加入同步阶段、尝试序号、终态分类、结果判定和结束原因，只记录稳定标识和枚举；补充脱敏字段读回测试，确认不含正文、token 或敏感凭据。
- [x] 4.2 运行受影响的 `flutter analyze` 和会话/任务定向测试，覆盖异常挂断后稍晚结果、积分不足、网络失败、结果未确认、重复结果、旧事件覆盖和多路结束。
  - 2026-10-20 合并复验修正同步窗口耗尽后误清除 `activeRequest`；超时退出等待且保留恢复身份。`task_160_call_test` 修前失败、修后通过；受影响 31 个测试文件 221 项和 Flutter analyze 通过。全量测试仍有已在 `codex/dev` 基线复现的设备流程及积分刷新失败，未宣称全量通过。
- [ ] 4.3 按授权执行一次真实测试环境异常挂断/网络异常回归；使用后台 API 日志和客户端 diagnostics 对照 session/task/callAttempt 时序，未取得真实回包的场景标记为待验，不以源码或模拟测试代替。
- [ ] 4.4 更新本 change 的任务勾选、根 `tasks.md` 和 `docs/codex_issue_log.md`，记录实际证据、未验证项和回滚方式；完成 `openspec validate --all` 后再提交验收。

- [x] 4.11 校验超时后的新拨号工具：已知物理闭合线路停止本地状态轮询，新卡须再次明确确认并保留旧 call/attempt 前台只读补查；无 callId 或仅 call_finished 的执行不确定线路须阻止死确认卡并给出待核提示。call_finished 的内层 ID 在本地未绑定线路时仅能凭同 command 启动无注册账本读；本地仅有 callId 时不把未知 attemptId 强行与之比较。事件在状态 GET 失败时仍启动有界结果读取，不推断物理或业务终态。
  - 同 command 的无注册 `call_finished` 带内层 IDs，以及仅绑定 callId 且结果带不同 attemptId 的两种连续回放均先 RED 后 GREEN；新确认卡、旧结果补查和持久终卡投影已纳入最终 14 文件 156/156 合并回归。真机来电/断网回放归 4.3 验收。

- [ ] 4.12 单路已有可信 `CALL_OUTCOME_REPORTED.outcome=UNCLEAR` 或非运行最终结果的 `status=UNCLEAR`／`agentOutcome=UNCLEAR` 时，任务型显示“任务未完成”、普通电话显示“通话未完成”，状态均为“未完成”，结果观察同步闭合；仅有物理完成或 `call_finished`、没有业务报告时按 v66.0.3 显示黄色“正在确认通话结果”小提示，不投整张黄色结果卡。以禅道 #23809 的真实字段形状及非订餐单路做投影和组件回归，验证同 sessionId、callAttemptId 的后续字段原位补齐、不同 session/attempt 隔离及原事实保留；三类事件 `commandId` 不要求相等，真实 test 包同会话页面仍待验。
  - 本地 7 文件 63/63 回归通过，覆盖 Android/iOS 等待文字、纯物理 `COMPLETED/ENDED`、最终 `UNCLEAR/FAILED/COMPLETED` 原位替换及账本字段；19 文件定向 analyze 无问题、格式检查 0 变化、diff 检查及本 change 的 OpenSpec strict 校验通过。`conversation_single_receipt_revision_test.dart` 另有 2 项滚动断言失败，改前基线未核实；test 包同会话页面和历史恢复仍待真机验收，因此总项不勾选。
  - 提交前复核补齐：已上报结果优先于旧实时说明、已结算物理账务不被后续待结算字段盖掉、纯物理挂机不触发结果已读；缺少 attemptId 的 `SDK_PHYSICAL_ENDED` 已读用例先失败后通过。相关 4 个测试文件 54/54、7 个 Dart 文件定向 analyze 通过。真实 test 包同会话页面仍待验。
  - 交付分支再合入源工作树时保留已提交或实时最终 `UNCLEAR` 的红色未完成卡，以及目标分支已有的 test DB 原始字段证据；源草稿中相反的黄色卡断言和“未取到原始字段”记录不纳入。相容改动覆盖工具元数据伪造、同通话 SUCCESS／FAILED 缺字段或账务补齐、迟到 live UNCLEAR 不覆盖已提交结论。最新投影与 overlay 两文件 36/36、其余四个相关文件此前 29/29、原因 revision 定向 1/1 通过；目标分支原有两项滚动断言在未修改的 HEAD 上同样失败。真实 test 包同会话页面仍待验，4.12 继续未完成。
  - 2026-10-22 合入交付分支的连续回归发现：可信结果投影先关闭观察，结果观察随后因旧观察失效漏掉任务刷新；物理标记携带旧 `UNCLEAR` 时还会提前关闭观察并画整张卡。两项均先用失败回放确认，再修正同步后判定、物理标记准入和页面优先级；补齐可信实时 `UNCLEAR`／`EXECUTION_ERROR` 替换物理标记的回归。原对话编排与卡片顺序不变。六个相关测试文件 82/82 通过，13 个改动 Dart 文件定向 analyze 无问题；真实 test 包的原页终卡仍待验，本项不勾选。

- [ ] 4.13 对齐结果等待与终卡的交互边界：单路同身份已提交 `callResult.status=COMPLETED`，但无可信报告、合法语义 `agentOutcome` 或明确技术异常时继续等待，即使有普通业务 `resultCode` 也不单凭它显示黄/绿/红结果卡；已有明确技术异常沿用红色异常反馈，但不据此裁决业务结果。可信完成显示绿色终卡，可信 `UNCLEAR`／`EXECUTION_ERROR` 与失败显示红色终卡。多路五分钟耗尽仍无已提交结果时保留“结果尚未确认”临时进度，不出现“执行结果／结果回传”终卡区域；后续同身份可信回执原位替换。以当前页 Android/iOS 和批量正式入口回放核对，并保留真实 test 真机验收待办。
  - 本轮本地回放：`native_task_result_ui_parity_test.dart` 的 Android/iOS 正式入口原先出现结果卡，先有 2 个失败；修后该文件 18/18。多路新增 `batch_receipt_widget_test.dart` 正式入口用例先红后绿，7/7；关联 `batch_progress_refresh_test.dart`、`task_160_batch_final_test.dart`、`batch_progress_tracker_test.dart` 定向回归合计 40/40。以上仅为本地回放，明确未确认文案与最终变更仍需复核；真实 test 真机同故障未验证，本项不勾选。
  - 补齐控制器、同步观察器与正式结果卡对合法语义 outcome 的共同门禁；`PENDING`／未知 outcome 携带成功 `resultCode` 的负向回放先失败后通过。快进至 `origin/codex/dev@83ab13b6` 后最终合并 12 文件 123/123，10 个改动 Dart 文件定向 analyze 无问题，格式检查 0 变化、OpenSpec strict 有效；仍未构建或在 test 真机复测，本项保持未勾选。

- [ ] 4.14 按 2026-10-22 用户纠偏及 v66.0.3 对照，任务型单路失败、未完成或执行异常结果卡保留简短业务说明，不把 `metadata.agentReason`／`resultReason` 的长诊断或 `terminationCause=SYSTEM_STOP` 等技术码展开给用户；正常的业务原因字段仍可显示。保持业务字段、状态、通话转写和已确认账务，核对 Android/iOS 当前页、同会话恢复及只读详情；做截图式失败回放、短原因保留回放、定向测试和静态检查。真实 test 安装包及现场重放未完成前不勾选。
  - 已在旧版 `test/v66.0.3@a0bedb12` 核对：服务端本来就返回 `metadata.agentReason`，有结构化字段的 Android 任务卡只画字段与状态；Flutter 2026-10-21 的 `aa97eaadb` 新增了未完成卡优先读取 `agentReason`。先前“一概隐藏原因”的本地 45/45 验证不再作为本项验收；收窄后 Android/iOS 相关 3 文件 48/48、定向 analyze 无问题，仍待真实 test 安装包和同会话页面核对。
