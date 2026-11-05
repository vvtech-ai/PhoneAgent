说明：用户后续澄清：十多分钟是再次查看的间隔，并非持续失败时长，不再追查该时段完整根因。已确认源码机制、自动回放及代码审查通过即可构建；实际安装/服务精确版本、SQL与真实双端渠道证据如未取得仍如实注明，不作为此次打包前置。
以下为当时取证/实施记录，时长假设由上述澄清覆盖。

# R02 / R07 实施与验证报告

## 交付范围与提交

2026-10-21；依据 commerce-brief.md、已接受 commerce-preflight.md 与 root 冻结的两仓 delta spec 实施。根任务负责后续独立审查、最新拉取、最终构建和运行验收。

| 仓库 | 实施基线 | 本包中文提交 |
| --- | --- | --- |
| Java `D:/work/04phoneAgent/aiassistant-java` | `0ff4ec70506d4b5c75ccddf713b4fc4e3c52a59f` | `315e2eb87e7241fc83008bad0e44b5c1cb51c043` 区分支付保护原因并保留原单安全约束 |
| Flutter `D:/work/04phoneAgent/_isolated/phoneagent-task-flow` | `832de32c4a9894e404a6188e66747330218b1fa5` | `2529c927c6e0abe3983c8f23e7cf600e81401f72` 保留支付失败原因并补齐双端恢复诊断回放 |

Java 7 个文件、Flutter 15 个文件均按明确路径提交；提交后这些路径无未提交修改。未纳入 root 的 AGENTS、OpenSpec、知识库文档及其他任务修改。未拉取、推送、构建 APK、安装、部署、连接真实支付或外呼，未创建子代理。源文件每批不超过 3 个，最后检查 22 个自有文件 UTF-8 严格解码与中文读回、无 U+FFFD；提交前 diff --check 与 staged diff --check 通过。

## 合同与最小实现

| 安全原因 | 服务端 / 客户端代码 | 页面文案 |
| --- | --- | --- |
| 分钟建单频控 | `COMMERCE_ORDER_MINUTE_LIMITED`（新增服务端） | 支付操作过于频繁，请稍后重试 |
| 小时建单频控 | `COMMERCE_ORDER_HOUR_LIMITED`（新增服务端） | 同上 |
| 材料最小间隔 | `COMMERCE_MATERIAL_INTERVAL_LIMITED`（新增服务端） | 同上 |
| 订单生命周期材料累计上限 | `COMMERCE_MATERIAL_LIMIT_REACHED`（新增服务端） | 本订单支付重试次数已达上限，请查询原订单 |
| 支付结果未知 | 既有 `MEMBERSHIP_PAYMENT_UNKNOWN` | 支付结果确认中，请查询原订单 |
| 已付未履约 | 既有 `MEMBERSHIP_STATE_CONFLICT` | 已支付，权益处理中，请查看恢复方案 |
| 支付操作 HTTP 5xx | `COMMERCE_SERVICE_UNAVAILABLE`（客户端受控分类） | 支付服务暂不可用，请稍后重试 |
| 支付操作网络错误 | `COMMERCE_NETWORK_UNAVAILABLE`（客户端受控分类） | 网络连接异常，请检查网络后重试 |

四个增量服务端代码走现有 BusinessException / SdkGlobalExceptionHandler 的 HTTP 200 envelope；未修改全局 handler。原频控阈值、分钟/小时优先级、取消状态优先、累计上限优先于间隔、材料与租约及订单保护保持不变。累计上限不会承诺等待后恢复。

客户端保留 `AC0006` 的保守兼容文案“支付操作过于频繁或已达重试次数，请稍后查询原订单”；不全局允许 `AC0005`，不解析任意供应商正文。支付操作的 HTTP 500–599 高于业务 code 分类，包含 502 + allowlisted code。非支付目录/current/订单列表原有语义及鉴权/账号分类保持。原 404 的受控 unavailable 映射仍保留，其他支付错误不再依赖空值断言。

### 文件职责

Java 生产 3 文件：`CommerceErrorCode.java` 定义代码与安全默认文案；`CommerceOrderLimitService.java` 在原边界分别给出分钟/小时原因；`CommerceMaterialRequestPolicy.java` 在原边界分别给出间隔/累计原因。测试为 `CommerceOrderLimitsTest`、`CommerceMaterialLimitsTest`、`CommerceMaterialAfterQueryTest` 的精确原因断言及新增 `CommerceProtectionWireTest` 的真实 handler/Jackson envelope。无新状态机、阈值、SQL、队列或 cooldown 变更。

Flutter 生产 10 文件：

- `domain/commerce_failure.dart` 从 repository 独立出受控失败类型、文案及 HTTP 状态；`domain/commerce_repository.dart` 保留接口并导出类型。单一映射职责可继续增加受控原因，不扩大 controller。
- `data/api_commerce_repository.dart` 负责支付 HTTP/业务/网络分类与四码允许列表。
- `core/network/account_error_mapping.dart` 只向已有 allowlisted `ApiCodeFailure` 构造传递原 `statusCode`。实际 502 + AC0006 RED 证明原值被丢为 0，故这一公共边界的一行修复是必要的；没有扩大全局映射规则。root 已明确接受。
- `presentation/pages/membership_route.dart` 移除 `contains('订单')` 的文案覆盖；`presentation/widgets/pending_membership_purchase_sheet.dart` 展示 controller 已投影的安全错误。
- `app/commerce_providers.dart` 使已有诊断 decorator 同时覆盖 Android 与 iOS。
- `core/diagnostics/diagnostic_commerce_details.dart` 增加 query/fulfillment/refresh、允许原因及 hash requestRef 序列化。
- `data/commerce_diagnostics.dart` 记录受控业务原因、HTTP、耗时和脱敏关联；`data/diagnostic_commerce_repository.dart` 在既有调用外增加 query/refresh 诊断、传递 create 的真实幂等请求身份。

Flutter 测试 5 文件：新增 `commerce_recovery_transport.dart`（离线响应脚本，接真实 AccountApi）、`commerce_recovery_api_test.dart`（API/controller 连续序列）、`commerce_recovery_route_test.dart`（真实页面）、`commerce_recovery_diagnostics_test.dart`（双端 provider/脱敏/无干扰）；既有 `commerce_diagnostics_test.dart` 将去重断言按 orderState 与新增 fulfillment 阶段分别保留。

PurchaseController / PurchaseState 未改：既有安全 `CommerceFailure.message` 投影和 `_attemptError` 保持即可保存本次原因，可信终态清理仍走原实现。C1 基准直接 GREEN，因此不扩张恢复行为、不删除 PROCESSING guard，不添加 C2 同次点击自动新报价。诊断复用原安装版本/环境来源；create requestRef 来自真实幂等 ID 的 hash，其他阶段是本地 operation correlation，不能当作服务端请求 ID。没有增加业务网络请求。日志不会保存原账号、订单号、电话、Token、签名或 provider body。

## RED / GREEN 与命令

下列为实施时实际执行记录；夹具初始化等待/可见区域修正不计作业务 RED。后续测试均在明确路径运行，未进行无关全仓压力测试。

### Java

工作目录 Java 仓库；先设 `$env:JAVA_HOME='D:\tools\phoneagent-jdk17\jdk-17.0.20.1+1'`，执行 `& "$env:JAVA_HOME\bin\java.exe" -version` 确认 17.0.20.1。

RED 命令：

```powershell
& 'D:\tools\apache-maven-3.9.14-bin\apache-maven-3.9.14\bin\mvn.cmd' -pl aiassistant-sdk-api -am '-Dtest=CommerceOrderLimitsTest,CommerceMaterialLimitsTest,CommerceProtectionWireTest' '-Dsurefire.failIfNoSpecifiedTests=false' test -q
```

11 tests，7 failures，0 errors / 0 skipped：真实策略和 handler envelope 仍返回旧 AC0005/AC0006，与四类原因的预期不符。新增 wire 还覆盖取消优先、累计上限过一天仍不可恢复、间隔精确边界与材料预算。

最终 GREEN 命令：

```powershell
& 'D:\tools\apache-maven-3.9.14-bin\apache-maven-3.9.14\bin\mvn.cmd' -pl aiassistant-sdk-api -am '-Dtest=CommerceOrderLimitsTest,CommerceMaterialLimitsTest,CommerceProtectionWireTest,CommerceMaterialAfterQueryTest,CommerceMaterialProofTest,CommercePaymentLeaseTest,CommercePaymentFactsTest,CommerceOriginalPaymentRetryTest,CommercePaidQueryTest,MembershipPurchaseMatrixTest,MembershipProtocolContractTest,MembershipFulfillmentServiceTest' '-Dsurefire.failIfNoSpecifiedTests=false' test -q
```

64 tests 全通过，exit 0，0 errors / 0 skipped。初次扩展回归只发现 MaterialAfterQuery 两处预期仍为旧 AC0006；改为精确的新代码后通过，保留不额外生成材料、租约、query/material 分离、支付事实、履约幂等断言。

### Flutter

工作目录 Flutter 仓库；以下 `$flutter` 指 `D:\tools\flutter-3.32.0\bin\flutter.bat`。

最初真实 API/controller RED：`& $flutter test --no-pub test/features/commerce/commerce_recovery_api_test.dart`，13 tests 中 11 failed（后来补齐边界后本文件 15 tests）。覆盖原因被丢失、HTTP 非 404 的空断言/错误分类，以及 502 + allowed code 丢失 statusCode。新增真实 route 回放 `& $flutter test --no-pub test/features/commerce/commerce_recovery_route_test.dart`：5 tests 中 4 failed，实际页面安全文案丢失；C1 直接通过。诊断 `& $flutter test --no-pub test/features/commerce/commerce_recovery_diagnostics_test.dart`：4 tests 中 3 failed，Android 未接 decorator、iOS status 为 0、缺阶段；sink 抛异常的业务不干扰基线已通过。

生产修复后直接回归命令：

```powershell
& 'D:\tools\flutter-3.32.0\bin\flutter.bat' test --no-pub test/features/commerce/commerce_recovery_api_test.dart test/features/commerce/commerce_recovery_route_test.dart test/features/commerce/commerce_recovery_diagnostics_test.dart test/features/commerce/commerce_diagnostics_test.dart test/features/commerce/commerce_flow_diagnostics_test.dart test/features/commerce/payment_retry_error_contract_test.dart test/features/commerce/commerce_service_availability_test.dart test/features/commerce/purchase_controller_test.dart test/features/commerce/purchase_busy_test.dart test/features/commerce/purchase_order_intent_test.dart test/features/commerce/pending_membership_route_test.dart test/features/commerce/pending_membership_controller_test.dart test/features/commerce/ios_repeat_purchase_test.dart test/features/commerce/purchase_feedback_sheet_test.dart test/core/network/account_api_test.dart test/core/network/account_error_mapping_test.dart test/core/network/account_message_projection_test.dart test/features/app_logs/log_report_version_provider_test.dart
```

138 tests 全通过，exit 0。现有 diagnostic 去重测试曾因新增 fulfillment 事件总数增加失败，已改为对两阶段分别断言去重，未删减去重要求。

最后校准连续回放的实际目标商品夹具后，只重跑改变的覆盖测试：

```powershell
& 'D:\tools\flutter-3.32.0\bin\flutter.bat' test --no-pub test/features/commerce/commerce_recovery_api_test.dart test/features/commerce/commerce_recovery_route_test.dart test/features/commerce/commerce_recovery_diagnostics_test.dart
```

24 tests 全通过，exit 0。此后无生产源码变更。

包内静态分析最终命令：

```powershell
& 'D:\tools\flutter-3.32.0\bin\flutter.bat' analyze --no-pub lib/features/commerce lib/app/commerce_providers.dart lib/core/diagnostics/diagnostic_commerce_details.dart lib/core/network/account_error_mapping.dart test/features/commerce/commerce_recovery_api_test.dart test/features/commerce/commerce_recovery_route_test.dart test/features/commerce/commerce_recovery_transport.dart test/features/commerce/commerce_recovery_diagnostics_test.dart test/features/commerce/commerce_diagnostics_test.dart
```

9 items，无问题，exit 0。另一次全局 `flutter analyze --no-pub` exit 1，仅有其他任务文件 `test/features/conversation/stop_transient_header_status_test.dart:166:22` 的 info `curly_braces_in_flow_control_structures`；本包未修改该文件，已报告 root。不能声称全仓 analyze clean。

## 连续序列与证据判断

| 要求 | 实际自动证据与结论 |
| --- | --- |
| 首单完成后 quote502，再立即重试 | 同一个真实 AccountApi → ApiCommerceRepository → PurchaseController 完成首单 native/query；失败报价不增加 create/material/native。恢复 transport 后立即报价成功，确认前无新建/拉起；显式确认后独立 requestId/order/material，各拉起一次。没有等待 15 分钟或重建 controller |
| 同级 / 升级 / 低级及 QUEUED | PREMIUM→PREMIUM（首单 renew、权益 QUEUED）；BASIC→PREMIUM（首单 new、ACTIVE）；PREMIUM→BASIC（首单 upgrade、ACTIVE）。记录请求目标、quote preview 与 order membershipLevel，验证第二次 RENEW / UPGRADE / LOWER_QUEUED；第二单独立材料，避免只改测试标题而夹具仍同目标 |
| C1 真实旧本地 PROCESSING | 真 route/controller/API 经 PROCESSING/query502；服务端可信终态且 current 无 pending 后点购买，仍先查原单，终态后关闭 sheet；下一次明确购买才报价。该安全恢复原本 GREEN，保持 guard，不以 current 无 pending 推断付款成功 |
| 未知 / 已付未履约 | 两类真实 pending route 经 query502 显示安全服务错误，仍可“刷新状态”；服务恢复后原单查询终态，无重复建单/native。累计上限保持原单查询，可信终态才清理错误 |
| 分类与兼容 | HTTP 500/502/503/504，create/material/close，502 + null/AC0006/MEMBERSHIP_PAYMENT_UNKNOWN、四码、未知/履约、网络、AC0005 非公开映射；direct mapping/API/account callers 回归通过 |
| 诊断 | Android/iOS 实际 provider 路径均装饰；真实 API/controller/native stub/query/refresh 序列记录 quote/create/material/native/query/fulfillment/refresh、HTTP/受控原因、耗时与 hash；序列化不含敏感原文；故意 sink throw 仍维持各业务输出与调用次数 |
| 既有安全回归 | busy/order intent/pending/controller/iOS repeat/lease/facts/material/query/fulfillment 原有定向套件通过；没有为每个时序组合新建重复状态机，也未宣称覆盖所有可能排列 |

### 独立结论

- **源码机制**：已用实际 API/controller/UI RED→GREEN 证明并修复 HTTP/业务原因丢失和页面覆盖；新增四码明确区分频控/间隔/生命周期累计；双端诊断接线与阶段缺失有 RED→GREEN。C1 实际入口可安全收敛，故没有新增恢复行为。
- **现场归因**：原报告确认的精确首单已支付并履约、无 slot、一次材料；SDK 重启和真实 quote502 已确认，但单个 quote502 与该账号未相关联，完整十多分钟阻塞原因仍未知。原 PROCESSING 只是假设；C1 GREEN 不能升格为这次现场根因。本包不声称完整现场故障已解决。
- **自动验证**：Java 64、Flutter 138 直接回归及最终夹具修正后 24 连续测试通过，包内 analyze clean。使用离线 HTTP/native stub，不是假造客户端 COMPLETED 状态。全仓 analyzer 上述他任务 info 独立存在。
- **数据库验证**：未提供已授权隔离 MySQL 输入，未执行真实 SQL/业务写 fixture，无 H2 替代。成功单不作 SQL pending blocker 的完整数据库连续序列未验证；服务/domain mock 回归不能替代 SQL 证明。这是未执行，不是把环境跳过计作通过。
- **运行验收**：没有 Android/iOS 真实设备、渠道收费、最新构建、网关部署验证。版本来源只复用既有测试与代码，未制造第二版本来源。完整 R07 现场运行验收仍待 root 后续证据。

本报告为交付记录；root 负责独立审查及全局 OpenSpec/进度文件收口。未代报 PMReport 已成功执行。
