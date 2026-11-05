# 首页、任务编排、列表与详情重构验证记录

## 基线与保护

- Flutter：从 origin/codex/dev 9a8d4e642ec1e892df4128992b84e8686233e732 创建 `D:/work/04phoneAgent/_isolated/phoneagent-task-flow`，当前开发分支 codex/refactor-conversation-task-flow；原 foundation dbb274f7 工作区不修改。未合入 dev_zys 翻译改动。
- 分支交付修正：此前4957a0ea、7899c78b、1b10805a、94991e52曾直接推送codex/dev。用户最新明确要求新分支、旧分支保留上版；已先将完整94991e52保存并核验于origin/codex/refactor-conversation-task-flow，再以精确提交号force-with-lease将origin/codex/dev恢复9a8d4e64。核验无其他人的新提交；后续仅推送新分支，原dev内容与提交身份均恢复，源码及既有测试结果不变。
- Android：fetch 后 origin/v71 98fe930638a452cdec74fce828ee0312142f98eb。对规划2c07940的差异为12个翻译文件，任务行为按该当前分支有效源码核对。
- Java：对应 origin/feat/v70-parity 4df226b8578cefdbfd5adc53ae4914a9ab226b77。原 v3 多项未提交改动受保护；本轮未修改后端、表、Redis、日志、提示词、SIP/ASR/TTS实现。
- 历史：origin/test/v65.0.1 Android 0f8879e4、origin/iOS/v1.0.46/dev bb9ff349，仅只读追溯。旧 Android 网络错误降级与当前仅明确无ledger兼容冲突，采用当前行为；旧iOS兼容展示不覆盖当前终态有效session可恢复规则。

## 对应源码与契约

相对路径分别以 aiassistant-app、aiassistant-java 的上述提交为根，避免本地旧 v4/v3 或历史 backend 当作最新契约。

| 能力 | 当前依据 | Flutter落点 |
| --- | --- | --- |
| 统一分页及资源身份 | app `data/remote/tasklist/TaskListApi.kt`、`data/repository/tasklist/TaskListRepository.kt`、`domain/model/UnifiedTaskListItem.kt`（均在app/src/main/java/com/vvtech/aiassistant/下）；Java `aiassistant-sdk-api/.../tasklist/controller/AssistantTaskListController.java`、dto与service/impl | ApiTaskRepository、TaskPageMapper、TaskRef、TaskController；默认15条，保留服务端顺序与置顶 |
| 详情与原会话恢复 | app `features/assistant/AssistantRootScreen.kt`、`features/assistant_shell/AssistantTaskNavigationActions.kt`、`features/assistant_tasks/TaskConversationListLoadController.kt`、`data/repository/timeline/ConversationTimelineRepository.kt`；Java agent-sse `assistant/history/api/ConversationTimelineController.java`、sdk-api `task/controller/TaskQueryController.java` | TaskDetailRepository/Controller/Page/Route；会话复用history/ledger，legacy映射detail，翻译沿用当前详情 |
| 事件与结束状态 | app assistant/viewmodel、assistant_tasks、assistant_lifecycle当前处理器；Java agent-sse当前事件/timeline投影 | EventFlow/SignalFlow复用既有协调器；账号/session/command/attempt隔离，SSE结束不决定成功，物理结束释放展示与输入 |
| 首页及跨页 | app `features/assistant_home/HomeConfigViewModel.kt`、assistant根入口及统一列表投影 | HomeController失败重试，ShellTaskNavigation入口防重、离线拦截、push前epoch绑定、返回刷新 |

网络先扩展既有AccountApi，不建立第二套请求客户端。支持字符串`000000`及既有数字0成功封装；任务路径使用Bearer及已有刷新合并，账号变化拒绝旧响应。HTTP契约：GET `/api/assistant/task-list/page?offset=0&limit=15&userId=...`；PUT `/items/{type}/{id}/pin`（pinned）、`/read`、`/read/clear`，DELETE `/items/{type}/{id}`（以上items路径位于task-list下）；GET `/api/task/detail/{id}`及既有会话detail/timeline。错误只暴露白名单code/retryable/recoveryAction，删除限制采用服务端结果。未改变其他模块业务或环境配置。

## 实际修改与验证

- 列表：刷新/分页代际、加载/空态/失败重试、去重、防重复操作、置顶/已读/删除限制。旧响应不覆盖新请求，补偿状态同步失败不阻止列表读取，停滞游标保留失败供重试。
- 详情：只读水合任务信息、历史对话、结果、关联回执/录音/评价，加载失败可重试，底部固定恢复入口，终态保持有效恢复。恢复同session；历史进入不重放外呼、权限、上传或工具。
- 对话/通话：拆分实时事件和交互分发，仍由原ledger及控制器持有状态。普通slot进度不误激活批量；当前attempt推送显示进度，500ms常规读回、健康outcomePush时10秒读回/45秒窗口，连续推送不推迟10秒读回。物理结束与服务端结果分离，挂断失败提示不被轮询清除；普通退出不自动挂断后台电话。
- 首页/边界：配置异常结束加载并重试；重复点击防重、离线先拦截；详情返回和对话返回刷新共享投影。详情push前捕获账号epoch，挂载前或请求中切账号均不加载旧任务；对话旧账号在准入前拒绝发送。令牌刷新保留控制器及草稿，失效释放页面/订阅。
- 固定SDK `D:/tools/flutter-3.32.0`（Flutter3.32.0/Dart3.8.0），锁文件未升级。OpenSpec35项通过；交付analyze无问题。定向网络/任务首批37项、列表/网络/历史56项；对话/权限/批量26项、详情/通话页9项、timeline13项、入口/账号/详情9项等通过。
- 首轮交付全量3305个success事件/17失败（可见testDone，含既有可选跳过），失败为旧直接导航断言、旧entry身份、离线入口与挂断失败轮询保留问题；逐项修复、定向复验。最终`flutter test --no-pub --reporter json`于776.186秒结束，退出0、done.success=true：3325通过、1个既有可选Agent文档测试跳过、0失败/0error；原始日志保留本地`build/task-flow-full-final-tests.jsonl`。
- 可选跳过随后单独启用验证：`flutter test --no-pub --dart-define=UI_AGENT_DOCUMENT=true --dart-define=UI_DOCUMENT_PARSE_DELAY_MS=10000 test/shell_agent_document_capture_test.dart`，1项通过。首次仅启用UI开关、解析默认立即完成，无法观测测试要求的“正在解析文件”而失败；核对既有预览解析延迟配置后按完整参数复验通过，未修改文档模块或测试来掩盖问题。
- 独立只读审查发现普通进度误判批量、分页游标停滞、旧账号准入和详情挂载前账号窗口，均修复并补回归；最后复核未发现新的Critical/Important问题。审查不替代测试或设备证据。

## 运行态与剩余风险

- Android调试集成APK构建成功（首次916.2秒，增量31.1秒）。原Resizable_Experimental模拟器存在原生Dev版本43，Flutter版本1的install-r被INSTALL_FAILED_VERSION_DOWNGRADE拒绝；未卸载/清数据，原firstInstallTime 2026-09-28 12:55:22和lastUpdateTime 2026-09-28 13:06:38不变。已创建独立空白PhoneAgent_TaskFlow AVD继续验证，避免覆盖原生数据。
- 独立PhoneAgent_TaskFlow（API37、16KB页、1080×2400）首启229.1秒，初次启动未完成时install-r返回空错误；复读boot_completed=1、无已安装包后仅重试一次成功。原原生模拟器已正常关闭，未清数据。
- task-flow设备脚本使用正式页面与隔离内存端口，并明确标记MOCK；显式install-r和use-existing-app/keep-app-running附加驱动成功。最终APK增量55.5秒；最终stage于2026-10-08 11:08:40 UTC通过：首页→对话→列表→只读详情→同session续接，执行异常详情/恢复、终态恢复、批量详情/恢复，不重放工具（命令总数保持2）。详情网络失败/重试、重复点击、账号切换及迟到结果另由定向自动测试覆盖。
- 三张最终设备图均已读取检查：`01-task-detail`（205406字节）、`03-failed-detail`（166706字节）、`02-batch-detail`（193795字节），均1080×2400；可见状态、历史/批量回执及底部恢复入口，无溢出。局部图不代表与全部原生视觉验收一致。证据位于忽略目录[设备结果](../../.local/shared-stage/task-flow/android/result.json)，构建/驱动日志保留本地build目录，不提交服务连接信息。
- 独立Dev包firstInstallTime始终2026-10-08 11:03:40，第二次保留数据安装后的lastUpdateTime为11:07:58（模拟器UTC）；附加驱动结束仍保持安装，未卸载/清数据。该结果是独立调试包导航证据，不是从原生应用升级/生产OTA证据。
- 当前无连接Android真机，无可用iOS/mac环境。本轮iOS仅共享Dart与平台主题自动测试；不得表述为iOS真实运行通过。
- 待真实验证：现网鉴权与任务接口联调、真实外呼、媒体/录音、后台电话与结果回传、Android生产签名/OTA及旧数据升级、iOS设备运行。不会用合成SSE、回执或模拟器成功代替这些证据。
- OpenSpec保持active，未归档；待上述运行态及用户验收。
