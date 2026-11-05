## Why
当前手机会议会话查询通讯录后连接中断。READ_CONTACTS已授权；测试网关19:42:05记录姓名查询结果POST误发SDK服务并返回404。两个结果回传Controller实际属于Agent服务。

## What Changes
- 客户端精确将姓名、号码两条联系人回传路径归属Agent服务，地址和C1凭据同步按Agent选择。
- 保留原请求体、权限请求/拒绝/读取失败结果及不自动重放规则。

## Impact
仅Flutter网络路由与回归；不改Java/Web、后端配置、数据库、接口契约或服务部署。
