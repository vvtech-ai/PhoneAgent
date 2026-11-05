# 补齐 iOS APNs 注册链路诊断

## Why
用户提供的 diagnostics.jsonl 18/19 仅有 IOS_APNS_ALLOWED，无 token、注册失败或绑定事件，无法判定注册调用、系统回调与 token 校验的断点。用户授权增加必要日志并启动检测；不将缺少日志判成注册失败。

## What Changes
- 记录注册调用、配置门禁、系统回调、token 校验和 SDK 初始化阶段。
- 每次等待周期只观察一次20秒无回调状态，不重试、不更改成功失败状态。
- 原生与 Flutter 采用固定诊断码，不含 token、号码、账号或原始错误描述。

## Impact
PhoneAgent 的 iOS 平台适配及 Flutter 诊断数据层；状态 owner 仍为 PushRegistration/PushBindingDriver。入口为启动、前台、账号同步、系统 APNs 回调。无业务接口或身份变更，保留 owner/token/permission/environment 门禁、代次隔离与显式重试；UI 和共享任务编排不变。关联 DEVICE-01、ENTRY-03 的账号隔离验证。源码 SHA 5132667b；现场根因尚未确认。
