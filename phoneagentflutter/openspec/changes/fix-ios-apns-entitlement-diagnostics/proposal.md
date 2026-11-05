# 修复 iOS APNs 权限声明与失败诊断

## Why
诊断有通知授权成功及 APNs 注册失败，却无 token 收到或 SDK 绑定成功。Debug/Profile 共用的 RunnerDebug.entitlements 缺少 aps-environment；本地旧签名产物同样缺少，但尚未证明与手机安装包相同，不能签收现场唯一根因。

## What Changes
- Debug/Profile 增补既有环境变量对应的 APNs entitlement，保留关联域名及 Release 配置。
- 注册失败保留固定域分类与整数错误码，不记录 NSError 描述、userInfo、token 或凭据。
- 覆盖签名配置、原生诊断、Flutter 导出与账号绑定回归。

## Impact
仓库 PhoneAgent；owner 为 iOS 构建签名层及原生 APNs 回调、Flutter 诊断数据层。入口为启动/前台注册及系统成功/失败回调，身份为原 Bundle ID、环境及现有账号代次。无业务接口变化；保留授权、owner/token/环境门禁和迟到解绑，不修改 UI、Android、任务编排、私有配置。关联 DEVICE-01 的 iOS 设备证据；任务连续回放不受影响。签名成包版本待用户指定，真实 token 与 SDK 绑定需分别验收。
