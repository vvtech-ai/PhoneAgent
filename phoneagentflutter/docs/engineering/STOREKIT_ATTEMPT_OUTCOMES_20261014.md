# StoreKit 取消 / pending 本地修复证据

日期：2026-10-14。工作树：story1837-flutter；分支：codex/story1837-membership-commerce。此报告只证明源码与 Windows 定向验证，不代表 Swift 编译、iPhone Sandbox 或付款成功。

## 修改及职责

- ios/Runner/CommercePaymentChannel.swift：userCancelled 返回 CANCELED，pending 返回 PENDING；verified 交易材料和 finish 路径不变。
- domain/payment_launcher.dart：可选 NativePaymentOutcome，仅 canceled / pending，没有客户端成功枚举。
- data/device_payment_launcher.dart：严格解析可选 nativeOutcome；旧桥省略/null 为未知，错误类型/未知值拒绝；Android nativeResultStatus 不变。
- presentation/controller/purchase_controller.dart：将尝试结果绑定原 orderNo，查询失败保留，同原单新尝试清除旧结果，另一订单不继承。
- presentation/payment_attempt_feedback.dart：服务端付款/履约优先；取消“支付已取消 / 本次支付已取消。”；pending“本次支付未完成 / 本次购买尚未完成。”，不提示再买。既有反馈只有完成按钮，未增加订单操作。

未修改公共 HTTP、报价、金额、创建/原单重试、关单、释放、支付确认与恢复 finish 条件。取消/pending 不会验证或 acknowledge 不存在的交易，不创建替代单。已有 diagnostics 文件仅状态标记，归一化 blob 与 HEAD 均为 8cc79fd4f68404d86fb2e18e86b4f59a38919034，未修改或重格式。

## 实际执行

所有命令 cwd 为 D:/work/04phoneAgent/_isolated/story1837-flutter，Flutter 固定 D:/tools/flutter-3.32.0/bin/flutter.bat。

| 阶段 | 真实结果 | 完整日志 |
| --- | --- | --- |
| 新增两文件 RED | exit 1，2通过/7失败；取消文案仍未知、坏 outcome 被忽略、缺可选字段 | D:/Temp/story1837-storekit-outcome-red-20261014.log |
| 首次实现后测试检查 | exit 1，5通过/4失败；dynamic 调用 enum.name 扩展不成立，后改静态类型断言 | D:/Temp/story1837-storekit-outcome-intermediate-20261014.log |
| 九文件定向 GREEN | exit 0，37通过 | D:/Temp/story1837-storekit-outcome-green-20261014.log |
| pending 文案追加 RED | exit 1，1失败；仍出现“请稍后重试” | D:/Temp/story1837-storekit-pending-copy-red-20261014.log |
| 最终新增两文件 + Controller | exit 0，18通过 | D:/Temp/story1837-storekit-outcome-final-green-20261014.log |
| analyze --no-pub | exit 0，30.3秒，无问题 | D:/Temp/story1837-storekit-outcome-analyze-20261014.log |
| 本 change strict | exit 0，有效 | D:/Temp/story1837-storekit-outcome-change-strict-20261014.log |
| openspec validate --all | exit 0，103通过/0失败 | D:/Temp/story1837-storekit-outcome-openspec-all-20261014.log |
| openspec validate --all --strict | exit 1，99通过/4失败，原有 Purpose 过短警告 | D:/Temp/story1837-storekit-outcome-openspec-20261014.log |

定向命令均为 `flutter.bat test --no-pub <以下文件> --reporter expanded`。九文件：storekit_native_outcome_test、storekit_attempt_feedback_test、native_attempt_status_test、native_payment_launcher_test、payment_attempt_feedback_test、purchase_feedback_sheet_test、original_payment_feedback_route_test、direct_checkout_route_test、original_order_retry_test，全部位于 test/features/commerce/，后缀 .dart。最终三文件为新增两文件和 purchase_controller_test.dart。pending RED 额外使用 `--plain-name 'PENDING queries original'`。

37与18重叠9个早期新增用例，新增新尝试隔离边界后覆盖共46个唯一用例；不将重跑计入额外覆盖，也未重复252全模块/全工程测试。覆盖旧桥兼容、严格解析、取消/pending、查单失败、同原单新尝试与另一原单隔离、服务端成功/履约异常优先、Apple未完成别账号与验证后finish、Android numeric、直购、升级、原单重试、单完成反馈。

四个 strict 基线为 app-foundation、conversation-error-status-sync、migration-governance、web-development；本批这四个 spec 的 git diff 为空。app-foundation 独立 strict 确认 Purpose 少于50字符，日志 D:/Temp/story1837-storekit-outcome-baseline-strict-20261014.log；既有问题不扩修。

## 未覆盖边界与价格后续

Windows 本轮没有执行 Swift/xcodebuild 或 iPhone 操作，原生编译与 Sandbox 的 userCancelled/pending 实测仍待 Mac/iPhone；OpenSpec 对应任务保持未勾。本轮未安装、未构建APK、未部署，不接触税航、凭据或实际账户数据。提交与推送由主任务核对差异和验证证据后执行。

数值价格仍是明确后续缺口：StoreKit bridge/PlatformProduct 目前只有 id/displayPrice，不能将本地化价格字符串当金额；Quote.cashAmountFen/currency 是业务报价，Catalog.platformProductId 是 SKU 映射，PaymentMaterial 没有已确认期望价格/币种。后续需冻结 exact Decimal 字符串及币种的原生查询契约，并确认原单/SKU/期望金额如何进入拉起前校验；不得以 double、月价倍数或猜新增 HTTP 字段补齐。本次不改价格规则或 API。

完整审查 diff（含新增文件、排除既有 diagnostics）由本批导出到 D:/Temp/story1837-storekit-outcome-final-20261014.diff。
