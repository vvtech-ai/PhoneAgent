## ADDED Requirements
### Requirement: 20261014开发分支集成保留双方更新
项目 MUST 将codex/dev_zys 7c0bd25a合入codex/dev 99daa3e0，保留双方历史与有效代码，不覆盖其他工作树或纳入无关未提交文件。
#### Scenario: 集成和远端回执
- **WHEN** 用户要求合入开发分支
- **THEN** 采用保留父提交的合并，完成相应验证后仅非强制推送指定开发分支，并核实远端包含双方祖先
