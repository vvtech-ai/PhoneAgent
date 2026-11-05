## ADDED Requirements

### Requirement: iOS 本地交易失败可区分并关联
客户端 MUST 区分本地交易未验证、商品不符、账号 token 缺失/不符、交易类型不支持；MUST 在日志写入前将交易和商品 ID 脱敏，不记录 token、JWS 或异常原文。诊断 MUST NOT 改变支付、取消、恢复和 finish 的业务规则。

#### Scenario: 校验失败
- **WHEN** StoreKit 购买返回 success 但本地校验未通过
- **THEN** 原错误码和提示保持不变，日志包含固定校验阶段及可取得的脱敏交易/商品标识
- **AND** 可以与既有恢复交易日志的 transactionRef 对照

#### Scenario: 非法诊断内容
- **WHEN** 原生错误详情或持久化日志含未知阶段、原始标识、token 或交易凭据
- **THEN** 仅白名单阶段及有效脱敏标识可进入 JSONL，其他私有字段丢弃
