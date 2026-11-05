# 验证记录（2026-10-22）

## 实现与范围
PhoneAgent / Flutter / auth presentation，notice owner 为 AuthController。sendCode 的未知错误兜底为“获取验证失败，请稍后重试”；submit 为“登录失败，请稍后重试”。显式传入入口文案，保留原 generation 校验和全部已分类映射。网关、请求、冷却、成功、邀请、本地保存、页面与共用 Toast 均未修改。工作前已有商城页面、商城测试及相关 OpenSpec 改动，未纳入本轮。

## 回放证据
- RED：修改测试后、控制器修改前，15 项中 3 项失败。未知 StateError 仍显示“登录暂不可用”；两个入口的空 message 仍显示“登录失败”，均不符合新合同。
- GREEN：6 个直接相关文件 66/66 通过：auth_controller_test、dio_auth_gateway_test、auth_request_diagnostics_test、auth_invite_draft_persistence_test、sms_code_focus_test、auth_web_flow_test。
- AUTH-FALLBACK-01/02：两个入口分别覆盖非空、空、空白 AuthMessageFailure、StateError、Exception 和未知对象；核对固定文案、busy 清除、无成功冷却及后续成功重试。
- AUTH-PRESERVE-01：保留所有 AuthFailure 已分类文案、发送成功、登录成功、六位校验、邀请 challenge 和本地保存重试测试。
- Flutter 3.32.0 / Dart 3.8.0，两处改动 Dart 文件 analyze 无问题，格式及 git diff --check 通过；本 change OpenSpec strict 通过。

## 其他检查失败及边界
初次扩大到 auth_session_widget_test 共 68 项，67 通过、1 失败：iOS 登录/恢复首页用例退出后仍有 IosPaymentRuntime.restore 的 5 秒及 boundRecovery 的 15 秒 Timer。临时隔离副本保留工作区其他内容，仅将 auth_controller.dart 换回 HEAD 原实现，同一文件仍为 Android 1 通过、iOS 1 同样 Timer 失败，故不为此扩大修改支付模块或改断言。不是全套 auth 通过。

未发送真实短信、真实认证、打包、安装、提交或推送；未将本地模拟验证作为真机验收。不归档本 change。
