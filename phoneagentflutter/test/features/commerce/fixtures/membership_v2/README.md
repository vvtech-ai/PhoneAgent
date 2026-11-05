# PAUSE_QUEUE_V1 契约冻结

2026-10-14，membershipProtocolVersion=2。本目录 JSON 是 ApiResponse.data 的契约摘录，不替代既有 envelope/金额/开票字段；current 省略的 benefits 仍沿用既有 DTO。字段名以 PDR §4 为准；不得把示例价格/积分写作默认值。所有 EXAMPLE 订单均为虚构，固定 observedAt=2026-10-14T10:00:00+08:00。

## 类型与空值

新增 BIGINT ID、membershipVersion、expectedVersion 均十进制字符串；秒数/积分/期号为 JavaScript 安全整数（超出拒绝）；日期为秒精度 ISO-8601 +08:00。nullable 字段必须显式返回 null，数组为空返回 []，不能用空字符串或 0 替代未知时间。当前 benefits 沿用现有四档配置；FREE currentMonths=null。

MembershipQueueItem 固定字段：entitlementId/sourceOrderNo/level/months/state/position/firstActivatedAt/currentExpiresAt/estimatedStartsAt/estimatedExpiresAt/remainingSeconds/firstGrantPoints/totalPeriods/grantedPeriods/nextGrantAt。ACTIVE 返回实际当前到期；PAUSED currentExpiresAt=null、remainingSeconds 保留；QUEUED remainingSeconds/firstActivatedAt/currentExpiresAt/nextGrantAt=null。position 为全队列位置，ACTIVE=1，优先级由服务端给出，不按客户端数组重新排序。未初激活 offset/totalSeconds/actual expiry 均 null（持久化约束，不向队列 DTO 增加伪字段）。

quote 四 fixture 固定完整 MembershipPurchasePreview；报价 membershipProtocolVersion=2 必填，新单继续 quoteId/requestId/协议，ruleVersion 来自服务端报价。NEW/UPGRADE immediateGrantPoints=firstGrantPoints；RENEW/LOWER_QUEUED immediateGrantPoints=0，firstGrantPoints 仅承诺初激活积分。conversionSeconds 恒0。pausedEntitlement 是将被暂停的当前 ACTIVE 快照。预计日期不是付款承诺，付款后以实际生效为准。iOS 从 StoreKit displayPrice/currencyCode 显示，不比较服务端 CNY 参考价。

result 首次快照 actualPurchaseType/initialEntitlementState/fulfillmentDecisionAt/initialGrantedPoints/queuedFirstGrantPoints/totalPeriods 不可改写；entitlementState/activatedAt/firstActivationGrantedPoints 是当前投影。已交付排队为 SUCCEEDED/SUCCEEDED/COMPLETED，释放支付位置；后续激活不改首次类型。已付未履约示例 CREDITING 沿既有状态枚举，不再发起付款。PAUSED expiresAt=null；未激活 effectiveAt/expiresAt=null。每个 fixture 独立场景，不要求不同文件间订单状态同时成立。

## 后台与错误


errors.json 是 ApiResponse 既有错误结构中的业务 code/meaning 清单，不新定义 envelope。后台详情必须展示权益/逐期计划/事件/原单/渠道审计；后台列表 GET 不推进发分，刷新只重读，统一引擎由 SDK/SSE 和定时任务推进。原 recovery 接口只用于历史订单；v2 不显示折价换时长。

## 验证与追溯

SHA256SUMS.json 对本目录所有 JSON fixture 和本 README 固定摘要。消费者引用 manifest SHA256；调整契约须同步三仓 OpenSpec 和该摘要。完整规则、时间算法、锁/退款乱序、SQL守卫及 A01～A28 以 ../会员权益暂停恢复与排队购买_PDR.md 为唯一规范正文。T01 不代表 T02～T08 或真实运行验收完成。

## 后台详情fixture

admin-detail.json 冻结后台聚合投影 membership/entitlements/grantSchedules/events/relatedOrders/adjustments/lastAdvancedAt，详情内部运行字段 scheduleId/eventId/ledgerId 均字符串；未初激活grantOffsetSeconds/总秒数为null。该后台DTO仅投影，不增加客户端 MembershipQueueItem 字段。grantSchedules固定基础/赠送/总分及期号、状态和实际发放事实，events保留原单和规则版本，adjustments为预留空数组，本版无人工写接口及新增授权。quote precedingEntitlements只列新权益前实际会消费的项目；PREMIUM续购在当前PREMIUM后、PLUS暂停权益前。

后台不提供人工退款、退款撤销或积分调整功能；所有新增详情接口均只读并复用既有后台登录鉴权。
