# 需求语音后端回退：实现与集中验收

日期：2026-09-20。共享代码已接线并通过合成/回环/页面验证；未实际录音或请求线上识别服务，不代表双端声音验收。

## 来源与纠偏

Android固定v65 `4c781e3ccfcd148c1f205921534907ee0c5aa864`：

- `VoiceTaskAsrEventHandler.handleError/handleClosed`：错误触发一次备用；普通关闭不触发。
- `VoiceAsrWatchdogController`：启动8秒未ready触发回退，ready取消此定时器；不是每8秒静默就重连。
- `VoiceRuntimeLifecycleController.startBackendSpeechFallback`、`LiveSpeechTranscriptionSocketClient`：备用为自有后端WebSocket，不是平台识别SDK。备用失败的路径明确禁用platform speech fallback。
- `Index9AssistantConstants.DefaultUserId`读取当前AccountIdentityProvider.accountId；不能使用demo-user或虚构账号。
- `SpeechTranscriptionWebSocketHandler`：ready/partial/final/status/error与二进制PCM；无主ASR的JSON控制命令。
- iOS固定 `ddb996a28f98559ea7d8b76ca9d7712703dedbc1` 的AIVoiceSessionManager包含旧RTC→Dialog SDK路径，不能因此把旧架构搬入Flutter。当前两端共享Dart，仅采集/释放复用各自薄端口。

历史文档“SDK回退待做”描述不准确，本批以源码纠正为“后端转写回退”。不是新增产品能力，也不新增原生识别依赖。

## 正式实现

| 组件 | 职责 |
|---|---|
| `AsrRecognitionSession` | 数据层ASR传输接口；已有TaskAsrSession与新备用协议实现 |
| `RealtimeTranscriptionSession` | ready后16k PCM16 mono、最多640字节一帧；8秒就绪门限；取消关闭，不发送start_capture/stop_capture/finish |
| `FallbackVoiceInputSession` | 单手势最多一次切换；旧回调立即作废，实际采集释放成功后才创建备用；不缓存或重传PCM |
| `VoiceRecognitionFallback`、`VoiceInputController` | 本地类型事件显示切换提示；清未确认partial、保留final；保持2秒手势收尾/60秒上限和单次提交 |
| `voiceInputFactoryProvider` | Android/iOS同一组合工厂，快照当前账号/API；独立新采集对象，共用受保护音频租约 |

地址由可信API base拼接`/ws/assistant/realtime/transcription`，query为userId、languageCode和可选taskId。Flutter新统一页没有旧voiceTaskId，因此省略可选字段，不能用sessionId冒充；后端允许缺省。默认语言沿现有zh-CN。没有新增鉴权header、供应商直连、数据库或SIP改动。

主链路provider_error/connect_failed/transport_error/send_failed/ready_timeout/invalid_frame可切备用。主普通关闭、无效PCM和原生采集/中断/停止失败不切；备用失败停止并提示重新按住或切文字。事件订阅只负责交付，取消后凭generation拒绝晚到；真实硬件释放必须await session.cancel，失败保留同一owner供重试，不以订阅取消假报硬件已停。

## 已执行验证

9个相关测试文件共69项通过（最终测试计时6秒）；包含27项本批新增：备用协议6、单次切换17、输入收尾1、共享页面1、本地回环1、工厂1。无全量回归。

测试包括：ready/PCM门禁、关闭不发JSON控制、8秒超时及握手晚到、当前账号地址、一次回退、备用失败终止、普通Closed不回退、原生错误不回退、等实际释放、取消/显式停止/账号失效阻止晚到创建、停止失败可重试、未确认partial清理、final保留、同一手势只提交一次、三宽页面及切文字/后台。

真实本地HttpServer/WebSocket（仅127.0.0.1）串起TaskAsr→AsrCapture→Fallback→RealtimeTranscription→VoiceInputController：主连接收到PCM后错误，先释放旧采集；备用只收到新PCM，无控制串；最终提交一次“明天下午”。麦克风仍为合成端口，不能推导线上或真机成功。

`flutter analyze --no-pub`无问题；OpenSpec22项通过。只有共享Dart与文档变化，无依赖/原生改动，本批不重复双端构建安装。

另执行直接调用方`test/shell_workbench_test.dart`、`test/workbench_test.dart`、`test/features/home/shell_navigation_test.dart`共30项，通过（5秒）；包括正式工厂新增账号依赖后的整App导航。合计99项为两个定向集合，不是全量。

## Web集中入口

[验收目录](http://127.0.0.1:8122/) → 按住说话与文字切换 → 模拟异常 → 下次识别：备用成功/备用也失败。替换权限/识别外部端口，实际复用正式FallbackVoiceInputSession、输入控制器和对话页；不会访问账号、麦克风、后端或发送短信。

成功路径应增加1次识别回退和1次请求；失败路径只增加回退，显示识别中断、不追加请求。正常连接选项可恢复默认合成行为，退出场景重新进入重置。按住/上滑等细节仍由共享手势组件测试覆盖，不将浏览器短点击当真实声音时长验收。

本批浏览器8122实际依次执行：备用成功后请求1/回退1、显示一条用户消息与回复；备用也失败后仍请求1/回退2、显示“语音识别中断，请重新按住说话或切换文字”。浏览器未见error，存在两条DWDS registerExtension开发警告，不描述为零日志。

## 后续集中人工验收

1. 测试环境保证主ASR和备用转写服务有可用配置；只读确认配置即可，不为验收擅改线上服务。
2. Android/iOS同版本阶段包：默认按住说话、松手，正常情况下无回退，用户消息只出现一次。
3. 在受控测试代理/后端故障注入条件下仅使主识别报错，备用正常：观察切换提示、备用识别文本及只提交一次；切换前PCM不应被重传。此项需人工发声及受控环境配合，本批未执行。
4. 主与备用均失败：不循环重连、不自动提交未确认片段；松手后可切文字继续。单纯主服务主动关闭不自动备用。
5. 切换期间上滑取消、切文字、退出对话、切后台、进入通话或退出账号：旧请求/ready不能重新开麦或提交；回前台不自动重录。
6. 检查麦克风指示器、TTS抢占/恢复、系统中断、蓝牙/听筒路由与实际识别质量；若设备停止失败，先清理而非开始第二路采集。

记录平台/构建提交/发生时间/sessionId及允许的错误分类，按同时间窗核对测试后台；不要记录原始PCM、识别正文、token或含账号的完整地址。此处仅列验证步骤，不声称真实设备已经通过。
