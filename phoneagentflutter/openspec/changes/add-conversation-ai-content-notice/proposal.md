## Why

用户确认在对话页语音按钮和文本输入框下增加“内容由AI生成”，键盘弹出时仍可见，保留 Flutter 原有风格及共用控件。

## What Changes

- 在共用 ConversationComposer 底部统一加入居中、小号灰色说明。
- 沿用 Scaffold 键盘避让与 SafeArea，不重复叠加键盘高度。
- 覆盖双平台、双模式、键盘升降、模式切换与小屏大字布局。

## Impact

仅 PhoneAgent Flutter presentation；不改变接口、任务身份、音频、发送或停止状态，不修改原生工程。
