## ADDED Requirements

### Requirement: iOS SDK 初始化按进程复用
iOS 客户端 MUST 在首次显式采集准备时调用 SDK 初始化，仅在调用正常返回后在当前进程复用；MUST NOT 在插件注册时初始化，或将初始化状态与认证会话清理绑定。

#### Scenario: 新会话及插件重建
- **WHEN** 首次初始化正常返回后发生取消、会话结束、账号切换或插件重建并开启新会话
- **THEN** 当前进程不重复调用 SDK 初始化，新的进程仍在首次显式准备时初始化

#### Scenario: 初始化异常
- **WHEN** SDK 初始化调用抛出异常
- **THEN** 沿用现有失败处理，不记录初始化完成，后续显式准备可重试

### Requirement: 认证与交互契约保持
客户端 MUST 保留每个新会话获取 MetaInfo、请求原服务端初始化并使用本次响应 certifyId 的流程；MUST 保留 UI、所有参数传递与结果处理、录音配置、执行线程、媒体租约、迟到回调隔离及 Android 实现。

#### Scenario: 连续认证采集
- **WHEN** 用户重新开始一次认证采集
- **THEN** 重新获取本次 MetaInfo 并完成原请求及 SDK 调用，不复用前次认证数据；同会话 prepare 缓存保持原有规则
