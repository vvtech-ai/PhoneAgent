## Why

禅道 23737 的截图和 test SSE 会话证明中文号码原样进入对话；66.0.3 的 ASR 入口先执行号码归一化。23739 的思考内容在 Flutter 收到 thinking_done 后直接清空，与旧版保存同轮思考内容不同。23748 的诊断附件包含 PCM start/play 失败及独立的首包超时，当前日志丢失原生稳定错误码，不能据此宣称唯一根因。

## What Changes

- 对齐旧版 ASR 数字归一化，覆盖 partial、final、提交，保留用户原有语义。
- 按轮次保存思考内容，在当前轮完成后保留可查看的思考记录；ASR 转为用户消息时不重复、不丢失。
- 修复有可重复证据的播放错误传播问题，保留原生错误类别。首包超时保持失败语义，不伪造播放成功。
- 按用户追加授权补齐 PCM 原生失败详情和启停耗时，以及 TTS 每连接标识、阶段耗时和超时状态，与 Java 的任务 TTS 阶段日志关联。

## Capabilities

### New Capabilities
- `conversation-voice-continuity`: ASR 数字文本、轮次思考记录与任务播报故障的连续展示和诊断。

### Modified Capabilities

无。

## Impact

仅修改 Flutter 对话、音频及直接相关诊断和测试。23731 的电话媒体打断由 Java 配套变更负责。不改变外呼授权、计费、数据库、登录账号或系统配置；原有未提交工作保持原状。定向 Flutter 测试和 analyze 作为本地证据，原设备与同版本服务复验单独记录。
