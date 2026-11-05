## Decisions
新增 presentation/invoice_availability_notice.dart 只负责可信状态到安全中文的投影，不在 UI 计算或放宽服务端资格。第一批 invoice_sheet/invoice_route 接提示和售后邮箱，第二批订单 action 与结果详情复用。每源码批最多 3 文件。

OrderResponse 现有字段实际为 invoiceAllowed；没有退款金额或拒绝码，无法据 bool=false 区分退款、已开票占用和未知原因。主代理确认不增加拒绝原因字段：INVOICING/ISSUED 以原单发票查询为准，缺少证据使用安全的联系售后提示，不臆测已退款。非整分人民币采用“该订单金额暂不支持在线开票，请联系售后协助处理”，不在产品文案解释技术单位。

后续只读金额契约追加可空 invoiceAvailableFen，由服务端根据真实实付、退款、已开及开票锁定计算。客户端 domain/DTO/route 三文件微批优先展示该净额，不自行算财务事实；缺失/null 兼容旧 cashPaidFen。DTO 拒绝非整数、负数及大于实付值；已有发票详情仍展示该申请自身金额，禁止申请时不展示零应付或表单。

Apple 外币保持正常购买，人民币订单不按渠道一刀切拒绝。外币、非整分及零价状态展示说明时隐藏无意义的人民币可开票金额和表单；已有发票详情、下载、原查询行为保留。不得要求销方手机验证码，不把 Apple 收据称为我方数电发票。

## Validation
先以现有入口和 route 建立失败用例，再最小修改；覆盖 Android/iOS、320 宽双倍文字、详情直达、Apple CNY 表单和原发票状态优先。flutter analyze、受影响发票/订单测试和 OpenSpec；不运行 Maven、不付款、不打包安装、不提交推送。
