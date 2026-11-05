## Decisions

1. 以 a0bedb12 的 OnlineAndRestoredReceiptIsomorphismTest 五项实际断言为依据：SUCCESS、USER_CANCELLED、NEEDS_RECALL、FAILED、UNCLEAR。
2. transport status 与 metadata.agentOutcome 分开；后者使用权威 reported 值，不能由前者反推丢失业务信息。
3. 同一 fixture 经实时 finalResponse、账本补全、restore 和 TaskDetailState，比较身份、结果、字段、原因和展示文案；恢复不得新增命令或播放。

## Validation

先记录语义损失 RED，再最小修复 GREEN，并执行 receipt / history / semantic status 定向回归和静态检查。设备与真实后端另需对应证据。
