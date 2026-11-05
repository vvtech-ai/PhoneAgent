## Why
Release关联裸域名与用户要求的www域名不一致，Dart分享校验还依赖API host，可能拒绝合法分享链接。

## What Changes
- 按Debug/Profile与Release明确关联域名。
- 正式分享主域名固定www.chaken.ai，兼容后端默认生成的chaken.ai链接。
- 保持邀请码校验、环境隔离及专用Universal Link。

## Capabilities
### Modified Capabilities
- invite: 环境域名与分享兼容规则。

## Impact
Flutter iOS配置及邀请策略；后端只读，不切分支、不提交推送、不触发短信注册或设备安装。
