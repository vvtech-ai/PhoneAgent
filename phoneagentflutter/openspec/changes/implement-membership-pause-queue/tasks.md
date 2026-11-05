# 执行任务与证据

- [x] T01 读取规范、冻结 PDR/评审和四种购买/current/result/后台/异常 JSON。
- [x] T02 数据模型与 SQL 隔离演练（A23/A24/A25/A28）。
- [x] T03 core 统一推进、排序、发分与 SDK/SSE 准入（A01～A11/A14～A16/A19/A27/A28）。
- [x] T04 报价/订单/可信支付/退款/历史隔离（A01/A02/A04/A08/A10/A12/A13/A17～A20/A24/A26）。
- [x] T05 Flutter 四种确认与当前/队列/结果（A01～A05/A12/A13/A17/A20/A21/A26）。
- [x] T06 Web 只读队列、履约和渠道事件审计（A04/A15/A18/A19/A22）。
- [x] T07 跨仓隔离契约与UI/数据库验收；不能替代真实渠道。
- [x] T08a 审查、中文提交与授权目标推送。
- [ ] T08b 用户部署后运行/渠道验收。

## 实际验证与剩余项

自动化/隔离证据统一保存在 Java 仓库 `docs/membership-v2/交付验收记录.md`，精确 SQL 回执位于 `scripts/membership_v2/`。包括36场景迁移及恢复、39项真实原单/关单/积分包回归、SDK/SSE/core与Apple处置、后台8项MyBatis及10项投影SQL、Web76项和Flutter购买465项。

测试类按实际实现拆分，使用 MembershipTimelineEngineTest、MembershipRefundRulesTest、MembershipMySqlTest、MembershipPendingDispositionMySqlTest、MembershipPurchaseMatrixTest、MembershipProtocolContractTest、MembershipAdmissionParityTest 等。原PDR任务表中的预定类名不是额外未实现功能。

最新追加的会员功能提示及 AI/TTS 接线：Flutter 231 项和 Java 53 项定向回归通过，analyze 与架构检查通过，T07 自动化及隔离验证已收口。真实渠道、手机、业务库切换与部署属于T08b，不因代码检查通过而勾选。
