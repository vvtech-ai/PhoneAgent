说明：用户后续澄清：十多分钟是再次查看的间隔，并非持续失败时长，不再追查该时段完整根因。已确认源码机制、自动回放及代码审查通过即可构建；实际安装/服务精确版本、SQL与真实双端渠道证据如未取得仍如实注明，不作为此次打包前置。
以下为当时取证/实施记录，时长假设由上述澄清覆盖。

# R07 只读取证报告

调查日期：2026-10-21。本文时间均为 Asia/Shanghai。角色仅调查；未修改生产、测试、配置或业务数据，未创建支付、取消订单、部署、提交或外呼。

## 结论与实施边界

**现场故障的一部分已经确认：测试 SDK 服务重启期间，上游端口拒绝连接，真实报价请求得到 HTTP 502。整个“购买后十多分钟不能再买”的根因尚未确认。**

1. 用户提供的 ZIP 已按完整文件 SHA-256 精确匹配测试库 `client_log_upload`，因此其所属账号与首单不再依赖时间猜测。报告仅保留哈希：账号 `cbd5f8f192e5`，首单 `e8d0231144df`。
2. 此账号的首单确为 BASIC 月卡；14:10:41.249 创建，14:10:51 可信支付、履约均成功；当前没有该单会员占位，只有一次材料请求。没有依据把它认定为十多分钟的正常购买冷却。
3. Nginx 与 systemd / SDK 启动日志确认两段服务中断，以及四次真实报价 502。**Nginx 现有访问记录没有可用于绑定该账号报价请求的身份或请求关联号；不能把这些报价 502 逐笔绑定到用户。**
4. 当前客户端源码存在明确的错误原因丢失链：报价 502 → 通用网络拒绝 → 含“原订单”的通用错误 → 会员页覆盖为“暂时无法发起支付，请稍后重试”。该链可以成为最小失败回放，解决明确的服务异常语义和恢复路径；不能据此宣称整个十多分钟现象已解释。
5. 本轮不建议修改后端会员队列、频控数值、订单期限或租约规则。旧 PROCESSING 客户端门禁是独立未验证假设，不作为已确认现场根因，也不建议顺手重构。

## 取证范围与安全方法

- 已读 brief、两仓 AGENTS、Flutter change design / purchase-error-and-repurchase spec、相关 Controller / API adapter / 后端创建、材料、租约与履约代码。
- 外部 `D:/work/vibecoding/README_AI编程文档导航.md` 属于 Chaken-OMS，已确认不适用于 Phone Agent；环境事实使用 Java 当前发布文档和有效运行配置。
- SSH 使用已登记私有输入、系统 known_hosts 和 Paramiko `RejectPolicy`；未关闭主机校验，未输出凭据。
- 数据库经当前 SDK 配置与 Nacos 的 `db-common.yml` 解析连接；JDBC 使用 `START TRANSACTION READ ONLY`、20 秒查询超时、每条显式 LIMIT 和 rollback。只查上传元数据、哈希订单及安全材料计数，未执行业务 API 或 SQL 写入。
- 运行日志限定 14:09:00–14:28:00；Nginx access 最多 2,000 行、error 最多 1,000 行；SDK 使用对应小时日志而非全量 console。console 曾尝试限定窗读取，未采用其无界文件作为证据来源。
- 未保存原始 ZIP、用户内容、供应商正文、签名材料或完整服务日志到本报告。SDK 供应商错误日志包含签名请求与渠道正文，不能原样复制到后续报告或诊断。

## 已确认事实

### 1. ZIP 与上传账号精确绑定

本地文件 `C:/Users/wuxiwen/Downloads/phoneagent-diagnostics-1792566606454.zip`：只有 `diagnostics.jsonl`，共 201 条事件。事件字段为 `operation/result/time/statusCode/elapsedMs/trustedCaller`，缺支付路径、订单/请求关联、业务码与可信安装版本。

以 ZIP 完整 SHA-256 查询 `client_log_upload.checksum_sha256`，命中一条记录：

| 字段 | 结果 |
| --- | --- |
| 账号 SHA-256 前 12 位 | `cbd5f8f192e5` |
| 上传时刻 | 15:10:07.689886 |
| 字节数 | 2,829 |
| device_info | 非 JSON；仅可提取 Android / Flutter 与版本格式字符串 `1.0.0`，没有 build number |

`1.0.0` 只是上传元数据的字符串，**不能作为可信实际安装版本**。本轮没有读取设备 APK，不能将当前 Flutter SHA 或其他包版本绑定到此 ZIP。

ZIP 原有七次 accountRequest 502 为：14:10:33、14:11:14/19/26/29/36、14:26:16。这些通用事件仍不能逐条映射为支付请求。

### 2. 同账号订单与材料事实

限定此精确匹配账号、12:00:00–15:00:00，仅一笔订单：

| 字段 | 结果 |
| --- | --- |
| 订单哈希 | `e8d0231144df` |
| 商品类型 / 快照 | MEMBERSHIP / BASIC / 1 month |
| 购买类型 | NEW |
| 创建 | 14:10:41.249 |
| 支付 | SUCCEEDED，14:10:51 |
| 履约 | SUCCEEDED，14:10:51 |
| 原始期限 | 14:25:41.249 |
| 当前会员占位 | 无 |
| safe_error_code | 空 |
| attempt | 1，材料请求数 1，最后材料时间 14:10:41.546805125 |

Nginx 通过原始订单号在内存中匹配后，只输出订单哈希，确认该原单请求：

| 时刻 | 请求 | HTTP |
| --- | --- | --- |
| 14:10:41 | POST 原单 payment | 200 |
| 14:10:56 | GET 原单 | 200 |
| 14:11:03 | GET 原单 | 200 |

数据库证明最终事实及其业务时间；access 证明请求存在和 HTTP 状态，**没有保存响应业务码/正文**。不能把原单 GET 200 等同于该设备成功解码并投影终态，但也不能无证据假定客户端始终停留 PROCESSING。

未观察到此账号后续新订单。它说明新单没有落库，不能单独定位是报价拒绝、用户未确认、客户端门禁或其他环节。

### 3. SDK 重启与报价 502

测试环境事实为主机 `.220`、`/opt/chaken-ai/test`，由 systemd 管理；不是假设中的旧 K8S 部署。

| 时段 | systemd / SDK | Nginx |
| --- | --- | --- |
| 第一段 | 14:11:07 Stopping；14:11:11 退出 status 143 并重新启动；14:11:41.544 Tomcat 监听，14:11:41.901 应用启动完成 | 14:11:10–14:11:40 SDK 请求出现 Connection refused；14:11:46 起窗口内恢复 200 |
| 第二段 | 14:25:49 Stopping；14:25:50 退出 status 143 并重新启动；14:26:19.634 Tomcat 监听，14:26:20.663 应用启动完成 | 14:25:51–14:26:17 多个 SDK 请求 502 / Connection refused |

限定窗 Nginx error 共 63 条：59 条指向 SDK 端口 38082 的 `connect() failed (111: Connection refused)`；1 条指向 Agent 端口 38080；其余 3 条未作为支付错误归因。

同窗真实 SDK 报价失败：

| 时刻 | 路径 | HTTP |
| --- | --- | --- |
| 14:11:15 | POST /aiassistant-sdk-api/api/commerce/quotes | 502 |
| 14:11:20 | 同上 | 502 |
| 14:11:27 | 同上 | 502 |
| 14:11:30 | 同上 | 502 |

14:12:04、14:15:17、14:17:52、14:25:19 另有报价 HTTP 200；这些记录不含可绑定账号的业务响应。公网 IP + User-Agent 聚合会合并多账号流量，本轮**没有将它当成账号证据**。

以上确认的是约半分钟的服务中断及请求失败；不能解释为连续十多分钟不可购买。systemd 的 Stopping 在退出前出现，且 JAR 发布目录时间同步变化，符合发布/受控重启过程；未查明发起者，不把退出 143 当作应用自行崩溃或 OOM。

### 4. 运行构建与检出不相同

调查时 SDK 当前链接为 `/opt/chaken-ai/test/releases/aiassistant-sdk-api/360/application.jar`，15:41:55 进入运行；JAR SHA-256：`b8cb2152327819bd651f1e840e810aa21f4358b2c202dad7050f5568acee9c55`。

部署目录中 358 的文件时间为 14:11:07，359 为 14:25:49，360 为 15:41:53。当前 360 晚于故障，不代表故障时构建。JAR 没有 `git.properties` 或 build-info，manifest 只有 `Implementation-Version: 1.0.0` 和 JDK 17，故本轮不能给出故障时服务精确源码 SHA。

调查期间仓库存在其他工作并持续推进：Flutter `codex/dev` 读到 `b5c5ab4d57f22e3bd7644c0ae1d5a163916bd023`；Java `feature/test_v1.7.0` 起始读到 `8dad5c33b5729e5c910855fff4265725192e7ce2`。两者均不同于 brief 初始 SHA。所有源码只读，未重置、覆盖、提交或混入其他人的修改。

## 源码机制与现场归因的区别

### 已确认：502 语义在客户端丢失

当前读到的链路：

1. `lib/core/network/account_api.dart:204` 对未暴露的 HTTP >=300 抛 `ApiFailure.rejected`。
2. `lib/features/commerce/data/api_commerce_repository.dart:60` 只对特定 catalog/current/orders 的 404 暴露 HTTP 状态，报价 502 无独立 CommerceFailure 分类。
3. `lib/features/commerce/presentation/controller/purchase_controller.dart:138` 将非 CommerceFailure 统一为“操作结果暂未确认，请查询原订单或重试”；`_preview` 保留 existing 原单。
4. `lib/features/commerce/presentation/pages/membership_route.dart:151` 只要错误含“订单”，即替换为“暂时无法发起支付，请稍后重试”。

因此 502 完全可以生成用户描述的通用提示，且错误中“原订单”并不证明后端存在会员占位或命中频控。待处理 sheet 也会将非空错误覆盖为统一“暂时无法确认”。这是 R02/R07 可以直接以失败回放约束的显示和安全恢复问题。

### 仅假设：旧 PROCESSING 客户端门禁

`PurchaseController._preview` 在请求 quote 前保存 existing；quote 返回后仍按 `existing.unresolved` 拒绝非 PACK 报价，报“请先处理原订单”。`MembershipRoute._buy` 也允许以旧 `existing.unresolved` 作为 pending fallback。

这证明存在该条件分支，**不证明分支在本次现场命中或其安全边界应该删除**。服务端报价不等于原单已结束；不能仅凭新 quote 或 membership 无 pending 就把未知付款当成功。当前已有“成功原单可以立即下一报价”和“未知原单保留”的测试，两种规则应同时保持。

只有构造实际 controller 连续序列（旧 PROCESSING → 查单失败 → 服务端终态 → 重新查单成功 → 新购）并发现无法安全收敛，才应把该假设升级为客户端恢复缺陷。本轮未新增/运行该回放，不据静态推演进行修复。

### 未发现：首单成功后强制等待 15 分钟的后端规则

`CommerceOrderCreationService` 对可信支付且履约成功、无占位的单不作为 pending blocker；15 分钟是新未付订单期限。默认保护为 5 单/分钟、20 单/小时、材料累计 5 次、材料间隔 15 秒。`claimMaterial` 已分离查询冷却，但仍尊重有效活动租约。

本次目标账号只有一单、一次材料请求，成功单无占位；没有材料累计上限、活动租约、未履约或旧订单期限阻断的证据。当前读取的 common/module env、SDK 和 framework Nacos 未见上述限额覆盖；历史故障时完整有效属性快照未取得，默认值仍不能冒充历史运行值。

## 最小 RED / GREEN 建议与 owner

**推荐只围绕已证实的服务异常语义及恢复实施，不改变后端会员队列/冷却。**

| 回放 | 连续步骤与 RED 断言 | GREEN 目标 / owner |
| --- | --- | --- |
| R07-A，主要 | 经真实 ApiCommerceRepository / AccountApi 测试 transport：原单已支付+履约完成 → 下一 quote 返回 502 → 确认页提示。期望安全明确的“支付服务暂不可用，请稍后重试”，不能显示频控/原单待付或供应商正文；502 后 create/launcher 次数均为 0。当前代码丢 HTTP 类别并给含订单通用提示，因此语义断言应先失败。 | Flutter data 保留安全 HTTP 服务不可用类别；domain 使用受控失败分类；route/pending sheet 展示该类别。复用现有诊断，不新增网络/订单状态机。 |
| R07-B，主要 | 同一个 controller：首单完成 → quote502 → 服务恢复 → 用户立即重试 quote200 → 显式确认 → 新订单 → 新材料。既有首单始终保留终态，新订单/材料/幂等身份独立。 | 不等待 15 分钟即可继续；未确认不下单；不得自动重放扣费或创建第二笔事实。Flutter 负责状态与入口接线，后端维持既有合同。 |
| R07-C，安全相邻 | 原单支付未知 / 已付未履约 → quote/query502 → 恢复后查原单。穿插迟到响应、重复点击、账号切换。 | 原单未核实前保留恢复和门禁，成功查到真实终态后再新购；不清 slot、不取消保护、不把本地渠道成功当付款事实。 |
| R07-D，运维验证 | 发布/重启前后只读健康/入口观察，记录实际 SDK 就绪与错误窗；不通过本任务主动部署制造故障。 | 运行维护方核实发布是否有入口排空或就绪控制，单独记录可用性改进；不能用 Flutter 文案变化声称服务中断已消失。 |

R07-B 可以在 mock transport 下证明安全恢复，但不能关闭真实支付/设备验收。下一次运行证据应包含实际安装版本、环境、固定 commerce stage、HTTP/安全业务码、耗时和脱敏订单/请求关联；Android 共用现有 CommerceDiagnostics。不得记录真实号码、Token、签名材料或供应商原文。

## 保持未完成的事项

- 具体用户哪一次报价收到什么响应、截图提示对应哪个请求，仍未知。
- 全部“十多分钟”持续过程、恢复触发点以及故障时安装 APK / 精确服务源码 SHA，仍未知。
- 原单两次 GET200 的业务响应及客户端应用顺序未保留，不能确认其客户端是否已消费终态。
- 本轮只读取证，没有业务修改、自动 RED/GREEN 执行、部署或设备/真实支付验证。R07 的完整现场根因及真实验收不能勾选完成。
