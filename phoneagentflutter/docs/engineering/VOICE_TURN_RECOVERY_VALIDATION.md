# 统一对话网络失败恢复：实现与集中验收

2026-09-20。基于既有统一页和组件实现，视觉统一校准后置。恢复的是已提交的业务句，不是任意识别失败的partial，不自动重录或重放请求。

## 固定源码依据

Android v65 `4c781e3`：`VoiceRecoverableTurnCoordinator.onCommandStarted/onNetworkFailure/planSubmission`、`resolveRecoverableVoiceTurnServerState`、`ConversationSubmitActionHandler.submitVoiceSupplementTaskWithContext/submitPreparedVoiceTurn`、`AgentStreamFailureRecoveryHandler`及`VoiceManualControlHandler`。同页键盘也走VOICE，所以同样适用，不仅ASR输入适用。

iOS参考`ddb996a`仅查到`AIAssistantModels.h`中的`supersedesCommandId`模型字段，未找到同等恢复协调器；不据此虚构iOS规则。两端共享以下Dart实现，本批不新增原生API。

## 状态与提交决策

| 当前事实 | 下一次用户显式输入时的行为 |
|---|---|
| 普通VOICE用户命令传输失败 | 冻结原文本/命令ID；取消本地流、清理临时未完成回复；允许继续输入，无自动请求 |
| 原命令未接收、已接收、已终止 | 先同步完整ledger；合并原句与补充的重叠部分，发新commandId/idempotencyKey并携带supersedesCommandId；只替换临时用户展示 |
| 原命令已有有效持久回复，重复原句 | 同步结果，清除恢复状态，不新增POST或重复用户气泡 |
| 原命令已有有效持久回复，新补充 | 先同步，再将新补充作为新一轮，不再拼旧句、不带supersedes |
| recovery_revision取消后才到达旧回复 | 不认作有效旧回复完成；普通取消不具有这一特殊截断语义 |
| 历史不可用、缺失、缺段、落后于已收到事实或冲突 | 保留断网前的原句，不发新命令；用户恢复网络后显式继续。此次补充尚未发送，不宣称已经保存新补充 |
| 模型错误、文档/动作、活动单路/多路失败 | 保留既有专属处理，不套用普通用户句恢复，不重放权限或外呼确认 |
| 关闭页面、主动恢复历史、换账号销毁旧Controller | 清理本页恢复状态，晚到同步不得再次提交。恢复状态不跨进程持久化 |

按住时读取当前恢复基句，沿原有重叠规则合并识别字幕；取消只丢弃本次采集、不提交基句，下一次按住重新读取。ASR错误仍明确停止，不将不可信partial变成自动业务请求。SDK识别回退仍是独立未完成项。

## 核心实现位置

路径相对`lib/features/conversation/`：

| 类/方法 | 责任 |
|---|---|
| `domain/voice/ConversationTurnRecovery.started/failed/completed/plan/resolve` | 单一冻结事实、原命令归属、完整/新鲜ledger检查、取消顺序和合并计划 |
| `presentation/controller/ConversationSubmissionFlow.send/_recover/_prepared` | 用户提交与异步恢复、单次门禁、离页代次校验、首轮上下文复用；独立于Agent事件处理 |
| `ConversationController._start/_fail/restore/close` | 事件与生命周期接线；复用现有通话准入，不在大控制器中堆恢复规则 |
| `ConversationSubmission` | 复用原AgentCommand的supersedesCommandId及VOICE线协议，不改后端接口 |
| `ConversationMessageStore.applyRecovery/reviseUser/discardPartialReply` | 合并权威事实、临时用户替换与半截回复移除；不修改持久ledger |
| `VoiceInputController.press`、`app/conversation_voice_providers.dart` | 从正式ConversationController读取恢复前缀，同一按住/松手/取消规则 |
| `PreviewVoiceInput`、`VoiceInputPreviewPage` | 仅模拟Agent/历史/权限/媒体端口；复用正式Controller、提交编排和统一页 |

统一对话Controller保持500行以内；用户提交/恢复已按职责拆出，未放宽架构检查或登记超限例外。无依赖、权限、SIP、提示词或数据库变更。冻结正文仅本页内存，不写日志、Git或通用偏好。

## 自动与Web证据

- 新增19项：恢复规则6、正式会话恢复7、按住前缀1、同页Widget5（含320/390/430宽）。原先“所有网络错误禁止输入”测试按固定v65纠正为“显式输入先同步，缺ledger仍不POST”，没有取消禁止自动重放断言。
- 全量2034项通过；analyze无问题，919个Dart文件格式无变化；OpenSpec19项通过。全量包含未提交原生草稿的3项通道测试，不作为iOS验证。
- 隔离Web入口`tool/previews/voice_input_preview.dart`，本次`http://127.0.0.1:8120/`；也可从开发者交互演练进入“统一对话输入演练”。顶部明确MOCK并显示请求次数，“模拟异常”提供未完成断网、后台已完成、历史同步失败和恢复正常。
- 演练Web构建23.4秒、正式main入口Web构建29.3秒、Android Debug构建10.8秒通过。Flutter检查标签时GitHub连接重置，但本地固定SDK随后完成构建；既有Cupertino字体族提示仍列视觉校准，不声称像素验收。
- 真实浏览器已验证“明天下午”断网后保留→输入“下午开会”→仅显示“明天下午开会”一条用户句及回复，请求由1次变2次；没有重录或真实网络。
- 同一浏览器继续验证“后台已完成”场景：“周五整理资料”失败后再次显式输入原句，恢复持久回复，请求始终3次、无重复用户句、断网提示清除。自动化编辑一度仅更新语义输入节点；切语音再切文字重新建立真实编辑控件后完成验证，未为工具问题修改产品代码。

Mac `192.168.1.49`本轮SSH超时，本批没有iOS新构建。安卓真机在线，但阶段覆盖安装仍等待此前拒绝后的明确答复；未绕过安装约束、未覆盖原App、未动8080登录或Mac保留会话、未重发短信。

## 集中人工验收

前提：已安装相同阶段包、测试环境已有登录；先使用不会触发外呼的普通需求。人工授权后才测试语音或真实故障，浏览器合成计数不代表后台证据。

1. **用户句已接收但未完成时断网**：恢复网络后补一句；原句和补充按重叠规则合并，界面一条修订用户句。后台核对新commandId、旧supersedesCommandId、同一sessionId及recovery_revision，确认没有重复工具执行。
2. **后台已完成但App未收到回复**：再次说/输入原句，只读取历史恢复结果，不出现第二个用户命令。不能单看界面数量；同时查后台ledger与请求时间窗。
3. **已完成后新补充**：旧结果保留，新补充单独成为新轮；不把旧内容再拼入键盘补充。ASR按住时的前缀表现按当前v65规则检查。
4. **同步仍失败或副本落后**：提示原内容保留，不执行POST；解除故障本身不自动发送，用户再次输入才触发同步。核对没有“已发送”假成功。
5. **按住/取消/后台/关闭**：按住时原句为前缀，上滑取消不提交；关闭或主动恢复历史时，在途读结果不能自动提交。进程重启走原任务恢复，不声称保留未持久的本页恢复草稿。
6. **动作边界**：在单路/多路已经执行、文档导入或权限续接时制造断流，确认走原专属同步，不重复外呼确认、上传、权限弹窗或扣费。
7. **双端效果**：Android/iOS同样的文字场景、按住字幕与取消、键盘及安全区；再统一核对最终视觉。SDK回退及真实识别/声音质量单列，不由此项替代。

App调试日志定位`conversation_failure session=… reason=network`，服务端按sessionId、原/新commandId、supersedesCommandId和ledger sequence交叉核对。禁止记录语音正文、PCM、token或把仅App日志当成后端根因证明。只有人工验证结果和后台证据一致才勾选真实端到端验收。
