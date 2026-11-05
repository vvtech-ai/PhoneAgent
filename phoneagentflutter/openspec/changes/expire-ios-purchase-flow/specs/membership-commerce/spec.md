## ADDED Requirements

### Requirement: iOS 本地购买流程按服务端有效期关闭
系统 SHALL 仅对 Apple 未付款未履约到期订单幂等关闭本地流程，释放原单占用并保留 token；SHALL 不宣称 Apple 渠道已关闭或未扣款。新购买 SHALL 使用新订单并经过既有资格和并发检查。

#### Scenario: IOS-EXPIRE-01 客户端取消未同步
- **WHEN** Apple 原单超过 expiresAt 且无已记录付款和履约
- **THEN** 服务端独立关闭本地购买流程，不等待客户端事件，保留迟到验单

#### Scenario: IOS-EXPIRE-02 取消晚到
- **WHEN** 已关闭原单收到取消补报
- **THEN** 正常返回当前状态，客户端清理取消待办，关闭原因不变

#### Scenario: IOS-EXPIRE-03 关闭与付款交错
- **WHEN** 成功付款先于或晚于超时转换
- **THEN** 成功事实不被覆盖，原单幂等履约，超时标记不遮蔽付款结果

#### Scenario: IOS-EXPIRE-04 新旧两单均支付
- **WHEN** 原单超时后新建订单且两单均收到合法付款
- **THEN** 各自记账，按既有积分/会员规则处理权益或提供冲突恢复，不清新单占用

#### Scenario: IOS-EXPIRE-05 未知结果与进程恢复
- **WHEN** Apple pending、网络失败、杀进程或关闭后原生结果迟到
- **THEN** 不伪造取消，不因本地关闭丢失交易，恢复保持账号与原尝试身份

#### Scenario: IOS-EXPIRE-06 客户端原单支付限制
- **WHEN** 订单关闭或支付材料到期
- **THEN** 不允许再次支付原单；显示准确说明并保留主动查询入口

#### Scenario: IOS-EXPIRE-07 后台重复执行
- **WHEN** 多实例、重复扫描、过期租约或付款字段改变
- **THEN** 锁内重新检查，超时事件一次，已知付款不被关闭，历史空查询不挤占扫描

#### Scenario: IOS-EXPIRE-08 Android 保持
- **WHEN** Android 支付、取消、查看订单及恢复
- **THEN** 原业务规则、控件、文案、恢复节奏不变
