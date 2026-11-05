# 国内 SIP 设计

## 来源与业务边界

固定 Android TranslationCallRoutePolicy/AssistantSipRouting/AndroidAssistantCallEngineGateway；固定 iOS AITranslationCallRoutePolicy/AIClientSipRouting/AIClientSipCallSession/AIClientSipMediaBridge。位置CN→千问或豆包及国内/国际SIP，位置非CN→OpenAI/Gemini国外后端。测试强制后端必须由现有开发环境门禁启用，不能绕过可信位置。

纯Dart路由输出冻结plan（可信位置、canonical号码、网络号码、provider、transport、账号选择、语种、服务区域）。短号和分机沿现有DialPhonePolicy；分机保留手动输入，不复制参考自动DTMF。号码规范化只在路由处发生，国内/国际租约以网络号码的国际前缀判断。

## 分层和资源

国内模型参考使用客户端固定配置。Flutter不迁移参考中的密钥，使用仅内存安全配置注入端口；供应方握手header仅在对应wss连接中使用，不复用账户token。部署需提供安全配置来源或服务端短期凭证契约，缺失时明确不可用并禁止注册/拨号。此条件不阻塞协议、媒体及合成流程实现。千问原生输出24k需先按原生重采样转16k，SIP始终8k。

Domain定义租约/协议/状态机及可注入端口，data使用AccountApi调用POST api/client-sip/leases与POST api/client-sip/leases/{leaseId}/release；purpose=translation_call，结束reason=call_session_finished。账户切换不把凭证转交新登录。密码/响应不日志、不落盘。UDP信令/RTP独立于设备16k PCM端口；信令与编解码纯Dart，可离线和loopback验证。媒体在平台侧继续由唯一音频owner持有，8k SIP与16k模型音频显式重采样。不得先开放国内按钮再连接空实现。

取消/失败先释放媒体和socket，串行结束租约；申请中取消后接收的有效租约仅释放不拨号。申请异常未知结果不重申请。接通/振铃后禁止自动重拨。所有子模块以微批及定向验证执行。

## 接续顺序

路由和租约→信令解析/认证/SDP→UDP事务→RTP编解码/DTMF→模型协议与双向音频→国内协调器/积分/归档→设置与正式入口→平台后台与真实验收。每阶段完成自动进入下一项。

## 双向PCM接线细化

16k设备采集→local模型→16k翻译输出→8k G711/RTP；8k远端RTP→16k→remote模型→16k设备播放。两个模型准备后才启动采集，媒体退出关闭全部owner；准备/播放期间取消不得再次送帧。RTP固定20ms帧，沿原生160ms预缓冲及30秒上限，完整响应的不足一帧末尾补零排空以避免短句卡住。重复和已过期RTP不重复翻译。手动DTMF优先协商telephone-event（160ms/三末包），未协商才INFO且等待确认；分机不自动发送。当前原音动态混播、开场提示、录音归档仍独立待接线，不能因此提前开放正式入口。

## 设备出口路由

Dart UDP绑定地址不得从网络接口列表猜测；Android DatagramSocket和iOS BSD UDP connect到租约服务器/端口后读取本地地址，过程只选择系统路由、不发送REGISTER/INVITE或UDP业务报文。返回本地及同次解析的对端数值IP，UDP端口绑定使用同地址族；退出关闭薄通道资源，无需新增权限。原生代码/注册有变更时执行Android debug及iOS无签名构建，设备实际出口验证独立待验。

## 开场提示

复用固定iOS仓库四个非用户音频资源（zh/en/ja及zh触发音），Android与iOS共享20ms/16k帧、远端200ms前静音、按较长本地提示补远端尾静音、触发后600ms零帧。开场期间禁止现场输入和模型音频/字幕泄漏；千问仅response.done解除触发响应屏蔽（5秒期限），不能把audio.done当完整边界；豆包没有可靠完整边界时采用800ms保护窗。取消终止所有播放/注入，触发边界超时拒绝继续现场翻译。音频资源内容不包含用户录音或凭证，pubspec仅增加assets不刷新依赖。

## 国内录音时间轴与上传

双端原生使用LOCAL_CALLER与PEER_FINAL_OUTPUT两轨：本地采集时间轴在静音/开场时仍前进，但只写非静音现场；远端只写最终实际播放音频，开场提示和触发音排除。同轨start=max观测时间偏移,上一块end)，负时间裁切，最终按物理接通至结束窗口补静音/裁尾，两轨相加后才限幅。Flutter以有限窗口混音，避免整通电话累积数组；录音日志/输出使用账户与环境隔离的私有文件，队列或文件失败只标记录音不可用，不重拨。最终真实AAC/M4A16k单声道48kbit/s，最大300MB；归档后以服务端callId上传recording-content multipart(file,durationMillis,checksumSha256)。日志在归档及录音上传完成前保留，重试只复用原callId，不重复电话。逐步实现时间轴、文件日志、原生编码、媒体tap及上传/应用组装。

编码完成在私有目录原子保存时长/SHA256回执，回执与文件一致时恢复复用，不重复编码；无回执的孤立编码产物仅在已校验完成PCM日志基础上重新编码，不将未确认文件直接上传。相同文件finalize在进程内串行并拒绝冲突时长。未完成capture不伪造完成或自动电话恢复。

## 国内模型与账号设置

固定Android TranslationProviderUiCatalog把服务端QWEN_OMNI_PLUS（兼容QWEN_OMNI_FLASH/QWEN别名）显示为Qwen3.5，协议/积分引擎代码仍为QWEN；DOUBAO保持同名。模型读取/切换使用原生GET/PUT api/account/settings/realtime-translation-provider、X-Account-Id，不扩大Bearer路径。服务端active/configured/available及倍率为权威，切换成功才更新当前选择，不可用或失败保留原值，不影响活动通话冻结配置。两端SIP目录21311802至21311816/default21311802，只在可信CN位置显示；保存无密码的环境隔离设备偏好。当前原生租约请求没有选定账号字段且engine使用返回账号，Flutter不新增未知字段或强制租约id等于偏好，实际凭证以租约为准，此限制进入待完善清单。


## 活动翻译后台音频所有权

仅显式活动翻译PCM会话携带不可复用callAudioId；普通ASR/TTS/录音无token继续前台限制。Android在前台且麦克风已授权时启动非导出microphone前台服务并等待startForeground确认后采集，持续通知只返回App、不暴露号码/字幕；停止音频成功后释放服务和CPU锁，START_NOT_STICKY禁止重启电话。服务被系统停止时使token失效、停止关联硬件，不自动恢复。iOS声明audio后台能力，前台授权启动活动duplex后仅对匹配token跳过进入后台/失活停止；系统音频中断/媒体丢失仍停止且不自动恢复。后台不得新发起翻译采集或绕过麦克风授权。共享Dart owner在硬件停止未确认时保留租约，并支持重试清理。依据Android官方microphone前台服务类型/启动要求，固定原生iOS已有audio模式，固定Android未见对应前台service，按平台要求完善而不复制缺项。

参考官方要求：https://developer.android.com/develop/background-work/services/fgs/service-types#microphone 及 https://developer.android.com/develop/background-work/services/fgs/launch 。源码/构建通过不等同后台设备验收。


## SIP事务与失败收尾加固

REGISTER/INVITE及INFO响应同时核对Call-ID、CSeq方法/序号与顶层Via branch（RFC3261 17.1.3）；同号旧branch不得改变阶段、确认DTMF或覆盖当前协商。解析只取首个Via hop，重复branch参数拒绝匹配。初始失败保持原业务错误；CANCEL/BYE发送失败另外保留清理未确认，close仍等待启动任务结束后关闭wire，不用关闭socket掩盖未收尾任务，不自动重发未知终止。RFC依据https://www.rfc-editor.org/rfc/rfc3261#section-17.1.3 。


## 合成设备编码验证

使用独立Android/iOS模拟器演练身份运行实际Dart录音编码端口及原生AAC实现。输入为本地产生的16k单声道PCM（一秒静音加一秒440Hz正弦波），不注册业务账户/模型/SIP，不申请麦克风，不上传；Android演练manifest移除网络/麦克风/相机/电话/通讯录/位置权限，iOS只注册实际DomesticRecordingChannel。验证实际M4A可解码、采样率/声道/时长及静音间隙，报告源码SHA和平台，不将模拟器合成编码视为真机通话录音验收。普通业务App不覆盖、不卸载、不清数据；构建产物与合成音频放ignored .local。


## 归档后的私有文件清理

账户归档 controller 新增独立异步完成清理端口，只在远端 archive（含录音 multipart）成功、本地 pending 删除保存成功之后调用。清理异常与已提交交易分开，不能恢复 pending 或重复请求。仅 domestic 且有确认录音元数据的 entry 清理；无录音/不完整记录保留供诊断，国外不触碰。私有文件 owner 逐层检查 root/translation-recordings/scope/call 为真实目录且无链接，先检查全部目录条目为已知普通文件再删除，每次操作重查账户。删除仅 capture.pcmj、混音临时文件、编码产物及回执，非递归删空 call 目录，其他通话/账户不变。崩溃在 pending 删除与清理之间可能留下孤立文件，暂不做无事实依据的全局扫描/删除，列为后续存储配额与孤立清理待完善。


## 对端挂断的会话身份核验

现有holdUntilEnded仅按Call-ID接受BYE。按RFC3261第12节及12.2.2，对话身份由Call-ID/本地tag/远端tag共同决定；接收请求From是远端tag，To是本地tag。新增纯Dart地址tag解析只识别URI尖括号/显示名引号外的参数，严格拒绝重复/无效tag及重复身份头；CSeq须为有效BYE。冻结dialog依据实际已确认INVITE的To和本地FromTag，未知/错误BYE回复481、不改phase、不终止媒体、不发送本地BYE；正确BYE回复200且只结束一次。兼容原RFC2543无远端tag仅在已确认响应确实无tag时按null匹配，不能把解析损坏当null。此项不是TLS SIP或完整RFC事务栈验收。来源https://www.rfc-editor.org/rfc/rfc3261#section-12.2.2 。实际修改在当前ad32a9c全量回归完成后开始，之后执行协议/事务/UDP及协调器定向，不因后续修改将此前全量称为最终HEAD全量。


## 准入演练的国内端口隔离

跨模块回归发现旧CN测试仍期待禁用海外模型和“国内SIP暂不迁移”，实际入口已转国内页。演练Provider必须为新国内模型设置及设备偏好显式注入内存端口，不能读真实账户接口或FlutterSecureStorage；合成Qwen/豆包状态与倍率明确MOCK。正式页面/路由复用，当前无设备通话binding时明确当前环境不可用，不接空实现或真实呼叫。更新CN场景验证国内模型读取/切换/返回、海外模型不出现、US号码前缀不改变可信CN路由，既有开发强制/未知位置/海外场景保持。此修复在当前全量结束后执行，不以旧全量通过代替修后验证。


## Digest依赖分层修复

本轮架构测试明确domain禁止所有package依赖，新增SipMessage文件中的crypto违反该基线。将Digest挑战/MD5认证适配移到data，domain仅定义认证端口，SipTransactions通过构造注入，不放宽测试或自行实现密码算法。实际UDP连接装配data实现，协议已知向量及loopback继续验证；无新依赖/密钥/配置变化。按domain端口/data适配/消息三文件，事务/UDP接线/专项三文件及协议专项独立微批执行。


## 2026-10-09 用户批准参照配置部署
最新用户确认执行覆盖上方旧“不迁移参考密钥/等待短期来源”的阶段限制。实际Provider已接工程本地私有输入和双端只读原生通道，参考凭据仅ignored部署、会话内存使用，不进入Git/日志；参考长期客户端配置不能称短期认证。详见../reference-domestic-model-configuration/design.md，真实模型服务/电话仍待验，SIP租约与账号/计费门禁保持。
