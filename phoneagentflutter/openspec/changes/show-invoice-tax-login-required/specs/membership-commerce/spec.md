## ADDED Requirements

### Requirement: 税务登录异常须显示安全的状态说明
客户端 SHALL 对 safeErrorCode 为 SHUIHANG_TAX_LOGIN_REQUIRED 的 INVOICING 发票显示“开票暂时受阻，开票方需重新完成税务登录。申请已保留，请稍后查询，无需重复提交。”；对真实 FAILED 显示“本次开票未成功，开票方需重新完成税务登录。请联系售后，待恢复后再申请。”。客户端 SHALL 保留服务端原状态，不以该错误码自行判失败，不展示未知供应商错误码、销方验证码输入或固定登录倒计时。

#### Scenario: 供应商已受理但销方需登录
- **WHEN** 发票为 INVOICING 且带税务登录错误码
- **THEN** 页面显示暂时受阻提示和原申请查询入口，不展示提交或重新填写，不自动发起新申请

#### Scenario: 真实失败后用户主动重新申请
- **WHEN** 发票为 FAILED 且带税务登录错误码
- **THEN** 页面显示真实失败提示，原有 invoiceAllowed 门禁及用户主动重新填写能力保持，不自动重试

#### Scenario: 已开票或未知错误码
- **WHEN** 发票为 ISSUED 或错误码不属于安全提示白名单
- **THEN** 不显示旧税务登录提示或原始未知错误码，已有状态及文件权限保持
