## Why
用户确认双端 Flutter 共用 Toast 统一为 iOS 参考带品牌图标样式，并批准执行。
## What Changes
- 共用提示增加同源品牌图标，普通 SnackBar 迁移至共用入口。
- 保留文案、业务门禁、键盘避让、时长、替换和点击穿透。
## Capabilities
### New Capabilities
- branded-toast: 双端品牌 Toast。
## Impact
仅展示层和定向测试，复用已有资源；本地修改，不切分支、不提交推送。
