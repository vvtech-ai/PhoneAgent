## ADDED Requirements

### Requirement: 结果补全必须刷新原目标评分
客户端 MUST 在同一目标结果补全及再次获得卡片 owner 时重新核对真实资格，保留首次位置；重复相同结果 MUST NOT 引发连续查询。

#### Scenario: 资格晚就绪或初次查询失败
- **WHEN** 原任务已展示结果，首次查询无资格或失败，随后同身份结果补全且服务端已符合资格
- **THEN** 原评分区域显示可用评分，不退出重进，不阻塞结果与 Agent 说明

#### Scenario: 批量回执仅补业务结构字段
- **WHEN** 同批次终态的 headline、detail、status 未变，但补全单路 receiptFields、recalled、abnormal 或整批 totalCount
- **THEN** 原 batch 评分目标重新核对一次资格；同值重复投影或仅目标显示名变化不触发查询，不引入轮询

### Requirement: 刷新必须保持身份与只读防护
客户端 MUST 隔离旧请求、旧 target、旧账号，保留单一 owner、已提交只读与既有幂等语义；批量运行中 MUST NOT 因单路先结束获取整批评分。

#### Scenario: 请求交错与 owner 交接
- **WHEN** 请求期间有新结果或 owner 交接，旧响应最后返回
- **THEN** 旧响应不覆盖新资格，新 owner 仍仅显示一张卡

#### Scenario: 已提交与批量运行中
- **WHEN** 已有提交继续补全结果，或批量仍在运行但已有一路结果
- **THEN** 已提交评分保持只读，运行批次不伪造整批评分入口
