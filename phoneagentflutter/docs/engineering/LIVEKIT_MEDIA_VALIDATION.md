# 国外翻译 LiveKit 共享媒体适配

2026-09-20增量：既有演练现支持AppAudio回退共享协议与同页交互，详见[AppAudio回退验证](APPAUDIO_TRANSLATION_VALIDATION.md)。原生双工和正式工厂仍在制，不将本页历史待办误读为全部已完成。

2026-09-19，`overseas-translation-ui` 2.2c。本批补真实 SDK 适配及协议驱动交互，不代表国外翻译整体完成。视觉按用户批准后续统一校准。

## 实现与边界

固定 v65 提交 `4c781e3ccfcd148c1f205921534907ee0c5aa864` 的 `BackendLiveKitAudioClient`、`BackendLiveKitReadyProtocol`、`BackendLiveKitStartupCoordinator`、`BackendTranslationCallRuntimeSession` 为行为依据。优先共用 Flutter，未复制两套原生业务。

| 文件/类 | 核心方法 | 职责 |
|---|---|---|
| domain/TranslationLiveKitRoom | connect、microphone、speaker、publish、close | 纯 Dart 房间端口，close 必须实际等待资源释放 |
| data/SdkTranslationLiveKitRoom | _run、_release | Flutter LiveKit SDK 薄包装，音频专用、串行控制、可靠 control topic、Android/iOS 限制 |
| data/LiveKitTranslationMedia | connect、_startRoom、_event、_control、close | 双 ready、当前 session/topic、只读权限检查、音频租约、取消及晚到隔离 |
| app/translation_media_providers | liveKitTranslationFactoryProvider | 注入进程级音频管理、现有权限源及账号生命周期判断 |
| data/PreviewLiveKitTranslation | create、factory、subtitle、hangup | 合成服务/房间/权限，共用上述正式媒体适配和既有会话控制器/页面 |

依赖固定 `livekit_client: 2.4.6`，保持 Flutter 3.32 / Dart 3.8，不使用 dependency_override。SDK 自带的 WebRTC 处理原生媒体；应用仅新增 Android 普通权限声明 `MODIFY_AUDIO_SETTINGS`，不启用摄像头。本批不请求系统权限、不采集声音。

生产拨号按钮尚未装配该工厂，继续明确提示链路未接入。AppAudio PCM 输出/回退、生产预检查/权限顺序、Finished 本机记录/钱包刷新仍是父任务缺口，不能用本端口完成替代完整功能。

后续 AppAudio 的固定源码检查：`BackendAppAudioSocket` 连接附加 `downlinkAudio=binary`，先发 java-v1 start；`app_audio_ready` 放行商户呼叫，而 `merchant_audio_ready` 才启动 PCM 采集，不得照抄 LiveKit 的开麦时机。上行为 16k/mono/PCM16 的 640 字节帧，静音丢弃上行，输出按服务器 sampleRate 且去重非负 sequence。现有 ASR 原生采集使用 VOICE_RECOGNITION/measurement，而参考双工翻译使用 VOICE_COMMUNICATION；复用时须明确会话配置和输出端口，不能只把两个流拼接起来宣称已支持回声处理。

## 顺序与失败契约

1. 只读检查已授权麦克风，获取不可抢占音频租约；已有播放先实际停止，其他受保护采集占用时拒绝。
2. 先订阅事件，再连接 room → 听筒默认 → 开麦克风 → 可靠发送 `web_client_ready`。
3. 房间/麦克风完成并收到当前 session 的 `realtime_ready` 才返回 ready；上层才可请求 merchant-call。`worker_ready`、其他 topic/session 不放行；沿 v65 兼容空 topic/session。
4. 接通/字幕/结束仍由共享会话协调器处理，不把 HTTP started 当接通。静音、扬声器成功后才更新 UI；DTMF 使用自有 `dtmf_digit`，不是 SDK SIP 命令。
5. close 作废结果，等待在途 SDK 操作和真实 room 释放，之后才归还租约。清理失败保留占用，不并行回退采集。SDK dispose 若抛错后已标 disposed，不能凭第二次空操作声称释放；本批保守阻止复用，需实际设备排查，可能需重启应用。
6. 真断开走失败；暂时 Reconnecting/Reconnected 沿 v65 不推进业务终态。不新增无限重连、外呼或挂断重试。自己产生的错误不包含票据/原始消息；未声称第三方 SDK 的所有日志已经脱敏，不应开启详细 SDK 日志采集真实会话内容。

采集时机遵循 v65：用户发起且已授权的通话准备阶段即开麦，不是对方接通后才开麦。历史会话验收文档原“接通前无采集”表述已纠正；本次 MOCK 不触发这项真实采集。

浏览器发现共享 View 原默认扬声器开启与 v65 的听筒默认不符，已统一 false；控制失败保留听筒、成功才切换，三宽度语义断言覆盖。

## 自动与浏览器证据

- 新增 21 项：媒体状态/资源 17 项、共享页面 4 项；覆盖双 ready 两种先后、超时、错误 topic/session、权限晚到/拒绝、保护占用、连接/开麦期间取消、关闭失败、控制失败、断线和 1MiB 消息上限。
- 三宽度为 320×568、390×844、430×844。默认音源修正后整个 translation 目录 172 项通过；全量与三端构建最终结果见下方批次记录。
- `tool/previews/livekit_translation_preview.dart`，本次本机 `http://127.0.0.1:8111/`；也可从“翻译共享会话演练”进入“LiveKit真实适配双就绪演练”。这是隔离 MOCK，不访问真实服务、账号、麦克风或电话号码。
- 浏览器完成双 ready → 振铃 → 模拟接通/双语 → 静音/扬声器/DTMF → 挂断返回。结果 `merchant 1 / hangup 1`、音频占用已释放，顺序含 `speaker:false → microphone:true → web_client_ready → merchant-call → microphone:false → speaker:true → dtmf_digit → room.close → hangup`。
- 浏览器另观察到真实准备超时边界：未及时注入 ready 时返回失败，`merchant 0 / hangup 1` 且占用释放。没有为自动点击放宽生产超时。
- 首轮 fake-clock 用例因完成 Future 跨 zone 阻塞，已将合成端口取消 Future 限定在调用 zone 并在 fake zone 内构建时钟对象，不跳过断言、不延长生产超时。

## 集中人工验收（生产装配完成并获准安装后）

| 场景 | 操作/预期 | 实现边界与排查信号 |
|---|---|---|
| 授权与创建 | 拒绝麦克风不得进入媒体；授权后严格 create/双 ready/merchant | 本适配只读已授权；权限申请由后续生产准备流程负责 |
| 双端音源 | 默认听筒，扬声器开/关；耳机/蓝牙插拔 | 检查实际出声而不只看按钮；由 Flutter SDK 路由，系统差异须实测 |
| 录音与翻译 | 双向说话、静音/解除、字幕两种顺序、DTMF | 合成事件不证明真实声音/后端 DTMF 收到，需授权测试号码 |
| 就绪失败 | 服务不 ready、连接失败、准备中取消 | 无 merchant；旧 room 关闭后才允许 AppAudio 回退；AppAudio 尚待实现 |
| 生命周期 | 连接/开麦/控制时退出、切账号、后台/来电中断 | 无晚到复活，结束后麦克风指示器消失；本批 SDK 原生中断行为尚未实测 |
| 资源与结束 | 录音播放→翻译、克隆采集时翻译、远端结束 | 保护占用不抢占；close 完成后其他媒体才能启动，无残留漏音 |
| 记录/计费 | 挂断后记录、字幕/录音授权、钱包刷新 | 仍属后续装配，不凭模拟 hangup 当归档/结算完成 |

失败证据只记录阶段、清理是否完成及脱敏关联 ID，不记录 token、身份证、真实号码或音频正文。本批没有设备安装，已有安装授权门禁未被绕过；8080 登录及 Mac 保留会话不变。

## 构建记录

全量 1862 项、analyze、865 个 Dart 文件格式、OpenSpec 19 项和 Web 构建通过。Web 既有 Cupertino 字体树摇警告保留，不等同图标视觉验收。

Android 初次因缺少 WebRTC 插件使用的 `platforms;android-31` 失败，通过官方 sdkmanager 补齐后构建成功。新插件第一次 Kotlin 增量缓存遇到 C/E 跨盘路径异常，编译器自动回退后成功；随后再次构建 9.2 秒成功，无此错误。APK 核对为 `com.vvtech.aiassistant.dev`、minSdk 26/targetSdk 35、V2 签名通过；SDK 31 仅为插件编译依赖，没有把 App 目标版本改为 31。未安装设备。

Mac iOS Debug 无签名构建通过：首次 CocoaPods 安装含 WebRTC 下载耗时 1710.8 秒，Xcode 编译 55.4 秒，生成 Runner.app。构建前已在 CocoaPods 阶段同步最终 lib，构建后核对关键文件 SHA-256 与 Windows 一致，Bundle ID 为 `com.chaken.phoneagent.test`。回收生成的 `ios/Podfile.lock`，固定 WebRTC-SDK 125.6422.07；未签名、未安装、不等同真机媒体验收。2.2c 自动验证子项完成，2.2/2.3 父项仍未完成。
