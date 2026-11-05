# 任务编排回归补齐审计（2026-10-20）

本轮依据已批准的 `task-orchestration-v1.2`，比较重构前 `a0bedb12` 与原生 App 1.6.0 `8f235920` 的源码和测试，再为当前 Flutter 补充连续回放。旧仓库只读；没有运行旧版测试，也没有把旧断言机械复制为当前实现。

## 旧保护、当前缺口与补齐

| 来源或合同 | Flutter 发现的缺口 | 本轮实际保护 |
| --- | --- | --- |
| v66 / 1.6.0 `TimelineSnapshotConfirmationReconciliationTest` | 确认提示依赖可操作卡，失活后删除；同 command/tool 的独立正文可能被吞 | `continuous_task_orchestration_test` 3 项：真实 controller / speech / 页面连续两通，提示持续保留、各执行一次、恢复零重拨零重播；merge 另增 3 项独立正文及重复工具轨迹防护 |
| v66 `OnlineAndRestoredReceiptIsomorphismTest` 五种结果 | USER_CANCELLED / NEEDS_RECALL 被归一化；稀疏 callId 在恢复时丢失 | `receipt_entry_isomorphism_regression_test` 6 项：原五种结果加 COMPLETED 别名，实时→账本→重复恢复→只读详情保留同一业务事实 |
| 1.6.0 `ApologyVoiceCoordinatorTest` 切模反馈与迟到隔离 | 按模型命名消息，切回原模型覆盖旧位置 | `apology_model_operation_identity_test` 5 项：操作身份、A→B→A、同文案、重复回调、旧查询及 pending 隔离 |
| 1.6.0 TaskRatingViewModel 的重新 claim / generation / 幂等保护，RATING-01/02/03 | 结果补全和 owner 交接没有资格重查信号；批量 revision 漏业务字段 | `task_rating_result_refresh_test` 12 项与 `batch_task_rating_result_revision_test` 4 项：真实反馈 route/controller、补全、失败恢复、旧响应、编辑/提交/账号隔离、整批终态及原位置 |
| 已批准 ENTRY-01/02/03；开场逐字核对 v66 Skill frontmatter | 可点击默认卡开场为空，远端与标语阻塞有效快照 | `home_snapshot_readiness_test` 与 `home_snapshot_lifecycle_test` 共 12 项：完整兜底、缓存先用、后台单飞、慢写、损坏配置、关闭和账号代次、真实 VoiceHost 开场一次 |
| THINK-01 与用户结果后双思考卡反馈 | 没有本轮 assistant 时思考被放到全会话末尾 | `thinking_result_anchor_regression_test` 2 项：结果 / 账本先后互换，真实页面坐标、两轮各自锚点、重复投影不移位 |
| STOP-01 与用户反复点击取消反馈 | 停止待终态提示进入对话，结束后残留 | `stop_transient_header_status_test` 6 项：Android/iOS 页面，顶部临时状态、终态清理、一次停止、迟到回调隔离 |
| 既有批量积分准入及失败播报回归 | task_failed 携带 batchCallResult 被误解码为普通错误，未驱动原结构结果链 | `call_event_decoder_test` 新增 2 项；保持未知失败语义，联验钱包刷新、准入与会员拒绝播报 |

共新增 **55 项唯一用例**（新测试文件 50 项、已有 merge 文件 3 项、decoder 文件 2 项），不把重复运行累计为覆盖数。各 change 保留失败→修复→通过证据。

## 集成验证与兼容断言迁移

- 固定 Flutter 3.32.0，`flutter test --no-pub --reporter json` 的最终定向集合为 36 文件 **241 passed / 0 failed / 0 skipped**，有成功 done 事件；另 `test/shell_call_workbench_test.dart` **3 passed**，合计 **244 项唯一用例通过**。
- 全仓 `flutter analyze --no-pub` 无问题；最后 shell 测试调整另做定向静态检查。未修改平台、依赖、公共 API、数据库、SIP、模型提示词或服务端记忆业务。
- OpenSpec 普通全仓校验 230 项通过，本轮八项 change 分别 strict 通过；全仓 strict 为 226 通过 / 4 失败，均是既有主规格 Purpose 过短警告，不将普通校验结果称为全仓 strict 通过。
- 保留既有确认宽度与选项内容 / pending / 执行断言：裸确认卡不再承担正文职责；同身份结构选项收起重复工具轨迹。旧详情文件按钮已由此前提交改为“查看”，本轮修正准确按钮 finder，仍检查保存 / 下载 / 打开次数。
- 320px 正式 shell 回归中的旧确认价格位于历史懒加载区域。保留确认提示后增加内容高度，测试需先向旧消息方向滚动，再检查固定价格；仍核对模型切换、历史价格不变及提示保留，不为测试改变生产滚动或删除正文。320 / 430px 三个场景均通过。

## 全仓扩大运行的真实结果

全仓 `flutter test --no-pub --reporter json` 曾执行，最后三个用例长时间没有进展后中止，无 done 事件。已完成的可见记录为 **6,625 passed、2 skipped、77 failure records**（含一个加载 / 编译 suite 记录）；这不是完整全仓结论，不能声称全绿。三个未结束用例是 identity rejection clears settings navigation、active conversation released on signout、contact tool continuation and candidate restore 320.0。

对修改前 `2cb51ec6` 创建只读用途隔离检出并独立复跑失败文件：首组 8 文件 48 项，25 个同名失败重现；第二组 9 文件 22 项，16 个同名失败重现。合计 **41 个失败有基线重现证据**，涉及原有滚动、长 pending、语音输入、设置预览、国内模型及正式退出 / 重登流程。临时检出已清理。其余失败不能未经逐项核对就全部归为基线。本轮不为全绿而修改无关正常业务或削弱断言。

本轮暴露的直接相关问题已分别修正并定向通过：COMPLETED 别名、批量结构失败、确认卡职责迁移、联系人重复工具轨迹、旧文件按钮 finder 和 320px 懒加载历史断言。

## 尚需取得的验收证据

- 客户端回放使用真实 controller / route / widget，外部 HTTP、通话与音频使用受控端口；不能代表实际电话、可听 TTS 或双端真机验收。
- 现场双思考日志能证明结果与账本交错，缺逐段思考 command / 应用索引；已证实同类源码失效路径，不宣称截图唯一根因已签收。
- 评分以有效结果补全、owner 交接或显式 load 重查；后端单独改变资格而没有新客户端事实，仍需后端通知合同，不用无限轮询掩盖。纯工具历史不能补造未落账 Agent 提示。
- 模型切换本地各次反馈已保留；服务端初始开场只存最后选择时，离页后的全部操作历史仍有持久化边界。
- 记忆已完成三仓共同规则和后端对照方案，**未实施公共使用确认门禁**。当前 Skill / 账号范围约束保留；不能宣称“找到记忆先问”已随此客户端包生效。
- 四类入口共同标准已冻结，本轮相关入口自动回归通过；真实后端、Android/iOS 相同输入、实际 TTS、账号与配置运行态继续分别待验，不归档 change。

各项实现设计与 RED/GREEN 见 `openspec/changes/` 下本轮八项 change；规则的当前版本直接位于仓库根 AGENTS，不依赖个人目录或诊断文件。
