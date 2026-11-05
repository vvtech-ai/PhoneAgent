## ADDED Requirements

### Requirement: Complete scoped memory alternatives
缺失字段的记忆检索 SHALL 保留同一用途的所有相关备选，未明确选择时不可擅自缩成一人；采用仍须确认并限于所选版本。
#### Scenario: Two related contacts
- **WHEN** 当前 Skill 有两位适用联系人，用户没有指定某位
- **THEN** 展示两位供选择，选择一位仅授权该位，其他 Skill 与无关用途不进入候选

### Requirement: Safe management continuity
当前管理工具的安全状态与写入结果 SHALL 可用于后续说明，内部隔离标记不得展示或播报；管理候选正文不授予任务采用。
#### Scenario: Save confirmation followed by result
- **WHEN** 用户确认保存本次工具回答中的联系人并产生写入结果
- **THEN** 后续模型得知真实结果而不循环新增或输出内部隐藏提示

### Requirement: Effective model and installed version
准入与报价 SHALL 使用当前任务有效模型；日志设备信息 SHALL 使用实际安装版本。
#### Scenario: Task model differs from global
- **WHEN** 全局模型首分钟110、任务模型100、余额105
- **THEN** 报价与准入依据任务100，后续请求携带同模型且不修改全局选择
#### Scenario: Diagnostic upload
- **WHEN** 实际安装版本为1.0.52（45）并上传日志
- **THEN** 设备信息记录该版本，读取失败不得伪造1.0.0（1）

## Repository scope

本仓只实现任务有效模型与诊断版本接线，记忆后端合同由服务端实现；评分保持既有逻辑。

### Requirement: First missing-information question uses current memory state

公共工具规范层 SHALL 在主模型跳过记忆检索而准备补问缺失资料时，按当前账号与 Skill 有界核对相关未决定候选；首次任务不依赖客户端缓存热身。

#### Scenario: Fresh restaurant or apology task skips recall
- **WHEN** 当前有相关记忆，首个业务轮次直接产生普通缺资料 askUser，且未停止主动询问
- **THEN** 当前命令最多补核一次，相关未决定候选进入既有使用确认，未明确同意前不采用

#### Scenario: No additional step is needed
- **WHEN** 当前无候选、无关、不可用、已拒绝、资料已完整，或问题属于管理 / 保存确认
- **THEN** 保留原流程，不追加无关确认、不无限分类、不执行电话
