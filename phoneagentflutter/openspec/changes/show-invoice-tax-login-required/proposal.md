# 税务登录失效时显示明确开票提示

## Why
销方税务登录失效时，App 已接收 safeErrorCode 但没有展示原因。用户需要知道开票暂时受阻以及如何继续查询原申请。

## What Changes
- 对 SHUIHANG_TAX_LOGIN_REQUIRED 按 INVOICING/FAILED 显示已确认的安全中文提示。
- 处理中保留原申请查询；真实失败保留现有用户主动重填能力，不自动重试。
- 已开票忽略旧错误码，未知码不直接展示；不要求买方输入销方验证码或显示登录倒计时。

## Impact
仅 Flutter commerce 展示策略、发票详情和定向测试。接口仍用 INVOICING 表示处理中，后端内部 PROCESSING 不成为新客户端状态。无平台、依赖、数据库、支付或开票服务操作。
