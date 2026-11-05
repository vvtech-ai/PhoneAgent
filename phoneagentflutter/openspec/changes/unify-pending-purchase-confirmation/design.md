## 设计
现有 NativeConfirmationDialog 是 NativeBusinessDialog 的布尔结果适配器。退出登录使用 NativeBusinessDialog 的 confirmation/danger 组合，按钮由 NativeGradientAction 提供；本次直接复用，不创建另一套外观或独立大文件。

PendingMembershipPurchaseSheet._cancel 只替换 builder。保留 showDialog 的等待、_confirming 前后设置与 _current 检查，_current 同时验证 mounted、登录 epoch 和当前路由。业务请求仍交 PurchaseController，成功/未知状态按原契约显示。

先在现有真实路由测试增加统一组件和主次按钮 tone 断言得到 RED，再作最小替换；回归确认、不确认、切号、小屏/双平台及确认时查询暂停、离页销毁。该测试不证明真实支付渠道关闭成功。
