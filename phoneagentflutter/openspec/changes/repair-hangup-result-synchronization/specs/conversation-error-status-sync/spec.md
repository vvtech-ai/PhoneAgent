## MODIFIED Requirements

### Requirement: 任务列表必须保留后台终态与异常补偿
系统 MUST 在任务列表刷新前尝试同步异常退出与异常挂断后的结果事实；同步失败时保留可恢复的 pending 状态和异常提示。系统 MUST 在读取到后台 `COMPLETED`、业务失败或积分不足终态后接受该权威事实，并触发当前会话与任务列表刷新；MUST NOT 因 pending recovered 乐观显示 RUNNING，或因物理通话终态取消结果恢复入口。
此处后台 `COMPLETED` 指任务列表的权威状态；单路 `callResult.status=COMPLETED` 若缺可信业务结论，仍按结果观察规则等待，不能仅凭该状态或单独的 `resultCode` 生成绿色结果终卡。

#### Scenario: 后台已经完成任务
- **WHEN** 异常退出或物理挂断后的同步响应为 `COMPLETED`
- **THEN** 接受后台完成状态，删除匹配的旧 pending，合并当前会话结果并刷新任务列表
- **AND** 不再强制覆盖成异常或保留无限 loading

#### Scenario: 后台返回业务失败或积分不足
- **WHEN** 异常挂断后的同步响应包含可识别的业务失败、积分不足或网络失败事实
- **THEN** 接受该事实并在当前会话和任务列表显示对应终态，停止该 session 的结果等待
- **AND** 不把失败事实升级为成功或 RUNNING

#### Scenario: 网络恢复
- **WHEN** 网络重新可用且当前账号有待同步的异常退出或挂断结果
- **THEN** 进行有界重试并刷新列表，失败保留待同步状态，不无限轮询或重复创建结果

#### Scenario: 物理终态早于后台结果
- **WHEN** 通话已挂断但后台结果尚未在第一次历史读取中出现
- **THEN** 保留同一 session/task/callAttempt 身份进行有界补偿读取，结果出现后更新会话和列表
- **AND** hangup、SSE done 或 transport failure 本身不被当作后台完成事实
