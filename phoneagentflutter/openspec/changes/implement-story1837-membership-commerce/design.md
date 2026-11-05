# 设计

## 边界

PDR v1.7 D01–D18为批准基线。导航知识库描述OMS，与本项目边界不同；以当前源码/PDR为准。数据库说明仅作为接口事实参考，Flutter不执行迁移。旧项目只读git show；不构建或改动。

## 模块与接线

- `features/commerce/domain`：纯Dart商品、会员、订单七态、报价、本人恢复、发票校验和repository/payment端口。
- `features/commerce/data`：严格DTO解析、AccountApi签名SDK请求、平台中立MethodChannel适配、受控文件下载。
- `features/commerce/presentation/controller`：购买/目录、订单、发票各自生命周期，dispose和请求代次守卫清理旧账号数据。
- `features/commerce/presentation/pages/widgets`：单页会员、积分包、结果、总积分与订单、开票Sheet；UI不访问网络或原生SDK。
- `app/commerce_providers.dart`：依赖注入，跟随loginEpoch重建；首页仅调整积分入口。
- Android/iOS独立原生支付桥接不向共享Dart加入渠道SDK/资源。

现有钱包page/controller已同时包含流水、余额和邀请展示，不塞入商业化状态机。类似新渠道只实现PaymentLauncher，商品/权益来自发布目录，不新增硬编码套餐或价格。

## 状态与安全性

支付PENDING/PROCESSING/SUCCEEDED/FAILED/CANCELED/CLOSED和履约NOT_STARTED/PROCESSING/SUCCEEDED/EXCEPTION独立。SDK结果仅触发查单；可信SUCCEEDED且履约SUCCEEDED才COMPLETED。未来续购展示生效时间；未知/本地超时保持PAYING，不释放会员单。恢复必须展示原单实付、目标等级、依据、追加期限与有效期，提交recoveryQuoteId/proposalHash/requestId，失效必须重看。同次确认复用幂等键。

## 视觉依据

只读UI来源7e7bd38a，`monetization-demo/css/monetization.css`：背景#f6f7f9、白卡18/20圆角、14–16水平间距、四档灰底白选中、紧凑25积分余额、权益下方三周期卡、24圆角底部Sheet。会员页真实身份与营销选择分离，免费默认初级月度，免费选择隐藏周期卡。无示例商品兜底。

## 验证

消费者JSON契约、支付/履约投影、未知结果、切号迟到回调、预览失效/重复确认、协议未选、空目录/禁售、发票草稿隔离做定向测试。每微批最多3手写文件，阶段analyze/OpenSpec；跨模块里程碑全量。375/390/430宽、长文案与键盘Widget检查及截图另存证据，真实系统支付/设备待验。
