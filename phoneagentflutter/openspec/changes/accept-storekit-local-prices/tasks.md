- [x] 追踪客户端与 Java 的 CNY/金额门禁、落账/恢复/统计依赖，向主代理报告设计。
- [x] 客户端移除原生 CNY 等价检查与失效错误分支，保留身份/交易校验。
- [x] 商品及升级确认采用 StoreKit 本地化显示，移除 Apple 特有后台价格门禁；真实 Dart RED/GREEN。
- [x] 对接主代理冻结的可信当地实付 DTO，完善订单金额展示和回归。
- [x] 定向 Flutter 测试/analyze/OpenSpec/中文检查，公共任务摘要交主代理。
- [ ] 后端可信 JWS 多币种验证/精确落账与真实履约（主代理负责）。
- [ ] Mac/Xcode 编译及 StoreKit 地区购买验收（本机不可运行）。
- [x] 缺可信 Apple receipt 的已付订单不回退人民币现金字段；定向 RED/GREEN、analyze 并冻结交付。

## 2026-10-14 客户端实施证据

- 在 4db3aaea 合并基线上实施；保留新 StoreKit recovery/diagnostics/价格加载逻辑。冲突只处理 storekit_attempt_feedback_test，恢复备份 stash 不删除，源码未提交。
- 每源码微批不超过 3 文件：原生 bridge/helper/Xcode；catalog/checkout/purchase；失效错误码与诊断；升级 route/widget；receipt domain/DTO/格式化；订单/恢复/完成展示。独立 PlatformPaymentAmount 负责精确 milliunits 值格式，order_payment_amount 负责兼容展示，未向核心 controller 加金额格式化。
- 实际 RED：合并前通道/反馈 13 项 11 过 2 失败；合并后通道/反馈/catalog/preflight 23 项 17 过 6 失败。升级 route USD 显示缺失单项真实失败；receipt DTO/展示 5 项全部失败。日志 D:/Temp/story1837-apple-local-price-merged-red-20261014.log、story1837-apple-upgrade-red-20261014.log、story1837-apple-receipt-red-20261014.log。
- 首轮 commerce 375 项 372 过 3 失败：2 项旧人民币材料断言已按覆盖需求更新；1 项新增测试未及时恢复平台 override，修正测试生命周期。receipt/升级/材料后续 15 项通过。
- 修正后的 commerce 389 项通过；附加确认弹窗路径误写带来 1 个文件加载错误，正确路径 test/native_confirmation_dialog_test.dart 单独 2 项通过，随后使用正确命令复验。误写日志保留 D:/Temp/story1837-apple-final-commerce-20261014.log。
- 最终正确命令 `flutter test test/features/commerce test/native_confirmation_dialog_test.dart --reporter expanded`：391 passed，exit 0（63s）。日志 D:/Temp/story1837-apple-final-green-20261014.log，覆盖所有 commerce 及已合并的取消确认 UI 回归。
- flutter analyze：No issues found（15.2s）；OpenSpec 136 passed/0 failed；git diff --check 与 UTF-8 中文回读通过。
- RunnerTests 保留新上游本地价格变更/unfinished/Ask-to-Buy，删除撤销规则的 5 个旧纯校验测试，增加美国 StoreKit 本地购买用例。Windows 未执行 Swift/XCTest，也未构建包、安装或操作设备；不能将 Dart 通道成功视为原生购买验收。
- Java 多币种可信支付事实、会员参考计价及 Web 由主代理协调；未运行 Maven、未访问真实数据库/供应商/付款。公共 tasks.md/issue 交主代理合并。

## 2026-10-14 缺失可信回执修正

- 仅改 order_payment_amount 一个生产文件：Apple 已付且原币字段缺失/双 null 显示“以 Apple 账单为准”，不因 cashPaidFen 为正而推断人民币实付；待付提示不变，支付宝不变。
- 真实 RED：receipt 9 项中 7 通过、2 失败；修复后 receipt/DTO/订单/结果/发票 16 文件共 76 项通过。新增 cashPaidFen=3900、原币双 null 的订单列表回归，明确不显示 ¥39.00。
- Flutter 3.32 analyze 无问题（38.0s）；OpenSpec 137 通过、0 失败；UTF-8 中文回读和 diff 检查通过。日志 D:/Temp/story1837-apple-null-receipt-{red,green,analyze,openspec}-20261014.log。
- RecoveryPreview 无渠道字段，recoveryPaymentAmount 保持原兼容逻辑；服务端须拒绝无可信金额的 Apple 恢复预览。本批不构建、安装、提交或推送，交主代理重新构建。
