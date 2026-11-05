# 钱包与评价共享页面增量

2026-09-17：静态优先，交互完成不等于视觉验收。用户已明确授权运行态设计缺失不阻塞页面实现；不以臆测像素数据填充覆盖率。

## 页面与分层

- 钱包、流水：PointsWalletRoute共享controller；PointsWalletPage/PointsLedgerPage纯状态与回调。首页PointsBalanceBadge为入口。
- 赞踩：CallEvaluationRoute/Card/Controller；只有稳定callId或非RUNNING batchId挂载。
- 条件评分：TaskRatingRoute独立资格、单owner，TaskRatingSheet语义表单；只读查看与成功对话框；TaskRatingController管理草稿与提交，SecureTaskRatingDraftStore负责存储，API复用已有协议。
- 没有新增AppRoot/通用JSON renderer/原生页面。生产AppRoot与导航系统沿用现有工程；辅助preview独立debug入口不编入普通main。
- 手写Dart文件全部小于500行，架构测试通过。UI不直接调用API/存储；无新依赖。

## 设计来源/资源/差异

来源：固定 `0cd58de9` memory/css/monetization.css、memory/js/monetization.js、pure-voice.js的SVG，及现有ShellTokens/Flutter控件；行为以固定v65 `4c781e3` WalletScreen/LedgerScreen/AgentCallEvaluation/TaskRatingSheet为准。没有新增NormalizedDesignTree运行态测量数据，高保真/layout覆盖率未测量，不宣称100%。

| 控件 | 来源/映射 | 待统一校准 |
|---|---|---|
| 首页余额徽标 | HTML34高、17圆角；points.svg→积分星标 | 真实字体/标题间距 |
| 钱包TopBar/余额卡 | 现有返回SVG；v65 32字号、18圆角卡 | 与完整设计运行态像素差未测 |
| 流水 | v65正负颜色、时间/描述/余额；HTML白卡背景 | 列表密度/细分割线 |
| 赞踩 | pure-voice原SVG→thumb_up/down；198宽评价卡 | 采用可访问48触控区，非原型小点击区 |
| 条件评分Form | v65无默认1–5按钮、克隆不评价、滚动建议 | 复用Material3表单/按钮，不声称原型像素一致 |
| 成功Dialog | v65文案/奖励规则；共用AlertDialog | 当前居中系统组件，v65底部圆角布局留校准 |

资源均局部矢量，不用截图当整页背景，不用坐标overlay。系统状态栏/导航栏由平台提供，SafeArea避免重复绘制。钱包/流水使用剩余高度滚动；评分表单主体滚动、提交按钮固定底部，结合键盘viewInsets；320宽/大字/键盘以及390宽路由有widget回归。

## 交互与状态

2026-09-17余额同步增量：沿用现有文本组件，区分余额过期与流水过期；独立准入刷新后显示“余额已更新，积分流水待刷新”，流水页提示待同步且不伪装空列表。页面语义Widget新增回归，真实浏览器普通钱包/流水返回刷新通过；未制造真实扣费测试新状态，不作为视觉校准通过证据。

导航边：首页→钱包→流水；两个显式返回以及系统返回；回执→条件评分→成功提示→只读评分。赞踩是回执内动作。保存中禁止重复提交/关闭，失败可重试，关闭未提交表单保留草稿。所有按钮、表单、刷新、分页均语义组件，无绘制伪按钮。三维15个评分按钮，克隆可见时再增加5个和不评价开关；实际资格控制可见数量。控件事件绑定覆盖上述生成控件；尚未完整扫描设计全部节点，页面/状态覆盖率不伪造百分比。

状态覆盖：钱包未知/加载/成功/旧快照/错误/空流水/分页；赞踩隐藏/成功/选择/保存/回滚；条件评分隐藏/可编辑/克隆条件/超长建议/保存/失败/成功/只读。回归与真实/mock证据见 docs/engineering/WALLET_FEEDBACK_VALIDATION.md。

## 排除与残留

无会员、购买、订单、发票或支付。钱包离线持久缓存、激活赠送、计费准入/结算、真实奖励和真机验证未完成。视觉统一校准未开始；待补运行态基准后统一登记逐节点diff，不反向修改已确定功能。
