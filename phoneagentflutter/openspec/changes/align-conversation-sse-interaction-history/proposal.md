# Proposal: 统一 SSE 编排会话的事件、交互与历史投影

## Why

当前 Flutter 已同时存在实时 `AgentEventKind`、服务端 `LedgerEvent.type`、`ConversationMessage` 临时覆盖层和 `activeOptionsId`，但它们的职责边界没有被一份规范明确固定。道歉 Skill 的现场证据暴露了这个问题：原生 Android 在用户选择后保留旧选项卡、追加用户选择回显、把操作权转移到新卡；Flutter 当前只保留临时提示和活动卡状态，选择路径没有统一的用户操作回显，历史恢复又会清除临时层。这个差异不是道歉专属，而是所有复用 SSE 编排会话的公共规则问题。

本变更把 Android 现场和 Flutter 现有实现抽象为一套可复用的事件分类、身份、生命周期、临时覆盖、历史恢复和去重规则，避免把传输事件、持久事实和界面消息当成同一类型处理。

## What Changes

- 明确 `AgentEventKind`（实时传输生命周期）、事件内 `eventName/payload.type`（业务子类型）、`LedgerEvent.type`（可恢复服务端事实）和 `ConversationMessage`（展示投影）的边界与映射。
- 规定 durable ledger、实时 transient overlay、用户操作回显和提交事实之间的替换、去重及身份优先级。
- 规定所有交互卡的 active、失活、原位更新和跨用户轮次隔离；道歉音色确认只作为一个案例。
- 规定开场白、Consent/选项卡、工具轨迹、最终响应、错误和 done 的显示与消失时机，以及历史恢复不得重播临时内容。
- 建立实时与历史共用的投影/归一化契约，并补充定向测试覆盖普通 Skill、道歉 Skill、确认卡和恢复场景。

## Capabilities

- `conversation-sse-interaction-history`: 统一 SSE 编排会话的事件分类、交互卡生命周期、临时覆盖与 durable ledger 投影、历史恢复和去重规则。

## Impact

- 影响 Flutter conversation domain、SSE stream/controller、presentation projection、history restore 和通用选项/确认卡路径。
- 影响所有复用公共会话管线的 Skill；不会为道歉 Skill 建立独立协议。
- 需要更新相关 OpenSpec capability delta、定向单元/组件测试和实施任务；本 proposal 阶段不修改业务代码或 baseline spec。
