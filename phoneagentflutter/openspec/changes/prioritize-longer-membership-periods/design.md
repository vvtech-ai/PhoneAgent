# 实现边界

## 基线和证据
Java HEAD029cf087、Flutter HEAD89d0b1c6，feature/test_v1.8.0_zys，开始时工作区干净。未核对实际安装包/部署。源码候选优先级为等级→PAUSED→paidAt→orderId，接替判断仅比较等级；确认预览将所有RENEW归AFTER_QUEUE。新增连续时间线回放先复现。

## owner、入口、身份
membership-core domain维护排序与精确时间线；application持有账号锁内入账、结算、退款重选、当前读及预览；Flutter只读服务端顺序与生效字段。入口含新购买、读取当前权益、维护补算、退款/撤销及现有确认。身份沿用account/entitlement/sourceOrder/period/eventSeq/membershipVersion，时间游标不代替业务版本。

## 修改与不变量
MembershipEntry统一等级/周期比较；MembershipTimelineEngine在补算到目标时刻后纠正现存短周期ACTIVE，并在同一有界推进中激活长卡、首期仅发一次。存量已记录usedSeconds和发分不回退，日历初激活锚点不改，暂停恢复保留offset。后续未发生阶段按新优先级推进。MembershipPurchaseService同级长周期也精确暂停原卡；RENEW类型保留。MembershipPreviewService根据等级/周期决定IMMEDIATE，前序只包含真正在目标前面的卡。后台会员只读明细与历史列表的同级业务排序同步加入months DESC，保留原进度时间优先及分页规则，不增加页面。currentLocked继续只读；日历积压或新优先级尚未结算时返回同步中，不在调用方钱包事务内发分。维护任务同时发现当前短卡存在同账号同级长周期候选的账号，沿原锁和补算入口完成切换；普通前台读取照常独立补算，不要求等到原卡到期。

Flutter不排序、不估算权益，使用原字段展示；仅扩展现有生效规则文案以覆盖同级长周期暂停。历史quote/result fixtures不回写，历史初始履约快照保留。无权益折算、合并资产、退款资金或额外弹窗。

## 验证
新增月→季→年逐级接替、年→季→月恢复、高级月优先中级年、同周期稳定、存量按切换时刻结算、离线跨期、有界恢复、退款重选、初期幂等、报价和投影测试。回归新购限制、SDK报价/原单/支付恢复、Flutter确认和按钮。关联原需求T07/T08/T10-T18/T21/T24/T27-T28（仅优先级相关）；ENTRY-03/MODEL-03/CONFIRM-01-02/HISTORY-01不改变任务合同。无共享编排规则修改，不声称三端一致或真实支付/真机验收。
