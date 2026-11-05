- [x] 核对订单、发票查询、售后入口和现有字段，向主代理说明缺失退款证据。
- [x] 真实 RED：外币和非整分说明、Apple CNY、双平台窄屏和详情直达。
- [x] 小批实现统一说明并接入原入口/详情/发票页，不改变支付或申请资格。
- [x] 定向 GREEN、analyze、OpenSpec、UTF-8 回读；任务摘要交主代理。
- [x] 追加只读 invoiceAvailableFen 的 domain/DTO/route 三文件微批，拒绝非法净额并验证服务端净额展示。

## 2026-10-14 验证记录

- 基线 9015c768，首轮新测试 9 项：4 通过 / 5 失败（缺少外币、非整分、零价提示及入口文案）；最小实现后 9/9 GREEN。日志 D:/Temp/story1837-invoice-availability-red-20261014.log 与 story1837-invoice-availability-green-20261014.log。
- 发票、订单、布局、receipt 和支付结果定向集合 110/110 通过；最终非整分文案修订后整个 test/features/commerce 集合 405/405、exit 0（60s），日志 D:/Temp/story1837-invoice-availability-commerce-final-20261014.log。
- 首次 analyze 提示测试公开辅助函数带私有类型，辅助函数改为私有后补跑 9/9；最终 analyze No issues found（10.6s），日志 D:/Temp/story1837-invoice-availability-analyze-final-20261014.log。业务源码未因此修改。
- 既有 INVOICING/ISSUED 优先，invoiceAllowed=false 仍可查询原申请；Apple CNY true 保留表单及按钮；Android/iOS 320宽双倍文字未溢出；售后邮箱来自目录。没有证据的退款/净额不推测，不增加后台或客户端开关。
- 检索 lib/test/当前主规格，未发现要求 Apple 订单一律向 Apple 开票的绝对文案。Apple 收据与我方发票没有混称；保留安全服务异常提示。
- 首批 OpenSpec 全部 137/137，git diff --check、UTF-8 中文回读通过。首批没有修改公共 tasks/issue、Java、controller/repository/DTO；未调用付款、Maven或真实设备，未打包、提交、推送。

## 只读可开票净额补充微批
- 主代理复核发现实付不等于可开票净额，冻结可空 Long invoiceAvailableFen 契约。只改 commerce_order.dart、commerce_dto.dart、invoice_route.dart，金额运算仍由服务端负责，未新增拒绝原因字段。
- 真实 RED：11 项 9 过 2 失败（3800 实付/3300净额未显示、非法净额未拒）；GREEN 67/67 包含所有原发票测试、DTO、旧服务器契约兼容、receipt、订单入口与新 route。日志 D:/Temp/story1837-invoice-net-red-20261014.log、story1837-invoice-net-green-20261014.log。
- 有字段非整数/负数/超过 cashPaidFen 拒绝；缺失/null 保留旧实付兼容；可开净额为0且invoiceAllowed=false保持说明/查询，不显示0应付或新表单；已有发票仍以自身金额为准。
- 净额微批最终 analyze No issues found（16.7s，D:/Temp/story1837-invoice-net-analyze-20261014.log）；OpenSpec change strict、diff --check、UTF-8 回读通过。全部源文件冻结，交主代理构建/设备验证；本代理未打包安装或提交推送。

## 最终未知 Apple 凭证提示微批
- [x] 缺可信原币 tuple 不从 cashPaidFen=0 推断零实付；提示暂无法确认资格并联系售后。真实 RED 为8项7过1失败，修复后全部发票定向45/45；相关代码独立只读复核通过。
- [x] 最新 origin/codex/dev 90db9e82 已合入，商业化/定位/权限/语音相关459/459；最后提示微批后 analyze 无问题，OpenSpec 138/138。集合有重叠，不相加。
