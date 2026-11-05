## Context

2026-10-19 真机回归：Android 网络 EventChannel 在 onListen 后立即发送当前状态，
新增的 TTS 监听却无条件将每条事件映射为 network_changed。手机诊断中多次在连接后
8–105ms、requestSent=false/audioBytes=0 时失败；从 Dart VM 读出的实际运行源码
与本地该增量非空行一致。定向用例在稳定 available 初始快照下复现 failures=1。
修复仅在 TTS 消费端记录首个明确状态为基线、忽略重复状态和 unknown；明确状态
发生变化时暂停当前传输，连续离线最多等待 15 秒，不消耗后续句子；恢复在线后，
尚未向播放器交付 PCM 的当前句最多重连一次。已交付 PCM 的当前句中断保留失败，
不整句重播，在线后继续后续句子。取消后和超时后不得因网络回调复活。
不修改共享网络流、其他功能的网络预检或后端。
同为 available 的物理网络切换不能由此枚举区分，仍依靠已有连接错误/心跳处理，
不得把本修复描述成完整物理切网识别。

对照只读 v66.0.3@a0bedb12。23737 会话 5ac5362bb1804692c5d42dad65f36cb3；23739 会话 e9349b02a4262447547673e4198aa3db；23748 截图输入与 test SSE 16:24:17–22 的会话 70128e5af4f14b81594746cd2b317297 对应。23748 附件另含 16:15/16:16 PCM 故障，不能把所有失败都绑定为同一轮。

## Goals / Non-Goals

恢复明确丢失的 ASR 号码转换和本页思考记录。保持 ledger、确认授权、原生输出的真实完成判定。没有原生错误码之前，不猜测 iOS 根因，不以延长超时或静默成功掩盖故障。

## Decisions

- ASR 转换集中到纯文本函数，在 ManualVoiceTranscript 的 partial/final 合并之前执行，覆盖独立 final 和超时提交。
- 思考记录使用 command 绑定的独立临时展示消息；合并时不被普通 assistant 事实替换，不参与 TTS。保留在页面生命周期内，不新增服务端持久事件。
- 完成后以静态图标显示思考记录，保留原占位思考卡给未收到文本片段的阶段。
- 2026-10-16智能合并远端后统一使用ConversationThinking与远端增量事件语义，移除重复的本地thinkingText/thinkingDurationMs表示。旧66.0.3的PureVoiceStageCards实际显示“AI 思考过程”、处理状态/Phone Agent和三行滚动正文，不显示耗时；按此证据同步UI测试，不再要求展示耗时。
- 播放错误只增加枚举白名单类别，旧诊断继续可读。先用现有合成输出测试明确错误传播，设备复现与供应商首包仍是独立验收。

## Risks / Trade-offs

用户追加日志授权：每次 TTS 连接（包括空音频重连）生成新的 UUID mediaRequestId，作为可选查询参数交给现有签名传输后再连接；媒体诊断保留该标识、尝试序号、连接内单调耗时、ready/已发送状态及接收字节数，与 Java 供应商阶段日志关联。不会输出 URI、查询串、合成文本、speaker 或异常原文。PCM 的 FlutterError.details 只承载固定阶段、白名单 NSError domain、整数错误码、应用/路由/引擎状态；Dart 二次白名单解析后写入现有可导出日志，旧客户端/旧日志可忽略可选字段。启停日志增加耗时和 stop started，不增加逐帧日志。Windows 不能验证 iOS AVFoundation 编译和硬件运行，需明确保留设备验收。

其他线程正在修改单呼和语音宿主：不覆盖这些改动。新思考字段保持可选，既有构造与恢复不变；重开历史不伪造未持久化思考。

23739 截图还包含编排位置问题，当前思考和语音提交回归不证明全部附图中的编排差异已关闭。23748 的诊断增强尚不能替代原设备根因修复；现有输出失败测试均保留失败状态，未复现真实硬件底层错误。

## Migration Plan

追加已复现的取消分类修复：iOS PcmOutputChannel.release 会以 output_interrupted 拒绝待播请求，DevicePcmOutput 在主动 stop 后仍原样上抛，导致 DiagnosedPcmOutput 误报设备故障。仅在本实例已主动停止、非 stop 操作且原生明确返回 output_interrupted 时映射为 output_cancelled；不把 output_start_failed、output_play_failed 或 stop 错误改成取消。方法通道回归先复现旧行为，再验证取消/真实故障分离。此证据不证明 16:15 的启动失败及 16:24 的首包超时已修复。

通过定向测试和 analyze 后保留本地差异；尚未发布。回滚仅撤销本变更对应增量，不清空工作区。

2026-10-19 分支集成：按用户要求将 origin/codex/dev 与其已包含的 xiaosy/dev_v1.7.0 纳入当前 codex/dev_zys，保留原有未提交的会话级 TTS 修复。冲突处理同时保留远端请求标识/原生诊断与本地连接代次/请求代次；首帧预算和一次恢复沿用本地会话实现。单句 TaskTtsPlayback 在完成事件后释放专属连接，音频队列独立排空。更新旧的逐句断连、连接前首帧计时及平台测试边界，不把设备故障标为已验收。
