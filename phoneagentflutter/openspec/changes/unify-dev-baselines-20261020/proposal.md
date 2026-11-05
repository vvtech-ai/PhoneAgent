## Why
用户明确要求统一代码基准与本地新增功能，撤回本会话改乱的道歉 Skill 修改。

## What Changes
- 基准：origin/codex/dev @ 8445d06f。
- 保留批量结果卡/逐路进度、评分刷新与系统音色试听；道歉控制器、任务确认询问投影和相关测试按 codex/dev 恢复。
- 统一交付分支 xiaosy/dev_v1.7.0，保留原 Git 历史，不 force push。

## Capabilities
### New Capabilities
- `unified-dev-baseline`: 本轮整合范围与基准约束。
### Modified Capabilities
无。

## Impact
仅源码与相关既有回归；不部署、安装或操作数据库，不触碰 aiassistant-backend。
