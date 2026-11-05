# 执行异常退出 / 恢复状态同步

## 本批完成范围（2026-09-21）

正式统一对话和任务列表已接入共享 Dart 状态补偿，不是仅实现测试类。保持普通退出不调用 interrupt、不挂断后台电话；本批没有调用真实状态写接口、发送短信、注销真实账号、安装新设备包或改音频。

固定依据：Android `4c781e3ccfcd148c1f205921534907ee0c5aa864` 的 TaskConversationExitResetController、TaskErrorRecoveryConfirmController、TaskErrorRecoveryPendingSyncUseCase、TaskErrorRecoveryStatusPolicy、AgentStreamSimpleResponseStatePolicy、TaskStatusContract；后端 AgentController / ConversationInterruptTransitionPolicy / ConversationInterruptApplicationService。

## 触发和流转

| 输入 | 处理 | 不做的事 |
| --- | --- | --- |
| 普通对话执行/网络失败 | 会话记录未恢复错误；退出时入队 `execution_error_exit` | 不自动重发用户需求 |
| 活动单路/批量通话流失败 | 保留现有通话/回执处理 | 不误作普通任务异常 |
| 恢复 NETWORK_ERROR / EXECUTION_ERROR 及 v65 别名 | 恢复错误标记；本地 pending exit 优先于尚未更新的详情 | 不因 GET 历史直接提交 recovered |
| 八种有效 signal/final 类型 | 清除当前错误；入队 `execution_error_recovered` | 不使用 delta / heartbeat / done 作为确认 |
| CALL_RESULT / BATCH_CALL_RESULT | 清除错误但不请求提升 RUNNING | 不把终态改为进行中 |
| 队列写盘成功 | 当前账号受保护 POST `/api/agent/conversations/{sessionId}/interrupt` | 不发送泛化 interrupt/reset reason |
| 请求失败 | 保留命令，退出触发/任务刷新/网络重新可用时重试 | 不无限自旋 |
| 请求返回成功 | 匹配命令才确认；包括后台保留 COMPLETED 的响应 | 旧回执不删除较新命令 |
| 列表同步 | 先补偿，再加载三来源；仅 pending exit 叠加异常，原始缓存不改 | pending recovered 不乐观显示 RUNNING；终态仍可恢复 |

八种业务类型：TEXT_REPLY、ASK_USER、SHOW_OPTIONS、REQUEST_PERMISSION、IMPORT_DOCUMENT_REQUEST、LOOKUP_CONTACT_REQUEST、LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST、MAKE_CALL_REQUEST。

## 代码所有权

- `TaskErrorRecoveryPolicy`：纯错误/确认规则；不持有 UI、录音、通话状态。
- `TaskErrorRecoverySession`：一页的租约，接 restore/failed/accept/close；关页不销毁账号级队列。
- `TaskErrorStatusSync`：账号队列、单飞、有界重试、最新命令匹配；新状态持久化不等待旧 HTTP 完成。
- `SecureTaskErrorStatusStore`：environment/API/account 的 SHA-256 槽位；schema 1，单槽 1 MiB，当前 isolate 同 key 跨实例串行更新。损坏/未知结构报错且保留原文件，不当作空队列。
- `ApiTaskErrorStatusGateway`：沿用 AccountApi；请求 reason/userId/commandId/idempotencyKey/traceId 固定，重试复用身份；校验同 session、非空规范状态。不是后台 exactly-once 的跨版本保证。
- `taskErrorStatusSyncProvider`：登录 epoch 变更销毁旧租约，页面释放 keepAlive；存储及 HTTP 都有旧账号保护。诊断只用操作/结果和白名单 ID，不保存文本或 token。
- `TaskController`：先调用补偿，再加载；根据原始来源重投影 pending overlay，失败仍保留上次列表。变化通知不额外发列表 HTTP。
- `ConversationRestoreFlow`：提取原历史恢复事务。父控制器 506 行例外已登记，不新增第二份消息或 UI 状态所有权。

## 已执行验证

- 35 项新增：7 策略/协议、10 队列、5 安全存储、5 HTTP、6 连续流程、2 正式 Provider。均使用明确合成端口，不读取真实账号数据。
- 最终 96 项定向测试约 7 秒通过：上述新测试，以及原 conversation controller、call receipt、call confirmation、contact lookup、task records、diagnostic journal/archive。没有全量回归。
- 导航/工作台/脱离批量 10 项通过（320/390/430 宽度按各用例覆盖），钱包 2 项及开发者列表 4 项通过；这属于 Flutter widget/VM 自动测试，不等于本批浏览器或手机截图验收。
- `flutter analyze --no-pub` 无问题，4.0 秒；OpenSpec 30 项验证及 diff 检查通过。
- 编写期发现并修正：测试包名误写、Future 清理回调返回自身导致等待、新增持久化前置后的测试等待时序及大括号 lint。最终验证不是用跳过失败用例取得。

## 尚未完成与集中验收

1. **网络恢复自动触发已接线**：TaskErrorNetworkRecovery 负责账号队列恢复、连续 available 去重、重连单飞与列表刷新。已登录 ShellRoute 挂载即建立监听，不等待打开任务/对话页；首页不额外发任务列表请求。Android 默认网络回调只读取 OS capability，iOS 使用 NWPathMonitor；不探测第三方 URL，不重发用户需求，不重启电话或音频。页面释放保留账号级监听，登出销毁；平台取消后以 generation/token 拒绝晚到事件。真实断网验证仍见第 3 项。
2. **Web 已完成本批连续演练**：下方记录浏览器实际操作；仅合成网络/服务，不能据此声明系统网络、持久存储或像素验收通过。
3. 阶段安装后验证同一账号：异常后退出、返回任务、断网重新联网、恢复回复；普通退出无 interrupt，通话中断网不误标任务；必要时通过授权测试环境制造错误，不能拿真实外呼随意重试。
4. 杀进程测试：命令持久化完成后重启应可继续补偿。持久化前断电不保证保留；存储失败会保留当前内存并记录失败，不能承诺 durable。
5. 已成功请求但删除失败：当前进程仅重试本地确认；进程重启沿用同一 commandId/idempotencyKey 再请求，核对后台幂等及终态保护。
6. **旧 Android 未绑定账号的 pending 集合不导入（用户2026-09-21已确认）**：旧 `index9_task_error_exit` 的pending/recovered不按新登录用户重放，原文件保留，任务以服务端最新状态为准。现有Store/Provider已符合，新Flutter有效队列持久化/重试保持；此项处置已关闭，不再作为待决策的兼容缺口，不代表真实生产升级已验收。
7. Android 普通 Dev 包恢复/登录与 iOS 当前包版本仍按既有阶段记录，本批不覆写其结果。iOS 网络链路另已实测：旧 `.49` 超时、主机名可连到 Wi-Fi `.51`、USB 和实时 Dart VM 正常。

## 网络恢复增量验证（2026-09-21 04:30 CST）

- 5 条共享恢复测试、2 条 EventChannel 适配测试、3 条正式 Provider 测试通过。新增 Provider 用真实正式队列和内存 API 验证一次失败 POST 后只刷新列表、不重复 POST；关页后继续补偿、登出后停止监听。
- 新增 1 条正式页面连续 widget 测试通过（390×844）：错误退出→任务列表→重连→恢复→业务确认→正常退出；仅显式输入两条用户命令，不自动重放。原合成端口 4 条、两宽完整 App 2 条、三宽导航 3 条均通过。
- 队列 10 条、任务列表 5 条、工作台 30 条定向通过；不是几千条全量回归。执行时误写一条既有测试路径，已改为实际 task_error_status_flow_test.dart 单独补跑；不把命令部分失败当整体通过。
- 最终 analyze 无问题（5.1 秒），OpenSpec 30 项通过。Android Debug 构建 26.0 秒通过；同批正式 lib 和网络 Swift 复制至既有 Mac 阶段目录，iOS Debug 无签名编译 49.2 秒通过。最后仅补共享 ShellRoute 首页监听后，复跑连续页/导航/完整App/目录共36条通过，Web重新编译；未重复双端打包，因此构建产物不含最后这一行共享接线。没有重新安装、签名、发送短信或改动手机运行中的 App；编译不能证明真实网络切换已验。
- 编写期修正：测试 import 位置、等待异步补偿完成的时序、合成 DRAFT 默认映射、外层 MOCK 控件被内层 Navigator 遮蔽的无障碍语义。失败用例没有删除或降低断言。

### 浏览器交互证据

入口：[隔离验收目录](http://127.0.0.1:8122/) →「异常退出与恢复」。正式 main 不导入 tool 目录，真实 8080 App 未操作。

| 实际操作 | 可见结果 |
| --- | --- |
| 首页订餐厅→MOCK 断网→切文字→输入“网络恢复验收”并发送 | 保留内容，显示网络中断且不会自动重发 |
| 关闭对话→任务 | 返回首页再进入任务，新任务“执行异常”；状态请求 1→2（退出和列表各触发一次） |
| MOCK 恢复网络 | 请求 2→3，任务仍异常：联网不冒充已有业务恢复 |
| 点击同一任务→切文字→输入“继续补充” | 历史保留；收到 MOCK 有效回复，请求 3→4 |
| 普通关闭 | 返回任务，新任务“进行中”，请求保持 4，无新增异常中断 |

已查看目录、异常任务、续聊对话、恢复后任务四处浏览器截图；截图内文本/按钮/状态/底部输入区可读、无阻断性裁切，error 日志列表为空。截图为本任务工具内联证据，未保存为仓库 PNG；可通过上方同场景复跑。控件不是坐标覆盖层：正式 Button/输入/列表和路由实际执行。常驻黄色工具条是 MOCK 宿主，非产品 UI；模拟服务只在内存保留状态，退出场景重置。

视觉精校按用户决定后置，`VISUAL_CONTRACT_COMPONENT_COVERAGE_MISSING`；没有本批逐参数设计对比、OS 键盘/系统栏及真机断网/进程重建通过声明。新增场景完整步骤已自动化，不扩大为其他页面或整机验收结论。

本 change 5/6 项完成，尚不归档；整体 Flutter 迁移目标未完成。
