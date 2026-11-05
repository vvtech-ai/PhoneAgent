## ADDED Requirements

### Requirement: 按最新用户授权切换集成分支
本轮系统开发 MUST 将已验证任务功能分支合入最新 codex/dev，并在现有隔离工作树的 codex/dev 继续开发；MUST 保留双方提交历史及有效更新，保护原 foundation 工作区和其他仓库未提交内容。此用户授权覆盖此前仅推任务功能分支的限制，MUST NOT force push、归档未验收变更或把历史验证当成本次真实双端验收。

#### Scenario: 开发目标分支同时有更新
- **WHEN** origin/codex/dev 和任务分支均有独立提交
- **THEN** 三方合并保留双方更新，按语义处理冲突，验证后中文提交并非强制推送 origin/codex/dev；确认双方父提交均为合并结果祖先

#### Scenario: 原始工作区仍使用 foundation
- **WHEN** 现有隔离工作树切换到 codex/dev
- **THEN** 原始 foundation 工作区的分支与内容保持不变，后续开发使用已经切换的隔离工作树
