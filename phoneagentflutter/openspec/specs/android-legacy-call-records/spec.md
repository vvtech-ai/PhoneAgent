# android-legacy-call-records 规范

## Purpose

定义固定v65账号本机通话元数据向Flutter安全仓库的只读导入，保持既有最近记录和系统来源边界；真实升级验收独立于合成测试。

## Requirements

### Requirement: 旧App记录只按同生产Android当前账号读取
系统 MUST 校验非Web Android、精确正式API及原生生产包名，只读取index9_native_screen固定账号键，MUST NOT 读guest、任意文件或系统通话日志，不修改旧源。

#### Scenario: 作用域与账号不符
- **WHEN** 平台/环境/包名不符，或返回信封账号不符
- **THEN** 不导入，不改变当前账号状态或旧源，账号不符明确失败

### Requirement: 共享元数据映射必须保持旧有效规则
系统 MUST 保留号码、callId或既有fallback ID、kind、时间、姓名、国家及语言；不迁入旧详情全文或凭据，MUST NOT 推断通话成功、补造后台任务或执行电话。

#### Scenario: 旧可选字段缺失
- **WHEN** 旧记录满足title/status/meta有效条件但缺少时间、callId或显式姓名
- **THEN** 时间按旧规则归0，ID沿phone:time:KIND，姓名只用固定标题前缀规则；未知kind为AGENT，列表显隐继续由现有消费者决定

### Requirement: 导入和清理必须在现有串行边界完成
系统 MUST 仅在新key不存在时读取旧源，先成功写入有效新信封再返回；空信封也代表已处理，MUST NOT 在清理或新保存后恢复旧记录，不用旧源覆盖新损坏数据。

#### Scenario: 失败或并发
- **WHEN** 旧读取/解析/目标保存失败，或读取期间账号失效，或追加/清理并发
- **THEN** 失败明确不假装空成功，源不变；有效登录可重试，同槽串行且失效账号不继续写入
