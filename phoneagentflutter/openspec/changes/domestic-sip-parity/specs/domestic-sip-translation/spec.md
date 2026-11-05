## ADDED Requirements

### Requirement: 国内模型配置必须安全注入
系统 SHALL 从安全配置来源注入模型连接配置，不复制原生固定密钥、不持久化或记录模型认证参数，不复用账户token。缺少有效配置 SHALL 在SIP注册和外呼之前显示不可用。

#### Scenario: 未配置模型凭证
- **WHEN** 国内翻译缺少有效模型连接配置
- **THEN** 系统拒绝注册和外呼，保留设置及取消入口

### Requirement: 共享路由保持原生地区与模型准入
系统 SHALL 基于可信当前位置生成冻结通话计划；中国境内使用千问或豆包客户端SIP、境外使用OpenAI或Gemini后端媒体。账号选择和网络号码 SHALL 在拨号前确定，不把服务节点或号码归属国当当前位置。

#### Scenario: 中国境内拨国内号码
- **WHEN** 可信位置为CN且号码是中国国内号码
- **THEN** 系统选择国内SIP账号与国内网络号码，缺少账号时拒绝准备

#### Scenario: 中国境内拨国际号码
- **WHEN** 可信位置为CN且目标为国际号码
- **THEN** 系统选择国际SIP账号与00国际前缀，仍使用国内翻译模型

#### Scenario: 未知位置
- **WHEN** 无可信位置，即使测试强制后端已启用
- **THEN** 系统拒绝通话准备

### Requirement: SIP租约凭证仅限当前会话
系统 SHALL 使用原生租约契约，凭证仅内存，不输出密码/认证响应，不自动重申请未知结果。已知租约 SHALL 在取消、失败或结束时释放。

#### Scenario: 租约申请中取消
- **WHEN** 用户取消后租约申请成功返回
- **THEN** 系统只释放该租约，不注册或外呼

#### Scenario: 释放未确认
- **WHEN** 后端释放失败或返回不匹配租约
- **THEN** 系统显示清理未确认，不伪造成功或重拨

### Requirement: 国内媒体和结算必须完整后开放
系统 SHALL 完整实现信令、双向媒体、翻译、账户清理与服务端积分结算后开放正式国内入口；离线验证不得标记真实能力验收通过。

#### Scenario: 正式国内通话
- **WHEN** 用户从正式入口发起国内翻译
- **THEN** 系统使用完整媒体与积分预检，接通与结束向服务端同步，归档与国外路径分开

### Requirement: 国内积分会话采用原生幂等契约
系统 SHALL 在外呼前创建TRANSLATION_CALL/LOCAL_SIP积分会话，使用标准Idempotency-Key及translation:callId格式；认证刷新 SHALL 保持请求体与幂等键不变。接通、心跳、续授权及终态 SHALL 使用递增sequenceNo和服务端authorizationVersion，未知结算不伪造成功。

#### Scenario: 创建会话需要认证刷新
- **WHEN** 积分会话创建遇到401且刷新成功
- **THEN** 重发仍使用同一标准幂等头和请求体，不生成第二个业务标识

### Requirement: 国内归档必须使用独立路由
系统 SHALL 在Android和iOS均使用服务端原生DOMESTIC_ANDROID归档路由，不携带WORLD_CALL locator或录音grant；已存在缺省路由的Flutter归档日志 SHALL 仍按WORLD_CALL读取，未知路由不得猜测。国内录音 SHALL 使用本地会话录音并独立上传，不能从国外会话伪造locator。

#### Scenario: 国内已接通翻译结束
- **WHEN** 国内翻译完成字幕终态收尾
- **THEN** 系统以DOMESTIC_ANDROID及相同clientCallId归档，不发送国外录音locator

#### Scenario: 恢复旧国外归档日志
- **WHEN** 旧日志未保存route字段
- **THEN** 系统按WORLD_CALL恢复并保留既有locator门禁

### Requirement: SIP绑定必须使用系统实际出口
系统 SHALL 通过薄平台端口读取到租约SIP服务器的实际本地出口和同次解析的对端地址，不从网卡列表猜测或广告任意地址。读取路由 SHALL 不发送SIP注册或外呼报文，取消及退出必须释放探测socket。

#### Scenario: 多网络或不同地址族
- **WHEN** SIP准备需要绑定UDP端口
- **THEN** 系统使用内核路由选择得到的本地数值IP及相同地址族对端，不使用0.0.0.0或未经核对的接口首项

### Requirement: 国内开场提示不得泄漏现场或触发回复
系统 SHALL 沿固定原生播放共享开场资源与触发音，开场期间抑制现场输入、模型音频及字幕。千问 SHALL 等待完整response.done，豆包 SHALL 使用无完整边界保护窗；取消终止播放和注入，触发响应超时不得开放翻译。

#### Scenario: 千问音频块结束但完整响应未结束
- **WHEN** 模型仅返回response.audio.done
- **THEN** 系统仍抑制触发回复直到response.done或超时终止

### Requirement: 国内录音必须保留物理时间轴与最终播放
系统 SHALL 仅录制非静音现场本地采集和远端最终播放，不录制开场或触发回复。静音期间 SHALL 保留时间间隙，同轨按序消除时间抖动重叠，两轨相加后限幅并按实际通话窗口裁切或补零。输出 SHALL 为真实16k单声道48kbit/s AAC/M4A，上传失败保留账户隔离日志，不重拨。

#### Scenario: 静音后恢复现场并结束
- **WHEN** 用户静音后恢复且通话结束
- **THEN** 录音保留对应静音间隙，以原callId归档和重试录音上传，不把缺失音频压缩成连续讲话

### Requirement: 国内模型设置以服务端确认和冻结通话为准
系统 SHALL 按原生接口读取和切换国内翻译模型，显示Qwen3.5/豆包及服务端可用性和倍率；切换失败保持当前选择，已开始通话保持冻结模型。账号偏好 SHALL 使用两端共同目录且不存储SIP密码，实际连接使用服务端租约，不发明账号选择请求字段。

#### Scenario: 模型切换未被确认
- **WHEN** 用户切换模型但请求失败或返回不同模型
- **THEN** 系统保持旧选择并允许重试，不将活动通话改到另一个供应方


### Requirement: 只有活动翻译会话可持续后台音频
系统 SHALL 为显式活动翻译会话持有独立后台音频租约；Android使用已授权且前台启动的microphone前台服务，iOS使用活动duplex与audio后台声明。普通录音/ASR SHALL 保持前台边界，系统中断或服务失效停止关联硬件且不自动恢复电话。硬件释放未确认 SHALL 保留资源所有权，后台不得新发起未经准入的采集。

#### Scenario: 已连接通话进入后台
- **WHEN** 活动翻译音频已在前台启动并持有匹配租约
- **THEN** 系统保持对应双向音频，结束后先停止硬件再释放后台所有权

#### Scenario: 普通采集或系统中断
- **WHEN** 普通采集退后台，或翻译遇到系统音频中断
- **THEN** 系统停止对应音频，不自动恢复或重新拨号


### Requirement: SIP响应严格匹配当前事务且保留清理失败
系统 SHALL 核对SIP响应顶层Via branch与Call-ID/CSeq方法和序号，旧事务不得确认当前注册、通话或手动DTMF。初始业务失败 SHALL 保持原错误，终止发送失败另外标明清理未确认；关闭 SHALL 等待已启动任务完成后释放wire，不自动重拨或重发未知终止。

#### Scenario: 同CSeq回包带旧Via branch
- **WHEN** 注册、INVITE或INFO响应的顶层Via branch不匹配当前请求
- **THEN** 系统忽略该响应，保持当前事务等待

#### Scenario: 取消发送失败
- **WHEN** 启动取消中CANCEL或BYE发送失败
- **THEN** 系统保留原业务错误与独立清理未确认，并等待启动收尾再关闭wire


### Requirement: 国内录音仅在持久归档确认后清理
系统 SHALL 在归档及录音上传成功且本地 pending 日志删除已持久化后清理同账户同 callId 私有录音文件。失败或未知归档 SHALL 保留音频用于原 callId 重试；清理失败不得重新上传或重拨。清理 SHALL 只删除已知普通文件，拒绝符号链接及未知目录内容，不递归清理账户或其他通话。

#### Scenario: 上传成功但本地日志保存失败
- **WHEN** 远端归档成功但 pending 日志删除尚未持久化
- **THEN** 系统保留录音文件与原日志，不提前清理

#### Scenario: 已确认归档的文件清理失败
- **WHEN** pending 删除已持久化但私有文件无法删除
- **THEN** 归档保持完成，不重传、不重拨，保留未删除文件


### Requirement: 对端挂断必须匹配已确认会话
系统 SHALL 仅在BYE请求Call-ID、本地To tag、远端From tag与已确认对话一致且CSeq有效时确认200并结束当前会话；错误或歧义身份 SHALL 回复481并保持当前通话，不发送本地挂断。解析 SHALL 忽略显示名/URI内伪tag参数并拒绝重复或非法tag，缺失远端tag仅兼容已确认无tag的会话。

#### Scenario: 同Call-ID但错误tag的BYE
- **WHEN** 对端请求Call-ID相同但From或To tag错误或重复
- **THEN** 系统回复481，保持媒体和当前phase，不触发结束或回声BYE


### Requirement: 国内准入演练必须隔离外部业务端口
国内准入演练 SHALL 为模型设置及SIP设备偏好注入纯内存合成端口，不能调用真实账户接口或安全存储；复用正式国内页面和地区规则，缺少通话binding时明确不可用，不发起模型、积分或SIP动作。

#### Scenario: 合成CN位置打开国内设置
- **WHEN** 用户在准入演练中使用可信CN和国际号码前缀
- **THEN** 页面仍打开国内模型设置并可在内存中确认切换，海外模型不出现，呼叫缺设备binding时明确拒绝
