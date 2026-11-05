# 任务列表与统一文字基础链路

日期：2026-09-16。行为 v65 固定 4c781e3；设计固定 0cd58de 的 memory/index.html。属于初版的基础批次，不是统一页完整验收。

## 已实现范围

- 任务三路来源：conversations、call-history、task/list；稳定时间排序、callAttempt 去重、旧成功任务 fallback；部分源失败保留上次数据。普通 session 不以 CLOSED/失败/完成状态禁止恢复。
- detail envelope + raw timeline；分页、sequence/eventId 去重、冲突/缺口至多一次完整重读、账号代际隔离。只有 503/网络不可达或明确空旧 ledger 允许空兼容视图，不解析 messagesJson 猜测历史。
- UTF-8 SSE 任意分包/CRLF/多行、Agent 事件解码、流取消、固定测试环境配置、命令标识/幂等键；channel 始终 voice。此基础批次断流不自动重发 POST，要求先只读同步历史。
- 新建统一页、历史恢复、文字多轮、askUser 文本、当前候选“第 N 个”、基础持久文本替换临时消息、未知 ledger 事件保留但不编造展示。
- 首页普通技能进入新会话；任务列表打开恢复；默认语音外观，底部可切换文字；普通退出只取消本地流和页面状态，不请求后台挂断。

## 验证证据

- 最终门禁：126 项 flutter test 全过、flutter analyze 无问题、OpenSpec 10/10、设计13类artifact schema通过；普通 lib/main.dart 测试环境 Android Debug 构建通过并重新安装启动，不遗留集成测试入口包。

- 单元覆盖历史分页/冲突/账号、HTTP 错误边界、SSE/取消、任务合并/状态/部分失败、controller 退出/恢复/ordinal/命令/断流；小屏 320×568 + 1.3 字号 + 键盘 widget 测试。
- emulator-5554 离线设备脚本 integration_test/conversation_flow_test.dart：任务 → CLOSED 恢复 → 切换文字 → 发送 → 两候选 → 第2个 → 流式回复 → 关闭 → 重入 → 系统返回。所有 Repository 为合成替身，未连真实 Agent，未短信、外呼或录音。
- 设备证据位于 .local/conversation-validation（不提交截图与本地数据）；固定设计提取在 design/conversation-history，120 节点、7 原始 SVG、schema 校验。
- 首轮设备脚本未等待按钮刷新导致断言失败，补 pump 后通过；截图发现切换图标索引与卡片阴影裁切，已修正并重跑。
- 不声称像素级一致；设备截图展示范围和设计静态样例数据不同。平台字体、SafeArea 允许差异。

## 尚未完成，不能作为通过项

1. 真实账号任务/SSE/模型在线联调、iOS 此批验证；不为此反复要求验证码。
2. 通话与翻译记录详情、回执明细、赞踩及条件评分入口。
3. 单路自动确认/积分准入/通话页；多路执行协调、后台活动退出保护与恢复。当前工具明确未接入，不假执行；不能用本批包验收真实外呼。
4. 权限、联系人工具、OCR、文档上传/导入、批量任务确认/产物、完整 tool-card 与 CallAttempt/Batch 回执投影。
5. 完整阶段条/执行状态/技术错误恢复策略、完整候选富信息和旧 payload 升级请求；当前只验收基础文字投影。
6. ASR/TTS/录放音、试听等按用户要求后置。语音按钮目前明确提示未接入，静态波形不代表正在录音。
7. 通用用户上下文、定位、联系人上下文与高级恢复修订命令；不将基础 AgentCommand 视为完整工具流程。

OpenSpec 保持 active，用户验收前不归档。下一批优先只读结果与设置接口/页面，再逐项补齐复杂工具，人工音频联调最后集中处理。
