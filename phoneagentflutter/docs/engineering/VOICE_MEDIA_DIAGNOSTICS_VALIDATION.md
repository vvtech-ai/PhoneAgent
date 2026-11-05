# 共享语音链路诊断（2026-09-21）

基点bb241ae后的增量实现；对应settings-interactions 2.1b7a。不是语音业务重新实现，也不代表整体Flutter迁移已完成。

## 实际接入

- 正式按住输入：voiceInputFactoryProvider在每次创建输入会话时绑定Journal和随机关联trace；主TaskAsrSession、延迟RealtimeTranscriptionSession回退与各自PCM采集沿用同一归属。
- 正式回复朗读：conversationSpeechFactoryProvider每次回复输出绑定一次；延迟分句TTS沿用该scope，PCM输出共用该trace。
- 音色试听：ttsPlaybackFactoryProvider将合成与实际PCM输出绑定同一scope。
- 以上均共享Dart；既有Android/iOS设备端口、权限、SIP、ASR/TTS协议、超时、fallback和音频仲裁规则不变。未为此新增第三方依赖。

## 如何读日志

`operation=voiceMedia`，`media.component`为taskAsr/realtimeAsr/taskTts/pcmCapture/pcmOutput；`traceId`只是本地操作关联，不是后端会话ID。随机源不可用时缺省ID，诊断不能阻止语音启动。

| 节点 | 实际证明的事实 | 不能推断 |
|---|---|---|
| connect/started→succeeded | WebSocket连接返回 | 服务已经ready或识别成功 |
| ready/received | 当前协议接受ready | 麦克风已经启动 |
| PCM start/succeeded | 底层start正常返回 | 已有可用录音或用户听到声音 |
| send/succeeded | 首个非空PCM交给socket.send | 服务端收到或识别成功 |
| read/received、receive/received | 首帧采集返回／首帧TTS音频到达 | 最终文本或播放成功 |
| complete/received | 合成结束；softTimeout另标 | 已实际播完 |
| play/succeeded | 首次非空PCM的底层play完成返回 | 整段已播完、硬件声学效果正确 |
| stop/succeeded | 本次设备stop返回 | 所有模块都没有音频占用 |
| close/succeeded | 当前socket及订阅清理返回 | 后台任务／通话已终止 |

协议失败使用固定reason，区分connectFailed、readyTimeout、firstAudioTimeout、providerError、invalidPcm等。PCM异常目前按失败阶段+deviceFailure归类；明确output_cancelled/capture_cancelled为cancelled而非故障。不保留任意异常code/message。首帧只记录一次，不逐帧刷日志；停止失败原异常保留、后续仍可重试。取消后的迟到连接记cancelled并关闭，不记连接成功；关闭失败继续原best-effort语义但不记成功。

不采集音频、转写、合成文本、speaker、URL、令牌、号码、原始异常或堆栈。未知可选字段归unknown，旧无media日志仍可读。账号切换后的旧fallback/分句/停止不改写新账号日志；上传仍沿设置页显式准备/发送，无自动上传。

## 本轮验证

- 15项新增定向：PCM首帧/实际返回/失败重试/原异常/取消/日志故障、隐私及旧日志→Journal重建→真实ZIP；ASR超时/回退分类、迟到连接、TTS协议完成、socket清理失败；正式三个工厂接线和账号切换。
- 原语音目录及直接调用方/日志共217项18秒通过（当时新增14项已含其中）；随后新增正式工厂接线1项，连同2项provider验证共3项单独通过。去重218项，不重复全量回归。
- flutter analyze最终通过；OpenSpec 30项通过。首次分析发现使用未直接声明的uuid依赖，已改复用现有随机ID并安全格式化，无依赖升级。工厂新测试初次缺合成账号而被正式登录门禁拒绝；补测试账号覆盖后通过，未修改产品鉴权。
- 没有UI改动，因此没有新增浏览器页面截图；没有平台/插件/构建链改动，因此不重复Android/iOS打包或安装。未真实SMS、录音、播放、外呼或上传。

## 保留的工作

后续翻译LiveKit/AppAudio专属观察已在[翻译诊断增量](TRANSLATION_MEDIA_DIAGNOSTICS_VALIDATION.md)接入并独立验证；不能把本报告早期范围当作当前缺实现。其他媒体路径不因此视为都有底层PCM诊断。匿名/未绑定日志用户导出仍未实现。真实声音、OS授权、耳机/蓝牙、来电打断及服务端结果继续按[MIGRATION_HANDOFF](MIGRATION_HANDOFF.md)集中人工验收。本报告只证明共享语音诊断接线和上述自动测试，不替代设备声学验证。
