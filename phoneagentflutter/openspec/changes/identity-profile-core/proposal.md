## Why

设置身份尚未接入，后续任务上下文、首次引导与声音克隆都依赖同一账号资料。先实现可独立自动验证的资料协议与状态管理，不等待认证 SDK 或设备安装。

## What Changes

- 账号绑定 GET/POST/PATCH/DELETE 身份资料；保留已认证与普通写入区别。
- EMPTY/FILLED/VERIFIED 解析、编辑草稿、字段规范化、单次保存/删除、失败保留与晚到隔离。
- 本批不调用真实账号写入；页面、首次引导/删除后模型刷新和 SDK 下一阶段接入。

## Capabilities

### New Capabilities
- `identity-profile-core`: 身份数据契约与编辑状态。

### Modified Capabilities

无。

## Impact

新增 identity feature domain/data/controller 与纯合成 HTTP 单元测试；复用 AccountApi。无依赖或原生变更，无后端/数据库/提示词/SIP/ASR/TTS变更，不记录身份正文日志。
