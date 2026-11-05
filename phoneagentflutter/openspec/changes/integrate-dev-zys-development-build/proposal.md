# 合并dev_zys并交付开发环境包

## Why
用户2026-10-10明确要求合入origin/codex/dev_zys最新代码并打开发环境包，覆盖此前本任务禁止混入dev_zys的限制。本次不更新origin/codex/dev，不修改后端或数据库。

## What Changes
- 将fetch核对的dev_zys 06eba014与任务重构ba80b6b9三方合并，保留双方有效功能与最新任务对话修复。
- 解决共享鉴权、翻译归档、任务列表/回执、壳入口、iOS工程及文档/测试冲突，不另建状态机或新增业务。
- 固定Flutter3.32分析、全量回归及Android开发环境构建，记录包版本、SHA和真实待验项。
- 按用户追加要求，将Android/iOS默认Flutter启动图标替换为原版PhoneAgent声波品牌图标；仅同步现有官方资源和平台注册引用。

## Capabilities
### New Capabilities
- `dev-zys-integration`: 分支合并边界与开发包交付。
### Modified Capabilities
无独立新增产品行为，既有双方OpenSpec需求保留。

## Impact
dev_zys新增翻译、可信来电、认证、声音克隆、联系人及平台SDK接线，共882个相对共同祖先文件；12处预合并冲突。共享请求/路由和平台构建均受影响，需全量回归。私有配置仍ignored，缺失不伪造，真实电话、SDK、媒体、后台和iOS构建不由合成测试代替。
