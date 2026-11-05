## ADDED Requirements

### Requirement: 邀请活动必须使用服务端事实
客户端 MUST 从邀请接口读取活动、邀请码、有效期、资格、名额与奖励；未知不得冒充零或有效。复制/海报成功后才上报对应操作事件，事件失败 MUST NOT 撤销已经成功的设备操作。

#### Scenario: 活动不可用或离线
- **WHEN** 活动结束、码失效或网络读取失败
- **THEN** 显示可辨状态与重试，不虚构有效海报或奖励

### Requirement: 邀请注册必须可以安全重试
客户端 MUST 在邀请注册发送REFERRAL来源及稳定registrationRequestId，同一提交重试复用ID；取消、销毁和切号 MUST 使旧回调失效。短信验证码和challenge MUST NOT 持久化。

#### Scenario: 注册结果未知
- **WHEN** 超时或REGISTRATION_RETRYABLE
- **THEN** 保持原请求标识重试，不能把失败展示当后端未注册

#### Scenario: 普通登录兼容
- **WHEN** 无有效推荐码或使用既有激活流程
- **THEN** 保持原有登录行为，不强制REFERRAL

### Requirement: 链接接收必须区分环境和会话
客户端 MUST 校验可信host/path/scheme及码格式，支持冷热启动和重复投递去重；MUST NOT 自动切换环境或给已登录账号绑定邀请。

#### Scenario: 恢复中收到链接
- **WHEN** 登录状态仍在读取
- **THEN** 暂存链接，状态明确后才进入欢迎或已有账号提示

### Requirement: 奖励通知必须账号隔离
客户端 MUST 仅展示服务端已到账事实，按账号及operationId持久去重；通知确认与钱包记账 MUST 分离，切换账号不得展示旧通知。

#### Scenario: 确认后重启
- **WHEN** 相同奖励重复到达或进程重建
- **THEN** 已确认奖励不再弹出；存储失败保留可重试状态，不本地加余额

### Requirement: 海报保存必须使用真实平台结果
客户端 MUST 生成可扫描的有效分享链接二维码，经平台端口保存图片；取消、拒权、磁盘失败 MUST 明确反馈，不上报保存成功。

#### Scenario: 双端权限
- **WHEN** 用户保存海报
- **THEN** Android/iOS分别使用对应文件或相册能力，失败允许重试，UI不直接调用设备API

### Requirement: 邀请页面范围必须与原生参考一致
客户端 MUST NOT 展示邀请记录入口或邀请记录页面。活动刷新 MUST 仅加载活动与邀请码，不依赖邀请记录接口；Android参考已有的记录API和模型 MUST 保留为数据层能力，不接入UI。积分流水、活动规则、复制与海报流程 MUST 保持可用。

#### Scenario: 从积分页进入邀请
- **WHEN** 用户查看积分页邀请活动卡片
- **THEN** 可以查看规则和邀请好友，但没有邀请记录按钮或对应页面

#### Scenario: 记录接口不可用
- **WHEN** 用户刷新邀请活动
- **THEN** 不请求邀请记录接口，活动和有效邀请码仍可正常分享
