# 会员未配置合法空态

用户追加要求合法未配置不显示加载失败。Root的active change为`refine-commerce-empty-states`；本agent只负责会员Controller、MembershipPage及契约/状态回归，Root独占Flutter命令、订单页、共享追踪和设备构建。未改Java/Web、私有配置、总积分来源规则、克隆或支付事实。

## 定位与来源

Java `CommerceCatalogService` 未发布返回`CatalogResponse(0,0,null,null,null,List.of(),Map.of())`；framework-default.yml使用NON_NULL，实际nullable协议与售后字段可省略。FREE会员的nullable benefits/version/日期可省略，但terms仍为必需数组。

现CommerceDto已正确支持这些合法省略。新增服务器literal和null/缺必需集合负例由Root实际运行通过，未修改DTO或把坏数据当空。用户看到的generic错误另由Root定位实际后端500：`MembershipReadService.current:94` primitive long ternary自动拆箱null。由Java子任务修复，前端真实500仍保留失败/重试，不能因库未发布而吞掉500。

实际前端缺口：空目录仍查询native availability/products，页面仍展示无配置等级营销与支付控件。回归加入不允许被调用的原生适配器，以及成功空态、旧期限/原单链接和真实错误保留；Root实际观察14通过/4失败，失败为两平台不必要native调用和两会员空态缺失。

## 最小修改

`catalog_controller.dart`负责目录加载与状态。unconfigured严格要求目录非null、version/revision均0、products与benefits均空；仅无商品目录跳过原生查询，非空目录保留既有availability和平台商品ID查询，停售Apple SKU仍能浏览StoreKit真实价格但不可购买。真实transport/authentication/malformed/CommerceFailure仍为error，目录与会员都读取成功才展示空态。

`membership_page.dart`负责渲染。保留总积分、原流水与订单入口、真实身份、期限/未来段/原pending单提示；合法未配置显示“会员与商品暂未配置”，隐藏无配置等级营销、购买会员、协议和渠道警告。用户追问后重新核对：PDR6.4要求原单恢复能力，但没有规定Android空页常驻底部恢复按钮。Android底部入口移除，原单处理仍经订单与发票进入；iOS依据既有requiresPlatformProducts标记保留Apple原交易恢复，即使销售目录未发布。没有新加平台业务策略或改变原单恢复服务。非空目录/真实错误行为不变。总积分卡“+购买积分”仍是原合法导航入口，无报价或付款假值，未修改共用余额卡。

## 回归与验证

- `server_contract_compatibility_test.dart`追加NON_NULL实际省略及null/缺集合负例。
- `unpublished_catalog_test.dart`覆盖真实literal→Controller、两平台native零调用、非空停售Apple商品读取真实价格但不可购买、网络/鉴权/服务拒绝/格式错误保留、未配置UI与期限/原单/恢复回调。
- Root实际运行 `flutter test test/features/commerce --reporter expanded`，121项全部通过。订单四项回归先RED后GREEN，验证空态无表格/箭头、有订单横向滚动与原发票操作保留，横滑说明永久移除。
- 绘图夹具新增会员未配置、无订单两种状态，375/390/430及1×/2×共48项全部通过；输出至 `output/commerce1837/ui-empty-refinement`，实看390空态及2×会员，中文正常、无溢出。
- `flutter analyze --no-pub` 无问题；两个相关OpenSpec严格校验通过；1304 debug arm64构建成功，53.9秒。APK SHA256 F244B85AB6BE0B2C7F30846281C4935F8A8CE96B85D63DB5EE38B9389A0D01FB，包名与私有环境配置沿用1303。
- Java500修复三项回归及SDK重新打包通过，SDK已重启。1304设备复验独立记录；不能把合法literal/组件成功当成实际后台成功或真实购买成功。

## Android底部入口收敛

根据用户追问，将恢复购买底部按钮仅限定既有iOS标记。Android空态断言先RED（仍出现一个按钮），iOS正常恢复及旧期限回归通过；修复后商业化134项全部通过，48项绘图重跑通过，analyze无问题、OpenSpec严格校验通过。1305 debug arm64构建成功19.9秒，SHA256 46767994653FAB8C4DDED48B024399447A0881DB1EB8AC33767FBD774C6D90D0。不改购买/原单恢复业务，未开启支付。

1304中间包已在用户本人已登录的手机上保留数据升级，实际会员未配置、空订单页面均正常。HTTP安全诊断未输出，精确status/code未采集，不补造200；截图含余额/身份仅保留私有临时目录，脱敏receipt另存。

1305包名/版本/证书已核验，但安装首轮及唯一常规重试均返回 `INSTALL_FAILED_ABORTED: User rejected permissions`，exit1。停止重试，未改变设备安全设置或清数据。实际手机仍1304、首次安装时间与登录保留，不能用1304图片声称1305按钮隐藏已经真机验收。最新源代码已通过测试并推送；新入口状态须在成功安装1305后复验，OpenSpec3.2保留未完成。

## 1305后续安装成功

用户再次要求安装后，重新核包名、版本、SHA与原证书，执行 `adb -d install --no-incremental -r` 返回Success。安装读回versionCode=2026101305/versionName=1.0.51，firstInstallTime仍2026-10-10 12:36:18，lastUpdateTime=2026-10-13 12:47:52；同一USB手机，18082反向代理保留，本地SDK51432仍监听。

已启动实际应用并核对普通首页/登录保留。实际会员页显示合法未配置且无加载失败，底部恢复购买按钮已不存在；Root实看新截图，原图仅在私有临时目录，不提交真实余额。1305订单导航检查过程中实际读取到积分包页，返回后首页已确认，未将该次动作伪报为1305订单验收；订单空态沿用1304实际验收和未变代码/134回归。未操作登录、短信、支付、购买恢复、清数据、安全设置或数据库。历史失败回执保留，新成功记录追加于同JSON，OpenSpec3.2已完成，等待产品验收后归档。
