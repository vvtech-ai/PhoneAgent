## Why
用户确认统一记忆、设置子页面、会员积分及其完整子页面导航栏，保留原背景，不包括弹出页面。
## What Changes
- 新增双端共用居中导航栏；21/w700/#0F172A，单行末尾省略，左右按较大实际宽度对称预留。
- 可选返回、原右侧操作；64 最小内容高度、左右16；原背景继承或显式传入。
- 定向迁移完整页面和已有导航栏的失败状态；弹窗、Sheet、系统/SDK 页面不变。
## Capabilities
### New Capabilities
- detail-navigation-bars: 设置与会员积分完整子页面共用导航栏。
## Impact
PhoneAgent presentation 层；页面持有状态与路由，导航栏只持有布局和回调。无 API、账号/session/tool 身份、权限、支付或任务合同变更；不修改共享编排规则。不提交推送或切换分支。
