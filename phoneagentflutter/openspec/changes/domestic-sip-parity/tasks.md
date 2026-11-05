# 子任务

- [x] 迁移共享国内/国外路由与网络号码规则，冻结请求并测试位置/模型/账号/语种门禁；5项专项和拨号邻接共168项通过。
- [x] 实现租约HTTP解析、申请/释放及取消迟到清理，离线验证，不落盘凭证；仓库/owner/路由共15项通过，未接正式入口。
- [x] 实现SIP消息、Digest认证与SDP协商；6项离线专项验证重复/compact/folded头、UTF8长度、已知Digest向量、音频媒体段与拒绝未知codec。正式事务接线仍待后续。
- [x] 实现UDP事务、REGISTER/INVITE/ACK/CANCEL/BYE、有限超时与取消；11项请求/事务/真实loopback专项通过。正式设备路由与国内媒体仍待后续接线。
- [x] 实现RTP PCMA/PCMU、8k/16k及原生Qwen24k转换、协商DTMF打包；6项专项通过。设备双向媒体接线属于后续任务。
- [x] 实现千问/豆包双向翻译模型协议和音频资源管理（源码接线及离线范围；真实模型/听感见独立待验项）。
  - [x] 实现Qwen JSON与Doubao protobuf/字幕逗号续句协议，11项专项及analyze通过；未调用真实模型。
  - [x] 完成双连接准备、失败/取消清理、迟到回收与安全WebSocket握手；生命周期5项、协议邻接8项及握手3项通过。实际供应方TLS/音频未验收。
  - [x] RTP协商端口适配和对端过滤完成，2项真实loopback收发/关闭/拒绝未知端点测试通过。
  - [x] 设备PCM双向模型/G711接线、静音/扬声器/手动协商DTMF与错误关闭完成；媒体4项、分帧3项及编解码/模型owner邻接共18项通过，未做真机验收。
  - [x] 双向原音混播、RMS平衡/限幅及40ms压低/200ms尾保持/350ms恢复完成；媒体与混播10项通过。供应方边界能力由协调器注入。
  - [x] 共享开场资源、20ms播放/触发注入、现场及回复屏蔽、完整边界/取消/超时完成；相关23项通过，双端Debug构建通过，真机听感待验。
  - [x] 完成国内录音归档接线（源码/合成编码；真实通话录音和上传仍待验）。
    - [x] 两轨时间定位、同轨顺序、静音间隙及有限窗口混音完成；4项专项及analyze通过。
    - [x] 账户隔离私有PCM日志、256块限额/损坏拒绝、完成标记、媒体tap及磁盘混音finalizer完成；媒体/协调器/日志/时间轴/tap共21项、finalizer2项及analyze通过。
    - [x] 双端文件流式AAC/M4A16k单声道48kbit/s薄适配完成，私有目录/路径白名单、禁覆盖、Android无进展15秒关闭；端口/finalizer4项、analyze及双端Debug构建通过，实际设备编码待验。
    - [x] 独立 Android/iOS 模拟器合成 PCM 实际 AAC 编码/解码、静音时间轴及普通包保护验证通过；源码哈希前后固定，Android 1.984秒/iOS 2秒，真实通话录音仍待验。
    - [x] 录音时长/校验元数据及pending持久化、归档后独立multipart上传、上传失败保留同callId重试完成；22项归档/上传/controller定向与analyze通过，未真实上传。
    - [x] 停止录音日志恢复、单次finalize owner、账户文件解析及符号链接逃逸拒绝完成；9项实际文件/owner专项和analyze通过。
    - [x] 协调器异步媒体准备取消/迟到清理与单次物理停止回调完成；相关15项与analyze通过。
    - [x] 编码回执原子保存/校验复用、孤立产物基于完成PCM重建、同文件finalize串行及冲突时长拒绝完成；10项文件/owner邻接与analyze通过。
    - [x] 国内presentation控制器与共享通话页/控制接口接线，物理结束冻结/编码迟到落日志/手动DTMF及账户门禁完成；既有及国内33项、后续国内共享route4项与analyze通过。
    - [x] 应用国内factory组装安全配置冻结、权限/独占音频、积分/模型/SIP/RTP/开场/录音/控制器，录音origin以实际连接单调时钟冻结；14项准入/owner/界面及analyze通过。
    - [x] 账户录音Provider与归档启动恢复/上传接线；仅恢复停止文件、不重开电话，活动编码不抢恢复；24项专项、上传/旧Provider邻接7项及analyze通过。
    - [x] 国内Provider/正式拨号分流及模型账号设置源码接线；安全配置默认不可用、21项离线准入/邻接通过；真实调用仍待验。
- [x] 接入国内预检/通话协调器、积分与归档（源码及合成端口；真实计费/归档仍待验）。
  - [x] 原生积分HTTP五动作/标准幂等头及单会话owner、准备心跳/接通/续授权/到期停止/终态完成；owner5项、接口4项及鉴权/克隆邻接共40项通过，尚未接正式国内协调器。
  - [x] 共享归档模型/日志/HTTP区分DOMESTIC_ANDROID与WORLD_CALL，旧日志缺省保持国外、国内禁止locator混入；17项国内/共享归档定向通过。
  - [x] 国内配置/积分/模型/租约/SIP/媒体独立协调器、控制及单次结束完成，5项连续/竞态及邻接20项通过。
  - [x] Android/iOS系统UDP出口解析及同次对端地址接线、正式UDP连接适配完成；端口4项/真实全事务1项/UDP邻接3项共8项通过，Android Debug/iOS Debug无签名构建通过。实际真机网络出口待验。
  - [x] 本地录音上传及应用组装源码接线完成；实际设备编码/真实上传独立待验。
- [x] 同步模型/账号设置与正式国内入口源码，并离线关键连续流程冒烟；生产安全配置及真实通话待验。
  - [x] 原生国内模型GET/PUT、wire/engine映射与服务端确认、环境设备SIP偏好、独立账户/设备controller完成；18项定向及analyze通过，页面/Provider/入口待接。
  - [x] 国内模型与SIP账号设置页面、独立Provider、可信CN设置入口及原音导航完成；页面5项与既有设置邻接27项范围、analyze通过，正式通话入口待接。
- [ ] 核对后台/锁屏/中断恢复，完成所需平台适配和对应构建。
  - [x] 显式通话音频租约、Android microphone前台服务/通知/CPU锁/不重启、iOS audio模式/活动duplex后台门禁完成；25项PCM/owner专项、analyze与双端Debug构建通过。
  - [ ] 双端真实锁屏、电话/耳机中断和后台双向听感验收；未以构建替代设备验收。
- [x] SIP顶层Via事务匹配、INFO旧branch拒绝、原业务错误与清理未确认分离、取消等待迟到收尾完成；19项协议/请求/事务/loopback及analyze通过。
- [ ] 按明确测试授权完成双端真实语音、字幕、DTMF、挂机、结算/归档验收。
- [ ] 完成整体验收后归档，未验收保持active。

- [x] 完成归档与上传及pending删除持久确认后的账户隔离录音清理；失败不重放、链接/未知文件拒绝，19项定向通过，追加同callId跨账号保留3项复验通过。

- [x] 对端BYE核对Call-ID/双向tag与CSeq、重复身份拒绝、未知会话481且不终止当前电话；身份/事务/协议/请求/实际UDP与架构共27项通过。

- [x] 国内准入演练注入内存模型和账号偏好端口，更新旧CN海外禁用断言，定向及里程碑复验。

- [x] Digest crypto适配下移data并通过domain端口注入，保持架构禁package规则，向量/事务/UDP及架构专项通过，未放宽架构规则。

冻结a25aaa3全量3484通过/1跳过/1失败：本change受影响范围无失败，唯一旧鉴权测试10ms竞态后仅测试同步修复9项定向通过；全量不标通过，真实能力仍待验。

2026-10-09 当前任务状态校正：上述三个父级源码任务的全部子项已完成但父项仍未更新，本次根据既有实施证据及实际DomesticTranslationSessionFactory/国内录音Provider接线勾选，不新增实现或验证结果。安全模型配置默认不可用仍在mic/积分/SIP之前拒绝；真实模型服务、双向听感、DTMF/结算/归档/后台及整体验收独立未勾。用户10月8日已删除手动SIP账号设置，早期子项是追溯记录，当前以remove-manual-sip-account-settings及服务端租约账号为准，不能据旧勾选恢复手动设置。查询delta/国内binding曾误猜目录，fresh rg定位domestic-sip-translation及app/domestic_translation_session_factory，无代码/设备修改或副作用。

2026-10-09 路由生命周期跨模块里程碑完成：源码冻结c14f983f8bf54fbee18788f0ba9584d0e898ea46，全量flutter test --no-pub --reporter expanded退出0，3777通过/1跳过/0失败，7分38秒；日志/tmp/phoneagent-route-lifecycle-milestone-tests.log。唯一默认opt-in文档UI开关跳过保留（既有显式开关专项2通过不是本轮新执行，不并入3777）。期间lib/test/tool/ios/android无diff，仅文档与独立pure UI运行；source HEAD仍c14f983，analyze此前2.5秒无问题，外部pubspec.lock28条host-only差异不提交。新全量取代2eb2fcf的3706/1作为此冻结源码最新回归，不覆盖未来修改；OpenSpec39、四报告182相对文件目标存在及diff校验通过，本次未查锚点。SDK工程副本/安全配置来源已落实，真实SDK初始化/SIM/APNS/后台、模型短期配置、真实媒体/电话/结算/录音上传、Android同签名OTA/旧数据和iOS发布、三端全部状态像素与触摸手势仍待验，不归档。


2026-10-09 用户确认执行参照国内模型配置接入：见 docs/engineering/DOMESTIC_MODEL_REFERENCE_CONFIGURATION_20261009.md 和 active reference-domestic-model-configuration。固定Android默认密钥空且当前local无值，采用iOS同服务固定fallback，本地覆盖优先；豆包voice共同Nofish但protobuf不新增音色字段；SIP仍后台租约。生成工具90/专项56/.gitignore三源码微批；原生Android52/iOS37/工程脚本27三源码微批；MainActivity215/AppDelegate103二源码注册微批、PBX机械接线；Dartdata85/Provider110/专项170三源码微批，factory专项234独立微批，均500内。私有两JSON0600/ignored/untracked/non-symlink，不输出或提交值，构建只读工程副本，通道不初始化模型或电话。57项关联定向6秒通过，后新增双平台真实配置Source→factory准入2项，连同重叠12项共14项复验通过，不合计71；独立范围59项。工具3项0.065秒及既有私有写入helper4项0.165秒通过，analyze最终3.6秒无问题。首次if大括号lint修复，再foundation/services重导出Uint8List提示各按实际import收窄，最终clean。
首次Android320MB APK复制因No space left失败，读取当前产物确认仅删除本批47MB不完整复制和本批已核对320MB组装APK，改target android-arm64后15.4秒构建成功，Flutter仅arm64运行库而vendor多ABI保持；首包检查过严误要求所有JNI无x86，fresh实际清单后只校验Flutter ABI及私有资源。iOS首Target Device Version解析失败，fresh Xcode26.3/SDK26.2有限verbose重试确定manifest/attachments/log磁盘满；后新空间930Mi证据允许再验证，17.0秒无签名Debug成功。两端最终包内私有资源字节核对通过，iOS源码符号实际在Runner.debug.dylib而非70KB启动器，fresh产物恢复核对，无SDK/电话执行。原SDK51哈希/portrait通过。磁盘满曾使文档及追加test heredoc未写入；恢复空间后重做，未清理共享build/ios，前清理问题已无需执行。未安装普通App/调用供应方/真实计费或拨号，真实验收未勾；APP_ENV/API后台配置不变，旧c14全量不冒充覆盖本批。外部pubspec.lock保留，不归档，中文提交至codex/dev_zys。
