# 分离 iOS SDK 与 APNs 环境并统一签名验收

## Why
用户确认 dev/test 使用开发签名和 development APNs，pro 临时业务配置保持原样。实际 test IPA df64a4bf…58fca92e 的 plist、签名及 Ad Hoc profile 均为 production；宿主却由 SDK test 推导 development，注册前返回 CONFIG_MISMATCH。另发现两个已声明 extension 未被 Runner 依赖或嵌入。

## What Changes
- 建立 dev/test/pro→业务环境、SDK、凭据、主包及两个扩展 ID、签名与 APNs 的明确合同。
- 注册检查只校验 APNs 配置合法值，不由 SDK 环境推导 APNs；最终签名门禁校验交付策略及三处一致。
- 提供工程内隔离构建入口，选择匹配设备和团队的开发 profile，恢复已有 extension 接线并校验最终嵌入身份。
- 保持 cloud-pro 的临时 test 内容；正式配置未就绪时阻止正式交付，不猜测替换。

## Impact
仓库 PhoneAgent；owner 为 iOS 构建/签名层和 TrustedCallerPushRegistration。入口为构建、安装、启动/前台通知注册；身份为主/扩展 Bundle ID、Team、账号/consumer、既有登录代次及 Token。SDK bindRid 接口、权限、账号隔离、Token 校验、成功码、重试及 UI 不变。关联 DEVICE-01、既有可信推送账号/迟到回调回放，不改变任务编排合同。保留其他未提交修改；不提交推送。
