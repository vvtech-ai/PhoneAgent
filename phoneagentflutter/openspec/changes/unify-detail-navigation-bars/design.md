## Decisions
新增 NativePageHeader 和 AppBar 适配器；保留 NativeDetailHeader 供范围外页面使用。父级继续拥有 SafeArea；AppBar 适配器交给 AppBar 处理顶部安全区。透明头部保留父级原背景，会员 AppBar 保留白色，其他 AppBar 沿用主题背景。邀请详情原蓝色背景上的白色前景保留以保证可读，其他页面用默认深色。标题不缩字号、不换行，完整语义仍可访问。
左右内容在同一布局周期测量，取最大宽度给标题两侧留白；侧边最多占可用宽度的一半减去标题最小余量，有限约束处理窄屏。无返回与返回禁用分别表达。页面继续拥有 PopScope、路由有效性、busy 和操作回调。
## Scope and owners
- memory: MemoryFrame 负责页框；controller/editor 继续拥有保存、清空、busy 和版本身份。
- settings: 设置完整子页面、Skill卡片、语音模型完整页、邀请及邀请记录；既有页面拥有路由/账号生命周期，模型/音色 Sheet 不改；声音克隆认证与结果完整流程头部纳入，创建选择弹层不改。
- commerce/points: CommerceScaffold、积分页框与购买结果已有失败导航栏；支付反馈、发票及确认弹层不改。
- 原生可信来电设置由 SDK 展示，介绍页无既有导航栏，不添加导航栏；身份入口已移除，不扩大范围。
- 开发者正式页和已有完整子页接入；独立迁移演练入口非设置正式路径，不全App替换。
## Preserved rules and validation
任务编排 ENTRY/MEMORY/MODEL 等业务回放合同不变，本次仅对直接页面做导航回归，无新增服务身份。测试双端主题、320/390/430宽度、大字体、动态操作、长标题、禁用/无返回、一次回调及原背景。运行 analyze、受影响模块测试、OpenSpec strict 和 diff 检查；无平台变更不打包，设备视觉未验收不归档。
## Baseline
feature/test_v1.8.0 @ c42719f6，初始工作区干净。现状为记忆固定76侧宽、设置左对齐28标题、会员58高AppBar；与用户批准目标有差异，按本次批准统一布局，仅保留背景与业务。
