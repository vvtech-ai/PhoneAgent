# App 1.6.0 最近更新同步

## 范围和来源

用户要求同步 App v1.6.0 最近更改，验证后提交推送 `codex/dev`。目标为 Flutter 隔离工作树 `phoneagent-task-flow`，起点 `d42befd2`；只读原生来源为 `origin/feature/test_v1.6.0` 的 `9a95803..8f235920`，包含 `da2e6d31`（记忆及批次上下文）和 `8f235920`（导航、会议反馈、克隆录入）。原生本地分支不切换、不修改，Kotlin 不直接合入 Dart 历史。

本次不修改后端、数据库、Nacos或支付配置。保留目标既有会员权益、支付、订单、发票、并发和拒绝历史成果。实际读写仓库不在 PMReport 当前内置项目清单中，因此本次无进度外发。

## 行为映射

| 原生更新 | Flutter 实现与边界 |
| --- | --- |
| `MemoryNotice`、SSE parser、step mutation、timeline preserve | `agent_event_decoder` 解码；独立临时提示按 command 身份保留，后续账本不覆盖，不混入下一轮；已有权威文本包含提示时去重 |
| 同步 ASK_USER / MAKE_CALL_REQUEST 记忆前缀 | 独立 `MemoryNotice` 规则识别提示段；事件展示提示后继续业务路由，语音按交付结果去重 |
| TTS bridge / response state | ASK_USER 的 pending tool 身份在同一会话跨轮去重；静音、阻塞、同步交付失败不消耗身份；历史不自动重播 |
| 活动批次失败恢复 | 未结束路线变为 `VERIFYING`，既有路线结果和批次身份保留；结束本轮思考，但未取得可信最终回执前不能再拨号；尚无 batchId 时按 session 补查，仅匹配原 command 的终态解除门禁 |
| TaskReceiptContract / BatchPlus 卡 | `VERIFYING` 属于 running，不计入已完成数，不显示结果资产；停止和整理结果阶段文案与物理阶段对应 |
| 最后 Pending 确认卡定位 / key | 纯展示规则选原消息身份；只在未处理回合且卡后无新用户、新确认或批次结果时聚焦；不创建新 tool 或执行外呼 |
| 被拒绝的 confirmBatchTask | 按 session + toolCallId 移除对应历史与临时卡，OCR 源边界同步；合法不同卡保留，拒绝不等于确认 |
| 终局后的旧单路确认文字 | 独立展示规则，保留账本事实及新确认身份，避免旧提示出现在结果下方 |
| AssistantNavigationPolicy | 返回隐藏通话界面，保留同一 activeRequest 和通话轮询，迟到状态不自动重新开页，不发送挂机 |
| FinalTaskPinPagePolicy | 旧任务取消置顶移出已加载窗口时，不插回当前分页；失败回滚保留已清除未读状态 |
| 文档选择上下文 / 首次来源 | 独立 `DocumentSubmissionContext` 冻结账号、任务、代次、输入方式；旧回调不提交，手动模式优先 |
| 联系人餐厅开场 | 当前 `contact_skill_opening` 已等价，保留原精确文案及模板优先级，以既有回归验证 |
| SDK 批次未读 | 已消费 `hasUnread/unreadResult/canDelete`，页面已调用统一已读接口；服务端任务关联部署仍需运行环境证据 |
| 大陆身份证录入 | 纯规则限制 ASCII 数字及末位 X，trim/uppercase/18位截断，非法编辑保留原值；既有生日和校验位提交规则不变 |

Flutter 单行 EditableText 在自定义 formatter 前移除 LF，故输入测试分别验证平台归一化后的值与 domain 对原始内部换行的拒绝；不通过改成多行或放宽业务规则改变页面。

播报开关沿用目标既有 `taskVoicePreference`、账号和活动通话门控；键盘/按住说话是输入方式，不在本次迁移中改成新的扬声器开关。新增去重只在实际同步交付成功后消费身份。

## 验证记录

首批实际 RED 覆盖导航/置顶（3失败）、文档（4失败）、克隆（8失败）、记忆/语音/批次（11失败）、被拒确认（8失败）、恢复确认焦点（3失败）。先出现编译问题的测试已修正后再取得行为失败证据，不把编译失败当作行为复现。

源码冻结后77项定向验证通过（记忆、播报、待核、无batchId补查、确认拒绝/定位/旧问句、monitor、置顶和架构）。`flutter analyze --no-pub` 无问题；`openspec validate --all` 149通过0失败；严格UTF8解码和U+FFFD检查通过。格式化是独立机械批次，未扩展业务范围。

扩大回归首次2021通过13失败，暴露旧期望冲突和两个实际问题：nullable Key泛型不匹配导致定位失效、失败回滚误用成功取消置顶裁剪。两者均修复，原有回滚断言保留；旧页返回和Pending卡尾随测试按来源规则更新且保留正常tail/键盘覆盖。修复后最终会话/通话/任务及附件shell集成1290项全部通过，耗时4分11秒，不与前次重叠测试相加。

最终命令：

```text
flutter test --no-pub test/features/conversation test/features/calls test/features/tasks test/shell_attachment_workbench_test.dart --reporter expanded
flutter analyze --no-pub
openspec validate --all
git diff --check
```

工具链固定Flutter3.32.0/Dart3.8.0。此前扩大集合还覆盖attachments、voice_clone和contacts；这些独立域无后续行为变更，复用其通过证据，不重复全仓构建。Git提交与远端回执以 `codex/dev` 日志为准，普通推送，不force。

两个独立领域代理交叉只读复核完成：文档账号/代次、manual模式、置顶窗口/回滚、返回observer、聚焦迟到回调、批次迟到done/身份、记忆合并和语音交付；发现的无batchId恢复死路已补实际RED/GREEN。其余未发现阻断问题，复核不代替运行态验收。

真实设备外呼、iOS 音频、供应商认证和服务端未读关联部署不由合成测试证明；本次无真实拨号、支付、认证或数据库迁移。当前请求是同步并提交代码，本轮未重新构建或安装Android包，之前包不代表本次新提交。
