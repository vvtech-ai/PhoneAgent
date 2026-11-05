# 普通 Agent 首声诊断验证

## 源码与问题边界

- `900b64cc` 对 `921385e8` 的差异未修改公共 speech/TTS/PCM 实现；Java `9a56cdf0b` 的代次回传修复未新增等待。不能认定该合并导致近期变慢。
- 800 ms 空闲计时、24,000 字节预缓冲、320 ms 前置静音在 9 月已存在，本变更全部保留。
- 旧上传日志缺少普通正文观测和入队时点。新增 `textObserved` 为 controller 实际接收首个非空普通 text 的时间，非 UI 首帧；到首个可播普通句子入队才补记到实际 TTS trace。
- `sentenceEnqueued.elapsedMs` 使用 `Stopwatch`，不依赖系统时间差。事件时间应按 trace 分析，补记顺序不等于原始发生顺序。
- 只收到 signal/finalResponse 而没有普通 text delta 的路径沿用既有诊断，不虚构首字观测。若同一播放 trace 更早已经播过 signal，该 trace 的首个 connect/receive 可能在普通正文之前，不能机械相减当成该正文耗时。
- `pcmOutput.play` 是首段 PCM 消耗完成，可能仍为前置静音；本变更没有记录真人听到的首声。需新现场日志/录屏与服务端阶段联查才能定位，未宣称加速。

## 定向测试

- RED：仅加入可编译的可选诊断参数，记录行为尚未接线。`speech_start_diagnostics_test.dart` 两项因期望首字/首句阶段而实际空列表失败；空 Markdown 与诊断失败既有行为一项通过。
- GREEN：新增文件最终 5 项通过，覆盖真实 controller/TTS/PCM trace 与顺序、真实 ConversationController 的跨轮迟到隔离和历史恢复静默、首字原始时间/单调耗时、同轮一次、取消/禁用/空文本、诊断 sink 与 observer 抛错不影响合成。
- 相邻 4 文件共 28 项通过：`conversation_speech_controller_test.dart`、`conversation_speech_integration_test.dart`、`conversation_tts_stream_test.dart`、`speech_pause_controller_test.dart`。其中已有 800 ms 重置分句、finalResponse 顺序、连接复用及暂停回放保持通过。
- 新增跨轮测试最初用尚未产生音频的半句调用输入打断，不满足现有“正在播放才取消流”前提，组合测试因此有 1 项 fixture 失败；改用已入队普通句子触发真实打断，再跑新增文件 5 项全部通过。未改生产打断行为迁就测试。
- 命令使用固定 Flutter 3.32.0、`test --no-pub --reporter expanded`；未运行构建、发布或真实接口。
- `openspec validate diagnose-agent-speech-start-latency --strict` 通过；本变更 `git diff --check` 通过，中文 UTF-8 读回正常。同轮录音卡协作者在本变更源码冻结后统一执行 `flutter analyze --no-pub`，回传 No issues（34.2 秒）。
- 主会话整合后独立复验：新增诊断、四份相邻语音测试及两份录音卡测试合计 7 文件 50 项通过；全工程 analyze 无问题（19.7 秒）。

## 待现场验证

合入新包后采集普通文本分段回复，按同一 trace 对齐首字、首句入队、连接、发送、第一包及 PCM 阶段；必要时同设备/网络/模型比较两个版本。没有新现场证据前不归因、不调整历史等待参数。
