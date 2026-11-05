## Why

批准范围内联系人仍是导航占位。需要迁移 v65 实际列表/详情/备注/拨号与联系人任务入口，并为双端系统通讯录提供薄适配，不能把后端目录当系统通讯录或复制废弃编辑页。

## What Changes

- 共享设备联系人模型、名称/号码去重排序、后端备注目录及单次保存状态。
- 明确系统通讯录授权、拒绝、不可用、加载失败与空列表，Web 使用显式离线合成入口，不伪造已授权。
- Android/iOS 薄授权/读取适配，复用 Flutter 页面与业务规则。
- 按 2026-09-17 用户批准的静态设计优先方式补列表/详情/备注编辑、拨号和 CONTACT_DETAIL 技能入口；保持系统拨号与 Agent 代打不同，视觉差异集中校准。
- 不新增旧目录删除、AI 建模、常用联系方式页面；不读取 iOS 系统通话记录。

## Capabilities

### New Capabilities
- `contacts-migration`: 有效联系人流程、目录备注、系统通讯录端口和明确 mock 边界。

### Modified Capabilities

无。

## Impact

新增 contacts feature domain/data/controller、composition providers 和薄原生适配；复用 AccountApi，不改后端/数据库/提示词/SIP/ASR/TTS。通讯录不入日志、不自动上传，真实备注写入和权限授权留人工集中验证。验证包含合成 HTTP/状态/权限测试、Web/Android 构建与分阶段 iOS 构建、页面运行态和双端验收。
