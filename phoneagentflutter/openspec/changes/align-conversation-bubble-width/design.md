## 来源与定位

只读核对旧库 D:/work/kexin_ai/aiassistant 的 origin/test/v66.0.3（a0bedb12），以及原生 aiassistant-app 的 feature/test_v1.6.0：PureVoiceStageCards.kt/PureVoiceBubble 使用 user=220、assistant=260 的 widthIn；PureVoiceThreadList.kt 对道歉说明启用 fillWidth；PureVoiceAgentOptionsCard.kt 无标题260、有标题284。思考及工具卡270上限本就不同，不应一律同宽。

用户补充要求核对确认卡等类型后，继续核对 PureVoiceStageResultCards.kt/PureVoiceCallConfirmSummaryCard 的280，PureVoiceCallCards.kt 转写/结果280，以及 LargeTaskConfirmationCard.kt、LargeTaskCardShell.kt 的绿色摘要280和检查/结果308。Flutter对应宽度本来一致；新增实际组件几何回归，验证共同左边缘18以及窄屏限制，不修改这些稳定组件。

## 实现范围

NativeConversationTextBubble 增加默认关闭的 fillWidth 展示参数，约束改用旧版角色上限，受父容器宽度限制；不修改 NativeMessageParagraph 的平台测量。ConversationMessageTile 仅在现有道歉说明分支开启填宽。ConversationOptionsCard 按现有 optionsTitleVisible 选择旧版上限。这三份展示文件均未增加业务职责，不新增策略或修改状态机。

## 验证

先用矩形测量重现比例宽度及道歉卡不齐；覆盖 Android/iOS、320/390/430 屏宽、正常/放大字体、短长消息、AI左及用户右边界；对照选项标题两种布局并点击选项。回归文本测量、混合卡间距及道歉展示。运行 analyze、定向测试、OpenSpec 校验。真实设备视觉验收仍待用户确认，不据测试宣称真机一致。
