## Why

基础列表已可恢复普通 session，但翻译详情仍是占位；普通无 session 记录的入口也需按最新代码接回统一页，而非新增旧独立结果页。继续优先实现无需真实通话/人工音频验证的数据与展示。

## What Changes

- 翻译历史 GET 详情、双方原文/译文、基本时间信息，保留 final=false 有效字幕。
- 录音元数据独立容错；不下载、不播放、不暴露授权串。
- 普通无 session 记录按照 v65 onOpenResult 进入新统一对话；不接未使用的 task/detail 旧 UI。
- 后续补统一回执中的通话结果投影，保留复杂批次、录音/评价单独验收。
- 2026-09-18接续：先补齐共享录音卡和隔离交互演练、合成授权协议验证；再单独装配真实缓存/播放器/系统保存。原只读批次的“不下载、不播放”在交互阶段仍保持，不能以MOCK声明录音已可生产使用。
- 普通回执续接：按固定v65单路metadata锚点/可见转写、批量最后接通时长决定录音入口，复用控件但保持普通按点击加载。先接纯插槽和明确MOCK，普通metadata/play-token及真实保存、媒体互斥另批，不能把翻译接口的完整性字段套到普通录音。

## Capabilities

### New Capabilities
- `task-result-details`: 翻译历史只读详情与任务入口一致性。

### Modified Capabilities

无。

## Impact

features/tasks、translation_history、导航装配、离线测试、设计与 OpenSpec。新增 GET api/realtime-translation-calls/{callId}；不改后端/数据库/提示词/SIP/ASR/TTS，无业务写入或敏感日志。
