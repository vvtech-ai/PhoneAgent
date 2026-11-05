## Why
用户要求Flutter双平台设置页退出入口仅参考Android，覆盖此前iOS居中按钮目标。

## What Changes
- 左对齐红色粗体退出文字，右侧显示脱敏登录手机号。
- 卡片间距、内边距和点击反馈对齐Android，不改变确认弹窗或登出业务。

## Capabilities
### Modified Capabilities
- settings-home-parity: 退出入口改用Android参考。

## Impact
设置Page/Route/LogoutButton及定向测试；不改原生项目、鉴权或依赖。保持当前分支，仅本地修改。
