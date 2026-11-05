## ADDED Requirements

### Requirement: 开票服务未就绪与订单资格拒绝分别提示
客户端 SHALL 将 INVOICE_SERVICE_UNAVAILABLE 映射为“开票服务暂不可用，请稍后重试”，INVOICE_NOT_ALLOWED SHALL 保留订单资格拒绝提示。失败 SHALL 保留草稿与同次请求身份，不自动提交，不展示供应商原文。

#### Scenario: 合法订单申请遇到开票服务不可用
- **WHEN** 发票提交接口返回 INVOICE_SERVICE_UNAVAILABLE
- **THEN** 显示固定服务暂不可用提示，保留填写内容，等待用户主动重试。

#### Scenario: 未知开票业务错误
- **WHEN** 发票提交返回未列入白名单的业务码与供应商原文
- **THEN** 保留通用错误，不向页面暴露原文或内部错误码。
