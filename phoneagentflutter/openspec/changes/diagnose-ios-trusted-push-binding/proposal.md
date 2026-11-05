# iOS 可信推送绑定状态诊断

## Why
用户提供的 diagnostics.jsonl 32 未包含可信推送事件，无法确定 APNs Token 是否已被 SDK 接口确认。现有一次性事件可能早于订阅或不在保留窗口；此为诊断缺口，不证明绑定失败。

## What Changes
只修改 PhoneAgent Flutter 仓库。绑定状态由原生 PushBindingState 持有，Driver 提供只读投影，PushRegistration 在当前插件订阅及通知状态回读后记录固定状态码，沿用可信诊断通道。保留绑定/解绑接口、账号与登录代次、环境、串行请求、显式重试和 UI。

## Impact
入口：登录账户同步、前台通知状态回读、可信事件订阅；SDK bindRid/deviceToken 接口不变。回放覆盖旧账号成功迟到、失败后不确定、未返回请求不重放、注销失活、初始化失败及诊断脱敏。仅成功回调后的当前完整绑定身份可显示 CONFIRMED，快照不宣称服务端实时状态或推送送达。
