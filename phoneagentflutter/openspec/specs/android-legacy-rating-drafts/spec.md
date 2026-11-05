# android-legacy-rating-drafts

## Purpose

定义Android v65条件评分草稿的一次导入与新数据优先边界；实现及设备验收状态以对应活跃change为准。

## Requirements

### Requirement: 条件评分草稿必须按固定旧作用域一次导入
系统 MUST 仅在Android同生产包、精确prod API且当前账号任务合法时只读固定v65草稿；共享Dart映射分数、建议及原提交key，不自动提交、不改变条件显隐或服务端权威。

#### Scenario: 首次恢复未提交草稿
- **WHEN** 当前新key不存在且旧账号/taskType/taskId存在有效草稿
- **THEN** 完整保存至当前安全槽后返回；保留未填写项、原建议和submissionKey，其他账号/任务不读取；iOS/Web/dev不调用旧源

#### Scenario: 新数据或已清除优先
- **WHEN** 新key已有内容、损坏、未知schema或清除标记
- **THEN** 不再读旧源；新保存后重启保持新值，清除后重启不能复活旧草稿

#### Scenario: 导入失败与账号关闭
- **WHEN** 旧读/转换/新写失败或旧读取期间仓库已关闭
- **THEN** 不返回导入成功、不写空成功标记，旧源保留可重试；已关闭实例不开始新读写，晚到导入不写其他账号

#### Scenario: 并发导入与显式编辑
- **WHEN** 同作用域多个实例先发起导入再发起保存或清除
- **THEN** 在当前Dart isolate内按调用顺序串行，后续保存/清除最终获胜；不同任务不会复用另一草稿

#### Scenario: 有界读取与保密
- **WHEN** 源数据非法或超过64KiB
- **THEN** 失败不截断，不输出草稿内容、提交key或私有凭据；不枚举偏好、写删旧文件或申请权限
