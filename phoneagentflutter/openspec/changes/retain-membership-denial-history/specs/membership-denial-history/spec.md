## ADDED Requirements

### Requirement: 权益拒绝提示可从历史恢复
客户端 SHALL 从已有 schema v1 RUN_FAILED 的已识别权益错误码还原安全的助手提示，与实时提示一致并保留事件身份；SHALL NOT 展示原始异常或把未知失败伪造成权益拒绝。

#### Scenario: 退出并重新打开被会员限制的任务
- **WHEN** 账本含 BATCH_CONCURRENCY_LIMIT 等已识别权益拒绝事件
- **THEN** 历史对话仍显示拒绝原因，且不重新外呼或自动重播历史 TTS

#### Scenario: 实时提示随后与持久化事件合并
- **WHEN** 同一命令已实时显示拒绝，随后收到对应账本事件
- **THEN** 只保留一条拒绝提示，来源步骤和可见消息保持一致
