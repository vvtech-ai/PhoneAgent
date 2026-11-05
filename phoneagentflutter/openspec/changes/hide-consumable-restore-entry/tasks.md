# 实施任务

- [x] 用户确认范围，登记基线并更新会员入口规格。
- [x] 修改会员页入口接线并调整受影响显示断言，保留恢复能力测试。
- [x] 执行静态检查、会员页与交易恢复定向回归，记录结果。

## 验证结果（2026-10-22）

- Flutter 3.32.0 / Dart 3.8.0；flutter analyze --no-pub通过，无问题。
- flutter test --no-pub：apple_restore_visibility、ios_transaction_recovery、ios_payment_wait、membership_partial_page、platform_purchase_availability、unpublished_catalog六个测试文件，共71项通过。
- OpenSpec 1.14.1：本change --strict通过；Dart格式检查及git diff --check通过。
- App根部仍watch iosCommerceRecoveryProvider；初始化restore、前台与网络恢复触发路径未改，原生Transaction.updates/unfinished及验单器未改。
- 未打包、未安装、未进行真实支付或杀进程真机验证，不声称已完成所有异常的端到端验证。
