## MODIFIED Requirements

### Requirement: iOS 支付界面等待有界且保留迟到结果
替代 bound-ios-payment-wait 中原生最多30秒的要求：Apple购买操作 SHALL 不计入成功交易后的30秒核验期限。完整交易凭据到达后 SHALL 核验并查询原单；最长30秒后释放界面等待，保留后续核验和恢复。明确取消、pending及错误 SHALL 各自反馈，不因时间推断结果。

#### Scenario: IOS-PHASE-01 长时间操作或永不返回
- WHEN Apple操作超过30/60秒或不回调
- THEN 不提前显示支付结果待确认；仅使用原有全屏“支付处理中…”遮罩并阻止重复操作，不增加底部提示或查询入口；Apple无回调时仍等待，不伪造结果

#### Scenario: IOS-PHASE-02 核验超时
- WHEN 完整成功交易到达后验单或权益结果超过30秒
- THEN 显示支付结果待确认，保留原单与迟到成功恢复，不取消底层验单

#### Scenario: IOS-PHASE-03 迟到及重复结果
- WHEN 超时后验单成功或相同交易重复到达
- THEN 原单更新，成功后finish，幂等不重复发放

#### Scenario: IOS-PHASE-04 非成功结果
- WHEN Apple取消、pending、失败或不完整成功材料
- THEN 分别保留真实语义，不等待成功核验期限、不伪造成功

#### Scenario: IOS-PHASE-05 查询及身份切换
- WHEN 等待时查询、离页、换账号或旧结果迟到
- THEN 查询有界，原生结果仍可恢复，旧响应不覆盖新页面/账号

#### Scenario: IOS-PHASE-06 到期与平台隔离
- WHEN 原单到期后交易迟到或Android支付
- THEN 保留现有到期及迟到核验合同；Android沿原流程
