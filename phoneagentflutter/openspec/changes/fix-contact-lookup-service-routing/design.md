## Evidence
1511实体手机当前会话复现，READ_CONTACTS granted=true。只读测试主机Nginx access.log提取19:42:05 POST /aiassistant-sdk-api/api/assistant/agent/device-contacts-lookup-result HTTP404；同路径在16:24/16:29/16:33亦出现404。未重试、重拨、读取或输出通讯录内容。

当前Java feature/test_v1.7.0的AgentDeviceContactsLookupController与AgentLookupContactController都位于aiassistant-agent-sse，路径/api/assistant/agent；SDK模块无这两个Controller。原生使用legacySseHttpBaseUrl。Flutter ServiceRoutes未列出两路径，默认落SDK，同时C1凭据也错误选择SDK。

## Change
仅修改core/network/service_routes.dart现有归属规则，显式加入两条精确路径；不把整个assistant命名空间改属Agent，不改业务lookup或核心会话状态机。没有第二种职责，无需新增生产模块；未来同类端点仍按既有服务归属表添加并验证URL和签名凭据。

## Verification
先在独立API/SDK基址下复现路径断言和C1服务断言2项失败，再修正映射。跑AccountApi、ServiceRoutes、结果API、姓名/号码lookup、权限及会话连续回归。拒绝权限/读取失败继续返回原约定状态；不重复聊天或自动外呼。签名test Release与道歉首屏修复一起递增版本，设备验收不触发真实收费操作。
