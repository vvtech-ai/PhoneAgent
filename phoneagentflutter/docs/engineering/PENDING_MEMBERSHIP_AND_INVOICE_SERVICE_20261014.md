# 未完成会员购买与开票服务提示

实施基线为隔离工作树 story1837-flutter 的 22a80a06。主任务批准本批实现、统一后续提交交付；本批未操作设备、构建 APK、提交、推送或调用真实支付/开票。

## 用户行为

- 会员页“处理待购买事项”直接查询原购买，选套餐时已有未完成会员购买也进入同一简洁弹层。显示继续支付、取消本次购买、刷新状态及稍后返回，不显示订单号和技术明细。
- 取消需要用户确认，通过现有原单 close 请求服务端核验。ALIPAY PENDING/PROCESSING、NOT_STARTED、实付为零时允许请求取消；canPay 保持原义。历史详情使用同一取消请求资格。
- 仅精确服务端 safeErrorCode=PAYMENT_CANCELLATION_PENDING 表示持久化取消中；此时显示“取消处理中，请稍后查看”，隐藏继续支付与重复取消。显式重试及幂等 create 返回旧单的自动唤醒路径都禁止继续支付。可信支付成功优先，旧错误不能覆盖已支付事实。
- legacy 未知且无取消码仍允许原单受控重试；关闭未知提示取消结果尚未确认，不假报成功。客户端不按 SDK 6001/4000、本地时间或 expiresAt 释放，不提供释放倒计时。
- 支付等待隐藏全部购买操作，返回复用原 PurchaseFeedbackSheet，只展示结果与完成。定时查询保留，退出后停止；确认期间切号不得关闭旧购买。
- 可信结束后退出弹层并同步刷新原单、会员摘要与钱包；会员页下拉刷新和历史页面返回也查询原单，防止陈旧控制器继续阻挡报价。
- INVOICE_SERVICE_UNAVAILABLE 白名单映射固定“开票服务暂不可用，请稍后重试”，真正的 INVOICE_NOT_ALLOWED 保持资格拒绝说明。失败草稿与同次申请身份保留，未知错误与供应商原文不曝光。

## 文件职责与批次

1. CommerceOrder 独立取消/重试规则，PurchaseController 关闭准入及自动唤醒门禁；没有扩展 canPay。
2. 新 PendingMembershipPurchaseSheet 为单一待处理购买交互，调用既有控制器；MembershipPage/Route 负责入口与同步刷新。新文件约 180 行，未把逻辑塞入已有结果页。
3. PurchaseResultPage 单独替换关闭资格，保持正常历史详情与支付时隐藏的既有规则。
4. ApiCommerceRepository/CommerceFailure 独立微批接开票新码；不修改开票 DTO 或生产控制器。

每个生产微批不超过三个文件；规格、测试、格式化和记录单独执行。后续渠道或状态扩展应仍通过领域资格与服务端安全事实接入，UI 不产生支付/释放事实。

## 实际验证

- 初始控制器 RED：7 项，4 通过、3 失败，分别复现 PROCESSING 不发关闭、取消中仍唤起支付、可信关闭未解除报价阻挡。
- 换套餐入口 RED：1 项失败，缺少待处理弹层。
- 初始 UI RED：7 项全部失败，入口缺失及手动刷新未更新旧购买状态；后补 320×568/2 倍字及确认期间切号用例。
- 历史详情资格 RED：1 项失败，PROCESSING 缺少服务端关闭入口。
- 幂等 create 取消门禁 RED：1 项失败，实际唤起支付 1 次；独立门禁修复后不唤起。
- 开票服务码 RED：4 项中 2 通过、2 失败，复现白名单拒绝及控制器只显示通用错误；未改真正资格拒绝。
- 中间一次 UI 编译发现 loginEpochProvider 类型为 int?，已修正可空声明；该编译失败不作为业务 RED。
- 最终 `flutter test test/features/commerce --concurrency=2 --reporter expanded`：308/308 通过，0 失败/跳过，73 秒。覆盖新增控制器 8、待处理页面 9、开票新码 4，以及既有订单、原生支付反馈、会员购买、开票和契约回归；不是全项目测试。
- 两个新 change 的 strict 校验通过；`openspec validate --all` 为 130/130。
- `flutter analyze` 初轮两处 use_build_context_synchronously，已显式补 mounted 检查；最终无问题，13 秒。UTF-8 严格解码/中文回读无 U+FFFD，git diff --check 通过。
- 显式 mounted 与 guard 花括号收尾后，三个新增测试文件最终 21/21 再次通过（不与前述 308 累加）；日志为 D:/Temp/story1837-pending-invoice-final-focused-20261014.log。

日志前缀 D:/Temp/story1837-pending-、D:/Temp/story1837-invoice-service-red-20261014.log；最终集合 D:/Temp/story1837-pending-invoice-commerce-green-20261014.log。保留全部首轮失败证据，不覆盖为通过记录。

## 验收边界

所有请求测试均使用合成内存仓库或本地 HTTP adapter，无真实交易、个人发票资料或供应商调用。新取消码、材料有效期与可信关闭的部署/运行态由 Java 主任务确认；旧材料的处理不能以 Flutter 本地解锁替代。设备视觉、真实支付宝和 Apple 环境未在本批验收。
