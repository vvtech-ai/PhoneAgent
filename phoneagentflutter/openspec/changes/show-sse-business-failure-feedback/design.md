# 设计

`task_failed` 保持既有 `AgentEventKind.error` 路径，`ConversationFailurePresentation` 按稳定错误码选择固定提示。通用业务拒绝告知操作未完成；积分不足明确提示补充积分。未知系统错误继续显示统一“服务暂时不可用，请稍后再试”。客户端不取 `displayMessage` 原文作为最终展示依据。

会员专用 `MODEL_ENTITLEMENT_DENIED` 与批量/并发码保持助手回复及 TTS 路径；单/批通话积分既有结果卡不受本变更影响。

系统诊断由 SSE 后台开关控制并复用 App 已支持的 `slot_updated.data.text` 与 `task_failed`，本变更不增加 App 调试事件解析或本地调试开关。普通 `task_failed` 仍始终走固定安全文案；业务失败即使服务端调试开关开启也继续走业务码提示。
