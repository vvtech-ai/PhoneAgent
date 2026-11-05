# 验证记录

2026-10-22，基线 codex/dev@edbf251193afb08ac90f40c3a427ad4ed8a97845。未改原生StoreKit、服务器协议、Android支付逻辑，未提交/推送、未安装或发起真实购买。

- 新回归先红：旧两层期限下，Apple未返回时state.error变为“支付结果确认中，请查询原订单”，与空错误期望冲突。
- 修复后 `flutter analyze --no-pub` 无问题。
- `flutter test --no-pub test/features/commerce --reporter expanded`：815项全部通过。日志 `/tmp/phoneagent-ios-payment-commerce-tests-final.log`。
- 随后补充“等待期间查询后再取消”的原单清理回归；阶段文件7项全部通过。日志 `/tmp/phoneagent-ios-payment-phases-final.log`。已有815项结果与追加单项分开记录，不声称运行过816项全量。
- 重点覆盖长于期限的Apple操作、模拟61秒无回调且可查询/返回、核验超时释放及迟到成功/finish一次、权益处理中超时、查询后成功/取消、离页后的账号内恢复；旧测试保留存储失败、取消网络失败、原请求ID、旧账号、到期迟到付款和Android边界断言。
- 广泛回归先发现取消网络失败被吞和成功取消后restore重新生成待办；按原合同修复，未删既有断言。补报成功返回订单交给运行时observe清理，失败仍保留原待办与错误。
- `flutter build ios --debug --no-codesign --no-pub`：成功，`build/ios/iphoneos/Runner.app`，bundle ID com.chaken.phoneagent.test，Xcode阶段14.6秒。日志 `/tmp/phoneagent-ios-payment-build.log`。
- 构建执行pod install，为基线已配置的崩溃诊断组件更新本地Pods。Podfile.lock与project.pbxproj的自动写回已恢复到进入时内容，不混入本次支付改动；此结果为本机可编译证据，不是锁文件一致性或正式分发验收。

未验证：真实设备上的Apple弹窗、密码/验证流程、沙盒pending/成功及长时间无回调；未确认当前安装包身份。构建不替代真机回放，本变更不归档。

## 按用户截图反馈恢复原遮罩

用户明确否决底部提示，要求只用原全屏加载遮罩。删除ApplePurchaseWaitingNotice并提取原有遮罩为共用PurchaseLoadingOverlay；支付阶段计时、取消补报及交易恢复逻辑不变。之前“61秒无回调可在页面点击查询”的展示验收被用户最新决定覆盖，改为“61秒仍显示原遮罩、无底部提示、不提前报支付结果待确认；回调到达后撤下遮罩”。不得将此版本描述为解决永久无回调遮罩问题。

- 支付阶段与原等待测试23项通过：`/tmp/phoneagent-ios-original-overlay-tests.log`。
- 静态检查无问题。
- 本轮仅Dart展示调整，未重新执行iOS打包或真机支付；前述构建证据属于上一轮。
- 恢复原遮罩后的商城全量816项全部通过：`/tmp/phoneagent-ios-original-overlay-commerce.log`。
