## ADDED Requirements
### Requirement: iOS身份通知必须区分凭据接收和活动新鲜度
系统 SHALL 以四必要字段和当前账号号码接收身份通知，冷启动25秒单候选缓存 SHALL NOT 因callTime缺失或Activity过期而拒绝凭据验证；时间限制仍 MUST 控制活动创建。nil账号、引擎替换、超时及结束 MUST 清候选。
#### Scenario: 冷通知没有活动时间
- **WHEN** 四必要字段有效但callTime缺失且账号在25秒内恢复并匹配
- **THEN** 验证并展示凭据，不创建Live Activity
### Requirement: iOS身份展示必须保留原生状态语义
系统 SHALL 先展示待验证预览、失败保留白名单预览；只有SDK成功可认证。SDK成功且showType6 SHALL 显示未认证警示且无证书，可显示新鲜警示活动。有效通知点击 SHALL 可以再展示当前事件，重复后台投递不得重复验签。
#### Scenario: SDK失败
- **WHEN** 当前事件验签失败
- **THEN** 姓名企业等预览保留并显示失败，不出证书或认证活动
#### Scenario: 未认证身份
- **WHEN** SDK解析成功且showType6
- **THEN** 凭据与活动明确警示未认证，无认证证书
### Requirement: iOS来电链路必须具有脱敏诊断与有限恢复
系统 SHALL 记录固定阶段、来源及结果/拒绝码，不记录token、身份内容、号码或异常文本；事件流异常 SHALL 清显示并有限恢复当前快照，不重放真实SDK请求。NSE进程日志 SHALL 与App诊断明确区分。
#### Scenario: 事件流中断
- **WHEN** 当前监听发生错误
- **THEN** 清旧显示、记录固定失败码并有限重订阅，旧owner不得写新账号诊断
### Requirement: iOS活动与头像必须绑定当前事件
活动和凭据头像 SHALL 使用有界安全数据，异步结果必须匹配当前事件。已有同事件活动 SHALL 保持，失败 SHALL 允许有限前台重试，不永久禁止同事件。后台自动启动 SHALL 依赖已确认ActivityKit服务端契约，不能以普通APNS假称支持。
#### Scenario: 创建失败后恢复
- **WHEN** 当前新鲜事件Activity创建失败后恢复前台
- **THEN** 允许有界重试并记录失败原因，不先销毁已成功的同事件活动
#### Scenario: 头像晚到
- **WHEN** 旧事件头像下载完成时已有新事件或账号
- **THEN** 拒绝旧数据，不覆盖当前凭据或活动

### Requirement: iOS来电能力查询必须使用布尔通道类型
iOS原生incomingEventsAvailable SHALL 返回Flutter标准编解码可识别的布尔值，不得返回数值0或1。
#### Scenario: 真机订阅前查询
- **WHEN** Flutter使用invokeMethod<bool>查询来电能力
- **THEN** 原生成功/拒绝结果均为布尔值，允许订阅或正常终止，不因类型错误耗尽重试
