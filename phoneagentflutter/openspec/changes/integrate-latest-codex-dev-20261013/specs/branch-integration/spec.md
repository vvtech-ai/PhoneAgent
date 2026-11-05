## ADDED Requirements
### Requirement: 保留最新远端与已验证修复
本次 codex/dev 集成 MUST 保留最新远端 c74f2e54 与已验证语音修复 9bd4c9bd 的源码、规范及提交历史，MUST 在相关验证后非强制推送，MUST 不提交本地私有输入和已有构建补丁。
#### Scenario: 双方记录冲突
- **WHEN** 根任务或问题记录出现三方合并冲突
- **THEN** 保留双方完整章节且验证无残余冲突标记
#### Scenario: 推送完成
- **WHEN** 合并验证并推送完成
- **THEN** 远端 ref 等于本地提交，双方原提交均为其祖先
