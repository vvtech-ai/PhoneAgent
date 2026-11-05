## ADDED Requirements

### Requirement: 按等级购买与保留权益
系统 MUST 执行 PAUSE_QUEUE_V1，等级 FREE < BASIC < PLUS < PREMIUM；仅等级关系决定 NEW/UPGRADE/RENEW/LOWER_QUEUED，同SKU及1/3/12月均可全价购买；PACK沿原折扣。

#### Scenario: 四种会员购买
- **WHEN** 无会员、买更高、相同或更低等级
- **THEN** 分别立即ACTIVE、暂停旧ACTIVE后激活、同级队尾或低级队尾；排队不提前计时/发首期
- **AND** 同级已使用PAUSED优先QUEUED，其后按可信paid_at和订单id排序，迟到支付不打断同级ACTIVE

### Requirement: 统一时间与原子资产
系统 MUST 共用core推进，唯一ACTIVE；初激活按Asia/Shanghai原点分别plusMonths生成边界；暂停冻结，恢复保留offset/usedSeconds/已发期。发分与状态/事件/来源/订单同事务；每期永久MEMBER_PERMANENT来源，原余额与来源守恒。

#### Scenario: 跨历史边界与并发
- **WHEN** worker/read/支付并发或离线跨期
- **THEN** 按账号锁统一序及锁内Clock推进，在历史耗尽边界恢复；每期只发一次，200边界分批独立提交，积压保持真实next_action并返回MEMBERSHIP_SYNCING
- **AND** membershipVersion仅业务变化增加，时间游标另用row_version；损坏保留原权益并返回MEMBERSHIP_REVIEW_REQUIRED

### Requirement: 版本2契约与结果投影
系统 MUST 使用proposal引用的共同JSON及README字段/空值约束；新增ID及版本为十进制字符串，安全整数积分/秒数，时间带+08:00。客户端不重算队列/时长/首期。

#### Scenario: 队列及后续激活
- **WHEN** 已付权益为QUEUED
- **THEN** payment/fulfillment均SUCCEEDED、释放支付位置，remainingSeconds及实际激活到期为null
- **AND** 后续激活仅更新当前投影，初始履约快照保持；已付未履约显示处理中不重付

#### Scenario: 未付与已付前态变化
- **WHEN** 报价前态变化或协议版本不支持
- **THEN** 未付款刷新确认，新会员入口要求协议2；已付款锁内真实重判，原单验单/查单/发票/回调继续可用
- **AND** iOS使用StoreKit当地价格，不用服务器CNY参考价做门控

### Requirement: 可信退款与只读审计
系统 MUST 依PDR §6的可信退款/撤销顺序和signedDate冲突规则处理；申请无副作用，已发积分不自动扣。本版不提供人工退款、撤销或积分调整入口，不新增授权配置。

#### Scenario: 可信通知幂等与权益处置
- **WHEN** 已验签渠道退款或退款撤销通知到达
- **THEN** 重复业务事件不重处理；旧通知不覆盖新状态，同时间矛盾保留异常；不自动扣已发积分或重发已发期次

### Requirement: 客户端与后台职责
App MUST 展示四种确认/协议和支付方式初始未选、防重、暂停保留与待生效区别，统一退款联系contact@vv.tech；Web MUST 分离支付/履约/权益状态并展示期次/事件/原单/审计，列表GET不写资产。

#### Scenario: 展示与只读边界验收
- **WHEN** 执行A20～A22与A26消费者验收
- **THEN** 切号迟到响应不渲染，375/390/430宽及长队列可用，后台无人工退款/调整入口，无额外授权，刷新不写资产

### Requirement: 历史隔离与运行门槛
系统 MUST 保留历史change/订单/发票/来源；仅获准开发库权益与未发计划可重置，先隔离MySQL5.7演练及实际恢复验证；禁止H2或mock冒充环境/渠道成功。

#### Scenario: 开发切换与旧通知
- **WHEN** 执行DDL/reset或收到旧单迟到支付
- **THEN** SQL严格UUID及ai_assistant_ref_dev双守卫、备份批次与reviewed确认，未决收款阻塞reset；旧已履约回调不重建权益，旧迟到真实成功留LEGACY_MEMBERSHIP_REVIEW_REQUIRED
- **AND** 新订单前可恢复备份，新订单后仅兼容前向修复，T08b由用户部署后另验

### Requirement: 验收规则可追溯
本仓 MUST 按PDR §9 A01～A28与tasks工作包对应执行，保留commit/命令/退出码/数量/数据库目标/时间证据；T01冻结不等于实现或部署验收。

#### Scenario: 交付验证
- **WHEN** T02～T07完成进入T08a
- **THEN** 先完成对应隔离/契约/UI测试及中文差异审查，只有T08b环境与真实渠道证据完成才关闭运行验收

### Requirement: 区分积分包和会员待支付限制
系统 MUST 允许多笔独立积分包订单待支付，不以未付积分包数量阻止新购；保留请求幂等和分钟/小时下单频率保护。会员保留单笔有效支付占位。

#### Scenario: 积分包累加与会员原单恢复
- **WHEN** 存在未支付积分包或未支付会员订单，用户新购积分包
- **THEN** 不因旧未付订单数量拒绝新购；同 requestId 返回原单，各成功订单独立且仅一次到账
- **AND** App 一次只唤起一个收银台，已绑定 Apple 交易不迁移到新单；会员再次下单仍恢复原有效支付单，队列履约成功后释放占位

### Requirement: 客户端慢请求与权益限制提示
App MUST 在购买报价、确认支付、继续支付和取消的请求等待阶段即时提供 loading 并抑制重复提交；功能资格读取当前生效权益，服务端保留最终裁决。

#### Scenario: 慢请求与失败恢复
- **WHEN** 报价、下单、Apple 价格刷新或原单操作延迟返回
- **THEN** 用户立即看到加载反馈，同一操作只发送一次请求；完成或失败后恢复交互，不遮挡需用户操作的确认内容

#### Scenario: 当前会员不具备功能资格
- **WHEN** 已加载的当前会员权益明确不允许模型、批量联系人、并发外呼或声音克隆功能
- **THEN** 说明当前限制，所需等级仅从有效发布配置推导；配置未知不假装无权限，供应商不可用与额度不足不误报为等级不足
- **AND** 不使用营销选中或排队套餐等级授权，不更改服务端准入与声音克隆执行逻辑

#### Scenario: AI 联系人及并发拒绝回复与播报
- **WHEN** AI 执行收到已知会员准入失败，包含 BATCH_ENTITLEMENT_LIMIT、BATCH_CONTACT_LIMIT、BATCH_CONCURRENCY_LIMIT、CALL_CONCURRENCY_LIMIT
- **THEN** 使用明确、安全的失败文案输出一条 assistant 回复，并依当前语音设置进入现有 TTS 一次；不能声称已开始拨打
- **AND** 实际通话占满提示等待，未知错误不伪装为等级不足，重复终态不重播，退出或切账号后的旧事件不播报
