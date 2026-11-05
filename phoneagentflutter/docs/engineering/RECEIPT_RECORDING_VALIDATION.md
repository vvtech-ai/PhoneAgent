# 普通回执录音：交互先行与真实接入边界

最新追加（2026-09-18，2.10b2c）：普通/翻译录音与克隆试听已共用进程级异步音频占用，停止后切换、失败保留、账号/晚到隔离及底层释放重试；25新增/1757全量、三端构建和8108浏览器通过。详见[AUDIO_FOCUS_VALIDATION.md](AUDIO_FOCUS_VALIDATION.md)。SDK/ASR/TTS/监听/实时翻译接入及双端声音仍待完成，下方旧“未完成跨模块媒体”以本追加范围更新，不标整体完成。

2026-09-18，最新为 `task-result-details 2.10b2a`：普通录音正式页面装配及真实保存端口已实现，尚未完成跨模块媒体仲裁和双端真实验收。以下按批次保留的早期记录仅供追溯，以最新章节为准，不代表整体迁移完成。

## 2.10b2a 正式宿主、保存和交互演练

- `lib/app/call_recording_providers.dart` 按登录代次及会话宿主创建真实端口；`ConversationRecordingHost` 已由正式 `ConversationRoute` 装配。Web不构造真实录音端口，显示明确能力提示；独立演练使用合成端口，不能向正式账号写入数据。
- `ConversationRecordingsController` 在会话级持有每个callId的播放、metadata和保存控制器：列表项离屏仅停止观察，不销毁正在播放的控制器；宿主退出/账号替换关闭全部端口。退后台、进入单路通话覆盖页、文字切回语音停止录音，恢复前台不自动播放。
- `SaveCallRecording` 与播放状态独立。Android先创建系统目标，再取当前call的新play-token、下载、写入；选择取消不取源。iOS先下载私有文件，再走已有export-as-copy。保存失败不会停止本来正在播放的录音。
- `CallRecordingFileDownload` 使用独立无账号头的Dio，只接受配置API上下文的同源令牌路径、不跟随重定向、流式下载、90秒超时和512MiB资源保护。校验可选服务端size和HTTP长度、非空与音频类型；本地计算SHA256供原生复制时核验，**不是服务端真实性摘要**。仅删除本次拥有的私有临时文件，不复用翻译录音的Range缓存。
- Android新增薄 `RecordingDestinationChannel`，只管理本次CreateDocument目标、校验私有源和流式复制。失败/取消尝试删除本次目标，不申请广泛存储权限；系统提供者拒绝删除、进程被杀时残留和权限实际行为仍需真机验收。iOS不新增原生实现，复用已存在的录音导出通道。
- 保存完成但临时清理失败单独提示清理未完成，不伪报导出失败诱导重复保存。取消/账号更换/关闭后的晚到结果不能更新旧UI。
- `preview_call_recording_session.dart` 现在共用正式会话管理器和保存用例，修正了早期演练先加载后选位置的差异。8097预览始终标识MOCK，无真实声音/文件；浏览器验证选择弹窗→取消无成功提示→重新选择→模拟保存成功。

验证：新增24项（保存9、流式下载5、平台适配4、正式宿主6），全量1,482项通过；analyze、664文件格式检查、19项OpenSpec、Web/Android Debug及Mac iOS无签名构建通过。iOS本批验证共享Dart更新，原生导出文件未改；未签名、安装或触发真实录音。Web仍有已有可选Cupertino字体构建提示，不声称视觉校准完成。

人工集中验收需在授权后执行：

1. Android选位置取消时不得出现play-token/内容下载；确认后只下载当前call。iOS取消导出不提示成功；两端成功文件能回放、文件名正确。
2. 播放期间保存取消/下载失败不打断原播放；选目标导致App失焦时按宿主规则停止播放，但保存流程应能继续。
3. 断网、零字节、错误长度、磁盘满、系统提供者写失败应显示可重试错误；检查本次目标和私有临时文件清理，不删除他人文件。
4. 列表离屏返回、后台/前台、关页、换账号和进入通话页，检查无旧播放重启、旧进度或旧保存结果污染。
5. 跨TTS/翻译/克隆/实际通话的统一媒体仲裁仍属2.10b2b，不能用普通回执间互斥证明全局无叠音。本批未读取真实录音、不发短信、不改现有登录、不安装设备包。

## 2.10b1 历史实现与边界（由上节覆盖装配和保存待办）

| 实现位置（lib/features 下） | 责任与证据 |
|---|---|
| conversation/data/api_call_recording_repository.dart | 账号绑定metadata GET与按点击POST play-token；保留API上下文，只接受同源固定令牌路径。原始URL、身份和错误正文不进入UI；close不关闭其他模块共享的AccountApi |
| conversation/domain/call_recording.dart | 普通录音状态、时长、可选大小；不把是否READY变成新增播放门禁 |
| conversation/presentation/controller/call_recording_metadata_observer.dart | 每2秒、最长60秒处理状态观察；失败保持已读元数据，停止/换账号/晚到不覆盖。正式宿主须按前台及可见性调用start/stop |
| conversation/domain/recording_playback_arbiter.dart | 新播放请求作废旧请求；串行等待之前的停止操作，包括快速A→B→C和重复点击；停止失败不准入下一个播放器 |
| conversation/presentation/controller/call_recording_playback_controller.dart | 普通播放策略复用RecordingAudioController和同一播放器端口；暂停续播不换源，结束后显式重播取新源；生产宿主将持有控制器，不应让懒列表销毁活跃播放器 |
| translation_history/domain/recording_audio.dart、data/plugin_recording_player.dart | 明确远程源与本地资产类型；远程源走现有audioplayers UrlSource且不附加账号头，本地仍走DeviceFileSource。远程源不能伪装成本地已校验文件导出 |

固定v65后端 `AgentCallRecordingController.PlaybackView` 含 **可选sizeBytes/expiresAt**，安卓DTO只消费url/contentType。纠正早期“普通接口无size”的表述；它仍没有服务端SHA256/cacheKey，不可假造。AccountIdentityService沿现有X-Account-Id契约，不增加重新登录。返回相对`/api/...`时保留配置中的`/aiassistant-api/`，拒绝外部主机、跨上下文、异常字段和已过期令牌。原生URL播放器的重定向由插件控制，本批不声称Dart禁止了原生HTTP重定向。

共享控制器显式区分播放与保存操作版本：普通播放中断不让已开始的独立本地导出永久卡住；新的播放错误仍作废旧保存UI回调。全量测试曾捕获旧保存成功覆盖新错误，已保留原测试修正。默认翻译预加载、本地缓存与摘要契约不改变。

隔离演练已接同一普通互斥核心，最新预览为 `http://127.0.0.1:8097/`，合成音频仍无真实声音；切换另一条录音停止旧项，回到语音模式/应用非前台停止演练播放。演练卡仍由列表子树拥有，只证明交互和互斥，不代替生产宿主的离屏保活。普通真实Repository当前仅有合成协议测试，**ConversationRoute尚未注入普通录音生产provider**，不能把本节称为普通录音可生产使用。

保存仍使用显式MOCK：它的先加载再选择次序尚未替换，不能用远程资产直接调用翻译本地导出器。2.10b2须接Android先选择目标再申请新token/下载/写入，iOS系统export-as-copy，并单独处理本次目标取消/失败清理；全局TTS/翻译/克隆媒体仲裁和双端真机仍未完成。

本批验证：新增34项（协议9、观察6、播放15、三宽度控件3、远程播放器1），全量1,458项通过；analyze、648文件格式、19项OpenSpec和Web/Android Debug构建通过。浏览器8097完成旧项→新项互斥与切回语音停止，最终代码刷新后再次复核互斥。没有真实录音、账号写入、短信或安装；本批无新iOS构建/真机验证。Web仍有已有可选Cupertino字体提示，不把构建通过写成视觉验收。

## 查看入口

正式 App 的设置 → 开发者功能 → 隔离交互演练 → 统一对话回执演练；独立启动入口为 `tool/previews/receipt_recording_preview.dart`。Web 本批在 `127.0.0.1:8096` 验证。页面持续显示 MOCK，无服务、电话、费用、声音或文件操作。

- 单路回执：转写 → 完整录音卡 → 结果/计费。播放、暂停、剩余时间、结束再播放、失败重试；保存弹窗只有模拟确认/取消。合成失败联系人第一次加载失败，手动重试后可播放。
- 批量回执：每项只显示紧凑播放/暂停/重试，不增加完整录音卡或保存按钮；合成乙最后接通时长为0，因此没有录音按钮。转写展开/收起仍独立。
- 初始不加载文件。第一次播放显式加载再播放；保存先加载但不播放。12秒进度只验证控件状态。翻译录音默认预加载但不自动播放的既有行为未改变。
- 生产回执的纯展示组件已经提供builder插槽，但本批不向其注入MOCK、不新增真实录音请求。演练并非正式能力已上线。

## 固定 v65 证据与差异

依据 `4c781e3ccfcd148c1f205921534907ee0c5aa864`：

| 证据 | 必须保持的行为 |
|---|---|
| PureVoiceThreadList / CallRecordingContract | 单路需可见转写和 result.metadata.callId，不用taskId/attemptId冒充；完整录音卡位于结果前 |
| BatchPlusCallResultItem.batchPlusRecordingCallId | 使用item.callId；存在最后结算时connectedDurationMs须大于0，无结算时保留已有callId；不能用displayDurationSeconds或较早结算推导 |
| CallRecordingViewModel | metadata是独立读取/处理状态轮询；播放源按点击获取，错误可手动刷新重试；宿主停止和播放互斥需单独接入 |
| CallRecordingApi / Repository / AgentCallRecordingController | GET api/agent-calls/{callId}/recording；POST对应recording/play-token。安卓DTO消费url/contentType，后端另有可选sizeBytes/expiresAt；没有翻译录音的hash/cacheKey |
| CallRecordingSaveUseCase | 选择目标后重新获取播放源并保存；失败清本次目标，不把取消当成功 |

`ReceiptBilling`新增connectedDurationMillis与显示秒数分离。普通与翻译共用RecordingAudioState/Controller、完整卡、端口抽象；通过可选loadOnAction保持两类加载时机。批量紧凑控件纯展示，不读网络/Repository/平台；明确MOCK装配由PreviewCallRecording提供。

本批合成保存共用“先取得资产再选择目标”的演练流程，并非普通v65“先选择目标后取源”的正式协议实现。真实保存应在2.10b按上表接入，不能照搬演练次序或声称后端提供了SHA256。

## 自动与浏览器验证

- 新增19项：6领域规则、7按需控制器、6控件测试。覆盖metadata锚点、缺转写、最后结算、无结算、首次点击/暂停续播/失败重试、单飞、账号切换/关闭晚到、保存取消，以及320/390/430宽度。
- 全量1,424项、analyze、635文件格式检查、19项OpenSpec通过；Web/Android Debug测试环境构建通过，API保留`/aiassistant-api/`。本批无新iOS构建或双端设备安装，不引用旧构建冒充本批验证。
- 浏览器验证合成批量点击→加载→播放/暂停、单路保存选择→取消；没有真实下载、声音、系统文件或账号操作。视觉仅复用已有组件，未做像素评分。
- 旧连续导航测试因回执变长，新消息在滚动区域外；把消息断言移到既有“回到最新消息”步骤之后，保留发送、返回、再进入清空的完整断言。

## 尚未完成与集中验收

2.10b1已补普通metadata/play-token、受信初始播放源、有界观察和普通回执间互斥核心；2.10b2继续负责真实保存、正式provider/宿主装配、跨TTS/通话/克隆媒体互斥与双端设备验证。演练已共用普通互斥控制器，但不证明真实声音、平台焦点或生产宿主正确。

真实接入完成后再统一检查：

1. 打开单路/批量历史只读取允许的元数据，不自动播放或下载整段；无接通项目不显示入口；两个attempt不混用callId。
2. 点击后申请当前call播放源，令牌失效仅显式重试；保存取消无成功提示，下载失败清本次输出，不删除其他文件。
3. 同页第二段录音、TTS、翻译、克隆试听及实际通话不能相互叠音；退后台/退出/换账号停止旧播放与晚到结果。
4. Android/iOS权限、扬声器/耳机、系统选择器、导出文件回放及安全区集中验收；不把本批MOCK和编译成功当作通过。

无需为本批重新登录、发短信、读取真实录音或操作现有手机。
