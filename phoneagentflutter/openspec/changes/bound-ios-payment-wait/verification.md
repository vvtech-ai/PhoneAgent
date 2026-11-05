# 验证结果与未执行项

2026-10-22，源码基线 codex/dev@6689ec49。用户确认计划后执行本轮；保留此前取消恢复修改，无提交、推送、安装、部署或线上订单写入。

## 本轮检查
- Flutter 3.32.0：`flutter test --no-pub test/features/commerce --reporter expanded` 退出0，800项通过，39秒；日志 `/tmp/phoneagent-ios-payment-final.log`。
- `flutter analyze --no-pub` 退出0，无问题，13.1秒。
- 两个active change：`bound-ios-payment-wait`、`resume-apple-cancellation-after-recovery` 经已缓存 OpenSpec CLI strict 校验 valid；未安装新依赖。
- `git diff --check` 及新增文档 UTF-8读回通过。PurchaseController 496行，新运行时326行，均低于500行。
- `git diff --name-only` 无 pages/widgets、Android、iOS原生文件。UI复用原加载/反馈/原订单入口，测试覆盖原有会员、积分、订单及Android页面。

## 新增连续回放
- 默认原生30秒（测试断言生产配置，运行时使用短期限回放），无反馈时控制器 busy 释放，保留原单和“支付结果待确认”，无取消请求。
- 支付材料迟到超过界面等待期限，不在用户已退出等待后才偷偷调起支付。
- 迟到成功自动回原验单，后端成功前不 finish；确认后只 finish 一次、同原单刷新。
- 迟到取消失败保存原请求ID；成功补报后原待办清理；不保留过期的“结果未知”反馈。
- canceled尝试写入后进程中断、outbox尚未写入时，重启可重建唯一待办。
- 等待中杀进程恢复waiting记录，不制造取消；原生发现卡住后仍查询服务器；整个恢复超时后旧响应不覆盖当前状态。
- 存储失败不调起；同单并发仅一次原生调用；旧账号迟到不提交；作用域隔离及旧attempt清理不能删除新记录。
- Android provider 不读取iOS存储或取消owner，保留原launcher和ALIPAY渠道；Android不启用等待期限。
- 诊断包含attemptStore/nativeWait等阶段，不含原订单号、绑定token、签名交易正文。

## 架构检查的既有失败
`test/architecture_test.dart` 本次运行两项失败，均与HEAD内容核对一致：
1. `conversation_call_controller.dart` HEAD为1038行，测试登记上限507；本轮未修改该文件。
2. `domain/apple_cancellation_outbox.dart` HEAD已经引用`package:crypto/crypto.dart`，违反测试对domain包依赖的限制；本轮保留其既有稳定请求ID算法，未改变该导入。

未删除断言、未新增架构豁免，不将其报告为全仓验证通过。

## 限制
所有支付和持久存储自动化使用模拟端口；不是iPhone沙盒和实际磁盘权限验收。实际iOS断网、杀进程、迟到StoreKit事件和原未完成订单结单仍需安装后验证。本轮未构建或安装，因此手机现有订单不会因本地改动直接改变。未知结果仍保留原单，不保证无交易证据时自动结单，不推断扣款。
