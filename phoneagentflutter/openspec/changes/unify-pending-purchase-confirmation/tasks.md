- [x] 对照 NativeConfirmationDialog、NativeBusinessDialog 与 logout 用法，读取待处理购买现有规格。
- [x] 现有 widget 测试先 RED：13 项中 7 通过、6 失败，均为找不到 NativeConfirmationDialog 的行为断言。
- [x] 最小替换 builder，保留生命周期/账号/业务保护。
- [x] 定向三文件 23 项通过；analyze 无问题（30.4 秒）、OpenSpec 全仓 133 项通过及本 change strict；中文/diff 检查通过。
- [x] 将公共 tasks/issue 更新摘要交主代理统一记录，不并发修改公共文档。

## 验证与交付摘要

基点 255e59fd；生产仅 pending_membership_purchase_sheet.dart 的导入及 builder，widget 测试仅 pending_membership_route_test.dart。测试命令：固定 Flutter 3.32.0 的 flutter test test/features/commerce/pending_membership_route_test.dart test/features/commerce/pending_membership_controller_test.dart test/native_confirmation_dialog_test.dart --reporter expanded，以及 flutter analyze。

日志位于 D:/Temp/story1837-pending-dialog-{red,green,analyze,spec}-20261014.log。覆盖 Android/iOS 统一组件、危险/次要按钮、确认/暂不取消、切号、页面销毁、320 宽两倍字、确认期间暂停和退出后恢复轮询、可信终态/未知保留。未操作设备、真实关单、打包或提交，不以 widget 测试宣称渠道取消成功。

公共任务/issue 建议：待处理购买取消弹窗从默认 AlertDialog 改为统一 NativeConfirmationDialog；业务关闭失败根因由后端单独调查；保留服务端终态权威。现有查询 timer 为 5 秒，Java 默认 queryIntervalSeconds 为 15，运行配置需另核，可能触发限流提示；本次样式修复未调整这些规则。
