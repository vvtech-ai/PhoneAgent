# 国外翻译交互产物

## 2026-09-17 模型sheet增量

来源v65 AssistantTranslationModelSheet/ModelLatencyPolicy，沿现有TargetAppConfig与用户静态优先授权。补`model-sheet-contract.json`：最大420、20顶圆角、24/20/32内边距、14行圆角/1.5边框、17标题/15模型字号；刷新采用文字控件，关闭复用dial_close.svg，不下载图片或新增整页背景。源红黄绿延迟pill暂用明确文本等级，倍率未接不伪造；运行态设计对比待统一校准。

新增一条dialer→modal→dialer往返及六组语义动作：打开、两项选择、刷新、关闭、系统返回/遮罩。RadioListTile点击已选项也关闭；普通GET质量与MOCK路径隔离，刷新时保留旧值和禁重复。SafeArea+可滚动内容，没有固定短画布。新增源码均低于500行，main/router无扩张，domain/data/app/widget分层。

11项新测试/807全量、analyze、Web/Android Debug、19项OpenSpec通过；普通浏览器截图显示完整两行/选择圆点/刷新/关闭，无溢出；测速刷新、选择GPT/重开/恢复Gemini/返回首页验证。三种短屏自动测试通过。无本批双端安装/像素比对，不给高保真分数；集中说明见TRANSLATION_CALL_VALIDATION。

输入：固定v65 `4c781e3`、设计HTML `0cd58de`、现有DialerPage；用户允许静态参数/既有组件先行。没有运行态高保真/像素通过结论。

## 结构和导航

10个新增Dart文件：2个纯领域模型、2个独立控制器、4个页面/入口文件、2个控件文件。最大200行；main.dart未扩张，无JSON解释器、透明点击层或整页截图。

7路由/9条边、13个页面/通话状态、13组关键动作在interaction-contract.json登记。所有动作绑定真实Switch/Button/RadioListTile/InkWell/Navigator；配置/语言/底部提示层支持系统返回和取消，活跃通话按v65拦截返回，演练另有退出。生产外呼受真实端口门禁阻止，不是无响应按钮。

## 参数级映射

| 组件 | 来源与消费 | 已知差异/待办 |
|---|---|---|
| 拨号头/键盘/主按钮 | 既有dialer静态设计和SVG close/call/delete；配置插槽不复制键盘 | 翻译原型按钮色与整体间距待统一校准 |
| 语言/提示层 | v65两开关、两语言卡、54高CTA、24圆角、20水平边距；Navigator层叠返回 | 平台AppBar/Radio控件允许先行，视觉后校准 |
| 海外设置 | v65 Gemini/OpenAI、Default/US/JP、14水平边距 | 仅页面会话偏好，未接实际目录/存储 |
| 通话标题/转写 | v65标题24、状态12、计时13；82%气泡宽、14×11内边距、18圆角、15/12字号 | 正式环境指示器和最低环境检查展示时长未接 |
| 四按钮/DTMF | v65 Material矢量对应Flutter Icons；64圆、28图标、7标签间距、14挂断间距 | 不是旧HTML三按钮或Unicode近似；真正媒体路由待接 |
| 系统/短屏 | SafeArea、底部控制锚定；短屏剩余区不足140时标题随内容滚动 | 不绘制状态栏/Home Indicator，不采用固定画布 |

资源来自已落地dialer/identity资源与v65明确使用的Material图标；没有新图片下载、preview切片或fallback背景。布局/控件映射见component-tree.json与call-component-contract.json。源SVG复用在拨号页，语言/settings使用平台返回控件，最终视觉统一校准时核对。

## 验证

21项新回归；全量484项/analyze、Web405项+Chrome2项+Node1项、19项OpenSpec通过；Web/Android Debug构建通过。浏览器配置、语言/海外返回以及通话阶段/双语/四按钮/DTMF/挂断返回实测。320短屏48px溢出已修复，重新回归通过；无障碍重复按钮标签已移除。

尚未验证像素差、双端新包、真实权限/地区、媒体/呼叫/归档/费用。未给主观相似度或高保真分数；mock仅共享UI演练。详细实现与集中人工步骤见TRANSLATION_CALL_VALIDATION.md，OpenSpec 1.2/2.2/2.3/2.4保持待办。
