# 文件规模复核

## 2026-10-21 dev 合并复核

`lib/features/calls/presentation/controller/conversation_call_controller.dart` 为 507 行。本次新增的两处 `EXECUTION_ERROR` 终态判断仍属于同一个通话结果观察生命周期，保留 507 行的准确路径例外，不提高默认 500 行上限。风险是执行异常后继续观察或漏发终态通知；用 `conversation_call_timer_test.dart`、`conversation_result_observation_test.dart` 和架构测试复核。后续新增职责或继续增长时重新评估提取。

`ConversationController` 的前台批次恢复已交给 `ConversationStopBinding`，通话结果阶段回调交给 `conversation_call_binding.dart`，主控制器回到原 527 行门槛以内；相关风险由前台恢复、通话结果和架构测试复核。

## 2026-10-20 全量回归基线复核

`lib/features/translation/domain/sip/domestic_sip_media.dart` 在本轮读取基线即为 504 行，字节归一化比较确认本轮未修改。它继续承担单次双工媒体生命周期，授权、音频焦点、上行路由、字幕处理和录音端口已在独立模块。为避免在任务记忆 / TTS 修复中按四行差额改动稳定翻译媒体状态，登记此准确路径 504 行例外，不增加通用预算；涉及该文件的新行为、增长或第二职责时必须重新评估拆分。其风险为媒体代次与输入输出结束顺序，保留现有翻译媒体及全量回归验证，不以本轮记录声称完成真实 SIP 验收。

任务 TTS 的连接健康处理已提取为同一个 TaskTtsSession 的 connection part，单次请求和连接依然共享唯一代次 owner，没有新增并行状态机；主文件已回到 500 行以内，移除其原 507 行例外。新增任务级 owner 与 reply lease 分别管理连接与播放资格，具体回归见任务级 TTS 变更。

## 2026-10-20 统一基准保留批量诊断端口

`ConversationController` 相对 `origin/codex/dev` 的 523 行仅增加 import、构造参数、转发回调和字段声明四行，实际 527 行。批量结果判定、恢复预算和诊断内容仍在既有独立组件，控制器仍只做接线；因此只将该准确路径例外更新为 527 行，不放宽其他文件。风险为批量恢复接线遗漏或重复回调，使用既有 batch_progress_recovery、task_160_stop、conversation_speech_integration 与架构测试验证；继续新增职责或增长时重新复核。
## 2026-10-20 草稿受理证据复核

`ConversationController` 为 523 行，本次只增加一行只读 getter，受理命令集合归现有 `ConversationMessageStore`，流事件判定归 `conversation_event_binding.dart`；账号索引、存储排序和清理分别在独立草稿存储与应用接线中。保留同一会话的公开读取边界，避免为一行接口另建编排器；准确路径例外从 522 调至 523，其他上限不变。风险是有效响应后业务失败误回填已发草稿，由真实控制器无 ledger 回执测试、草稿迟到失败/新编辑及账号释放回归覆盖；后续增长仍重新评估。

## 2026-10-19 双工作区合并复核

`ConversationController` 合并后为 522 行，保留远端提交/选项行为，仅加入结果确认、未确认和列表失效接线；判定与诊断仍在独立 domain/结果流中。`ConversationCallController` 为 505 行，新增部分仅管理同一通话观察生命周期的结果通知及有界同步，保留远端积分刷新和 launchProven 守卫；将这些回调按行数拆分会分散同一观察代次的状态。对这两个准确路径分别登记 522/505 行例外，其他手写源码继续 500 行。风险为结果重复通知、旧账号迟到、确认后仍加载或退出时漏已读；由 conversation_call_flow、batch_conversation_lifecycle、conversation_result_observation、visible_task_result_read 和远端 fresh_balance_admission 定向回归覆盖。后续新增职责或继续增长时重新复核，不据此通用放宽。

## 2026-10-19 TTS 网络恢复

`lib/features/conversation/data/voice/task_tts_session.dart` 为 507 行，仍只管理单个合成会话的连接、请求代次与恢复预算；音频设备和句子排队均在独立类。已合并重复诊断字段，保留此精确路径的 507 行例外，避免将紧耦合状态拆成两个生命周期。风险为离线/在线及连接 Future 迟到后复活请求；由 `tts_network_recovery_test.dart`、原会话/单句播放/诊断用例覆盖。后续增长或引入新职责须重新复核，不通用放宽 500 行规则。此记录不证明真机恢复。

用户确认默认 500 行，300 行不触发机械拆分。多职责必须拆分；少量单职责例外需记录文件、原因、风险、测试、复核条件。

ios/Runner.xcodeproj/project.pbxproj 为 Flutter/Xcode 生成工程元数据，不按手写业务类限制拆分。

## ConversationController（2026-10-06，508 行）

2026-10-15最新1.6.0同步复核：格式化后505行，沿用508行以内既有单职责编排例外。只暴露文档上下文代次/来源及已有批次恢复调用；记忆、确认焦点、旧提示折叠、批次待核和session补查分别位于独立domain规则或既有消息/停止绑定。没有放宽架构测试上限；以本次77项定向回归和最终会话集成回归复核generation、退出及事实门控。

`lib/features/conversation/presentation/controller/conversation_controller.dart` 保留统一会话编排：已有提交、流传输、消息存储、工具、通话、语音各自独立。本批额外提取 `ConversationRestoreFlow`，错误状态规则与持久补偿位于独立 domain 对象，控制器仅调用四处钩子。保留超限 8 行的编排器例外，避免按行数制造无领域边界的 part/extension。没有新增网络或存储实现进入该文件。2026-10-06仅增加工具部分授权提示回调一行；授权策略在纯Dart工具策略中，复核后仍保持单一会话编排职责，相关工具/控制器定向复验，后续新增生命周期或领域职责必须重新拆分。

风险：generation/退出顺序和回执调用顺序。验证：原 controller 的 12 项定向回归，以及本批异常退出/恢复的连续流程测试。后续新增业务分支前必须重新评估；不允许沿用此例外继续堆规则。恢复提取不改变历史工具不执行、CLOSED 可输入或本地退出边界。

Agent文档批次复核：提取权限与文档的`ConversationActionFlow`和纯Dart动作协调，不在主类新增文件选择、解析或协议规则；主类只持有文档控制器并调用生命周期钩子，格式化后507行（净增1）。保留此编排例外，架构测试仅对这个准确路径允许507，其他文件仍500；不是通用放宽。验证覆盖原权限/对话、文档取消/续接及restore/close晚到，后续增长须重新复核。

2026-10-08任务流程重构：按事件分发与实时交互职责提取`ConversationEventFlow`、`ConversationSignalFlow`，主控制器已低于500行，本轮不再需要超限例外。仍复用同一ledger/提交/tool/action/call/batch，未创建第二套状态机。复核覆盖迟到command/attempt、重复工具、账号切换、普通退出/批量例外、物理结束与服务端结果；后续新增职责仍应先评估拆分。

2026-10-09 v66补齐复核：主控制器格式化后507行，继续保留原准确路径508行以内的编排例外，不放宽其他文件。确认、停止、通话接线及结果接线分别在`ConversationConfirmationBinding/Flow`、`ConversationStopBinding`、`ConversationCallBinding`、`ConversationOutcomeFlow`，网络/偏好/文件保存均位于独立data与domain端口；主类只持有和调用生命周期钩子。风险仍为generation/退出/投影顺序，已用确认七分类、停止迟到事件、恢复无执行及原控制器定向回归；交付全量记录另见v66验证文档。后续增加职责先提取，不沿用此例外堆业务规则。

2026-10-09再次复核：结构化回答的校验/动作构建进入已有ConversationSubmissionFlow/Submission，选项提交也交由该提交职责处理；主控制器只公开受账号生命周期保护的回调，格式化后502行。问题模型、九类输入、日期时间、复制菜单各自独立，不把表单或剪贴板实现放入Controller；旧508上限未放宽。

2026-10-10会议同步复核：主控制器501行，本次只调整done时的已有phase守卫，保留recoveryRequired，不新增职责。确认快照读取放在139行ConversationSignalFlow，展示合并位于独立domain合并器，通话收尾仅展示现有状态。继续使用原准确路径508以内例外；验证确认同步失败后done、旧账号迟到、恢复不执行及对话/回执模块回归。后续新增职责仍须提取，不能以此扩大控制器。

2026-10-19异常挂断结果同步：`ConversationController` 当前格式化后 530 行，基线已存在编排器超限例外，本批只增加结果确认/未确认两个生命周期回调和任务列表失效钩子；结果判定、结果幂等和诊断已分别提取到 `ConversationResultObservation`、`ConversationOutcomeFlow` 和 `conversation_call_diagnostics.dart`，没有把网络或协议实现塞回主类。定向 calls/conversation/task 回归与 `flutter analyze` 通过；后续新增终态职责必须继续提取。
