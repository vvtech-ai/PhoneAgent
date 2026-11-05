# 积分页面静态交互契约

固定源：设计 `0cd58de9` memory/css/monetization.css、js/monetization.js；功能 `4c781e3` PointsWalletScreen/PointsWalletPresentation/PointsBalanceFormatter/FinalHomeTopBar/PhoneAgentPricingPresentation。2026-09-17 用户授权静态优先，未获取本批运行态计算样式，不声明视觉已还原。

| 路由/状态 | 控件和行为 | 实现映射 |
| --- | --- | --- |
| 首页 | 积分徽标：未知 -- / 千分位余额，点击积分页 | PointsBalanceBadge + ShellRoute |
| 积分页 | 返回、可用余额、参考分钟、后端每日赠送事实、积分流水、刷新 | PointsWalletPage |
| 流水页 | 返回积分、分页、错误重试、空、刷新 | PointsLedgerPage |
| 首次加载/失败 | 不造零余额；错误可重试 | PointsWalletState.account=null |
| 已知快照刷新失败 | 保留数字并提示非最新，不算入结算 | PointsWalletState.stale |
| 账号变化 | 销毁旧控制器，不跨账号复用数据 | accountApiProvider 代际绑定 |

组件参数：mon-balance-pill 最小高34/水平10/圆角17/灰底#f1f2f4，星形16px；mon-screen背景#f6f7f9，header返回44px/标题20px；balance-card白底/圆角18/水平20竖向18，数字32–34px；流水行左右16/上下15、正数绿负数红。使用平台SafeArea和可滚动内容，排除设计系统状态栏。

资源：积分星形来自 monetization.js 内联SVG path（24×24），落地 assets/images/shell/points.svg；返回复用 identity_0.svg。没有预览图铺底或透明点击层。目标是一个共享Flutter实现，不产生两套原生页面。

排除：会员等级、购买积分、充值支付、订单、发票及原型写入本地余额。不添加设计独有功能。钱包预计分钟沿v65基准100积分/分钟，仅为展示。

视觉待校准：标题位置、卡片阴影、徽标细节、字体平台差异和大字折行；功能优先用既有组件，尚未做像素比较。Native本批效果与真实评分仍列集中验收。

## 回执赞踩

来源：v65 SingleFlowConversationContent、AgentCallEvaluationRoute/Card/ViewModel；设计 memory/js/pure-voice.js pvAddTaskRating 的两枚 thumb SVG。正式回执下方装配 CallEvaluationRoute，展示使用模型、平均时延、赞/踩；纯页面通过可选 builder 注入，离线预览不默认接入真实网络。只有服务端模型名非空才显示；单路使用 callId，批量仅非 RUNNING 且有真实 batchId；不使用 session/attempt/local fallback 作为评价锚点。

保存沿 v65 乐观选中，失败回滚并显示重试文字，保存中互斥，旧请求/账号不得覆盖新状态。不把原型“评价送100积分”带入赞踩卡。条件任务评分是另一协议/入口，不由赞踩代替。thumb SVG落地 assets/images/conversation/thumb_up.svg / thumb_down.svg，当前卡片198宽/圆角14/横12竖11；触控保留语义按钮，精确视觉后校准。

## 条件评分

后端eligible和稳定回执锚点控制入口；TaskRatingRoute/Card owner防重复；TaskRatingSheet无默认分值、三项必填、克隆条件和不评价选项、300码点建议、提交互斥、失败原稿重试、关闭保留、已提交只读；成功奖励仅读后端并刷新钱包。草稿存储不与展示混合，协议保持ApiTaskRatingRepository；真实写入待人工，浏览器独立MOCK端口只操作内存。样式从v65表单和现有Material组件构建，居中成功Dialog与原底部版式的差异留后校准。
