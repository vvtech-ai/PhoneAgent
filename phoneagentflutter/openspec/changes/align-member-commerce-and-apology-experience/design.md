# 设计
用户已在对话中批准六项现有行为修复，并最终确认恢复购买保留但空记录隐藏。沿用现有分层，不新建子系统。

## Global Constraints
- 会员商品固定后台配置价。积分包最低实付1分保留；折扣标识表示当前等级后台配置权益，不再用实际金额比值反算，最低1分仍显示配置折扣。Apple价格与SKU支付保持。
- 恢复入口证据必须当前账号隔离；正常无记录、未加载、失败不凭空显示。自动补单不能依赖服务端订单已存在。已有账号归属保护、旧交易/迟到结果、取消与幂等保留。
- 后台时间仅展示统一Asia/Shanghai，格式YYYY-MM-DD HH:mm:ss，空值—；有时区先转北京时间，不重复加8小时。查询/提交/签名/时间间隔不改。
- 道歉只在现有环境检测通过事件后展示/播报首次同意卡，失败等待重试；不得用固定延时凑顺序。账号切换/退出失效，重复通知不重复开场，历史恢复不重播。
- 道歉候选必须权限允许且资产READY可用；使用服务端cloneEntitled（包含通话+克隆权益），不能仅available或历史资产授权。确认/切换/发起时重读现有权威数据。未知权限失败关闭，保留有证据的未发布legacy兼容。
- 仅修改请求可追溯文件，UTF8/中文读回。固定JDK17/Flutter3.32，不部署、不安装、不触发真实登录/支付/外呼，不读真实账号凭据。保留Web未跟踪output目录。

## 分工与接口
Java ProductOffer增补可空packDiscountBps配置折扣元数据，非积分包为空；现有discountMembershipLevel用于适用等级，合法折扣最低一分时也携带，金额不变，保留旧构造/旧响应解析兼容。Flutter仅展示权威折扣，不计算实付。
恢复历史用既有账号订单分页接口增补可选channel过滤，APPLE_IAP、page0/size1轻量查询，不为可见性拉全量历史；账号仍来自认证，缺省过滤保持原行为。Flutter通过独立小型历史/恢复可见性模块组合现有自动补单和账户内待同步证据。
Web新增统一时间展示工具，小型规则与既有formatter接入，不在每页重复解析；不猜测无时区数据为UTC。
道歉在现有provider/controller/binding扩展生命周期接线，不把开场/权限逻辑塞进页面或超限主控制器。已有cloneEntitled权威字段优先复用。

## 验证
每批先真实RED再最小GREEN；Java目录/报价/订单/折扣与流水投影，Flutter恢复/价格/入口时序/权限交叉回归，Web格式器与相关页面断言/构建。每批独立规格及质量复核，最后完整跨仓复核。定向集合通过后不无理由反复全量。

## Task 3 接线与权限细节
正式道歉入口均由 conversationControllerProvider 创建：依赖显式 waitForPrecheck=true，binding 先不生成 prompt，等待期间输入直接消费而不缓存。OCR owner 完成赋值、speech 和其他监听建立后才订阅现有 precheck；presentation.visible=false 等价 complete 且未 blocked 且 modelReady，触发幂等 begin。同步已完成回调也不会提前读未初始化 owner。恢复 binding 独立标记已开始；普通会话不增加 precheck 订阅。VoiceHost 在道歉无 prompt 时不回退旧 entry.opening。

ApologyCloneAccess 单独负责一次目录读取中的权益适配；ApiApologyVoicePort 继续负责资产可用性及同模型检查。cloneEntitled=true 放行，false 正常过滤，但 ENTITLEMENT_UNAVAILABLE 优先作为读取失败。缺失/null 仅在 api/commerce/catalog 明确返回整数 configVersionId=0 时兼容；未知/错误/字符串0不授权。Java CatalogResponse 为 long，Flutter CommerceDto 既有契约也是整数；SDK legacy 的 null 本身不构成未发布证据。该证据仅在本次 voices 调用内复用，确认和切模新读不沿用缓存。

候选仍 activate=false 确认并再次读目录。重读已过滤该模型时走正常无可用音色；仍有同模型候选/不匹配当前资产表示确认尚未可见，保留原重试。执行服务 requireClone、默认音色、会员排队权限、接口请求字段及真实外呼准入不变。
