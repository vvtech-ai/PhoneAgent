## Context

诊断属于 Flutter 对话语音观测层，状态 owner 仍是现有 speech controller。首页、联系人、任务继续的实时普通正文共用该路径；恢复历史不触发播报。已有 TTS trace 由播放 factory 在首句入队时创建，提前创建播放器会改变资源生命周期，因此不采用。

## Goals / Non-Goals

**Goals:** 关联同轮首个非空普通正文观测、首个可播句子入队与真实 TTS/PCM trace；保持原合成播放动作和顺序；诊断异常不影响语音。

**Non-Goals:** 不认定近期合并导致延迟，不承诺加速；不更改 800 ms 空闲计时、24,000 字节首包、320 ms 静音、音频焦点或连接生命周期；不更改录音卡。

## Decisions

- 新增小型首字观测对象，持有实际 `DateTime` 与单调 `Stopwatch`，不持有正文。controller 仅负责在已有普通 text 分支捕获、普通句子入队处交接、切轮/中断清除。
- 可选 observer 接口让真实 `ConversationTtsStream` 使用 provider 已创建的 `MediaDiagnostics`，不改变已有 factory / playback 合约。后续实现可选择实现该观测接口。
- `textObserved` 在入队时补记，但 `time` 为原始观测时间；`sentenceEnqueued.elapsedMs` 为单调耗时。二者均不是屏幕首帧时间或实际开口时间。
- 仅首个可播普通句子记录一次。空文本、仅 Markdown 空内容、未入队即取消、恢复历史不创建诊断 trace。已有事件流的代次/所有权检查继续拒绝迟到事件。
- 复用 `voiceMedia`、`taskTts`、trace/time/elapsed 字段，仅增加阶段枚举；不增加正文、号码、凭据或任意错误信息。

## Risks / Trade-offs

- 补记使文件写入顺序不等于事件时间顺序 → 分析按 trace 与 `time`/单调 elapsed 解释。
- 没有可播句子即没有对应观测记录 → 明确不是所有文字的 UI 性能统计。
- 系统时钟跳动 → 入队前耗时使用单调时钟；跨链路事件时间仍需与现有日志共同解释。
- 仅有新观测点不足以推断近期回归 → 等待新包现场日志，必要时同设备/网络/模型作版本对比。
