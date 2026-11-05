# 设计

后端从已验证的原订单环境输出 `parameters.environment`。Flutter DTO 和 MethodChannel 已保留全部字符串参数，不新增 Dart 环境配置或默认值。Android 桥在创建 pending 之前通过小策略验证参数，缺失或未知值返回 CHANNEL_UNAVAILABLE；支付任务沿现有单线程 executor，在 payV2 前设置 SDK 的进程级环境。SANDBOX 对应 EnvUtils.EnvEnum.SANDBOX，PRODUCTION 对应 ONLINE。每次调用都设置，避免此前沙箱调用影响下一次生产调用。

`AlipayPaymentEnvironment` 只负责严格环境解析和执行 SDK 环境设置；`CommercePaymentChannel` 保留 Activity、MethodChannel、任务生命周期与结果通知职责。类似平台环境规则可在自身适配器扩展，不进入购买状态机。

回归使用真实 SDK EnvUtils 的内存状态和合成支付回调，验证设置顺序、生产复位及错误环境拒绝，不调用 PayTask、不使用凭据。Flutter 边界测试验证服务端材料环境抵达 MethodChannel。原生返回仍仅触发签名原单查询，取消、超时不能释放原订单。

本批验证为 Android JVM 定向测试、Flutter 支付直接调用方测试、analyze、debug APK 编译和 OpenSpec。真实沙箱支付与真机安装仍待另行授权验收。
