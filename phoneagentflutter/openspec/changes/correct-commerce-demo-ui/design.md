# 设计

## 来源与现状
指定Demo分支fetch后仍为7e7bd38。来源为 `monetization-demo/css/monetization.css` 及相同版本联动客户端。v67邀请和流水继续按用户明确指定保留；会员/永久积分分类不再上App。

## 文件职责
- 新增membership_balance_card：总额、预占和流水入口的紧凑展示；从membership_page提取，不扩展已有页面职责。
- 新增commerce_agreement：会员与积分包共享的圆形勾选及协议链接展示，回调沿用购买controller。
- 新增commerce_display_format：展示千分位与整数元价格；平台本地化StoreKit价格原样保留，服务端报价/金额契约不变。
- membership_offer/points_purchase_page：会员权益顺序和细分隔、周期卡/积分包选中态与商品显示。
- invoice_sheet：表单整行分隔和原型说明。不开新字段，不修改开票或支付生命周期。
- purchase_completed_summary：只有服务端支付/履约双成功时使用原型简洁成功反馈，原单金额等可展开；处理中/失败/本人恢复保持既有详情与操作。

现有文件均先检查职责与体量；改动按不超过3个手写文件的微批进行。新增同类展示可组合现有展示组件，不新增业务状态机或全局主题覆盖。

## 验证
先保存旧同数据绘制并重现差异，再逐批修正。375/390/430宽度、1/2倍字号、键盘及未加载/404状态；同一合成目录与订单在原型和测试呈现，不以组件截图声称真实购买成功。最终analyze、定向测试、OpenSpec及中文回读；同签名Android保留数据安装后验收可达真实页面。
