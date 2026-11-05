## Context

ConversationStatusPresentation 将异常 notice 直接展示在顶部，ConversationPage 又显示同一 notice 及大面积重试按钮。批量 ASK_USER 语音取 questions.title，SignalFlow 却仅恢复确认卡，使卡片继续展示 TOOL_REQUESTED 的 assistantText。

## Decisions

1. Header 保留唯一简短恢复入口，点击仍调用已有 onRetry，不改变恢复状态或重发命令。
2. 独立纯展示投影使用当前批量 ASK_USER 标题替换对应确认卡的旧前言，仅按工具身份和同轮关系关联；原始 ledger 不修改。
3. SignalFlow 复用现有 interactive 消息保存当前提示，不新增另一套执行状态。
4. 普通空问卷保留提问来源正文这一纯展示元信息，以相同轮次和原文准确消除准备前言；提交仍沿用原 pendingToolCallId 与自然文本，不增加问卷动作。
5. 思考卡采用原生正式 PureVoiceThreadList 标题 Phone Agent；普通回退 AI 思考中...，三种批量技能回退正在理解任务...。不展示正式入口未采用的原始模型思考 token。
6. AgentEventDecoder 原本已保留 raw final schema，缺口在 EventFlow 的分派。final 互动直接进入原 SignalFlow，不创建第二套互动处理器；在 observed（含语音）之前以 command/type/pendingToolCallId 去重，并沿用停止抑制。没有工具身份时不推测两条事件相同。
7. 短异常状态保留确认卡同步失败、通话状态核对、任务保存失败等业务含义，未知固定客户端提示只取首句；时间线仍不重复显示长段异常区域。

## Verification

由主线程串行运行定向 Flutter 红绿测试，避免与测试包构建重写注册器冲突；随后统一 analyze/OpenSpec 校验。
