# 规范冻结验证记录

> 下文最初校验为 v1 阶段历史记录。用户后续确认改为各仓 AGENTS 独立完整收录 v1.1，三端共同块同步，新增本仓源码知识库，并纳入 TTS 调度和 STOP-01 顶部临时状态规则。历史“Java 唯一维护 / AGENTS 仅入口”的分发决定已被替代；最新验证见本文后续 v1.1 记录。业务修复由独立 change 验证。

本次仅文档与 OpenSpec，实际规则由 Java 仓库的 `docs/architecture/task-orchestration-contract.md` 唯一维护；入口见本仓 [AGENTS.md](../../../AGENTS.md)。

## 修改前基线

- Flutter `codex/dev@8445d06f` 已 fetch，与远端一致；全仓 OpenSpec 221 项通过。
- Java 快进至 `514f8eb4d`，全仓 106 通过 / 1 项既有失败：`audit-v66-single-call-stop-ui-parity` 无 delta。
- Web `feature/test_v1.7.0@94150ab` 已 fetch，全仓 14 项通过；原有未跟踪的截图产物目录保持原状。

## 本批验证

- `openspec validate --all --json`：222 项通过，0 失败。
- `openspec validate <change> --strict --no-interactive`：本 change 与受改的 `fix-apology-local-prompt-timeline`、`home-model-shell`、`align-conversation-sse-interaction-history`、`restore-conversation-thinking-order-v66` 均通过。
- 三端文档 UTF-8 / 中文读回、replacement / NUL 检查、Markdown 本地链接与仅文档范围检查通过，各仓 `git diff --check` 通过。新增任务记录不关闭业务待办。
- 独立只读复核发现有效 SSE delta 仍允许删除真实思考结束内容，已改为结束占位 / 动画并保留内容；随后重跑验证。未发现其他可操作项，无延期的次要审查项。
- Java / Web 最终结果与审查范围见 Java 同名 change 的 `verification.md`；Java 107 通过、保留同一项既有失败，Web 14 通过。未把历史测试当作当前新竞态通过。

## 未覆盖项

没有修改或测试业务源码，不打包 / 安装 / 部署，不进行真实外呼。入口快照、消息操作身份、评分补全、正文清理等后续实现与合同连续回放未完成；联系人 / 任务列表 / 历史详情跨入口一致性、同会话后端响应、双端画面和可听音频仍待验。此前探索阶段的 26 项既有测试不计入本批文档验证，也不用于证明新规则已实现。

## v1.1 独立仓库规范验证（2026-10-20）

- 三端完整共同块逐字相同，20 个唯一回放编号；SHA-256：`8d6bacfef839921b759ed8dc7156a1040147dd14bd20857ce7ebfd3db7c5a15e`。
- 三端 AGENTS、各仓知识库、freeze 变更及 Java 来源索引共 21 份文档 UTF-8 / 中文、replacement / NUL、本地链接与个人路径检查通过；规则不依赖相邻检出。
- 本次全仓 OpenSpec：Java 107 通过 / 同一既有无 delta 失败；Web 15 通过；Flutter 此检查时 224 通过（包含并行实现变更元数据，业务验证由各自 change 报告）。
- 本批提交仅文档；模型、评分、确认、入口、停止状态与播报的业务代码及测试分开验证和提交。未打包、安装、部署或真实外呼。

## v1.2 规则同步（2026-10-20）

- 新增多轮思考无正文锚点约束、MEMORY-01 / 02；记忆必须与当前绑定 Skill / 原作用域相关，使用前确认，保存 / 采纳 / 拨打确认分开。记忆业务改造未混入客户端补丁。
- 三端共同块一致，22 个唯一回放编号；SHA-256：`9ffed869dd95b482e5fa4cc95a1ef067dfa054e40fc60565f586ad9d7eb53360`。
- 23 份规范 / 知识 / 变更文档的 UTF-8、中文、本地链接和个人路径检查通过；三端当前 freeze change strict 校验通过。
- 本次规则与源码职责仅说明确认的合同和事实，当前缺口、现场证据和验证记录保留在 review / change 中。
