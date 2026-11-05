## ADDED Requirements

### Requirement: 本轮集成保留双方历史和有效功能
本轮集成 MUST 将fetch核对的origin/codex/dev_zys 1c608cb3三方合入codex/dev 7a3e100b，保留测试环境及双方任务、账号、设置、记忆、语音和平台更新。MUST只推送核对后的origin/codex/dev，不force或混入其他工作区内容。

#### Scenario: 合并无文本冲突
- **WHEN** 三方预合并没有文本冲突
- **THEN** 仍检查公共请求、依赖锁及正式入口，并执行跨模块全量回归和双端编译
- **AND** 保留来源未验收change，不把真实声音、SDK、后台及正式升级标为通过

### Requirement: 验证和推送结果可追溯
集成 MUST 记录两方父提交、实际验证范围、失败及未验证项，并核对推送后的远端HEAD；产物和私有配置MUST不进入Git。

#### Scenario: 编译或测试受环境限制
- **WHEN** 任一验证失败或不可执行
- **THEN** 先核对状态并有限恢复，记录实际错误和验证边界，不将缺失证据当作通过

### Requirement: 用户追加的反向同步保留目标更新
本轮反向同步 MUST 将9975afe7的codex/dev合入ba2c946e的codex/dev_zys，保留双方历史及目标退出样式和Universal Link更新。用户追加授权后 MUST 仅向origin/codex/dev_zys非强制推送，本轮不更新dev；上方仅推dev要求只适用于此前正向合并。

#### Scenario: 仅带入文档和测试修正
- **WHEN** 来源独有变更仅为集成文档和账号测试修正
- **THEN** 执行静态分析、相关定向测试、OpenSpec及diff校验，不重复全量或平台构建
- **AND** 推送后验证双方祖先、远端与本地一致且来源dev未变
