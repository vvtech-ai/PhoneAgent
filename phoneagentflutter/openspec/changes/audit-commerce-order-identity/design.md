# 设计

PurchaseResultRoute 的 orderNo 是详情身份事实源，共享 PurchaseController 仍负责串行支付和恢复。路由遇到不同原单时隐藏状态及动作，等待现有请求结束后查询指定原单，不新增第二套支付控制器。未带 orderNo 的恢复入口继续展示控制器发现的原单。

订单身份修复修改 purchase_result_route.dart；测试分别覆盖旧单未决、旧单已完成及目标查询失败后重试。不调整稳定平台桥，不改变现金/履约/权益状态投影，不产生真实支付或开票。类似路由继续用显式订单身份接入现有控制器。

追加 Apple PENDING 原单重试：独立 helper 只读查询原单响应中的 platformProductId（来自原单锁定快照），再读取 StoreKit 当前价并要求确认。报价发现不得调用会将PENDING转PROCESSING的payment接口。只有用户接受后，_launch才唯一一次准备材料并核验同SKU/价格。控制器保持busy和账号/页面归属检查，订单详情和待处理弹窗共用独立确认组件，不创建替代单，不将未知结果判失败。

最小服务端增量契约：订单DTO顶层nullable string platformProductId；只能来自订单锁定渠道商品，不从现目录回填。旧订单无SKU则不允许客户端猜测续付，仍保留查单/安全结束。CommerceOrder与CommerceDto接收同字段，测试模拟prepare真实改变PROCESSING，明确拒绝/取价失败/页面离开零prepare、接受仅一次。

最终纯领域 confirmed_payment_material.dart 统一原单/渠道绑定与已接受的Apple价格校验，控制器只保留编排，保持500行；没有放宽架构测试。未来新渠道继续通过PaymentLauncher和材料适配接入，不在UI中生成支付事实。
