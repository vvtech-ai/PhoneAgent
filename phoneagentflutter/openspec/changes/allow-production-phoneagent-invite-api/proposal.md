## Why
正式配置使用 phoneagent.chaken.net.cn，但邀请 API 白名单仅接受 chaken.ai/www.chaken.ai，导致有效正式邀请入口被禁用。用户确认补齐该正式域名。

## What Changes
仅扩展 prod API 主机白名单，不变更分享域名、Universal Links、路径、邀请码校验、UI 或私有配置。

## Impact
PhoneAgent Flutter domain/invitePolicyFor 持有策略，影响冷/热链接入口及邀请分享地址校验，Android/iOS 共用。API 身份与账号生命周期不变；任务编排连续回放不受影响。INVITE-PROD-API-01 覆盖正式域名解析，INVITE-ISOLATION-01 覆盖环境和恶意域名拒绝；不实际绑定邀请码或访问业务接口。
