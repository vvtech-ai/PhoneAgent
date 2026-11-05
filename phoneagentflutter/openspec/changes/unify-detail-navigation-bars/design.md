## 当前批准目标（2026-10-31）
以 docs/design/UI_DESIGN_STANDARD.md 的 D02/C02 及项目执行约定为准。此前21/w700居中导航规范被本版替代，旧 verification.md 保留为历史证据，不能作为新规则验收依据。

## 文件职责与接口
- NativeDetailHeader 是唯一普通页头实现，负责28/w800、40/28、18/8内边距、28前占位、48返回、单行省略及宽操作约束；补充 showBack 与 backLabel，默认保持已有详情页行为。
- NativePageHeader 保留 title/onBack/showBack/backKey/trailing/backgroundColor/foregroundColor 接入，默认前景改为规范#111111，委托公共实现。
- NativePageAppBar 增加必传 textScaler，首选高度等于16+max(40,scale(28)*40/28)；内部显式恢复页面原始TextScaler，避免AppBar的默认标题缩放上限造成首选尺寸和字形不一致。背景、安全区和自动返回规则保持原语义。
- 右侧操作默认40高，宽度至多占扣除左侧标题起点后的剩余宽的一半，超宽内容支持横向滚动而非溢出；完整文字语义保留。
- 页面只替换头部结构；原回调、busy条件、PopScope和账号/路由守卫不修改。

## 页面与例外
包含现有NativePageHeader/AppBar调用链；联系人、任务、设置普通一级标题；初始化；国家地区选择；日志、更新、任务详情正式AppBar；注销验证码将已有正文标题移到唯一页头。现有NativeDetailHeader页面自然复用。邀请海报白字前景保留。无普通导航标题的专用资料页不新增业务标题。
品牌、对话运行状态、通话联系人、联系人资料与翻译历史通话信息保留专用结构。普通弹窗/Sheet内部标题不迁移；独立演练入口不全项目替换。停止控件文件不改，文字灰/语音蓝及处理中反馈保留。

## 验证

用户2026-11-02追加取消按钮 tooltip：在 PhoneAgentApp 的 MaterialApp.router builder 及 TrustedIdentityOverlayApp 的 MaterialApp builder 中以 TooltipVisibility(visible: false) 包含整个导航树，覆盖路由及弹层。沿用框架原生能力，保留原 tooltip 语义文案，不逐页删除参数或增加业务层开关。专项覆盖持续按住、程序请求显示被拒绝、读屏文案、点击及弹层关闭，两个入口及Android/iOS主题分别验证。
TDD先观察旧居中/固定高度对新几何合同失败，再实施；双平台320/390/430、1x/2x、长标题、宽/动态右操作、无/禁用返回、一次回调、原背景、安全区和业务返回门禁。定向运行相关模块及连续流程、flutter analyze和OpenSpec strict；不升级依赖或打包。独立测试重新读取设计原文及PDR，记录实际画面或缺证据。

## 实施记录
- 基线：feature/test_v1.8.0@41a4ac44，独立工作树；主检出有他人未提交修改，保持不动。
- 当前聊天内执行；本项目PDR和OpenSpec tasks承担计划与进度台账，不再建立重复的业务合同或计划文件。
- 改造前已知：iOS系统返回测试的支付恢复定时器在测试结束时未完成；不放宽测试、不顺手改支付逻辑。

- 小字号补充：0.8x 字体下首选高度仍至少56，避免首选48但内容56造成正文与页头重叠；已先通过新增用例观察正文起点78而非86的失败。
