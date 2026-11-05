## Why

首次 OCR 上传后退出再恢复时丢失首页 Skill 绑定，模型重新选成转达留言并进入普通单呼确认；列表分类与上传占位标题随之错误。用户已于 2026-10-29 确认按前轮方案实施、独立回归、推送 test_v1.8.0_fix 并打测试包，不安装。

## What Changes

- OCR 授权和提交携带原入口 Skill 与选定联系人，首次上传即保存同会话绑定。
- OCR-only 恢复不冒充已接受业务输入；恢复继续使用原绑定。
- 有正式文字输入后上传占位标题让位于实际任务输入，成功生成的标题保持冻结。
- 不限定 Skill，不改记忆确认、工具确认、外呼准入或多人执行。

## Capabilities

### New Capabilities
- `ocr-first-task-binding`: 上传优先任务的身份持久化、恢复和标题兜底。

### Modified Capabilities
无；补齐现有任务入口合同。

## Impact

Java Agent OCR 接口、初始化持久化、标题元数据投影；Flutter OCR 数据接线和恢复初始化判定。无新依赖、DDL、部署或真实外呼。
