# 克隆音色选择卡：静态优先交互批次

2026-09-17 用户允许按既有 HTML/CSS/组件完成全部交互，视觉后统一校准。仍使用本目录 TargetAppConfig，固定 Flutter 3.32，不调整原生身份/工具链。

- 源：memory/index.html cloneVoiceGroup/selectCloneVoice/cloneVoiceDetail，style.css 479–492；既有 SourceSnapshot 的遮挡截图不作为验收。
- 实现：CloneVoiceCard + CallVoicesPage，ShellRoute 回调进入已有 CallModelController；16px 卡片内边距、16px 详情块圆角、选中边框与现有 SelectionIndicator。所有按钮为真实控件。
- 状态：仅支持模型显示；加载/未克隆/不可用/处理中/读取失败/已就绪/当前使用/READY+CHARGED 候选/等待同步。错误与等待同步只能刷新；所有写入共享互斥。
- 动作：使用已确认 current → 既有 CLONE PUT；候选确认 → 已有 confirm POST；重试 → 只读刷新；选择 AI → 既有 AI PUT；返回 → 模型配置页。按钮不触发录音/采集或拨号。
- 自动验证：clone_voice_page_test.dart 11 项，实际组件三宽度点击、状态门禁、返回和忙碌状态；不对真实账号执行写入。
- 视觉待校准：克隆详情文字、选择区域点击范围（当前显式按钮）、选中阴影、字体字重和窄屏换行。没有新增资源，也不使用设计预览图铺底。
- 录音/认证/开始克隆/重录/试听/删除仍是未完成能力，不以此选择卡代替全流程；暂不制造无作用的采集成功状态。
