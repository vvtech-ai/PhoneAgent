## ADDED Requirements

### Requirement: 通知扩展引用保持唯一
通知扩展接线 MUST 复用同物理目录group，保留全部真实文件、原配置与唯一Target，不改变业务功能。

#### Scenario: 重复group及已使用引用
- **WHEN** 同目录存在多个group或重复项已被source/config使用
- **THEN** 接线 MUST 合并引用而不丢失原构建关系

#### Scenario: 幂等及重命名Embed
- **WHEN** group仅path，Embed阶段已重命名或脚本重复/交错执行
- **THEN** MUST 保持唯一group和Embed，第二次执行字节不变
