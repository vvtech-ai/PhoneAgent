## Context

用户于 2026-10-26 明确批准三项需求并要求创建提案后直接实施。三仓使用当前 feature/test_v1.8.0 检出，保留 Flutter 两处打包脚本和 Web 原有 output 未跟踪目录。已阅读工作区研发入口、目标仓规范、已有会员展示变更及源码；通用 vibecoding 导航属于 OMS，不作本项目事实。

## Goals / Non-Goals

**Goals:** 精确邀请时间、可运营的模型目录、可编辑会员介绍；保持权限、账号偏好、任务有效模型与历史购买数值。后台/客户端字号对应并提供真实界面证据。
**Non-Goals:** 不部署，不写共享环境，不真实外呼/支付，不改安装版本，不重构任务状态机。

## Decisions

### 跨仓接口

1. Web API 新增 GET/PUT /admin/api/ai/call-model-presentation。GET 返回 {defaultModelId: string|null, rowVersion: number|null, models: [{id,modelName,appDisplayName,appSubtitle,status,sortOrder,rowVersion,recommended}]}。PUT {defaultModelId: string, rowVersion: number|null, items: [{id,rowVersion,sortOrder}]}。items 必须覆盖当前全部未删除 REALTIME_VOICE 模型，顺序从 0 开始且唯一。默认只允许启用并支持的通话模型；保存事务校验目录完整、每行版本及默认配置版本，冲突返回既有错误语义，不半保存。
2. 排序复用 ai_model.sort_order。默认独立存 global_config，键 app_default_call_model，先登记 GlobalConfigKey；空配置不读写生产数据。旧通用配置入口不得绕开专用默认值验证。SDK GET /api/account/settings/realtime-call-provider 复用原目录/权益检查，选择优先级为有效账号偏好、可用配置默认、排序中第一个可用项，无可用项保持空。保留既有自动保存偏好机制，不追溯区分自动和手动。
3. CommerceBenefits 新增可空 displayItems: [{id,title,description,fontSize}]。id 为稳定且唯一字符串，长度 1..64，保留 monthlyPoints 禁止手填；title 去空白后 1..200，description 0..200，fontSize 为 REGULAR/LARGE，最多 30 条。null/缺失沿旧介绍展示；空数组明确隐藏其他介绍。每月积分不进入数组，仍由 monthlyBasePoints/monthlyBonusPoints 生成。保留 displayOptions.monthlyPoints.fontSize 和旧 JSON/Java 构造兼容。有效会员投影取当前发布 displayItems，购买数值沿原快照，展示不授权。
4. Web 首次编辑旧配置时，将现有真实介绍转换为可编辑列表；仅应用时写入草稿，取消不写；月积分首行只读，四档保持原数值语义。字体每条独立，移动条目携带 id 和字号。Flutter displayItems 缺失时旧渲染，存在时按数组顺序渲染，每月只读首行独立。
5. Web 邀请总览与记录采用 datetimerange。使用 Asia/Shanghai 墙上时间转换 Instant，from 包含、to 排除，结束必须晚于开始；快捷今日/近7日/近30日为北京整日边界，全部清空。查询与 CSV 使用同一范围，不给手选结束时刻额外加一天。

### 文件职责与扩展

Java 新增独立 presentation Controller/DTO/Service 与默认读取/选择规则，不扩大 AiRuntimeConfigServiceImpl；公共权益条目 DTO 与校验独立。Web 新增 call-model-presentation feature 弹窗/API/规则；会员文案与预览独立组件接现有表单；日期转换留纯策略。Flutter 介绍投影与行渲染独立，页面接线最少。未来新增模型复用目录，新增介绍只填列表，无需给核心拼接分支。

### UI 基线与状态

视觉来源为本对话三张截图及现有 Vue Element Plus/Flutter 会员卡。沿用蓝色、浅灰边框、圆角与现有交互；新增弹窗保留标题/底部操作，内容可滚动，桌面有预览、窄屏单列。拖动配上移下移，支持键盘。常规标题/描述 13/11，放大 18/13（逻辑像素），月积分与手填项使用同一配套规则，月积分数字仍可沿既有强调。状态覆盖加载、空项、失败重试、禁用、并发冲突、长文、大字体。App 保留推荐/延迟/灰态，目录不按当前选中或延迟重排；后台更新下次读取生效，不跳动已打开弹层或改任务。

## Risks / Trade-offs

- 老客户端不识别新介绍 → 保留旧字段与缺省兼容，先后端再 Web/Flutter 发布（本轮不执行部署）。
- 默认对部分等级不可用 → SDK 根据当前账号现有权益回退，不授予权限。
- 三端并行契约漂移 → 同一 design/interface，集成核对序列化字段和空数组语义。
- 无设备/后端环境证据 → 分层标记已测与未验证，不用 fixture 代替真实联调。

## Migration Plan

无破坏性数据库迁移。后端兼容读取新增 nullable 字段和缺失默认键；运营通过专用界面显式保存默认值。回退客户端保留旧字段，新 displayItems 仅展示。默认配置撤销通过受控专用保存/恢复原值，不自行操作共享数据库。

## Open Questions

无待用户确认业务项。运行态/真机 UI 证据按实际可用环境记录。

## 2026-10-26 用户反馈补正（当前确认版）

沿用已批准变更，用户要求拉取最新 feature/test_v1.8.0 后修正颜色、标题长度及入口；随后明确增加实时翻译，最终明确实时翻译不分国内外，使用同一排序。本节为最终范围，替代讨论中的国内/国际拆分草案。

- 月积分只读首行仅积分数值使用既有蓝色 #3478F5；“每月到账”和“积分”文字保持 #202532（用户最后纠正：是积分蓝色不是所有标题蓝色）；说明常规 #858991、放大 #7D8491，其他标题 #202532，配套字号13/11和18/13保持。不是可运营配色，不新增颜色配置。原权益标题及已填写文案原样保留，不用新文案替换。
- 标题上限由60改为200（Web输入/校验与Java校验同步），描述仍200。后台标题多行输入、预览与App自然换行，200允许201拒绝，不截断已有标题。
- 模型配置菜单保留。删除顶部总入口，在实时语音通话和实时翻译的原分组标题旁各放明显按钮，打开对应弹窗状态；共用弹窗只分通话/实时翻译两个场景，标题与按钮对应。克隆只沿通话目录过滤后的排序，不自动选定克隆模型。
- 既有call-model-presentation接口兼容；新GET/PUT /admin/api/ai/translation-model-presentation无region参数，JSON沿用既有Configuration/Save。目录包含全部未删除REALTIME_TRANSLATION模型，单独完整保存顺序和默认。默认键app_default_translation_model，受专用验证/停用保护，不允许通用配置绕过。保存推进既有翻译目录configVersion。
- SDK翻译账号设置先按现有地区/准入过滤，保留有效偏好，再选统一后台默认，再统一序首个可用。TranslationOptionsResponse兼容新增nullable defaultTranslationModelId；模型和国家绑定可选ID统一按ai_model.sort_order顺序，保留国家/协议/语种/计费与会员边界。App同样保留有效exact ID；有后台默认但不适用则序首可用；没有后台默认保留原兼容回退，不修改已打开通话。
- 验收先失败回放颜色/84字和200/201标题，再验证两场景加载、取消、切换防串、默认/排序独立、地区回退及克隆顺序；实际浏览器1440/390截图，Flutter组件渲染与自动回归分层，真实后端/真机另记。