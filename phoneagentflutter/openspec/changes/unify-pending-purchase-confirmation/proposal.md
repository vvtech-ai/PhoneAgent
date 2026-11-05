## Why
待处理会员购买的取消确认仍使用默认 AlertDialog，和当前 App 的统一确认弹窗不同。用户要求复用现有风格，关单业务失败另由服务端调查。

## What Changes
- 待处理购买使用 NativeConfirmationDialog，沿用退出登录同一 NativeBusinessDialog 底座和危险确认按钮。
- 保留确认/暂不取消文案、账号 epoch、路由生命周期、busy 与查询暂停保护。
- 仅调整展示及 widget 回归，不改变关闭资格或服务端终态规则。

## Impact
单个商业化 widget、既有路由 widget 测试和本 change；不修改 controller/repository，不打包、安装、提交或推送。
