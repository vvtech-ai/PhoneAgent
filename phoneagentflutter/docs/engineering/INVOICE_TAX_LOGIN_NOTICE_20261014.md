# 税务登录异常开票提示（2026-10-14）

## 约定与范围

用户要求开票遇到销方税务登录失效时，App 明确提醒。沿用当前发票契约：供应商处理中在 App 仍为 `INVOICING`，服务端附 `safeErrorCode=SHUIHANG_TAX_LOGIN_REQUIRED`；内部 `PROCESSING` 不作为新 App 状态。仅真实拒绝/失败对应 `FAILED`。不由客户端猜登录有效时长或改变发票状态。

本次工作树 `D:/work/04phoneAgent/_isolated/story1837-flutter`，基线 detached `99daa3e0`。未切分支或修改其他 worktree。OpenSpec `show-invoice-tax-login-required` 先行，产品微批三个文件：

- 新 `invoice_status_presentation.dart`：安全错误码与可信状态的用户说明；不返回供应商原始内容。
- `invoice_sheet.dart`：在状态下方显示可换行、可滚动说明，仅新增展示接线。
- 新 `invoice_tax_login_test.dart`：解析、状态展示、动作、布局及真实 Repository/Controller 查询防重验证。

DTO 已接收错误码，无需新增字段。Controller、原申请身份、付款/履约、草稿重试规则不改；邮件售后仍沿用已发布目录和已有页面入口，不增加手机号、验证码或税务登录界面。

## 用户可见行为

- INVOICING：“开票暂时受阻，开票方需重新完成税务登录。申请已保留，请稍后查询，无需重复提交。”状态仍显示开票中，保留查询原申请，不展示提交/重新填写。
- FAILED：“本次开票未成功，开票方需重新完成税务登录。请联系售后，待恢复后再申请。”保留真实失败标签和原 `invoiceAllowed` 门禁下用户主动重新填写能力；不自动重试。
- ISSUED 即使带旧登录错误码也不显示异常说明；未知码或空码不原样显示，文件权限保持服务端允许格式。

## 实际验证

1. 红测：新 9 项中 4 通过、5 失败，失败均为当前生产页面缺少已约定提示文案；不是编译错误。日志 `D:/Temp/story1837-tax-login-flutter-red-20261014.log`。
2. 绿测：Flutter 3.32.0 `flutter test --no-pub --concurrency=1 --reporter expanded` 执行 `invoice_tax_login_test.dart`、`invoice_controller_test.dart`、`invoice_draft_test.dart`、`invoice_keyboard_layout_test.dart`、`invoice_sheet_test.dart`、`server_contract_compatibility_test.dart`、`commerce_support_contact_test.dart`，**33 项通过，无跳过**。日志 `D:/Temp/story1837-tax-login-flutter-green-20261014.log`。
3. 新测试覆盖 Android/iOS 两套提示与显式动作，320×568 双倍文字不溢出、滚动说明及固定查询按钮可达；处理中 Controller 不允许清除原申请或重复 submit，Repository 两次请求均为原订单 GET、无 POST 或文件下载。既有真实失败草稿保留与重填门禁、跨账号晚到响应、企业敏感输入、文件权限和邮箱来源一起通过。
4. `flutter analyze --no-pub` 无问题，27.1 秒。日志 `D:/Temp/story1837-tax-login-flutter-analyze-20261014.log`。
5. 新 change strict 校验通过；`openspec validate --all --no-interactive` 全仓 118 项通过。额外全仓 strict 为 114 通过、4 警告失败：既有 `app-foundation`、`conversation-error-status-sync`、`migration-governance`、`web-development` 的 Purpose 少于 50 字符。已逐项核实，仅历史规范警告，不改无关文档。
6. 修改文件 UTF-8 中文回读与 `git diff --check` 通过。

## 合入最新开发分支后的复验

实现提交为 `e89b7660`，保留远端新增工作后合并 `origin/codex/dev@bb4f015d`，合并提交 `41110ed1`。未覆盖其他工作区或重置分支，两边进度记录均保留。合并后上述 33 项测试再次全部通过、无跳过，`flutter analyze --no-pub` 无问题（30.7 秒），本次 OpenSpec strict 校验通过。日志为 `D:/Temp/story1837-tax-login-flutter-merged-green-20261014.log` 和 `D:/Temp/story1837-tax-login-flutter-merged-analyze-20261014.log`。

## 交付边界

合成协议和 widget 测试不替代真实税航或设备验收。后端代码部署与手机安装尚未完成，不能声称手机已经出现新提醒。本次 Flutter 工作未创建真实发票、登录税局、读取验证码或操作数据库；真实小额蓝票及冲红的独立供应商验收由 Java 仓库报告记录。
