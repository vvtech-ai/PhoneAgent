## Why
用户2026-10-28截图并实测确认Android任务通话和实时翻译通话底部系统手势区域出现白条，已批准同时修复。
## What Changes
- 仅Android两类通话面启用有生命周期的edge-to-edge与深色底层，系统导航栏透明/浅色图标，内容保持原SafeArea。
- 弹层保持当前通话模式；其他业务页面覆盖、通话结束/返回时释放并恢复应用既有全系统栏可见基线。
- 保留iOS原widget路径、Flutter样式/共用控件、回调和业务状态。
## Impact
PhoneAgent presentation，owner为共享AndroidCallSurface和当前PageRoute可见性；无业务接口/身份/Controller/音频变化。涉及任务通话、实时翻译及共用预览；回放ENTRY-05、STOP-01、VOICE-01仅验证页面退出/回调边界，不执行电话。保留主线程align-ai-content-notice-reference全部未提交改动，不切分支/提交推送，不覆盖安装。
