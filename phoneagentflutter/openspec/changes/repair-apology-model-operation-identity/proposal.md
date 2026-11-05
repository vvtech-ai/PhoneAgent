# 道歉模型切换操作身份修复

## Why

当前 Flutter 道歉 binding 使用 modelId 生成就绪反馈及已选模型记录身份。连续 A→B→A 或重复返回同一模型时，消息 store 按身份原位更新，从而覆盖旧操作。用户批准保留原生 App 1.6.0 每次成功切换的独立反馈，不能复用模型身份。

## What Changes

- 为每次就绪反馈使用现有 ApologyPrompt 的交互身份。
- 为模型选择提问、旧卡和用户选择使用该次已选卡片的交互身份。
- 增加真实 ConversationController 的 MODEL-01/02 连续回放，保护旧卡、pending、重复回调和旧请求隔离。
- 收紧首次 opening 的本地归属：一条权威 opening 只接管同一提交锚点下最新的对应本地记录，保留更早同文案操作。

## Impact

涉及 Flutter presentation binding、既有道歉 prelude 合并规则与专用回归测试。沿用现有 Controller、消息 store、query generation 和 TTS prompt；不改接口、数据库、权益、SIP、ASR、TTS 协议或模型默认配置。不用本次局部修复声称真机验收。
