# 2026-10-14商业化分支集成验证

## 固定输入
目标codex/dev 255e59fd89996e39b4eb9269f808b77307729427，来源codex/dev_zys 9cdc1b4ff6192775aff2e34cb63210b89abb2280；fetch后本地/远端相同，工作区起始干净。当前其他两个工作树不改。

## 解决7处冲突及自动合并复核
- CommercePaymentChannel.swift：先保留dev StoreKitPriceValidation对服务端expectedCurrency/expectedCashAmountFen的CNY精确锁价，再执行来源expectedPrice/type确认快照校验；两类错误和原生诊断均保留。
- DevicePaymentLauncher：保留安全诊断、PRICE_CHANGED映射及APPLE_IAP专用APPLE_PRICE_UNAVAILABLE映射，去除重复import。
- MembershipCheckout：保留dev purchaseEnabled独立开关与来源Apple商品/类型/金额门禁、报价身份和确认后预检。
- MembershipOffer：同时保留readOnly平台模式与onReloadProducts整列表重试参数，保持共用控件。
- RunnerTests：纯Foundation5方法与本地StoreKit2场景分成两个类，避免纯金额测试被StoreKit setUp故障阻挡；本地场景补服务端锁价字段。
- direct_checkout_route_test：保留dev待处理购买/平台入口测试与来源iOS未选协议拒绝完整接线测试。
- storekit_attempt_feedback_test：保留专用价格失败、未知失败、已付优先以及取消/Pending/恢复测试，补事件mock和Apple预检响应。
- 自动合并后PurchaseController保留服务端expectedCurrency原值（不以本地CNY覆盖或补造），只叠加确认的expectedPrice/type；新增3场景检查CNY/USD/缺失字段均原样到原生。自动合并反馈补回已知价格/币种不可购提示；未知Apple结果仍查询原单，不重复支付。
- 独立StoreKit宿主工具加入dev StoreKitPriceValidation源码引用，避免合并后失去链接。来源积分完整流fixture补服务端CNY/分字段。

共同修改17路径逐项核对；79个单侧变化的index blob保持正确父版本，主动例外为上述宿主工具和积分测试fixture；dev开票/税务逻辑单侧文件不改。修改源码最高500行（PurchaseController），无新增超限例外。

## 实际验证
- 商业化、app_logs、共享media诊断、session嵌套路由/生命周期首轮471通过3失败（474项，非全量）：1项fixture缺服务端币种，2项价格失败测试未提供新增商品预检。
- 补fixture复验16通过2失败：自动合并通用Apple反馈覆盖了已知不可购原因；补回专用提示，未知结果按来源原单查询语义更新断言。
- 最终受影响9文件67项全部通过（与首轮重叠不相加），涵盖锁价材料跨Controller/桥、价格变化、原单/支付事实优先、反馈与几何布局；不重复全仓。
- flutter analyze --no-pub最终4.4秒无问题。
- iOS Debug无签名编译：首次11.3秒、最终8.0秒通过；仅初次Pod install1.569秒，无Podfile/lock/pubspec.lock变化。
- StoreKitPriceValidation与原5组测试方法的断言在macOS临时纯Foundation宿主直接执行通过。它不是XCTest或iOS StoreKit运行通过。
- Ruby工具语法检查Syntax OK；diff检查通过。OpenSpec全仓134通过、0失败。

## 工具恢复及边界
尝试CLI执行XCTest时先缺模块、加framework路径后缺Swift断言overlay、核对路径补overlay后发现Apple XCTest无XCTMain/testCase入口。按有限恢复停止该方式，保留XCTest/StoreKit运行待验；另以原5方法和断言作临时Foundation直接执行，通过但不冒称XCTest。已发生结果仅临时编译输出，无手机或业务操作。首轮引用不存在可选preflight文件后读取实际controller/锁价报告确认服务端字段权威，无产品副作用。

未安装、卸载、清数据、收费、外呼、开票或改后端。来源原StoreKit配置Code3、真实SKU/沙盒/履约与双端设备诊断保持待验；不归档。仅非强制推送origin/codex/dev，来源分支不改，远端回执见下。

交付回执：合并提交61e22aef430c1d3bc1db7f565c7d31cb2e49ea8f，两父版本255e59fd与9cdc1b4f、祖先检查通过。非强制push成功，ls-remote确认origin/codex/dev同值，来源origin/codex/dev_zys仍9cdc1b4f。OpenSpec134通过/0失败；随后仅补交回执文档，不改产品。
