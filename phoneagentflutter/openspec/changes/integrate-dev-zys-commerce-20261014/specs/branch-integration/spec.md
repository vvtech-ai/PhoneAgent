## ADDED Requirements
### Requirement: 商业化分支集成保留双方行为
项目 MUST 将codex/dev_zys 9cdc1b4f合入codex/dev 255e59fd，保留双方提交历史、税务开票提醒、平台购买规则、Apple精确价格/恢复与安全诊断，不混入其他工作树内容。
#### Scenario: 合并验证与交付
- **WHEN** 用户要求本轮dev_zys集成
- **THEN** 逐项核对共同修改及冲突、运行商业化及直接调用方验证和iOS编译
- **AND** 仅非强制推送指定origin/codex/dev，确认双方祖先及来源不变，真实业务待验状态保持
