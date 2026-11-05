# 批量实时进度、退出接收与历史恢复

2026-09-18，OpenSpec `task-result-details 2.11`。本批补齐共享实现及隔离交互验证；不代表真实外呼、后台保活或视觉已验收。普通登录保持，不需要短信。

## 行为证据与实现边界

依据固定v65 `4c781e3ccfcd148c1f205921534907ee0c5aa864`：AgentStreamSseEventParser、AgentStreamBatchCallActiveStateHolder、TaskBatchCallProgressPolicy、TaskBatchCallStreamFailurePolicy、AgentStreamEventHandler、AgentStreamHandler.interruptCurrentStream、AgentStreamEventSessionGate、AgentStreamTurnRunner。

| 文件 | 责任 |
|---|---|
| `lib/features/conversation/domain/receipts/batch_progress_tracker.dart` | 纯Dart聚合：工具开始标活动、非空状态文案/批量字段识别，按正itemIndex排序更新，total不缩小，重拨保留两次尝试提示。不是服务端事实存储 |
| `lib/features/conversation/presentation/controller/conversation_message_store.dart` | 集中本地ledger视图及临时消息；最终批次原位替换进度，普通文字独立，积分拒绝移除未执行卡，不补造费用 |
| `lib/features/conversation/domain/receipts/receipt_overlay.dart` | 当前进度可覆盖旧的运行中展示，但不能降级持久终态；不修改持久事实 |
| `lib/features/conversation/presentation/controller/conversation_controller.dart` | 调度共享状态；活动中不提交新轮，断流只将仍运行项标“结果未完整返回”，Done缺最终结果只做一次只读历史同步，不重试外呼POST |
| `lib/features/conversation/presentation/controller/conversation_event_stream.dart` | 订阅可脱离页面，移除全部UI/工具回调；退出后仅接收，终态释放活动标记，Done/错误/EOF释放资源，旧订阅标识不能作用到新流 |
| `lib/features/conversation/presentation/controller/detached_batch_streams.dart` | 账号级持有退出后的批量订阅；活动期阻止重复新轮；结束通知任务列表，关闭账号释放所有订阅 |
| `lib/app/conversation_providers.dart` | 正式账号代次装配，保留gateway生命周期；结束使三源任务列表失效刷新，换账号不向新账号投递旧刷新 |

所有新业务均在共享Dart内，没有新增Android/iOS原生代码、后端接口、数据库或提示词。新控件沿用现有页面与结果卡，视觉仍后置。主控制器已先提取事实/消息存储与投影，保持500行；后续继续增加复杂交互须进一步提取，而非扩张该文件。

## 生命周期

普通对话退出仍取消本地请求；不调用后台挂断。只有本次已识别为活动批量的订阅才移交账号级接收。退出后不响应权限、联系人查询、确认拨号或其他交互，不更新已退出页面，也不向新会话注入旧消息。活动批量期间拒绝新轮，沿v65既有规则；恢复只读取历史，不重放确认。

Done并不证明业务成功。没有最终快照时保留已知进度、读取一次历史并提示到任务列表确认。断流保持已经完成项目，其余标明结果未完整返回，不虚构计费、电话或最终成功。实际后台任务是否继续、何时持久化仍以后端为准。

本方案是当前App进程内的订阅管理，不新增前台服务或OS后台保活，也不承诺系统杀进程后客户端流继续运行。进程恢复依靠既有历史接口；不保存SSE凭据或真实用户fixtures。

## Web查看与MOCK范围

正式开发者入口：设置 → 开发者功能 → 隔离交互演练 → 批量进度与退出演练。

独立入口：`tool/previews/batch_flow_preview.dart`，本批验证地址 `http://127.0.0.1:8098/`。始终显示MOCK，不连接账号/API/电话/费用。`PreviewBatchStream`把合成后端JSON经过正式SSE decoder，使用正式ConversationController、订阅管理、统一页和结果卡；不是静态HTML假界面。

演练路径：进入并发送合成需求 → 推送逐项进度（0/3→1/3）→ 关闭统一页（活动接收1）→ 模拟退出后结果到达（活动接收0）→ 从合成任务列表恢复（3/3，2路完成/1路未完成）→ 单项通话记录展开/收起。也可推送最终结果、模拟断流或账号释放。

本批浏览器已完成上述退出后恢复路径。自动测试还覆盖最终快照替换/晚到、重拨、乱序项目、旧持久运行态与终态覆盖优先级、积分拒绝、普通退出、跨页面污染保护、账号代次释放及三源任务列表仅刷新一次。

## 验证与集中人工验收

- 新增28项回归；全量1,510项、analyze、676文件格式与19项OpenSpec，以及Web/Android Debug/Mac iOS无签名构建均通过。本批共享实现未改原生工程，不以构建代替安装和后台运行验收。
- 构建使用测试环境及`/aiassistant-api/`上下文。未重启真实8080、未发送短信、未发起真实多路外呼、未签名安装新包，也未改变Mac保留会话。
- Web仍有已有可选Cupertino字体构建提示，不将编译成功等同视觉校准。

授权真实联调后集中检查：

1. 以测试账号发起获准的多路需求：留在统一页，没有单路监听/挂断/音源页；逐项开始/失败/重拨按后端真实顺序更新，不重复显示。
2. 执行中退出到任务列表：后端不因页面关闭被挂断；结束后任务列表刷新。重新进入与新会话不混入旧流，恢复不发送新确认请求。
3. 网络中断、服务错误、仅Done无最终快照：已完成项保留，未知结果明确提示；没有自动重复POST或伪造费用。检查恢复后的ledger权威结果。
4. Android/iOS退后台、系统回收、恢复App和切账号：旧账号连接关闭，无旧消息/权限/确认弹窗晚到；系统回收后依赖历史恢复，不能把进程内保留当后台服务。
5. 结合后台按sessionId/commandId/batchId核对进度、最终ledger与积分结算。现有诊断记录不输出电话号码、通话正文或凭据；本批合成验证不替代后台真实收件证据。

剩余跨模块音频、真实媒体/通话、双端集中安装、旧数据OTA及视觉校准继续在总验收清单跟踪；不因此勾选完整迁移完成。
