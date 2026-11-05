# Design

## 基线与差异

- 只读来源 `test/v66.0.3@a0bedb12`：`ApologyVoiceCoordinatorTest.initialConsentThenDefaultCloneSwitchIsSilentAndUsesNewAsset` 断言切换不新增 prompt。
- 只读对照 `feature/test_v1.6.0@8f235920`：`defaultCloneSwitchStopsOldSpeechAndAnnouncesNewModelAndAsset` 断言 prompt 新增一次；`switchingToMissingVoiceStillAllowsReturningToAnotherReadyModel` 连续两次返回同模型；两版均有 `lateResultFromPreviouslySelectedModelCannotReplaceNewSelection`。
- 当前目标遵守 `task-orchestration-v1.1` 已批准例外：每次成功切换追加，旧代次不可应用，同一次回调不可重复追加。
- Flutter 既有 `apology_voice_flow_test.dart` 覆盖单次切换和 voice controller 的迟到响应，缺少真实 ConversationController 多次返回同模型的全文、身份和旧卡连续断言。

## 文件与职责

1. `apology_conversation_binding.dart`：仅修正本地交互到消息 ID 的适配，不新建状态机。现有文件单一职责为道歉与会话适配，使用已有 prompt.id / 被选择卡片 id，无需新增通用身份服务或扩充 Controller。
2. `apology_model_operation_identity_test.dart`：集中覆盖该回归；网关和音色端口只隔离外部异步边界，Controller、binding、store、projection 均为真实实现。
3. 本独立 OpenSpec change：记录目标、差异与实际 RED/GREEN 证据，不改共享任务记录。
4. `conversation_message_merge.dart`：经后续授权扩展，仅收紧既有道歉 opening 合并入口。对已冻结于首次提交锚点的本地 prelude，opening 参数代表最新选择；同一 opening 事实只接管该锚点下最后一条对应普通记录，其后选中卡跟随该记录原位保留。更早同文案记录仍是独立操作；普通 SSE / 账本及其他消息分支不变。

## 身份与不变量

ready 的 ID 保持既有 `local:apology:voice-ready:` 前缀，后缀取单次 `prompt.id`。选择记录保持现有前缀，后缀取被选择模型卡的 id，避免同模型多次选择覆盖历史。已存在的同模型无变化短路、query generation、consent、选中旧卡、pending 暂停恢复与首次 command 开场参数不变。

本次不调整全局 merge / reorder，也不以文案去重。类似本地反馈继续复用已有交互身份；新增业务类型应接入各自 feature 端口。

## 首次提交的身份桥接

现有 opening wire 没有客户端 prompt ID，不能从纯文案断言多次操作是同一事实。保留原有 role + payload 校验作为该专用入口的兼容桥接，并将匹配范围收紧为同一首次 command 锚点下最新对应记录；一次权威事实不能消耗更早重复操作。相关连续回放已先确认 RED：A→B→A→B 的 opening 到达后少一条 B 反馈。重复同 eventId 的 committed 事实仍只一份，之后普通 command 的相同文案回复继续独立保留。

## 验证边界

回放 MODEL-01、MODEL-02，并运行道歉开场、提交事实、模型作用域、取消与普通消息合并的相邻回归。Android / iOS 真机、真实后端、实际可听音频和外呼均未执行，不由 mock 回放替代。
