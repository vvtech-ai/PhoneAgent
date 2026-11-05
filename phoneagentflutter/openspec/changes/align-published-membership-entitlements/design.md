## 设计
支付展示由 commerce_order_display 映射 paymentState，订单模型状态机不变；详情分别显示支付和履约说明。会员权益列表使用 cloneEntitlements.enabled，克隆准入仍读取当前 membership，发布目录仅生成支持等级说明，失败可重试、切号迟到失效。

ProductOffer/DTO 增加 regularPlatformProductId、discountMembershipLevel 可选字段；CatalogController 同次查询购买 SKU 与普通 SKU。积分包价格采用独立纯 Dart policy：Android originalCashAmountFen/cashAmountFen，iOS 保留所选 SKU displayPrice，仅同币种结构化 price 十进制转 BigInt 后比较。无普通价只给有效等级专享标签，无真实折扣不显示原价或折扣。购买仍使用原选定 SKU，金额预检不变。独立价格组件接入卡片，不把计算堆入页面。

后端提供当前已发布模型、折扣及克隆权益，历史月赠等保持快照。翻译 API 按当前账号过滤模型和国家关联 ID，客户端不按等级猜测授权。购买Provider在会员可信履约完成后失效翻译目录，正式模型面板每次打开重新读取，刷新期间不显示旧选项、不允许旧动作选中；preview不触发读取。沿用账号、地区和路由代次保护，不轮询或打断通话。

## 验证
每手写微批最多三文件，UTF-8 中文读回。先 RED 后 GREEN，覆盖六支付态、履约独立、克隆非连续等级/排队/失败重试、DTO 兼容、Apple 金额币种/缺失普通价/无折扣/免费及普通 SKU 查询。运行受影响 commerce、voice_clone、直接调用方定向测试、flutter analyze、OpenSpec validate；不打包安装或真实支付。
