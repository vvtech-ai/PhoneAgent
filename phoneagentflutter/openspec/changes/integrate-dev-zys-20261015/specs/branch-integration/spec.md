## ADDED Requirements
### Requirement: 合并必须保留双方有效改动与历史
本次集成 MUST 将codex/dev_zys 1df878ff合入codex/dev 543ee23c，保留双方父提交及各自产品源码，文档保留双方记录；MUST NOT更改其他工作树或force push。
#### Scenario: 双方存在独立提交
- **WHEN** 合并来源邀请修复和目标任务修复
- **THEN** 两方产品源码与提交历史均保留，完成定向/平台验证后仅普通推送目标分支
