## Why

普通 Agent 回复的正文已经显示，但无句末标点的流式片段会反复重置 800 ms 播报计时器。持续到来的片段可让首段 TTS 入队一直推迟。用户反馈测试环境文字出现后约 2 秒才听到声音；现有诊断包没有屏幕首帧事件，因此本变更只针对已由源码和回归确认的客户端等待机制。

## What Changes

- 普通正文的未分句缓冲从首个片段起最多等待 800 ms，不再被后续片段无限延长。
- 完整句仍立即入队；中断、切轮、禁用和最终结束仍按现有身份与播放规则处理。
- 早期入队前过滤跨片段 Markdown 的代码围栏、链接地址和图片内容，避免未闭合语法被提前送进 TTS；未闭合强调标记仅在普通流式正文切段时清理。
- 保留 PCM 预缓冲、前置静音、首音超时及任务 TTS 连接复用。偶发 Qwen 无首音单独排查。

## Capabilities

### New Capabilities

- `conversation-first-speech-wait`: 实时普通回复的首段有界入队等待。

### Modified Capabilities

无。

## Impact

PhoneAgent Flutter 的共享 `ConversationSpeechController`、播报文本策略、其定向测试及工作记录。无后端协议、数据库、TTS 服务或公共接口变化。此本地修改需随新测试包在同设备实测，才能确认实际开口改善。
