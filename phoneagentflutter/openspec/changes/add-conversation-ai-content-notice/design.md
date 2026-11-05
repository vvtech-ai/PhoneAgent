## 范围与事实

基线 feature/test_v1.8.0@921647c0，开始时工作区干净。两个模式共用 ConversationComposer；ConversationRoute 的 Scaffold 和 SafeArea 持有键盘及系统安全区布局。当前输入组件没有 AI 生成说明。

## 职责与方案

仓库 PhoneAgent；展示层 owner 为 ConversationComposer。新 ConversationAiContentNotice 仅负责固定文字与样式，使用 ConversationTokens.subtitle，12sp 居中，放在共同的 controls 下方。页面保留原键盘避让，不增加独立固定浮层或手动键盘偏移。

影响入口为所有复用 ConversationPage 的正式会话入口。无接口、账号/session/command/tool 身份变更；草稿、发送、录音、TTS 和停止门禁仍由原 owner 管理。保持 VOICE-01、STOP-01 相关控件合同；本次新增布局测试不代替完整业务或真机回放。

## 验证范围

新 widget 测试先确认缺少说明，再验证 Android/iOS、语音/文字模式、320×568 与390×900、1/2倍字号、底部安全区、键盘弹出/收起及模式切换。运行既有输入、语音及停止控件专项测试、静态分析和 OpenSpec 校验。无原生/依赖变化，不构建安装；设备键盘视觉待验。
