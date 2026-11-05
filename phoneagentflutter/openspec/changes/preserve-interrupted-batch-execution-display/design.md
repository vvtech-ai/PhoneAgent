## Context

基线 Flutter origin/codex/dev 为 6689ec49，Java feature/test_v1.7.0 为 3d5230dda。现场流失败后 ConversationController._fail 保留批次并启动补查，但 phase=ready；ConversationPage 的占位依赖 sending，顶栏仅对 VERIFYING 补充状态，可信逐路状态恢复后仍可能显示待命。历史重进正常，已有停止跨页恢复修复必须保留。

## Goals / Non-Goals

**Goals:** 当前页跨来电、断流和只读恢复连续展示原批次运行状态；执行中、核对中、汇总中及有界耗尽明确；Android / iOS 共用规则；停止及可信结果沿原 owner 收敛。

**Non-Goals:** 不修改 SIP / SDK、服务端接口、账本、评分、记忆、外呼准入、媒体租约、任务输入门禁、轮询次数或构建版本。不将合成平台回放当作真机或真实音频验收。

## Decisions

- presentation 新增小型只读批次展示投影，从当前 transient batchReceipt 派生状态，供页面和顶栏复用。只承担读取既有事实和展示判断，不创建状态机。
- ConversationPage 继续复用 conversation-thinking 的原 slot/key；真实思考去重、停止展示、单路结果优先级保持。观察耗尽时使用静态说明，可信结果后不残留加载。
- ConversationStatusPresentation 沿现有优先级处理真实错误、precheck、结果整理和停止；批次运行信息补足 ready 期间的待命缺口。
- 不通过把整个会话强制改回 sending 补 UI，避免影响输入、重试及停止准入；Controller、StopBinding、Recovery 和服务端保持原职责。未来类似展示扩展集中在只读投影与回放。
- 测试使用真实 Controller / VoiceHost / Page 连续处理流失败、全屏路由及 inactive / resumed、进度补查、停止和终态，边界端口为合成数据，不做真实外呼。新增回放先 RED 后最小 GREEN，再跑相邻停止、恢复、真实思考、结果与语音组。

## Risks / Trade-offs

- 临时核对卡也被视为持续执行 → 区分观察耗尽的 VERIFYING 总态，显示静态说明，不增加无限等待。
- 终态和错误回执混淆 → 沿现有 BatchReceipt.isRunning / stopSettled，不另定终态，不重开已停止按钮。
- 重复真实思考或卡片移位 → 原 slot/key 与已有真实思考门禁保留，连续回放验证元素身份。
- 其他窗口 iOS 工作未提交且阻止快进 → 在独立干净检出开发，以显式提交推送至 codex/dev；不暂存、回滚或提交其他工作。

## Migration Plan

验证后将本次独立中文提交推送 codex/dev。无协议、数据或依赖迁移；需要回退时可单独回退本修复。Java 无源码改动则不制造后端提交。
