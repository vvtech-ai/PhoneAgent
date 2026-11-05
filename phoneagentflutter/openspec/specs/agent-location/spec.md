# agent-location Specification

## Purpose
定义任务对话的位置采样、可信缓存回退、时效与授权边界，确保 iOS 定位短暂失败时仍能使用真实有效位置，同时隔离取消后的迟到回调，避免发送过期或未授权坐标。

## Requirements

### Requirement: iOS Agent 位置采样可信回退
客户端 MUST 在已授权时获取有效位置，对短暂定位错误进行有界重试，并在总超时或采样失败时使用有时效和精度限制的可信缓存。权限拒绝、取消、账号过时代际 MUST NOT 产生缓存上报或迟到结果。
#### Scenario: 实时采样失败
- **WHEN** iOS 实时位置不可用且存在 5 分钟内精度合格的缓存
- **THEN** 在 9 秒总预算内返回真实缓存经纬度，不因逆地理编码失败丢弃坐标
#### Scenario: 没有可信位置
- **WHEN** 所有候选过期、不合法或精度不足
- **THEN** 返回无位置，不制造坐标，不无限沿用共享旧快照
#### Scenario: 首次权限申请
- **WHEN** 当前有效 REQUEST_PERMISSION 包含 location permissionKey 而不含 androidPermission
- **THEN** 客户端按类型请求原生权限，已有授权不重复弹窗，授权完成后继续准备新鲜上下文
#### Scenario: 权限撤销和取消
- **WHEN** 权限快照不是 OK 或请求已取消
- **THEN** 不上报缓存位置，旧采样或编码回调不能完成新请求
