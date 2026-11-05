# 开发者网络入口：实现与集中验收

## 最新：双端真实OS取样与共享入口控制（2026-09-18）

2.2d1在原模拟入口上接入真实只读输入。下方“仅模拟、真实联网待接”的说明是前一批历史，不再代表当前实现；列表/当前定位摘要/模拟权限消费者与双端真机仍未完成。

| 平台 | 薄端口与结果 | 不做的事情 |
| --- | --- | --- |
| Android | NetworkAvailabilityChannel：读取activeNetwork，INTERNET且VALIDATED才available；缺网络/能力为unavailable，读取异常unknown | 不新增权限弹窗、不读SSID/IP、不发HTTP；已有ACCESS_NETWORK_STATE |
| iOS | NetworkAvailabilityChannel.swift：NWPathMonitor等首回调；satisfied为available，unsatisfied为unavailable，requiresConnection为unknown；2秒超时unknown | 不用未初始化currentPath断言离线；每次回调/超时/engine detach停止本次monitor，不探测任意地址 |
| Web/其他 | UnknownNetworkAvailability，依然保留真实请求错误处理；演练单独注入合成source | 不使用navigator.onLine硬封锁开发页面，不假造系统online |

Android沿固定v65 `ValidatedInternetAvailability.kt`；iOS参考ddb996a的开发者页面只发现选项存储，未发现自有业务reachability消费者，不继承无消费者的旧配置。技术边界参见[Android网络能力](https://developer.android.com/reference/android/net/NetworkCapabilities)、[Apple路径监测](https://developer.apple.com/documentation/network/nwpathmonitor)、[浏览器联网标志限制](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/onLine)。网络路径可用不是目标API可达，更不是业务成功。

共享实现：`domain/network_availability.dart`明确三态及准入结果，`presentation/controller/online_entry_controller.dart`管理一次入口租约、单飞、3秒兜底、模拟优先、关闭/晚到保护；源失败/超时保持unknown，允许原业务尝试，不伪报available。UI使用重命名后的`widgets/online_entry_guard.dart`，不直接调用平台。`app/online_entry_providers.dart`显式声明作用域依赖，source变化关闭旧控制器。

正式消费者仍为首页、统一会话/恢复、联系人需求、翻译呼叫；普通系统拨号不调用检测。检查期间重复点击不重复进入，路由返回和Shell切Tab后旧结果不得导航；离线弹窗重试重新取样，恢复后只关闭提示，必须再次点击原入口。当前会话/HTTP/媒体不因OS事件被强制关闭。本功能无后台状态订阅和额外探测HTTP，也不取代请求超时/重连。

MOCK来源在`preview_network_availability.dart`，同一演练页增加系统在线/离线/未知及检测异常；计数仍不创建真实会话/电话。翻译准入合成宿主也覆盖新source，不能越界调用原生；父容器已读后的子覆盖有回归。旧纯模拟guard文件已改名并迁移消费者，可通过git历史追溯，不保留两套门禁。

本次验证：19项新增（纯Dart、通道和页面）、1601项全量测试通过，analyze无问题、723个Dart文件格式检查无变化；Web/Android Debug/Mac iOS无签名构建通过。浏览器8101验证系统离线→重试仍拦截→关闭→在线再次进入计数1→unknown进入计数2→异常进入计数3。没有真实API/短信/电话/新安装，也未修改8080登录或Mac保留screen。

### 新增集中真机验收

1. 取得阶段安装授权后，在两端已登录包中保持开发者模式“正常”。断开蜂窝/Wi-Fi后点首页有效Skill或任务恢复：应出现系统网络提示，不创建对话。恢复网络后点重试仅关闭提示，再次点原入口才进入。
2. Android另验连接需认证/无互联网Wi-Fi：没有VALIDATED时不放行；普通拨号仍可交给系统（真实拨出另需授权）。不要将Wi-Fi连接图标当作有互联网证据。
3. iOS另验启动首回调、飞行模式、Wi-Fi/蜂窝切换和requiresConnection路径。未知允许业务尝试并由真实请求显示成功/错误，不能假报网络在线。检查Xcode日志是否出现重复FlutterResult、未释放monitor或插件错误；构建通过不能证明这些运行态已验收。
4. 检查中连续点击/返回/切任务Tab，结果不得打开旧页面；离线弹窗重复重试需单飞，检查中关闭后可再次发起入口。Android/iOS系统回收和重启后仍遵守进程内模拟默认正常。
5. API服务故障但OS路径可用时，必须由原请求错误流程处理；不得因本检测通过显示假成功或自动重复写入。Web用合成页测门禁、用既有真实请求错误流程测浏览器网络，不更改用户OS网络做自动演练。

## 前一批：开发者模拟模式与入口

2026-09-18；固定行为源 Android `4c781e3`；OpenSpec `settings-interactions` 2.2c。先完成可操作页面/状态/导航，视觉差异统一后校准。本文件不是开发者全部能力或完整迁移完成报告。

## 行为证据与边界

| v65 源码 | 确认行为 | Flutter 本批 |
| --- | --- | --- |
| AssistantPermissionOverlayState / AssistantDeveloperPermissionPageHost | 正常、弱网、断网本地三态；弱网仅Toast | 进程内共享模式、ChoiceChip、提示，不写磁盘或OS网络 |
| AssistantOnlineEntryNetworkGuard / AssistantRootActionGraph | 在线入口按模拟断网或系统未validated拦截 | 本批只接模拟输入；真实系统联网检测仍为2.2d |
| AssistantVoiceEntryRootActions / AssistantRootTaskFlowActions | 新统一页/恢复入口调用网络门禁 | 首页、任务恢复和联系人Skill选择后拦截，不创建控制器/发会话 |
| AssistantRootCallEntryActions | 翻译流程检查；普通系统拨号不检查 | 翻译呼叫检查；普通拨号保持原逻辑，无自动降级电话 |
| AssistantOverlayPermissionActions / V88NetworkStatusLayer | 断网重试保留提示，其他模式只关提示；可点外部返回 | 共用弹窗、关闭/系统返回，正常重试不自动重放业务 |

不模拟HTTP超时/带宽/丢包，不取消已有会话或媒体。切正常不保证真实网络可达；现有HTTP错误处理不变。没有新增网络请求、后端接口、数据库、权限、SIP/ASR/TTS操作。

列表和权限的边界另行追踪：`AssistantDeveloperDataModeActions` 清本地通话/联系人，不是后台任务删除；`AssistantRootHostArgsShell` 的模拟权限重置还会重开翻译拨号并重置定位提示，不等于撤销OS权限。这两项及开发者当前定位摘要未在本批实现，2.2父任务不勾选。

## 实现位置

- `lib/features/settings/domain/developer_network_mode.dart`：纯Dart模式及入口拦截判断。
- `lib/app/developer_network_providers.dart`：进程共享单一状态；普通运行默认正常。
- `settings/presentation/widgets/developer_network_controls.dart`：复用控件与三态提示。
- `settings/presentation/widgets/developer_network_guard.dart`：模式检查、共享弹窗和“不重放”返回语义；只读取Provider，不调用网络/系统服务。
- `shell_route.dart` / `contact_actions.dart` / `translation_dialer_route.dart`：正式消费者。路由和弹窗显式继承原Provider容器，避免Navigator越出作用域。
- `developer_network_preview_page.dart`：新模式作用域+同一控件/门禁；通过次数仅是MOCK计数，不创建真实会话/电话。
- `translation_access_preview_page.dart`：正式开发者页的合成宿主也覆盖网络模式，不能修改外层正式状态。

Android/iOS/Web共用Dart，本批无新增原生适配或依赖。开发者解锁规则不变；模式只影响后续入口，不是鉴权。单文件均低于500行。

## 自动验证

- 新增8项，全部1,582项 `flutter test` 通过；`flutter analyze` 无问题；719文件格式检查无变更；OpenSpec19项通过。
- 新测试覆盖320/430宽度、四类MOCK入口、普通拨号例外、重试/关闭/返回、不重放、父容器先读后的子作用域、进程隔离；正式首页/已完成任务恢复/联系人Skill/翻译拨号均验证阻止下游消费者。
- 既有普通拨号测试改在模拟断网下执行，仍只调用注入的假系统拨号端口；不涉及真实手机。全量首次失败是320×480旧测试未滚动到新列表位置，修正滚动定位后重跑全量通过，未改业务来迎合测试。
- Web release、Android Debug、Mac iOS Debug无签名构建通过；iOS为 `com.chaken.phoneagent.test`。构建不是签名安装/真机验收。
- 浏览器8101：父合成设置断网→子演练默认正常，新对话计数1→断网任务恢复弹窗→重试仍拦截→普通拨号MOCK计数1→弱网翻译入口计数2→返回父仍为断网。全部内存操作，无真实账号/API/位置/电话。

本轮未重启8080真实登录实例，没有新短信、真实配置更改、新真机安装或Mac钥匙串/保留screen变化。

## 集中人工验收步骤

1. 在已授权阶段包中解锁开发者功能，切断网，分别从首页有效Skill、任务列表（含已完成会话）、联系人需求进入：应显示“无网络连接”，不得进入新对话/发Agent请求。
2. 重试应继续拦截；返回/关闭回原页。切正常后需再次点击原入口；不能自动创建会话、提交任务或拨电话。
3. 弱网只提示，新在线入口可进入。不要用它验证真实丢包、带宽或断线重连。
4. 打开翻译拨号并点击翻译呼叫：断网应拦截；真实翻译媒体仍未装配，正常放行不能代表翻译可用。普通系统拨号按原确认流程且不因模拟断网受阻；只有授权真实电话时才继续系统确认。
5. 重启App，网络模拟回正常；分别在Android/iOS检查返回、弹窗和竖屏布局，不要求系统视觉完全相同。真实OS断网/恢复在2.2d接入后另验。
6. 从MOCK网络入口演练切模式再返回，正式状态不变；演练没有会话ID/通话ID、后台写入或系统权限请求。发现意外下游调用即失败，不以MOCK计数替代证据。

尚待：真实联网薄端口、列表/位置/模拟权限消费者、双端阶段安装、其他媒体能力与统一视觉校准；完整目标保持进行中。
