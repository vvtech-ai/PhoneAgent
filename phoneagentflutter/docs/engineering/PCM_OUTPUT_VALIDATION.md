# PCM 输出与 TTS 播放：实现与集中验收

2026-09-19，`voice-protocol-foundation` 4.3c。本批提供真实双端 PCM 输出及已有 TTS 网关的共享播放组合，不代表统一对话完整自动播报已接好。没有播放真实声音、调用线上 TTS、申请权限或安装设备包。

## 固定证据与平台边界

- Android v65 `4c781e3ccfcd148c1f205921534907ee0c5aa864`：`AgentTtsBridge`、`PcmPlaybackPolicy`、`TtsAudioAttributes`。24k PCM16 mono，TTS 走媒体/语音内容属性；保留 320ms 起始保护和 60ms 尾部填充。不是翻译 VOICE_COMMUNICATION 的通话路由。
- iOS `ddb996a28f98559ea7d8b76ca9d7712703dedbc1`：`Core/Voice/AIAssistantSpeechPlayer.m`。参考 AVAudioEngine/Float32 转换与 playback 音频会话，不移植原生分句、网络、队列业务。
- Android 使用非阻塞写与播放头确认，不把写入返回当实际播放；参见 [AudioTrack 官方 API](https://developer.android.com/reference/android/media/AudioTrack)。iOS 使用明确的 `dataPlayedBack` 回调而非旧代码默认 completion；参见 [AVAudioPlayerNode 官方 API](https://developer.apple.com/documentation/avfaudio/avaudioplayernode)。取消也可能触发回调，必须先作废所属 output。

| 实现位置 | 核心行为 |
|---|---|
| `core/audio/pcm_output.dart` | 纯 Dart 单次 start/play/stop；play 完成表示实际消费，stop 等待真实释放 |
| `core/audio/pcm_playback_queue.dart` | 复用 PlaybackLedger；200ms 分块、最多2秒原生在途、默认16MiB有界待播；complete→draining→实际消费并释放后drained |
| `core/audio/focused_pcm_output.dart` | 共用全局音频占用，可被录音抢占；不能抢受保护采集，停止失败保留占用 |
| `conversation/data/voice/device_pcm_output.dart` | outputId隔离、大小/格式/平台检查、方法通道薄包装、清洗错误、显式重试停止 |
| Android `PcmOutputChannel.kt` | 单工作线程队列，AudioTrack非阻塞写、播放头确认/回绕、5秒无进展失败；音频焦点丢失或离开前台停止，无自动恢复 |
| iOS `PcmOutputChannel.swift` | PCM16转Float32/AVAudioEngine、dataPlayedBack确认、有界队列/5秒未确认失败；后台/中断/旧路由移除停止，恢复原会话配置 |
| `conversation/data/voice/task_tts_playback.dart` | 组合TaskTtsSession与输出；首音后才占设备，start guard/尾块、complete与排空分离、取消与错误传播 |
| `app/tts_playback_providers.dart` | 生产工厂装配既有全局占用及真实端口；调用方仍负责文本策略、音色、endpoint和会话生命周期 |

没有新依赖或权限。`play`可有多个有界在途请求，原生播放器保持同一实例，避免逐块重建；队列达上限明确失败，不悄悄丢音频。源码有平台消费证据，但真正可听到的尾音/延迟/路由仍需设备验收。

## 时序与取消

1. 网关 ready 后才 synthesize。收到首音才申请音频占用、启动输出、提交 PCM。
2. 服务端 complete 只关闭输入并补尾块。页面保持等待设备播完，不用服务端完成代替实际消费。
3. 原生逐块确认后消减 PlaybackLedger；全部消费后停止输出，实际释放确认后才返回 drained。
4. 主动取消先同步作废播放，再并行取消网关订阅/连接及设备。新录音等待旧 TTS 设备释放；取消触发的旧 play 失败不能覆盖 cancelled。
5. 播放/关闭失败不伪装 drained；真实停止未确认前保留全局占用，显式 stop 可重试。迟到传输失败不能自动重试清理。
6. outputId不复用；旧ID停止不得停止新播放器。Web正式端口明确不可用，测试/演练才注入合成端口。

## 自动及浏览器证据

专项覆盖设备方法通道5项、占用4项、队列7项、TTS组合6项、新增演练失败/取消1项，共23项新增；另扩充原3个手机宽度页面回归。专项27项通过，覆盖320/390/430宽度、实际排空、原生在途上限、样本顺序、权限无关平台拒绝、取消时序、失败/占用及晚到。

本轮浏览器 `http://127.0.0.1:8112/`，沿用 `tool/previews/voice_transport_preview.dart` 与开发者“语音网关链路演练”入口，不新建产品页面。MOCK只替换socket、采集和输出设备，复用正式编排。

- 点击“演练 TTS 预缓冲与尾块”：网关音频24000+2字节，设备待播42242（含15360保护+2880尾部），合成已完成但音频仍占用。
- 点击“模拟设备实际播完”：待播0、设备已播完并释放。
- 重开后“取消 TTS 播放”：已取消、0字节、已释放。
- 重开后“模拟设备播放失败”：失败、已释放，不假报正常结束。
- TTS待播时新建ASR并注入ready：TTS取消，占用交给采集；再取消ASR后全部释放。

首轮回归暴露主动抢占与原生失败回调竞争，已改为先同步作废播放，再并行收尾；方法通道fixture错误返回Future对象及关闭后的fake写入也已修正，未放宽生产断言。

最终全量1885项测试、analyze、877文件格式、19项OpenSpec及diff检查通过。Web构建成功（既有Cupertino字体提示仍需视觉阶段核对）；Android Debug两次构建成功；Mac iOS Debug无签名两次构建成功，最后Xcode18.3秒。未将构建成功视为真机声音或正式签名验收。

## 待完成的正式接线

4.3父任务仍未完成。后续4.3d已接普通回复delta/signal/flush分句、Markdown、固定音色、状态与手势打断，见[REPLY_SPEECH_VALIDATION.md](REPLY_SPEECH_VALIDATION.md)；通话结果持久事件播报、回退策略和双端真实设备仍待完成，不能以此宣称整个语音上线。

AppAudio仍需通信音源/双工会话策略与merchant_audio_ready门禁；本输出端口当前为TTS媒体属性，不能不加区分地用于国外翻译并声称回声处理完成。单路监听同样仍有独立接线工作。

## 集中人工验收（正式接线并获准安装后）

| 场景 | 操作 | 预期与失败证据 |
|---|---|---|
| 短句/尾音 | 播放只有短尾块的短句及常规长句 | 无截字；服务端complete时若仍有PCM应保持播放；记录平台/时刻/阶段，不记正文 |
| 流式连续性 | 不同块大小、网络快慢及连续多句 | 顺序一致，无每块播放器重建的断续；实际设备首音/尾音延迟须测量 |
| 手势打断 | 播报时按下说话、退出与恢复任务 | 旧声音立即停止，旧回调不复活，资源释放后才开新采集；4.3d已接普通回复。切键盘仅切输入控件，不静音，按后续固定源码核对纠正 |
| 音量/路由 | 调媒体音量、耳机/蓝牙切换/拔出 | TTS使用媒体音量，不改通话音量；检查实际声音及平台路由差异，当前不声称耳机全部情形通过 |
| 生命周期 | 前后台、系统来电/音频抢占 | 停止、不自动重播；设备状态恢复后新请求可播放 |
| 跨模块占用 | 历史录音→TTS→ASR；克隆/翻译采集中尝试TTS | 原播放停后交接；受保护采集不被抢占；没有并行声音或假空闲 |
| 失败与释放 | 输出错误/超时/关闭失败后重试 | 失败可见；释放未确认前保持占用，重试只清理本ID，不关闭新会话 |

本次未安装真机，既有设备安装授权门禁不变；8080原登录与Mac保留解锁会话未改。编译、合成设备与浏览器验证都不能代替上述真实声音验收。
