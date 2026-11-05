## ADDED Requirements

### Requirement: iOS preview session failure identifies the native operation
The client SHALL persist whether preview preparation failed in `deactivate`, `setCategory` or `setActive`, the audio session category, mode and options immediately before that call, and the bounded attempt number. Only allowlisted metadata SHALL be exported; legacy string NSError details SHALL remain readable. Diagnostic collection SHALL NOT change capture release or playback behavior.

#### Scenario: Native activation fails after category configuration succeeds
- **WHEN** iOS configures Playback successfully but activation returns an NSError
- **THEN** the exported preview failure identifies `setActive`, the numeric error and the session state before activation, without audio data or arbitrary native messages

#### Scenario: Native category configuration fails
- **WHEN** iOS fails to configure Playback
- **THEN** the exported failure identifies `setCategory` and its preceding session state, and does not claim activation was attempted

### Requirement: 克隆错误必须可按阶段定位且不泄漏材料
声音克隆诊断 MUST 使用现有日志上传，记录接口静态别名、平台、耗时、HTTP状态、白名单业务错误、SDK返回码、状态与失败阶段。MUST NOT 记录姓名、身份证、账号、token、音频、metaInfo、certifyId、receipt、签名或原始服务端/SDK消息。

#### Scenario: 初始化接口拒绝或格式错误
- **WHEN** 初始化HTTP400或响应字段缺失/类型错误
- **THEN** 日志区分verificationInit接口拒绝与本地解码失败，保留安全请求关联及字段名/类型，不记录响应值

#### Scenario: SDK及后续克隆操作异常
- **WHEN** SDK准备/采集/释放、轮询、生成、试听、确认、录音保存或恢复音色失败
- **THEN** 记录对应阶段、安全错误分类及耗时，使用本流程随机ID关联

### Requirement: 日志不得改变业务结果
诊断 MUST 保留原请求次数、异常、返回值、账户隔离和SDK释放时序；日志自身失败不得改变认证/计费/试听结果。

#### Scenario: 日志写入失败或未知敏感错误
- **WHEN** sink抛异常或收到未知服务端正文
- **THEN** 业务仍按原逻辑处理，正文不进入日志，不自动重发认证或收费请求

### Requirement: 网关前缀必须覆盖实际业务请求
克隆接口诊断 MUST 使用ServiceRoutes按配置base归一化后的逻辑路径识别，签名及发送保持完整路径；初始化日志 MUST 记录modelId是否存在的布尔元数据，不记录值。

#### Scenario: SDK网关前缀下初始化失败
- **WHEN** API base带/aiassistant-sdk-api/或其他合法前缀，初始化返回400
- **THEN** 必须输出voiceCloneRequest、verificationInit、HTTP状态、白名单原因和可用签名请求UUID；不得仅有通用accountRequest

### Requirement: 试听故障必须区分音频输入和原生播放阶段
试听诊断 MUST 在现有导出内记录音频容器、大小、可解析WAV格式、播放器准备/异步错误/清理阶段和白名单原生错误码，MUST NOT 输出音频字节、文件路径或任意异常消息。

#### Scenario: iOS接口成功而播放器失败
- **WHEN** 音色sheet或克隆流程下载成功后播放器失败
- **THEN** 同一随机关联ID下可见输入格式和失败阶段；日志故障不改变播放与释放行为
