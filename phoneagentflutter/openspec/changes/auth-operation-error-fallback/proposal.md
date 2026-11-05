## Why
用户确认未识别业务错误不再展示服务器 message，改为按获取验证码和短信登录入口显示固定提示，覆盖 align-login-error-notices 的未分类异常展示约定。

## What Changes
- 获取验证码未知失败提示“获取验证失败，请稍后重试”。
- 短信登录未知失败提示“登录失败，请稍后重试”。
- 保留已分类业务错误、网络错误、成功提示、Flutter 共用 Toast 及页面样式。

## Impact
仅 PhoneAgent Flutter auth 控制器及定向测试。状态 owner 为 AuthController，入口为 sendCode / submit，对应既有发送短信及登录接口；请求参数、generation 身份校验、冷却、邀请及本地保存重试不变。网关继续负责分类，控制器负责最终 notice，页面继续复用共用 Toast。本次不涉及任务编排连续回放；用 AUTH-FALLBACK-01/02 覆盖两个入口，AUTH-PRESERVE-01 覆盖已分类错误及成功重试。无真实短信、认证、打包、提交或推送。
