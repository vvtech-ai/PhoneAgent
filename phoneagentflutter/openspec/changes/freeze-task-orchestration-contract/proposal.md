## Why

任务消息与评分问题反复出现，历史规格存在清空道歉消息、保留旧卡、开场显示和首页网络优先等相反规则。用户已批准统一合同，并要求任务列表与联系人入口也按同规则验收。

## What Changes

- 将完整 `task-orchestration-v1.2` 写入本仓 AGENTS，与 Java / Web 共同块保持同版本同内容；单仓检出即可阅读全部时间线与回放。
- 新增本仓任务编排知识库，规则与知识不含个人目录或批次待验状态。
- 当前目标固定 `codex/dev`，v66.0.3 业务优先，保留 1.6.0 每次成功切模追加反馈的例外。
- 明确首页完整快照 / 后台刷新、联系人专用开场、任务列表身份恢复和详情只读边界。
- 直接修订冲突 delta；历史设计 / 测试记录不作为现行验收，业务修复另建 change。

## Capabilities

### New Capabilities

- `task-orchestration-governance`: Flutter 多入口任务行为与证据治理。

### Modified Capabilities

无主规格修改；本仓相关历史 active change 的冲突条款按本次批准同步纠正。

## Impact

仅 AGENTS、迁移基线、OpenSpec 与工作记录。无需业务源码、公共 API、数据库、提示词、SIP / ASR / TTS 改动，不打包、不安装、不执行真实业务。权威合同入口见 [AGENTS.md](../../../AGENTS.md)。
