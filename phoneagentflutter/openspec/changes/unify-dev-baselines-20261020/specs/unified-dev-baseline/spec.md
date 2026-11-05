## ADDED Requirements
### Requirement: 本轮统一基准和增量
整合结果 MUST 以 origin/codex/dev @ 8445d06f 为基准，保留批量结果卡/逐路进度、评分刷新与系统音色试听；道歉控制器、任务确认询问投影和相关测试按 codex/dev 恢复。 其他功能 MUST 保留其已批准边界。

#### Scenario: 整合完成
- **WHEN** 提交统一版本
- **THEN** MUST 核对最终代码增量、指定撤回路径和相关验证结果
- **AND** MUST 保留原 Git 历史、未提交输入及私有配置，不 force push、不操作运行环境
