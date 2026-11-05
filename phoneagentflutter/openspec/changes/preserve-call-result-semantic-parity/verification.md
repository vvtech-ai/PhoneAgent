# 结果跨入口语义回归

来源：重构前 a0bedb12 的 OnlineAndRestoredReceiptIsomorphismTest 五项实际断言：SUCCESS / USER_CANCELLED / NEEDS_RECALL / FAILED / UNCLEAR。

- 新 receipt_entry_isomorphism_regression_test 使用真实 controller 接收 finalResponse，再通过 gap committed 补入账本，最后 restore 两次并经 TaskDetailState 读取。
- 首轮五项 RED：USER_CANCELLED / NEEDS_RECALL 在补全时丢失原语义；另三项在恢复时丢失仅 reported / requested 提供的同 attempt callId。
- 保留 reported 原 outcome，并从同 attempt 的 reported / requested 取 callId 兜底，五项 GREEN。检查状态、原因、结构字段、身份与结果说明顺序，以及恢复零新增命令 / 播报。
- 定向静态检查通过。全量随后检出既有 COMPLETED 成功别名在原语义保留后须继续被展示策略识别；已保留该成功别名并新增第六项回放。最终六项及相邻回执 / 状态测试纳入 36 文件 241 项集成，全部通过；不回退原语义保留。

未使用真实后端、电话或音频；最终集成结果另记，不累加复跑次数为唯一覆盖数。
