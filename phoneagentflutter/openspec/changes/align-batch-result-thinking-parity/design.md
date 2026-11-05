## Context
用户确认上一轮探索方案并要求执行。Flutter 起点 d65c4c8d，原生 feature/test_v1.6.0 为 8f235920；两者与远端一致。日志包含状态、批量结果及提交事件，但无任务 ID 和完整内容，不作为指定任务的完整运行复现。

## Goals / Non-Goals
补齐既有多路展示，保留外呼准入、计费、录音、恢复门禁。既有大文件仅接线，不新增业务状态机，不全局重排其他任务或模板附件。

## Decisions
1. 新增纯 Dart 批次回执排列规则，使用 sourceBatchId 关联同批次结果，将回执置于对应消息之后。ConversationPage 已在结果消息后渲染模型评价/任务评分，继续复用该扩展点。规则覆盖 durable 投影及 live merge，不改 ledger 事实。
2. 新增纯 Dart 思考内容模型，承接 thinking_delta 的追加/起始及 thinking_done。实际内容成为独立展示消息，避免与普通回复覆盖；无实际思考内容时依据发送状态显示阶段提示。完成或恢复门禁不再播放思考动画。历史只能展示服务端已持久化的事实，不伪造缺失的思考文本。
3. NativeThinkingCard 单独负责原生主标题、进行中星光/完成品牌及最近三物理行滚动；TaskArtifactCard 负责原生绿色样式，下载生命周期沿用现有 controller/provider。
4. 先以真实顺序、阶段文本、思考追加/结束和组件行为测试复现，再最小修复。交付前 analyze、conversation/feedback 直接调用方回归、OpenSpec、UTF-8/diff，最后构建和核验 test Release APK。

## Risks / Trade-offs
临时与持久消息合并必须保留批次身份及思考身份，避免下一轮污染；多批次、重复提交、模板、未知归属回执分别测试。当前源码不提供持久思考记录的契约，不新增客户端存储或猜测 ledger 字段。人工真机同任务复验待用户安装后进行。

## Verification
记录 RED/GREEN、定向回归、静态检查、原生样式截图及签名/版本/环境/ABI/AOT/保护库核验。产物仅放工作区 deliveries，不提交二进制或私有参数。
