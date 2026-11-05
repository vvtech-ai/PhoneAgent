# PCM 采集端口与 ASR 编排：实现及集中验收

日期：2026-09-18。新增双端真实采集代码与共享编排，**统一对话页仍未装配语句提交/TTS，不能把本批视为按住说话已交付**。没有实际采集声音、申请权限、连接线上语音、重新登录或安装真机包。

后续输入接线与纠偏：正式统一页输入已装配并在Web合成验证，见[VOICE_INPUT_VALIDATION.md](VOICE_INPUT_VALIDATION.md)。本文原批次的“松手立即停PCM”实际指底层release/stop；正式手势松手沿v65继续最多2秒收尾。旧批次构建/演练证据不变，不能作为正式手势或TTS/设备验收证据。

## 来源与边界

- Android 固定 v65 `4c781e3` 的 `QwenTaskAsrSocketClient.kt`：16k PCM16 mono、640 字节帧，VOICE_RECOGNITION 优先、MIC 回退，可用 AEC/NS，不启用 AGC。
- iOS 固定 `ddb996a` 的 `App/AIMainTabBarController.m` 中 AITranslationCallAudioSocketClient（约 1609–1729 行）：AVAudioEngine tap 与 AVAudioConverter 的 16k PCM16 mono 转换。只借鉴硬件转换，不复制页面/网络架构或其日志正文。iOS 本批转换路径不等于验证了供应商 SpeechEngine 的识别表现。
- ASR/TTS 协议继续见 [VOICE_TRANSPORT_VALIDATION.md](VOICE_TRANSPORT_VALIDATION.md)。租约复用进程级 AudioPlaybackFocus，不另建生产音频所有权系统。

## 数据流与核心方法

| 层 / 文件 | 方法与职责 |
| --- | --- |
| `core/audio/pcm_capture.dart` | 单次 start/read/stop 契约；PCM16 小端、16k、mono、最多 640 字节；null 表示采集已停 |
| `conversation/data/voice/device_pcm_capture.dart` | 方法通道 `phone_agent/pcm_capture`，每实例独立 captureId；单次在途 read，停止后丢弃晚到数据，停止失败允许重试；Web 明确不可用 |
| `core/audio/focused_pcm_capture.dart` | start 等待旧播放实际停止，持有不可被播放/SDK抢占的租约；stop 等待硬件确认后才释放；账号/宿主 stopAll 可终止，失败不假报空闲 |
| `conversation/data/voice/asr_capture_session.dart` | start 只连网关；ready → 受保护采集 start → 顺序 read/sendPcm；release 先关上行并发 stop_capture，再停止硬件；cancel 作废结果、关闭网关并清理 |
| Android `PcmCaptureChannel.kt` / MainActivity | AudioRecord 与效果器，只检查已有权限；单工作队列非阻塞读取、每次最多 640 字节、最多等待 5 秒；onPause/引擎清理停止，无自动重启 |
| iOS `PcmCaptureChannel.swift` / AppDelegate | AVAudioEngine/Converter、加锁有界 32000 字节缓冲；不足 640 可返回短帧，溢出明确失败；前台丢失/中断/设备移除停止；停止后恢复此前 session 配置，恢复失败保留释放失败状态 |

共享 AsrCaptureSession 的 VoiceReady 在采集端口 start 成功后才发布，不把网关 ready 当麦克风已开启。松手后 PCM 不再发出，但网关原有一次非空 late final 继续有效。取消与原生中断不重录，不重连，不提交旧文本。

方法通道返回 stop 成功表示端口已经完成释放；不是任意延时后猜测成功。并发 stop 共用同一个清理 Future，失败允许显式重试。旧 captureId 的 stop 不会影响新原生采集。原生层不读账号、不持久化 PCM、不生成业务消息。

**未覆盖的性能边界**：Dart 拉取有界不等于操作系统/网关内部队列已经验证。Android AudioRecord 自身环形缓冲、慢消费/丢帧、iOS 转换延迟和蓝牙采样变化需要真实设备测量；socket.send 仍只表示本地排队。没有声称本批解决端到端弱网背压或实现无损录音。

## 自动验证与 Web

- 新增 22 项：设备适配 9、共享占用 6、采集/ASR 组合 7；已有三宽页面与并发启动 4 项继续通过，专项合计 26。
- 全量 1819 项测试通过，flutter analyze 无问题，841 个 Dart 文件格式检查无改动；Web、Android Debug、Mac iOS Debug 无签名构建通过。
- Web 沿用 8109 演练及开发者入口，共用 AsrCaptureSession、FocusedPcmCapture、AudioPlaybackFocus、TaskAsrSession；只有采集源与 socket 使用内存合成端口，不调用真实设备或账号。
- 浏览器验证 ready 前 0 → ready 后 640 字节 → 松手后再发仍累计 640 → late final → 取消显示释放；TTS 24000+2 尾块回归通过。320/390/430 宽度 Widget 连续操作通过。页面明确 MOCK，不是硬件验收报告。
- 首轮测试暴露方法通道测试桩未等待 Future、取消后无效异步边界，以及设备适配误入纯策略目录；已修正并重跑全量。保留架构检查，设备适配移到 data 层。没有遗留临时诊断输出。

## 后续集中人工验收（均未执行）

前提：完成生产统一页装配，恢复允许的阶段真机安装流程，使用既有登录与明确麦克风授权。当前正式页面仍有未接入提示，不能要求用户现在执行下列完整流程。

| 操作 | 预期 / 必查项 |
| --- | --- |
| 未授权时按住，再拒绝/允许 | 权限由上层显式流程处理；端口不自行弹框；拒绝不开始录音、不伪造文本 |
| 按住普通中文/英日语，松手 | PCM16/16k/mono 到网关；松手麦克风指示器消失；late final 归属本轮；实际文本提交策略按 v65 |
| 极短按、ready 前松手、连续两轮 | 未 ready 不采集；旧成功/PCM/文本不能串到新轮；无并发硬件占用 |
| 录音中切文字/退出/换账号 | 共享编排取消，后台不继续采集；新账号不能接收旧数据；不隐式挂断后台电话 |
| SDK 身份采集中尝试语音；录音中点试听 | 受保护占用不被抢走；失败明确，不出现双重录音/播放或假空闲 |
| Home、锁屏、系统来电、拔耳机、蓝牙切换 | 原生停止、共享清理；回前台不自动重录；检查实际指示器与声音路由 |
| 慢网络/慢消费、原生启动/读取/停止故障 | 明确失败、不无限重试；释放失败期间保持占用，恢复后显式清理可重试 |

证据只记录平台/系统版本、操作时间、关联的本地轮次及安全错误分类；不保存声音、转写原文、手机号或网关凭据。集中验收之后再补设备证据，不用编译或 MOCK 结果替代。

## 仍须完成

生产 provider/统一页按住与取消、权限流程、ASR 分段拼接和提交、TTS PCM 输出及实际 drain、音色/文字清理；单路监听/实时翻译；Android 旧数据升级与双端阶段安装。视觉按批准统一后校准。OpenSpec 只完成 4.3a，4.3 整体保持未完成。
