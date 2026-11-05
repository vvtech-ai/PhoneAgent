## Context
2026-10-12用户确认执行。当前Mac codex/dev_zys保持原分支。后端application-prod.yml的default-base-url默认为https://chaken.ai/aiassistant-api/invite/；ios-universal-link默认为https://ioslink.chaken.ai/phoneagent/ios/。线上覆盖配置和活动数据未知。

## Decisions
- Debug/Profile关联agent.vvtech.tech、phoneagent-ioslink.vvtech.tech；Release关联www.chaken.ai、ioslink.chaken.ai。
- 正式分享主host固定www.chaken.ai，额外仅接受chaken.ai；不把兼容裸域名添加到entitlements。
- 仍校验可信API环境，分享路径保留现有API部署前缀；不扩大路径、协议、端口或邀请码规则。
- 后端不修改。专用域名AASA与App Store回退保持既有契约。

## Validation
定向邀请/登录归因测试、analyze、OpenSpec及Xcode三配置检查。线上AASA可只读获取；系统唤起、安装与回退需设备验收，不由源码测试代替。
