# iOS 积分购买完善与验证（2026-10-14）

## 授权及范围
用户确认执行侧会话修改计划；保持原分支，仅本地修改，不提交/推送、不真实收费。变更为`harden-ios-points-purchase`。开始时docs/codex_issue_log.md、tasks.md、integrate-dev-zys-20261014/tasks.md已有修改；前两者仅追加本轮记录，未编辑集成change的已有任务。后端、旧项目、Podfile/锁文件/工程签名及依赖版本未改。

## 最终行为
- 服务端目录与Apple查询分离。价格区加载转圈，失败蓝色重新加载（全列表Apple SKU、防重），成功缺SKU、禁售或类型错误显示暂不可售。
- 商品卡、确认弹层使用原样displayPrice，复用Flutter价格组件及既有卡片/按钮/弹层。会员直接调用方共享同一价格状态，不另造样式。
- 精确Decimal字符串、currencyCode、productType跨本地桥；人民币分用BigInt对比。积分包只支持consumable，会员保留consumable/nonRenewable。未知金额单位不猜测，当前非CNY阻止支付，待服务器多币种契约。
- 购买条件检查Apple渠道、设备权限、商品可售/类型/金额、协议和未完成订单。报价校验产品/配置身份；确认后重新预检，Swift拉起前再比较本地确认快照。变化后刷新服务器目录及Apple数据，重新确认。
- iOS取消、等待确认、未知结果、积分到账处理中、可信到账独立反馈；处理中用中性蓝色图标。支付宝反馈、渠道传参及重试语义保留。Pending/未知不重复拉支付、不自动关闭或释放原订单。
- 原生Transaction.updates通知与unfinished扫描；账号作用域控制器串行消费、同交易去重、主动购买验单须同原单。切号dispose禁止迟到finish；服务器拒绝保持未完成交易。服务端可信payment SUCCEEDED后finish的既有规则保留，履约成功才显示到账并刷新钱包。
- 已登录iOS在App持有恢复控制器，启动/回前台/更新可恢复；历史支付宝订单查询也不能漏扫描Apple。不同生命周期的验单去重抽为独立helper。所有修改手写源码低于500行，购买控制器约450行，仍按单一购买/原单流程保持；无例外新增。

## 实际验证
| 范围 | 结果 |
| --- | --- |
| `flutter test --no-pub --reporter expanded test/features/commerce test/session_nested_routes_test.dart test/session_route_lifecycle_test.dart` | 302通过；之后微批另行复验，不记全量 |
| 最后价格/恢复/StoreKit反馈/桥直接调用方5个测试文件 | 19通过；包含原单身份、切号、拒绝后重试、历史支付宝订单扫描和迟到预检 |
| direct_checkout_route / checkout_owner_lifecycle / membership_checkout | 17通过；最后页面刷新接线复验 |
| `flutter analyze --no-pub` | 最终无问题，4.3秒 |
| `flutter build ios --debug --no-codesign --no-pub --dart-define=APP_ENV=dev` | 最终通过，Xcode8.1秒；com.chaken.phoneagent.test，未签名未安装 |
| `openspec validate --all` | 128通过，0失败（最终文档后复验通过） |
| `git diff --check` | 通过 |

以上测试集合重叠，不累计为新增总数。未执行全仓Flutter回归、Android重打包或真实支付。

## 原生 StoreKit 未通过项
主工程RunnerTests最初未显式指定Simulator SDK；核对后明确指定SDK仍因Pods测试架构排除arm64失败。第三次命令覆盖测试架构后，链接被既有IdentityCaptureSDK/APBToygerFacade真机arm64对象阻挡。未修改该SDK、Pods或产品构建基线。

`tool/prepare_ios_commerce_native_tests.rb`使用已安装CocoaPods的xcodeproj，在仓库外临时目录生成仅含现有CommercePaymentChannel、RunnerTests、Flutter模拟器框架的独立宿主。只在专用新模拟器执行，无业务账号/真实商品或费用；该模拟器已删除，现有设备数据未操作。

独立宿主成功编译并实际运行两项本地StoreKit测试，但SKTestSession保存配置、设置属性均报`SKInternalErrorDomain Code 3`，导致商品列表为空。开启仅临时宿主的adhoc模拟器签名/本地scheme配置后仍失败，最终2项测试、3条失败断言。原因尚未确认，配置/测试宿主/平台仍需排查；不能声明价格变化、AskToBuy批准、原生unfinished/finish运行通过。保留原生测试源码及失败记录，不以Dart合成通道通过替代。

## 仍需验收
1. 修复并重跑本地StoreKit会话；真实iPhone取消、Pending延迟批准、杀进程恢复、切号、重复交易及UI。
2. App Store Connect真实SKU/商品类型/地区可售性、CNY报价一致性；非CNY需要先批准服务器币种及金额单位契约。
3. Apple服务器验单与账号绑定、持久积分履约/补偿及可信支付成功后finish的完整保证；真实沙盒到账链路。

OpenSpec保持active，不归档；实际日志保存在忽略目录`.local/ios-commerce-20261014/`。主工程及独立宿主的完整临时Xcode日志还在本机/tmp，本记录仅收录无敏感材料的错误摘要。

## 官方参考
- [StoreKit displayPrice](https://developer.apple.com/documentation/storekit/product/displayprice)
- [Transaction.updates](https://developer.apple.com/documentation/storekit/transaction/updates)
- [Transaction.finish](https://developer.apple.com/documentation/storekit/transaction/finish())
- [SKTestSession](https://developer.apple.com/documentation/storekittest/sktestsession)


## 追加：商品获取至支付完成的调试信息

用户追加授权已实施。只在iOS商业化依赖注入启用，沿用账号隔离的诊断journal及既有日志上报，不添加UI、自动上传、网络请求或支付重试。日志存储/控制台写入失败不能改变支付结果。

### 查看方式
1. 运行包含本轮修改的iOS Debug版本，在Flutter或Xcode控制台筛选`COMMERCE`。`COMMERCE`后为结构化JSON，`COMMERCE_NATIVE`为StoreKit桥的阶段/数量/受控错误元数据。
2. Profile/Release的Flutter结构化事件仍进入现有账号诊断日志。通过“设置 → 关于PhoneAgent → 日志上报”手动上报后，在日志中筛选`operation=commerceFlow`。该入口是上传操作；本轮没有操作上传。
3. 用`sessionId`串联一段账号生命周期，结合`productRef/skuRef/quoteRef/orderRef/transactionRef`连接商品、报价、订单和交易。ref为原标识UTF-8 SHA256的前16位hex；同订单/交易在应用重启后的恢复段仍有相同ref，新sessionId表示新生命周期。原始标识不进入新增日志。

### 阶段与判断
| stage | 排查内容 |
| --- | --- |
| catalog | 目录/会员读取开始、结果、数量和耗时 |
| availability / products | 设备内购可用性、Apple查询开始/结果/耗时、请求与返回数量 |
| product | 每商品映射、可售性、精确金额/币种/类型；missingProduct、typeMismatch、currencyMismatch、amountMismatch等原因。skuRef为空代表未配置映射 |
| selection / agreement / confirmation | 选品、同意协议及购买确认/取消 |
| priceCheck | 支付前重新查询后校验通过或拒绝；不是“商品查询返回”就认为价格已通过 |
| quote / createOrder / paymentMaterial | 服务端报价、下单、支付资料获取耗时及关联关系；不记录请求体/支付参数 |
| nativePurchase | cancelled、pending、material或unknown；收到verified材料不等于付款或到账成功 |
| transactionUpdate / nativeRestore / recovery | 迟到更新、未完成交易发现、启动/前台恢复和受控失败 |
| verify | 服务器验单、去重、账号失效、原订单不匹配；拒绝后不finish |
| finish | 已有服务器可信付款确认后的原生交易finish开始/结果/耗时；不等于积分履约成功 |
| orderState | 明确paymentState、fulfillmentState和appState；只有二者SUCCEEDED且state=completed才是可信完成，crediting仍在履约 |
| dispose | 账号作用域控制器释放，结束旧生命周期 |

阶段请求的succeeded表示该步骤完成，不能替代orderState的付款/履约事实。常规成功轮询只在状态变化时记录，避免淹没关键事件；失败仍记录。价格是必要业务元数据，displayPrice及任意文本不入日志。

原生失败可保留`nativeStage/nativeDomain/nativeCode`：例如products、purchaseGate、productUnavailable、verification、finishLookup。domain/stage为白名单，code为有界数字；不会记录NSError.localizedDescription、PlatformException.message、JWS/收据、appAccountToken、原始订单/交易ID或完整parameters。原生控制台同时区分查到商品总数与支持类型数量。

### 本轮实际验证
- `flutter test --no-pub --reporter expanded test/features/commerce test/features/app_logs`：395项通过。
- 克隆隐私/流程、认证诊断/作用域、翻译绑定5个直接调用方文件：28项通过，验证公共DiagnosticEvent新增可选字段的兼容性。
- 最终新增两个商业化诊断测试文件：7项通过；包括持久化回读、敏感材料拒绝、sink抛异常、轮询去重、原生Pending/取消不误报成功、目录→付款→finish→履约关联，以及模拟Code3原生失败的安全采集。
- `flutter analyze --no-pub`：无问题；iOS Debug无签名编译通过，Xcode10.2秒；未安装、未真实支付、未上报日志。
- OpenSpec全仓与diff最终校验见本轮记录。测试集合重叠，不相加为全仓回归。

初轮测试实际发现commerceRequestId为32位hex，journal只允许UUID，导致诊断session被丢弃；改为独立UUID格式后重测通过，支付幂等键未改。此前本地StoreKit会话Code3仍未验收，本轮只模拟错误采集和编译，不把日志测试当作系统支付通过。

源码职责分离：公共闭合schema、commerce诊断helper、Repository观察装饰器和通知生命周期各自独立，购买控制器498行，无新增500行例外。真机控制台、Profile/Release实际日志包采集及真实渠道验收仍待进行。保留原有工作区修改，不提交推送、不归档。


## 追加：积分购买协议点击校验与Android一致
用户确认实施：iOS可售积分包未勾协议时“确认支付”仍可点击，复用原preview校验提示“请先阅读并同意付费协议”；不请求报价、不创建订单、不拉Apple支付。协议拒绝记录agreement/failed/agreementRequired。该错误不再触发iOS目录重载，商品选择和已加载信息保留。商品/渠道/价格有效性、忙碌与待处理订单禁用保留；勾选后的购买确认与支付流程不变，Flutter布局/样式/共用控件保持。

源码微批仅points_purchase_page、membership_checkout、membership_route三个文件；测试微批更新价格区按钮断言并新增真实MembershipRoute→积分页点击→提示连续流程，校验无报价/下单/支付/目录重载及拒绝诊断。6个定向文件22项通过，包含Android原流程和iOS勾选后正常购买；analyze无问题。首轮21通过1失败仅为新增测试debug平台变量未在框架不变量检查前复位，修正清理顺序后同集合全通过。

OpenSpec与diff校验通过；未改平台/依赖/构建链，不重复打包、未安装、未触发真实支付，不提交推送、不归档。当前设备1406不会自动包含本次新修改，真机交互仍待后续更新包验收。
