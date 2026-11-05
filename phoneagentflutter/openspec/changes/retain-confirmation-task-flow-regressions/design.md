# 设计与旧版依据

## Context

合同为 `task-orchestration-v1.1`。本改动对应 CONFIRM-01/02、HISTORY-01、ENTRY-05/06 与 VOICE-01；只修本端已显示确认正文的 owner，不变更业务规则。

固定来源只读核验：

| 基线与测试路径 | 测试函数 | 真实保护 |
| --- | --- | --- |
| `a0bedb12:android/app/src/test/java/com/vvtech/aiassistant/features/assistant_agent/TimelineSnapshotConfirmationReconciliationTest.kt`；`8f235920:app/src/test/java/com/vvtech/aiassistant/features/assistant_agent/TimelineSnapshotConfirmationReconciliationTest.kt` | `livePreCallReplyStaysBeforeTerminalReceiptAndFinalReply` | 确认提示早于结果、最终说明；重复投影不变 |
| 同上两文件 | `sameToolCallIdKeepsOriginalConfirmationBeforeReceiptAfterLiveCompletion` | 同工具确认保留原位置；最终说明不附着旧确认 |
| `8f235920:app/src/test/java/com/vvtech/aiassistant/features/assistant_agent/TimelineSnapshotConfirmationReconciliationTest.kt` | `consecutiveCallAttemptsKeepBothCardsAndDoNotReplaceTheActiveCallWithAnOldReceipt` | 第一通结果不覆盖第二通；两确认、两结果原位保留，重复恢复不变 |
| `a0bedb12:android/app/src/test/java/com/vvtech/aiassistant/features/assistant_agent/OnlineAndRestoredReceiptIsomorphismTest.kt` | `successOnlineAndRestoredReceiptsAreIsomorphic` 等五种结果 | 相同业务事实的实时与恢复结果内容一致；本次只以同一成功 fixture补跨入口，不能声称五种语义均补齐 |

## Decisions

独立复核补充：同 command / tool 仍可有不同正文，plain 消息保持各自身份；只有同工具且正文一致的临时副本才由 durable 正文协调。同身份 showOptions / askUser 已有结构卡时收起重复工具轨迹，独立正文与其他工具保留。此规则同时适用于联系人 continuation；旧测试中同时显示相同工具轨迹和选项的断言按已批准合同迁移，不删除选项内容、pending 或副作用断言。

- `ConversationMessageStore.confirmation` 已负责实时确认投影，在这里同时保存该次已存在的固定提示。身份包含 command/tool，重复 callback 不多插，不用文本作为全局去重键。保存正文不调用 speech；TTS 仍从原 SSE observation 进入。
- `CallConfirmationCard` 只负责卡片。移除其根据 executable 生成正文的职责，避免卡失活删字和首次双份提示。`ConfirmationBillingRoute` 保留已有调用参数兼容，但不再让它控制正文。
- 不把正文继续堆入 controller。独立测试 fixture 仅模拟 Gateway/History/CallSession 外部边界，生产 controller 负责全部状态流与 speech。
- 测试把固定提示作为真实服务端事实晚到补全；只有同身份事实协调本地记录。恢复纯工具历史不虚构提示。若真实服务端未落账提示，本次不以客户端恢复重造掩盖，仍是跨端持久化合同缺口。
- 同类确认继续通过既有请求/消息入口扩展，不新建执行状态机。

## Verification

证据见 verification.md。模拟端口与 SpeechFake 只能证明客户端接线/排队次数、代次隔离，不能证明 Android/iOS 实际可听音频、真实外呼或线上服务端落账。
