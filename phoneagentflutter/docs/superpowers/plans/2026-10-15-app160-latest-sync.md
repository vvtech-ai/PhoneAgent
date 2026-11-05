# App 1.6.0 最近更新迁移计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将原生9a95803之后、8f23592之前两次提交的有效行为同步到Flutter codex/dev，保留d42befd2已有能力。

**Architecture:** Kotlin仅作为只读行为来源；Dart按既有领域、覆盖层和controller接线实现。任务上下文、克隆输入为独立子域并行，主代理负责批次/历史/播报并统一运行Flutter验证。

**Tech Stack:** Flutter3.32/Dart3.8、现有REST/SSE/账本、Android开发构建。

**Spec:** `openspec/changes/port-test-160-latest-updates/specs/test-160-latest-parity/spec.md`；来源原生四份变更及meeting-invitation-feedback主规格见迁移报告。

## Global Constraints
- 只修改当前隔离工作树codex/dev，不改原生/后端/数据库/Nacos，不执行真实外呼、短信、认证或支付。
- 保留签名/账号/环境隔离、会员支付与权益拒绝历史、通话事实门控；每微批最多三个手写文件，UTF8中文、中文提交、不force。
- 旧通话未可信终结时不得合成结束，不因新source覆盖目标已有更严格边界。

## Review Focus
- 失败时仍保留逐路/批次身份，迟到进度不得恢复“正在拨打”或释放门禁；用流失败→补查→可信结果测试覆盖。
- 记忆提示与业务文本/账本不同顺序，不能被覆盖或插入下一轮；用两轮及最终文本重复测试覆盖。
- 旧确认身份相同但新版拒绝与重新生成不同tool；用拒绝移除、不同卡保留及滚动定位测试覆盖。
- 播报交付失败/静音不应消耗pending身份；用同步失败后重送、恢复但无新事件不播报覆盖。
- 文档解析跨会话/代次/输入模式，以及置顶窗口成功二次回包；用延迟完成与乐观更新/回滚测试覆盖。

### Task 1: 任务上下文和克隆输入
**Files:** `task_page_mutation.dart`、`task_controller.dart`、`conversation_call_host.dart`、`conversation_document_host.dart`、`conversation_route.dart`及独立上下文模型/测试；`clone_enrollment.dart`、`clone_enrollment_steps.dart`及独立输入测试。
- [x] 对照原生新增测试，已等价项记录，不重复实现。
- [x] 先写失败测试，由主代理统一运行RED，再最小迁移并GREEN。

### Task 2: 流提示与播报
**Files:** `agent_event_decoder.dart`、`conversation_live_messages.dart`、`conversation_message_merge.dart`、`conversation_event_flow.dart`、`conversation_speech_controller.dart`及各自测试；消息模型仅增加必要展示属性。
- [x] 新增memory_notice和ASK_USER播报交付去重回归并取得RED。
- [x] 使用当前命令身份合并提示，不重放历史播报；修复后执行对应测试。

### Task 3: 批次状态与确认历史
**Files:** `batch_progress_tracker.dart`、`batch_receipt.dart`、批次widget、`conversation_controller.dart`/恢复接线；`batch_confirmation_projector.dart`、`conversation_source_steps.dart`、`conversation_page.dart`/timeline及独立展示规则。
- [x] 新增VERIFYING、阶段显示、拒绝卡、恢复卡可见性和旧确认文字案例，先RED。
- [x] 只改变展示与既有恢复调用，保留可信终态和确认身份，定向GREEN。

### Task 4: 交付
- [x] 首轮扩大集合覆盖conversation/calls/tasks/attachments/voice_clone/contacts及调用方；修正后冻结定向77通过、最终conversation/calls/tasks及附件shell1290全部通过，analyze、OpenSpec149和独立复核完成。
- [x] 文档保存来源映射、实际命令/结果及未验运行项；UTF8/diff检查后中文提交并普通推送codex/dev。
- 本轮用户仅要求代码同步/提交，不额外交付开发包；如后续构建，必须固定产品提交并独立验签和保留数据安装，不能沿用旧包称作本次产物。
