## Why
用户确认仅完善联系人功能及页面，并于2026-10-09批准执行。现有主流程已实现，但长列表为急切构建、读取失败与空态同时展示、拒绝授权缺系统设置入口、技能版本写死，且仍需实际原生配对证据。

## What Changes
- 以固定Android 0f8879e4、iOS bb9ff349有效联系人入口为参照，复用现有共同风格和业务，不新增搜索、字母索引或设备联系人编辑。
- 列表按需构建、独立错误/空态、拒绝及有限授权设置入口，保留前台静默刷新。
- 联系人技能独立生命周期，读取已有安装版本端口，加载失败重试；保留公共目录缓存/内置回退契约。
- 核对详情、备注编辑/删除、系统拨号及CONTACT_DETAIL上下文；修复已证实缺陷。
- 同合成数据定向测试和双端运行参考，真实权限、接口写入、电话与完整像素验收分别记录。

## Capabilities
### New Capabilities
- `contacts-ui-interaction-parity`: 联系人本轮一致性完善。
### Modified Capabilities
无；承接contacts-migration与native-ui-interaction-parity的既有业务约束。

## Impact
仅联系人feature、联系人装配、必要联系人测试与隔离参考工具。共享首页/拨号/会话业务保持既有契约，固定Flutter3.32/Dart3.8，不改依赖、正式签名或发布身份。现有pubspec.lock不纳入提交。
