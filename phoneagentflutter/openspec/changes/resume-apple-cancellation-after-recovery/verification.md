# 验证与限制

2026-10-22，Flutter 3.32.0。旧实现上先运行新增 provider 回放：恢复成功不再补报（期望两次、实际一次），启动失败仍补报（期望零次、实际一次），两项明确失败。

最终 `flutter test --no-pub test/features/commerce --reporter expanded` 退出 0，779 项通过，45 秒；日志 `/tmp/phoneagent-side-apple-recovery-tests.log`。覆盖启动离线后成功恢复、网络 unavailable→available 后无需重启、旧 native 错误保留时查单成功回调、同原 ID、并发、预算三次、非终态成功不重复、账号隔离、已支付不取消、存储与相邻验单/finish、支付和 UI 既有测试。

`flutter analyze --no-pub` 无问题，8.5 秒；`git diff --check` 通过，新增文档 UTF-8 及本地规格结构检查通过。OpenSpec CLI 未找到，未声称 strict 校验。测试中修正过网络事件测试的 fixture（无 Widget 场景使用普通异步测试，避免平台 debug override 与 Riverpod 虚拟 timer 的框架清理断言），及购买前旧订单已结束的前置条件，未删除业务断言。

仅本地修改，未提交/推送、未构建/安装、未修改服务器或订单。此前服务器日志已确认原单仍 PROCESSING，但无法确认旧安装包是否保存待办、具体补报结果；本修改只补恢复调用时机，不制造旧待办、不推断未付款、不直接结束订单。真机杀进程断网、真实 StoreKit 通知/结单及原订单验证待执行，不归档。
