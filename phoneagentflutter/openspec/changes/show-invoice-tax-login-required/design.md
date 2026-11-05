# 设计

新增 invoice_status_presentation.dart，将状态与白名单 safeErrorCode 转为用户说明；InvoiceSheet 渲染可换行提示，不解释供应商原始响应。CommerceInvoice 和 API 已保留错误码，不增加 DTO 字段。Controller 现有 invoice 非空阻止重复 submit、仅 FAILED 可显式重填的规则保持。

INVOICING 提示“开票暂时受阻，开票方需重新完成税务登录。申请已保留，请稍后查询，无需重复提交。”；FAILED 提示“本次开票未成功，开票方需重新完成税务登录。请联系售后，待恢复后再申请。”。查询仍使用原订单，不创建替代申请。只有可信 FAILED 才展示失败标签，ISSUED 不显示历史登录错误。

沿用已有售后邮箱入口和已发布目录来源，不新增手机号、税务登录或验证码输入。不承诺自动恢复、固定有效时长或真实税航已验证。

验证包含 Android/iOS 提示与动作、未知码/旧错误隐藏、320 宽两倍字体、真实 Repository GET 查询链路及 Controller 防重提交；再执行受影响发票集合、analyze 和 OpenSpec。
