# 实施任务

### Task 1: 会员恢复、配置折扣与流水标题
- [x] 修改Java/Flutter商业化展示与投影并完成实施者回归，证据见 verification.md。
- [x] root 独立复核本批实现与验证证据，规格与质量均通过。

读取本节为唯一任务简报。Java仓库D:/work/04phoneAgent/aiassistant-java，feature/test_v1.7.0，base98a75836；Flutter仓库D:/work/04phoneAgent/_isolated/phoneagent-task-flow，codex/dev，based1a20cca。root已创建本change未提交规格，属于本轮且需保留；不要混入其他路径。
执行用户已批准第1/2/4项。先读各AGENTS/导航、本change的proposal/design/spec。仅一个实施者，不派代理，不推送/打包/安装/部署/真实交易或凭据。
1) 积分包新增权威packDiscountBps字段，适用等级discountMembershipLevel在配置折扣<10000时保留（最低1分也有），不再仅实际降价才给。非积分包无折扣元数据，会员金额不变。保持构造/旧DTO兼容，不让APP按实付比值推断配置折扣；缺权威数据不猜7折。Apple标识仍配置权益，实际支付/展示StoreKit价。原价等于实付不虚构划线价，0.01仍有配置折扣标签，可标为会员7.5折权益。
2) 恢复按钮留会员页仅iOS，当前账号有Apple历史或可证明归属的待同步交易才显示。既有orders接口加可选channel过滤，旧签名重载保持，采用APPLE_IAP、page0/size1查询，不拉全部历史。Flutter用独立小history/visibility模块组合账户内待同步证据与历史；未加载/失败不凭空显示，迟到/切号结果失效。自动补单继续，无服务端订单但账号内pending仍显示；不把其他账号原生交易或支付宝历史当证据。先核对现有PurchaseController/NativeAttempt归属接口再接入，不用UI直接发网络。注意补单创建了Apple订单后要更新可见性。
3) SDK PointsWalletServiceImpl与后台PointsAdminAccountServiceImpl的MEMBERSHIP_MONTH_GRANT显示名改订阅会员积分；历史不写库，新增grant描述可按实际需要同步，优先仅投影标题。
4) 回归必须包括7500bps原价10分→7分标识7.5折、最低1分同价也有权益标签、正常3000→2250/2700、FREE/无折扣不标、会员商品不打折、Apple真实SKU价不改；恢复空/支付宝/Apple后页历史/当前账号pending/异账号/迟到/错误/补单后状态；旧响应兼容；旧历史标题投影。
5) 先真实RED再最小GREEN，固定JDK17/Maven3.9.14、Flutter3.32；运行受影响Java目录/价格/报价/订单及流水投影测试，Flutter受影响恢复/价格/会员页与旧交叉流程，不扩大无关模块。运行analyze、当前change strict、Flutter all；Java all既有audit-v66-single-call-stop-ui-parity缺delta只记录。UTF8/中文读回/diff。每手写微批不超过3文件。文档批独立。
6) 更新本change任务和verification、Flutter根tasks及issue log。各实际仓库中文本地提交，不推送。外部报告由root调度给路径，记录base/HEAD/RED/GREEN/职责与范围/风险，完成后停止本次Flutter测试。不要修改道歉或Web时间，后续独立任务处理。

### Task 2: 后台统一时间
- [x] 修改Web共享展示格式器与所有业务时间入口，完成定向测试/构建及独立复核。

Web仓库D:/work/04phoneAgent/aiassistant-web，feature/test_v1.7.0，base69f14dd，保留未跟踪output/playwright/product-ordering/。本change未提交规格为root本轮创建，应保留提交。只改本仓时间展示；先读工作区AGENTS/导航、README、change上下文。
新增共享时间展示工具，Asia/Shanghai、YYYY-MM-DD HH:mm:ss，空值—；ISO微秒截到秒，明确偏移/Z正确换算跨日，无时区采用已存在后台本地墙上时间约定，不能猜成UTC。未知非法值稳定占位，日期纯值/时长等避免误改。不要把replace(T)/slice各页再写一遍。
核对并迁入会员权益列表当前到期/observedAt/详情，订单/发票/记录通用格式器，积分账单、用户、SDK/客户端/操作日志、OTA/配置发布历史、价格配置、监控/仪表盘/任务详情等所有业务时间展示。可保留现有各模块formatter作薄适配以兼容调用，但解析/时区规则统一。查询/提交/签名/接口日期和时间间隔计算保持。
测试至少含+08微秒、Z/负偏移跨日、无时区本地、空/非法、用户截图值、两个现有Intl模块与replaceT模块一致，代表模板不再raw展示；已有所有相关Node测试及生产build，测试Node20与构建Node16.20.2依README。先真实RED最小GREEN，不为纯模板重复加镜像测试。可用现有浏览器fixture补截图但不可读真实账号，不部署。
单一职责、UTF8中文读回、每业务微批<=3文件，成批模板接线可记机械批；OpenSpec当前strict、diff。更新本change verification/任务、现有相关文档；中文本地提交，不推送，不派子代理，不构建APK或碰Flutter/Java。指定外部报告记录base/HEAD/测试与未覆盖运行态，后续root独立审查。

### Task 3: 道歉开场与候选权限
- [x] 修改Flutter道歉时序/候选过滤，完成实际Provider、语音宿主、320真实Shell入口和定向交叉回归，见verification.md。
- [x] root独立复核本批规格与实现质量，均通过。

Flutter仓库D:/work/04phoneAgent/_isolated/phoneagent-task-flow，codex/dev。仅批准第5/6项，前序商业化提交由root告知，不改价格/恢复。先读AGENTS/导航、当前change及align-clone-entry-and-apology-voice现有行为。
现状ApologyConversationBinding构造voice.begin立即生成同意卡，ConversationController构造已创建binding，而ConversationPrecheckController尚在检测；用户要求环境检测先完成，再出现/播报首次开场。应通过现有precheck通过/complete事件接线，明确一次性生命周期，不用Future.delayed/纯UI隐藏。检测中或失败不能出现开场、处理同意或播报；重试通过只一次；历史恢复不重播；切号/离开/迟到不展示；普通非道歉流程保持。已有precheck是presentation，沿用其完成条件，不修改真实外呼准入或虚构已连接供应商。
现状ApiApologyVoicePort.voices只看available和current READY/usable/providerAssetId或candidate READY/CHARGED，漏了后端cloneEntitled。SDK该字段包含通话模型+克隆权限且执行服务仍requireClone。按当前权限过滤候选和当前选中的模型；false必须隐藏/不使用，缺失或未知失败关闭，未发布legacy要显式证据才兼容，不能一律null放行。已有资产不等于有权限。可复用字段无需按FREE/等级硬编码。确认和切模时已有_query会重读voices，要保持权限刷新与代次/账号守卫，旧卡片不能绕过。READY/CHARGED候选activate=false确认后重查，不改默认音色或排队权限。
无可用候选正常说明无当前可用克隆音色并保留不使用取消任务，不把正常权限关闭当接口失败。真正读取失败仍重试。需要区分null兼容与真实错误时优先小命名规则/数据适配，不把网络或授权塞进页面/大controller。
先真实RED再最小GREEN：实际Provider新道歉创建，pending/failed/retry/complete重复与讲话时序、恢复和切号；available=true/assetReady但cloneEntitled=false不显示；允许current/candidate正常，确认时权限撤回/迟到与旧卡/切换阻断；有证据legacy与未知失败；真实shell道歉入口与非道歉不受影响；既有取消/请求字段/模型scope/OCR初始化保护。固定Flutter3.32、analyze、OpenSpec strict/all、UTF8/diff；不重复无关商业化612全集。可生成一个320窄屏时序/候选合成证据，不提交图片。
按每微批<=3手写文件，保持主controller已登记行数例外不继续扩大职责。更新本change任务/verification和根tasks/issue。中文本地提交，不推送/打包/安装/部署/真实账号或凭据，不派代理。外部报告由root调度给路径；完成后结束本次测试进程。

### Task 4: 完整复核与交付
- [x] 完成独立复核、UTF8/diff与相关回归，中文交付提交并按既有分支推送；实际远端读回见交付报告，不部署、不安装、不自动改版本。

### Task 5: 会员权益最近推进排序
- [x] 后端会员权益列表按最近推进时间降序分页，完成回归及独立复核。

用户实施中新增明确要求：管理后台会员权益页面按最近推进时间最新排前面，无需再次确认。Java仓库D:/work/04phoneAgent/aiassistant-java，feature/test_v1.7.0，实际base由root派发前git HEAD确认。先读AGENTS、知识导航及本change Java新增spec。只改列表读查询，不改权益运行/推进状态机。
当前MembershipAdminServiceImpl.page实际调用MembershipAdminMapper.mixedPage；SQL位于aiassistant-web-api/src/main/resources/mapper/commerce/MembershipHistoryMapper.xml，UNION新entitlement与legacy term。当前ORDER BY先状态等级。最近推进显示observedAt来自runtime.last_advanced_at，legacy NULL。使用原始datetime的内部排序列（非格式字符串）在LIMIT前按降序；空值置后，相同时间保留现有状态/等级/购买次序作为稳定次序及最终唯一id。新增内部列不得输出原始账号/新字段；筛选/总数/分页接口保持，不前端当前页sort。MembershipAdminMapper.xml的sequence用于详情entitlements等，必须保留其权益业务队列顺序；核对未用page接口是否需要一致性，不机械改sequence。Legacy无推进数据不得伪造为购买时间，空时间显示仍—；仅旧引擎fallback原行为保持因其无推进字段。
先编写真实RED再最小GREEN：实际加载两mapper的BoundSql断言首要排序列方向、LIMIT/OFFSET与筛选/count一致，SQL可解析；同时间稳定、NULL最后、跨页语义以及详情sequence不变需有有意义证据。已有MembershipHistorySqlTest/相关MembershipAdminProjection和Routing集合可复用，MySQL门禁缺环境明确跳过，不能声称真实DB验证；不新增无关数据库依赖或访问真实账号。JDK17/Maven3.9.14，当前change strict、UTF8中文读回、diff；每手写微批<=3文件。可新增小专项测试，不重构Service/无关表。不改Flutter/Web生产文件，不派子代理、不推送/打包/部署/真实数据。更新本change任务/verification，中文本地提交；报告root给路径记录base/HEAD、全部验证与未验项，结束本次测试进程。
### 本轮测试签名包交付
- [x] 用户确认仍用1.0.52 (45)；从已审c42c97f1冻结源码构建测试Release并完成登记签名、环境、AOT与保护库核验，见verification.md。
