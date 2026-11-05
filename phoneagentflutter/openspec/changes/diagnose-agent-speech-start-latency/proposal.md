## Why

普通 Agent 回复出现正文到开口变慢的反馈。当前日志可看到 TTS 连接、发送、首包及 PCM 消耗，但缺少首个正文 delta 和首句入队时间，不能区分分句等待与连接/合成等待。

只读对比未证实 `900b64cc` 相对 `921385e8` 引入公共 TTS 等待；800 ms 空闲分句、24,000 字节首包和 320 ms 前置静音均早已存在。本变更补齐诊断，不承诺加速或认定近期回归根因。

## What Changes

- 在实际普通正文 speech controller 路径捕获首字时间，并在首个可播句子入队时通过既有 TTS trace 补记 `textObserved` / `sentenceEnqueued`。
- 保留真实观测时间及单调耗时，记录每轮一次；中断、跨轮、历史恢复不继承旧观测。
- 不记录正文、号码、凭据；不增加网络、合成、播放动作，不调整分句或音频缓冲。

## Capabilities

### New Capabilities

- `agent-speech-start-diagnostics`: 普通 Agent 正文到 TTS 入队的匿名阶段关联。

### Modified Capabilities

无。

## Impact

仅 Flutter 共享任务对话语音控制器、TTS 数据适配器、现有 media 诊断阶段和 provider 接线，以及定向回归。无后端接口、数据库、录音卡或播放行为变化。新增日志需随新包现场采集后才可定位真实差值。
