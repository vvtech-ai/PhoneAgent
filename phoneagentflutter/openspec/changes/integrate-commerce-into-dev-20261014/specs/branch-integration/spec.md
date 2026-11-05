## ADDED Requirements

### Requirement: 商业化与当前开发成果完整保留
集成提交 MUST 同时包含 e4b202e1 与 c10ad11c 的历史和有效源码，MUST 保留未提交内容，MUST 仅在检查后非强制推送 codex/dev。

#### Scenario: 记录追加冲突
- **WHEN** 任务和问题记录冲突
- **THEN** 合并结果保留双方完整章节，不删除已有验证边界。

#### Scenario: 发布远端代码
- **WHEN** 验证通过后推送 codex/dev
- **THEN** 远端提交包含源及目标祖先，私有文件和临时产物不进入提交；真实渠道及设备未验项单独列出。
