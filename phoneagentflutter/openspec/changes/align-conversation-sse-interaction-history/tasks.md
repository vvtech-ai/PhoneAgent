# Tasks

## 当前验收来源

当前规则以本 change 已修订 delta 和用户批准的 `task-orchestration-v1` 为准。下文为历史执行和待验记录；其中后台 opening 与道歉 Consent 共存、清空所有本地消息或恢复时删除已落账正文等相反要求不再适用。历史勾选和数字不关闭共享合同中的新竞态；未提交 overlay 与已落账内容必须分开。

## 2026-10-20 本地确认覆盖欢迎语与 Ready 漏字

- [x] 按用户最终决定撤回后台统一确认方案，恢复本地固定 Consent；Java 工作区无改动。
- [x] 普通音色确认后的 Ready 同时写文字与语音 prompt，道歉页面覆盖后台欢迎语，普通 Skill 保留原行为。
- [x] 新增漏字失败回归，双平台覆盖欢迎语先红后绿；14 文件 67 项定向测试、Flutter analyze 通过。
- [ ] 用户手机确认文字与语音一致；本轮未打包安装，不以自动回放替代。

## 2026-10-20 initial-opening 连续事实回填纠偏

- [x] 明确原始基线为 D:/project/aiassistant test/v66.0.3（a0bedb12），核对查询无提示、旧卡失活和选中索引恢复的源代码与既有用例。
- [x] 真实控制器回放查询、普通确认及切换模型路径，观察原代码 3 项失败；按初始事实身份与本地序列修复合并，并清除 Checking 的播报 prompt。
- [x] 双平台页面重建后验证旧卡蓝色高亮、禁用、消息坐标顺序和后台开场保留；18 文件 120 项定向测试通过。当前 change 有效，全仓 OpenSpec 213 通过、3 个既有 change 失败。
- [ ] 手机同输入画面和真实后端连续事实对照；未打包安装，不以源码或 Widget 验证代替。

- [ ] 1. 建立公共事件分类和身份契约（完整业务类型收集未完成）
  - [ ] 1.1 已区分当前客户端事件层级和已支持的交互/账本类型；完整业务子类型与真实后端提交契约尚未收齐，不能称为全部规范收集成功。
  - [x] 1.2 在 conversation domain 增加统一的事件归一化/身份解析入口，未知值保留失败语义。
  - [x] 1.3 为 committed、signal、done、unknown 及缺失 tool identity 编写纯 domain 定向测试。

- [x] 2. 收敛事实与实时覆盖合并
  - [x] 2.1 调整 `lib/features/conversation/presentation/controller/conversation_message_store.dart` 与 `lib/features/conversation/presentation/controller/conversation_presentation_projection.dart`，让同身份 committed 原位替换 transient overlay。
  - [x] 2.2 调整 `lib/features/conversation/domain/conversation_message_merge.dart` 与 `lib/features/conversation/domain/conversation_live_messages.dart`，统一内容指纹、工具身份和跨轮隔离。
  - [x] 2.3 覆盖正文先到/事实后到、事实先到/实时后到、不同工具同文案和迟到文件/工具结果测试。

- [x] 3. 统一 options/confirmation 生命周期
  - [x] 3.1 在公共 action flow 接入 transient user-action echo，选择后保留旧卡快照并转移 active identity。
  - [x] 3.2 让 `lib/features/apology/presentation/controller/apology_conversation_binding.dart` 和 `lib/features/apology/presentation/controller/apology_voice_controller.dart` 使用公共选择路径，不再单独维护一套回显语义。
  - [x] 3.3 调整 `lib/features/conversation/presentation/widgets/conversation_options_card.dart` 及页面 enabled 判定，验证旧卡不可点击、新卡唯一 active、同文案跨轮独立。

- [x] 4. 统一 opening、工具轨迹和终态清理
  - [x] 4.1 明确并实现 opening/Consent、thinking、tool progress、batch progress 在继续流转、完成、失败、取消时的保留或收起条件。
  - [x] 4.2 将 `heartbeat`、`done`、`error`、`toolComplete` 的展示副作用限制在对应 turn/工具身份内。
  - [x] 4.3 增加普通 Skill、道歉 Skill、通话确认和批确认的生命周期回归测试。

- [x] 5. 统一历史恢复与实时投影
  - [x] 5.1 调整 `lib/features/conversation/presentation/controller/conversation_restore_flow.dart`、`lib/features/conversation/domain/history/conversation_source_steps.dart` 和 `lib/features/conversation/domain/conversation_message_merge.dart`，先清理 transient，再以 durable ledger 重建。
  - [x] 5.2 保留可恢复 pending tool identity，但不恢复本地 opening、Consent、用户点击回显或临时进度。
  - [x] 5.3 增加重启恢复、实时/REST 重复事实、sequence gap/冲突和历史不重播测试。

- [ ] 6. 验证和交付记录（真实后端规范仍待核对）
  - [ ] 6.1 核对完整 payload 子类型、事件顺序和后端提交事实；原勾选证据不足，已有 fixture 只覆盖部分，design 中真实后端问题仍待确认。
  - [x] 6.2 按影响范围运行定向 `flutter analyze` 与 `flutter test`，跨模块投影改动再执行必要的主流程冒烟。
  - [x] 6.3 更新根 `tasks.md`、`docs/codex_issue_log.md` 和 change checkbox，运行 `openspec validate --all`；本 change 通过，全仓当前为 176 项通过、3 个既有 change 失败，未验收前不归档。
  - [x] 6.4 重写 `verification.md`，撤回首次输入隐藏和把分类断言当作连续事件回放的错误描述；列出实际 fixture 输入、断言、命令及设备待验步骤。本轮结果见第 7 节，真实后端 fixture 与双端设备仍待验。

## 7. 2026-10-19 用户确认原生画面后的纠偏

本节为来源工作区的历史实现记录。本次合并时用户改定 UI 以 `origin/codex/dev` 为主，道歉 Consent、提问/选项布局和本地回显采用该远端实现，不使用本节旧结果证明最终 UI；来源修改保留在 `4bb88d5c`。当前合并的相关测试结果另见根任务和问题记录。

- [x] 7.1 按原生 appendClarificationStep 顺序复现并修复本地回答复用提问 commandId 的错序；按钮与文本/语音识别文本选择共用回显路径。公共 merge 保留本地交互位于后续 committed 轮次之前。
- [x] 7.2 查询音色只切换状态，不追加查询气泡；保留模型切换时的 pending 工具和卡片恢复。
- [x] 7.3 道歉入口保留后台配置开场，再展示专用 Consent；普通 Skill 继续使用配置开场。仅道歉提问与选项卡分开渲染，普通卡保留标题。道歉旧卡保留选择索引，重建后仍高亮且失活。
- [x] 7.4 完整顺序、延迟查询、连续选卡、文本选择和页面结构回归及受影响路径共 23 个测试文件 123 项通过；定向 analyze 无问题。已纠正验证文档并更新交付三件套。
- [ ] 7.5 Flutter 真机与用户确认的原生样例同输入验收；未构建安装前不得勾选。
- [x] 7.6 用户再次反馈后撤回错误修复并按当前源码重做：选卡保存旧卡快照、追加独立身份回显，查询状态不写入消息，后台 opening 在点击后保留；页面坐标回归覆盖旧卡→回答→新卡顺序，公共 merge 修复后续事实到达时的顺序，模型切换保留 pending tool。
- [x] 7.7 基于本次源码重新完成 23 个相关测试文件 125 项、定向 analyze、当前 change 与全仓 OpenSpec 校验；全仓 177 项通过、3 个其他 change 的既有错误。用户本轮明确取消打包，未生成、导出或安装新 APK；之前 123 项和旧 APK 均不是本次完成证据。
- [x] 7.8 按用户确认画面在最新 `xiaosy/dev_v1.7.0` 修复点击后旧卡与配置 opening 消失：先复现失败，再保留选中旧卡、独立回答与新卡顺序；仅道歉卡拆分提问并保留选中高亮，普通锁定卡维持原样；14 个现存相关测试文件 93 项、全仓 Flutter analyze、当前 change 校验通过，全仓 OpenSpec 213 通过/3 项既有失败，当前分支证据已更新。真机同输入验收仍归 7.5 待办。


### 本轮最终功能优先级复核
- 用户再次明确功能和 UI 均以 origin/codex/dev 为主；拉取版本 dc4dcb9e，合并其最新 4 个提交。远端道歉、选项提交/active 判定、积分刷新、launchProven、ASK_USER 解析、联系人回调 thinking 重绑及退出已读等待均保留。
- 不合入会拒绝 CALL_* committed 事实的本地白名单门禁；新增 7 类通话事实回归，白名单版本失败，保留远端路径后控制器/架构 20 项通过。
- 最新 codex/dev 受影响回归 164 项通过，初次架构检查发现合并控制器超限，已按单一职责复核登记精确路径上限。
- fresh_balance_admission_test 的 batch=true 积分拒绝用例在本次合并前的 phone-refactor 基线同样失败（刷新次数预期 1，实际 0），没有为通过测试改动该远端行为。OpenSpec 全仓 212 通过、3 个既有 change 失败，保持待验项，不声称全仓验证通过。
