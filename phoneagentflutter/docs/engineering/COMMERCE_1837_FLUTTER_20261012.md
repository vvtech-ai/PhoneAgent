# 1837 Flutter商业化实施与证据（2026-10-12）

## 范围与实现

本树 `story1837-flutter` / `codex/story1837-membership-commerce` 基于 `origin/codex/dev 36f76ec0`，按PDR v1.7实施T01/T04/T06/T07客户端与T08本地验证。原phoneagent-task-flow和旧项目未修改。当前保持未提交、未推送、OpenSpec active。

新 `lib/features/commerce` 按domain/data/presentation分层，31个Dart文件，所有新业务文件不足500行；单一职责的开票组件309行继续承载表单布局。账户签名与鉴权复用AccountApi，仅补commerce/membership边界保护；首页会员入口和旧钱包来源字段做必要兼容。新能力通过Repository和平台端口扩展，不扩大旧钱包Controller。

- 目录配置、当前购买权益、报价和订单分开；营销切卡不改变真实会员。整数分、整数配置ID、上海墙上时间、可空FREE权益/currentMonths与积分包level/months按公共JSON冻结消费，不补造配置。
- 七态仅由服务端支付/履约事实投影；未知枚举协议失败。原生SDK取消、超时、返回成功均查询原单，不释放或直接完成。本人冲突恢复预览显式确认、稳定幂等ID、失效重看方案；跨账号晚到结果不发布。
- Android支付宝与iOS StoreKit独立原生桥接，中立Dart PaymentLauncher。StoreKit使用服务端appAccountToken、真实商品displayPrice，后台验证支付SUCCEEDED后才finish；履约异常仍保留原单恢复。发现原生恢复超时阻断查单，新增红测后修复，失败端口不影响权威原单查询。
- 会员、积分包、报价、购买结果、用量来源、横滑现金订单及开票Sheet已接线。协议未勾选不报价/下单。开票草稿仅内存、个人/企业/专用隔离、本人失败重新填写需服务端invoiceAllowed；文件下载复用签名API及PDF/OFD/XML受控保存。
- 克隆只兼容钱包来源，沿用原逻辑；未添加优化、存储收费或新克隆表。入口级会员锁定提示仍待相关准入联调，不声明T05全端完成。

## 实际验证

| 命令或检查 | 本轮结果与边界 |
| --- | --- |
| `flutter test --no-pub test/features/commerce test/core/network/account_api_test.dart test/core/network/service_routes_test.dart test/features/points/points_wallet_test.dart test/extended_device_stage_test.dart test/shell_workbench_test.dart --concurrency=4 --reporter expanded` | 103通过，约1分钟；后续恢复超时/发票收尾12通过，集合重叠不相加 |
| 钱包来源及原钱包直接调用方 | 116通过；非全量 |
| `flutter analyze --no-pub` | 最终无问题，24.6秒；中间一条新if大括号lint已修复 |
| `openspec validate --all` | 92通过/0失败 |
| `git diff --check`、UTF-8中文复读 | 通过 |
| `flutter test --concurrency=4 --reporter expanded` | 首轮4571通过/1既有跳过/8失败，24分34秒；日志output/commerce1837/full-test.log |
| 原全量六项旧导航失败 | extended_device_stage四项和shell_workbench两项修正新会员→用量→旧钱包返回链，专项及上述103项复验通过 |
| 原全量两项环境失败 | domestic_recording_cleanup_test与domestic_recording_session_test创建symlink报Windows errno1314；未修改/跳过无关测试，完整回归不宣称全绿 |
| Android原生编译 | JBR21显式wrapper `:app:assembleDebug --offline --console=plain --max-workers=2` 成功，12分20秒；Android PayTask已编译入包 |
| Android测试交付编译 | 下述test配置构建成功92.3秒、V2验签通过；不代表真实支付成功 |
| iOS本轮无签名编译 | 未执行：VVTechdeiMac-804.local无法解析；既有HostKeyAlias严格校验的192.168.1.51:22探测8秒超时。未操作screen/钥匙串/Xcode，10/11历史通过不能代验当前Swift |

固定Flutter3.32.0/Dart3.8，Android构建JBR为 `D:/android_studio/jbr`。首轮在线构建等远程依赖后有限中止；默认JAVA_HOME8离线wrapper失败，指定现有JBR21后成功。没有升级工具或取消发布保护。

## 原型与视觉

原型固定 `origin/codex/phone-agent-monetization-linkage-20260814` / `7e7bd38`，只读源码与Web树真实浏览器390×844五页截图。会员为余额白卡、四档灰tab、权益白卡和三周期卡；积分包选卡后统一支付；现金订单右侧开票固定；开票蓝色单选及底部操作。旧自动续费/退款/微信文案由PDR覆盖。

`commerce_visual_test.dart`执行375/390/430宽×1/2字号×会员/积分包/订单/结果/发票五页，30测试通过。捕图字体微软雅黑，生成15张 `output/commerce1837/{membership,points,orders,result,invoice}-{375,390,430}.png`，均查看主要390图并修正人民币字形。捕图命令：

```text
flutter test test/features/commerce/commerce_visual_test.dart test/features/commerce/invoice_sheet_test.dart --dart-define=COMMERCE_CAPTURE_DIR=output/commerce1837 --dart-define=UI_PREFLIGHT_FONT=C:/Windows/Fonts/msyh.ttc --dart-define=UI_PREFLIGHT_ICON_FONT=D:/tools/flutter-3.32.0/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf
```

这属于合成数据组件绘制，不是双端真实设备或同数据像素一致验收。公共consumer-fixtures在本树test/fixtures/commerce复制，测试不依赖跨树运行路径。输出证据与构建产物均忽略，不提交。

## 测试配置与Android产物

私有配置来源为原树 `.local/cloud-test/device-defines.json`，仅只读使用；APP_ENV=test，API/SDK指向chakenai-test域名，现有SDK/AGENT凭据不复制进源码或日志。正式入口lib/main.dart，关闭迁移预览。

```text
flutter build apk --debug --no-pub --target-platform android-arm64 --build-name=1.0.51 --build-number=2026101202 --dart-define-from-file=D:/work/04phoneAgent/_isolated/phoneagent-task-flow/.local/cloud-test/device-defines.json --dart-define=ENABLE_MIGRATION_PREVIEWS=false -t lib/main.dart
```

产物 `build/app/outputs/flutter-apk/app-debug.apk`，包com.vvtech.aiassistant.dev，1.0.51/2026101202，SHA256 `A7A6852A43E6D245EFBD097BEE1B392E4ACD243D8A4139CB0A57351C0DC9F92F`。现用设备KOZ_AL00旧包1.0.51/2026101201，只读pull原APK留证于忽略output/commerce1837/installed-before.apk。两包证书SHA256均 `45655392a9295955d0d651eb7d1ff3f3edb1d15f8a62d74f201dfbc3789cdb4b`。

按T08授权 `adb install --no-incremental -r` 成功；新版本2026101202，firstInstallTime仍2026-10-10 12:36:18，lastUpdateTime2026-10-12 20:39:15。`am start -W`冷启动Status ok，真实首页显示已有余额与模型，登录状态恢复；未卸载、清数据、降级或重发短信。只读会员/订单页实际加载失败并可重试，未填充假FREE/权益/订单。没有HTTP状态证据，不将加载失败推断为404或服务未部署。截图android-start.png、android-membership.png、android-orders.png留忽略目录，已查看；结束返回普通入口。

用户随后追加v67所有邀请变更及积分记录UI迁移，后续源码将另做定向验证/增量包；本APK仅属于上述商业化阶段，不替代新增范围验收。

## 保留工作包

iOS当前源码编译/真实StoreKit商品与JWS联调；SDK目录/会员/订单部署与真实支付宝可信查单；税航申请/文件与旧票终止后的失败重填；跨端本人唯一订单/配置变更/切号设备行为；会员入口准入和完整设备视觉。真实费用、短信、外呼与克隆创建均未执行。缺商户配置维持不可售，不以合成测试证明购买到账。

## 23:20最终调整覆盖上述历史UI
用户明确App不展示本期会员/永久余额和积分来源。CommerceUsageRoute/ApiWalletSources/WalletSources及provider/预览来源请求删除，会员总积分卡直接进入v67原流水；页头订单与发票，邀请独立首页礼物/设置入口。最新源码、真实邀请修复与1207同签名保留数据安装详见V67_INVITE_LEDGER_20261012.md。
实际SDK前缀GET api/commerce/catalog、api/membership/current、api/commerce/orders均404，已明确会员/订单服务暂不可用；积分包不能显示暂无可售假成功。真实渠道、权益履约、发票和iOS本轮编译仍待验。最终APK1207 SHA256 AEB9364A8ED40A0F016C39CBDAD9CFD7B02FD67E8C210972E29DE19D6B068676；firstInstallTime保持2026-10-10 12:36:18。
组合定向219通过；收尾404/积分包/会员直达11通过，500/timeout/4045通过；集合重叠不相加。会员375/390/430×1/2最新6项重新捕图，已覆盖旧用量入口绘图。analyze无问题16.3秒，OpenSpec93通过，Windows两symlink及Mac不可达边界仍保留。

## 2026-10-13 SDK交叉契约审查及1208修复

只读Java工作区0c111353与含untracked实现，未修改Java/运行Maven。发现3个Important并由root确认处理：CommerceCatalogService未发布目录合法null agreement/support在客户端被strict String拒绝；InvoiceService.detail NOT_APPLIED/null invoiceNo以及INVOICING/ISSUED与客户端枚举不匹配；OrderCreationService返回既有pending会员原单，而客户端会自动支付异报价原单。依据实际Service JSON literal先观察5个RED，原单异quote/缺quote launch1的2个RED；修复后20专项、8追加UI/原单查询专项通过（重叠）。

目录仅空products允许null元数据并保持空售，可售商品要求非零配置、非空协议版本及有效HTTPS/no-userinfo链接，不补商品/权益。发票NOT_APPLIED且null申请号/0金额/空formats表示未申请，INVOICING处理中，ISSUED才显示已开票与开放文件；FAILED保持草稿与服务端retry资格。SDK真实MIME为PDF/application-pdf、OFD/application-ofd、XML/application-xml，客户端20MB受控下载匹配。

root冻结OrderResponse nullable quoteId，新server将输出持久quote_id并保留旧19参constructor。客户端optional parse，自动拉材料只在同quoteId、PENDING、当前平台channel匹配；异quote/缺quote/异channel直接原单详情查询，不能靠相同价格/名称猜测。恢复原pending只query不拉材料；仍仅服务端payment SUCCEEDED与fulfillment SUCCEEDED完成，Apple他账号未完成交易拒绝后不finish，已可信付款但履约EXCEPTION可finish。

已检查公开CommerceRead/PaymentController、Common Catalog/Product/Quote/Order/Membership/Invoice/PaymentMaterial DTO、SDK目录/报价/订单创建/原单读取/支付尝试/网关/Apple验证/会员读取、InvoiceController/Service/Transactions/Eligibility，以及当前Flutter消费。省略quote channel由签名identity选择；integer ID/整数分、Shanghai yyyy-MM-dd HH:mm:ss、7态与404失败保持一致。除上述3项未发现额外Critical/Important；源码审查不等于未部署接口或供应商联调成功。

最新全scope定向命令为flutter test --no-pub test/features/commerce test/features/invite test/features/points/v67_points_ledger_test.dart test/shell_workbench_test.dart test/extended_device_stage_test.dart test/core/network/account_api_test.dart --concurrency=4 --reporter expanded，237通过1分36秒；analyze无问题51.3秒，OpenSpec93通过，diff中文复读通过。日志1208-targeted.log。未重复25分钟全量，两symlink环境失败仍保留。

Mac仅只读探测：2026-10-13本轮DNS VVTechdeiMac-804.local名称不存在，docs既有192.168.1.51:22 TCP8秒超时，未达到SSH认证；HostKeyAlias既有192.168.1.49不绕过，不推断SSH User或更改签名/screen/钥匙串。本轮iOS当前源码仍未编译。
1208最终APP_ENV=test主入口增量构建16.9秒、V2及同证书通过，APK SHA256 9C07F6E243189F4EC571D7D9E96F0007072EE0E43A3385344A059A0F52EE9E02。adb install --no-incremental -r Success，版本2026101208（本轮批准递增编号），firstInstallTime仍2026-10-10 12:36:18、lastUpdate2026-10-13 00:03:49；冷启Statusok、普通登录保留，结束首页。跨日总积分8889→8989由既有原流水“每日首次登录赠送”2026-10-13 00:04 +100确认，没有手工赠分。

最终1208真机会员/积分包/订单保持明确服务不可用，确认支付禁用；实际catalog/current/orders仍404。邀请activity/code/records200/000000，名额和按钮可用，首页礼物福利/设置邀请好友/记录0/2空态及来源返回正常；总积分卡直达原流水，无会员/永久来源页面和请求。真实9图为output/commerce1837/android-1208-{home,settings,welfare,invite,invite-records,membership,points,orders,ledger}.png，安全metadata日志android-1208-protocol-metadata.log；不是合成发票/购买成功证据。

root已完成OrderResponse原19参constructor兼容与Reader输出原quoteId的源码，本树共享fixture只追加order.quoteId=fixture-quote-1；consumer断言先观察旧fixture null RED后该字段同步GREEN1。237集合与后1项重叠，不相加。真实未发布目录、发票状态和原单不同quote场景仅API literal/controller/widget验证，本次测试服务404不能将它们表述为设备真实购买或开票成功。Java树仍只读，无Maven；不commit/push、不归档、无真实消息/付费/外呼/克隆。