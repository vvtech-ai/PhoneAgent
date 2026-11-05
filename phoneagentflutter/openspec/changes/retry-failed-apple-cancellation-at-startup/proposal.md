# 仅在启动补报失败的 Apple 取消订单请求

## Why
2026-10-21 诊断中 StoreKit canceled 后 HTTP statusCode=0，重启后原单仍 PROCESSING。用户撤回广泛调度改造，批准最小补偿：仅明确取消的上报失败留下唯一待办，下次登录启动恢复时尝试一次。

## What Changes
- 账号/环境范围内按原订单唯一保存取消请求ID；仅 StoreKit 明确取消上报失败或未确认留下记录。
- 复用已有启动恢复入口，每登录会话补报一遍快照，每单至多一次取消HTTP，失败等下次启动。
- 手动取消失败不保存待办；不新增监听、timer、轮询限制或UI文案。

## Impact
仅 Flutter commerce domain/data、原取消上报 helper、controller参数和provider接线；后端、Swift及网络/TTS/页面/轮询均不改。
