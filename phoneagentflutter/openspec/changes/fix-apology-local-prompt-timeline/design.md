## Context

`ApologyVoiceController` 的 `_promptId` 是本地交互身份，不是后端任务身份。本设计原先将这一区别推导为批量删除道歉历史，已由用户批准的 `task-orchestration-v1` 替代；当前规则见本 change 的有效 delta，完整合同入口见仓库 AGENTS。

## Decision

不通过批量删除 `local:apology:*` 修复排序。旧卡失活但保留快照，checking 只更新查询状态，ready 按当前操作追加正文；提交任务使用独立 command 身份，同身份账本事实在原位置协调。历史恢复清理旧进程 overlay 后从已落账事实重建，不重播或执行本地点击。

联系人回传接口由后台以新的 continuation command 承载，客户端在账本同步后将原 command 的 thinking 消息重绑定到最新 continuation command，使合并器能把 thinking 放在回传 assistant/options 前面。同步接口没有返回流式 `tool_card`，客户端仅对带 `SHOW_OPTIONS/pendingToolCallId` 的回传补一个同身份 `showOptions` 卡；普通 SSE 工具卡去重规则保持不变。

## Verification

- 历史“提交后不残留本地提示”的断言已不适用，不作为当前通过证据；后续按共享合同 MODEL / CONFIRM / HISTORY 用例验证交互保留、身份协调与恢复。
- 运行道歉定向测试、`flutter analyze`（若本机工具链可用）和 `openspec validate --all`。
