## 依据与职责
基线test_v1.8.0_fix@f285726b，起始干净，未对实际安装构建作验收推断。已读取AGENTS、README、MIGRATION_BASELINE、工作流spec及两个说明active change的proposal/design/tasks/delta。用户附件明确色值、11号/400；20/8底距为用户已批准计划值，并非截图测量值。
仅固定本说明Text的textScaler，不改变父MediaQuery或其他文本。共用浅/深两种明确主题，ConversationAiContentNotice保留轻量封装调用共享组件。说明独立于按钮enabled/Opacity。
页面承担SafeArea一次、Scaffold键盘避让一次；Composer只处理20/8额外间距。AI任务页底部18改20。翻译页保留可滚动控制区，将说明置于滚动区外，底部原20不变；控制组件仍可独立使用并默认含说明，正式页显式省略内置说明，避免两份。
正常单行，极窄允许居中换行，不ellipsis、不缩小或裁剪。保留按钮、标签字号、背景、布局主结构和所有回调。
## 批次和验证
先更新现有样式测试及新增整页底距测试确认旧实现失败。微批1共享控件/对话封装/Composer，微批2通话/翻译控件/AI任务页，微批3翻译页；测试独立，format机械批。
覆盖Android/iOS、320/360/390/430逻辑宽、短屏/长屏、系统1/1.3/2倍字号、0/34安全区、DPI差异、键盘开合、语音/文字切换、拨号盘展开、挂断禁用/终态。运行analyze与说明/页面/直接输入调用方定向测试，OpenSpec与diff。没有真实电话、音频或原生变化，不打包安装；真机视觉待验。

## 2026-10-28 iOS非零安全区间距追加
用户在侧会话确认计划并执行。当前检出test_v1.8.0_fix@2a9ec798干净，仅本轮本地修改，不切分支/提交推送，保护主线程。
展示层owner：AiContentNotice集中提供条件间距，ConversationComposer、CallSessionPage/CallControls、TranslationCallPage/TranslationCallControls负责一次性应用。无接口和业务身份变化，ENTRY-05/STOP-01/VOICE-01的状态、回调与音频规则保留，不修改共享编排规则区域。
仅Theme平台为iOS且所属View的原始viewPadding.bottom>0时，额外底距20改10，上方notice专属gap增加10（翻译7→17，任务通话/对话8→18）。读取原始View只判断条件，避免SafeArea消费后的0；所有间距仍为逻辑像素，不另加原始安全区高度。安全区仍由原页面应用一次；对话键盘底距8优先，不受本条件改变，上方gap仍按原始安全区条件处理。
普通高度下上加10/下减10保持控制区总高度及按钮位置，说明下移10。短屏/拨号盘仍仅上部滚动，说明固定可见。Android及iOS原始安全区0不变；固定11字号、浅深颜色、缩放、字重和所有其他标签gap不变。
更新已有页面几何测试，先确认iOS非零安全区新位置失败；补top gap和控制区坐标断言，真实viewPadding与padding分别设置，保留键盘时viewPadding。仅定向测试/analyze/OpenSpec/diff，无原生或依赖变化，不构建安装。
