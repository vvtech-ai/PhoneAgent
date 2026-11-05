# Tasks
- [x] 读取日志与原有购买/恢复代码，定义只读诊断范围。
- [x] 拆分 iOS 校验阶段并接入脱敏交易/商品标识。
- [x] 验证隐私过滤、日志往返及支付恢复回归。
- [x] 执行 analyze、Swift 与 OpenSpec 检查并记录结果。
- [ ] 新包真机重现，确认具体失败阶段和是否返回历史交易。

## 验证结果
- Flutter 3.32.0：commerce_diagnostics_test、commerce_flow_diagnostics_test、ios_payment_feedback_test、ios_transaction_recovery_test 共 17 项通过；含新阶段持久化往返、标识脱敏、非法字段过滤及原支付恢复回归。
- flutter analyze --no-pub：No issues found。
- xcrun swiftc 语法检查及 iOS 16.1 arm64 simulator + Flutter framework 类型检查通过；不是完整 App 构建或设备验收。
- openspec validate --all：218 项通过；git diff --check 通过。
- 未打包、安装、触发真实支付或提交推送；需将这些原生和 Dart 修改一并编入新包后重现并上传日志，旧包不产生新增字段。
