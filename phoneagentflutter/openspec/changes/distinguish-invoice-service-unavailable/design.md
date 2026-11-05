# 设计

只扩展 ApiCommerceRepository 的安全业务码白名单及 CommerceFailure 的固定中文投影。ApiInvoiceRepository 已复用白名单并转换异常，InvoiceController 已保留失败输入与同次申请身份，无需改生产控制器、DTO 或发票状态。未知错误和供应商原文继续不暴露。

使用真实 AccountApi、ApiInvoiceRepository、InvoiceController 配合离线 HTTP adapter 验证拒绝路径，先 RED 后 GREEN。不提交实际开票。
