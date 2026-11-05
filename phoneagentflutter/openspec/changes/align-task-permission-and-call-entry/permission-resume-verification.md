# 定位权限与播报续接验证

## 范围与责任

基线为 `codex/dev` 的 `8756f449`，本记录对应任务 1.1、1.2，及与展示代理协作的真实授权结果接线。只修改 Flutter 权限 domain/data、既有 Android/iOS 权限通道、权限动作与播报生命周期接线及定向测试。没有修改原生参考仓库，没有提交、暂存、推送、打包、安装或真实业务操作。

知识库导航已读，导航的 OMS 模块不作为本项目事实；项目以 Flutter AGENTS、迁移基线、当前 change 四类工件、voice-protocol 及 AI 开发流程规范为准。

## 实现与边界

- `TaskLocationPermission` 用 session/command 区分同轮重投与后续用户意图。附近、周边及“你重新获取定位呀”等新明确意图可重新检查和申请；明确拒绝不弹，同 command 与预检后同轮工具仍防重。
- `ConversationPermissionResume` 为纯 Dart 权限生命周期 owner，预检与权限工具共用同一实例。临时 inactive 等 resumed，paused/hidden/detached 使待续接代次失效并取消对应 stream；回前台不重放、不自动重试、不启动 ASR。离页解除绑定时也失效待续接。
- `ConversationActionFlow` 仅在有效 permission_result 开始时恢复新播报轮次。真实结果经展示代理的 `ConversationPermissionPresentation` 更新本地卡片，不制造 ledger 事实。仅 location 的 SETTINGS_REQUIRED 写入共享 notice 常量。
- `ConversationOutcomeFlow.complete` 先检查代次再完成 recovery/播报，旧流结束不能 seal 新轮。原控制器收尾职责移入既有收尾 owner；Controller 格式化后仍为 508 行，保持原编排例外，架构测试通过。
- `PermissionGrant.blocked` 区分永久拒绝；Android 以已实际请求记录与 rationale 判定，iOS 读取各权限真实拒绝状态。blocked 不再请求系统弹窗，回传 SETTINGS_REQUIRED。账号上下文映射保持 NOT_GRANTED，没有新增 HTTP 契约。
- 可选 `ConversationPermissionSettingsSource` 保持现有 fake/source 兼容。DevicePermissionChannel 复用既有 translation_location/openSettings，先注册生命周期监听，实际离开并 resumed 后才返回；失败或超时清理监听。打开设置本身不视为授权，实际回读及主动新意图由 root 的入口/路由协调器负责。
- 按 root 确认，本次不改变系统定位服务关闭的语义，沿既有 location null 处理，不把服务关闭冒充 App 权限拒绝。

## RED / GREEN

| 验证 | RED 证据 | GREEN 证据 |
| --- | --- | --- |
| 拒绝后新 nearby 与口语重新定位 | `permission-resume-location-red.log`，2 失败，实际只请求 1 次而期望 2 次 | `permission-resume-location-green.log`，10 通过 |
| blocked 平台结果解码 | `permission-resume-blocked-red.log`，1 失败，FormatException | `permission-resume-blocked-green.log`，16 通过 |
| 成功/拒绝的完整中断与续接播报 | `permission-resume-speech-red.log`，2 失败，只有旧播报没有新轮 | `permission-resume-speech-green.log`，7 通过 |
| 实际 VoiceHost inactive/后台 | `permission-resume-lifecycle-red.log`，2 失败，inactive/后台提前发送续接 | `permission-resume-lifecycle-green.log`，9 通过 |
| 原生请求返回永久拒绝 | `permission-resume-permanent-red.log`，1 失败，误报 DENIED | `permission-resume-permanent-green.log`，15 通过，含展示代理结果 2 项 |
| 设置等待实际 resumed | `permission-resume-settings-red.log`，1 失败，原返回过早 | `permission-resume-settings-green.log`，6 通过 |
| 预检原生弹窗的前台等待与播报 | `permission-resume-preflight-red.log`，1 失败，失焦时发送首请求 | `permission-resume-preflight-green.log`，21 通过 |
| 设置失败/超时清理、旧完成不 seal、架构 | 补充回归 | `permission-resume-guards-green.log`，7 通过 |

日志均在仓库忽略目录 `.local/`，无 token 或真实业务数据。

## 最终定向验证

固定 `D:/tools/flutter-3.32.0/bin/flutter.bat` / Dart 3.8.0。

2026-10-16 执行 `flutter test` 下列 15 个目标，**94 项全部通过**，日志 `.local/permission-resume-regression.log`：

- `test/features/conversation/task_location_permission_test.dart`
- `test/features/conversation/conversation_permission_test.dart`
- `test/features/conversation/device_permission_channel_test.dart`
- `test/features/conversation/permission_settings_return_test.dart`
- `test/features/conversation/permission_resume_lifecycle_test.dart`
- `test/features/conversation/permission_outcome_guard_test.dart`
- `test/features/conversation/permission_conversation_flow_test.dart`
- `test/features/conversation/conversation_controller_test.dart`
- `test/features/conversation/agent_context_builder_test.dart`
- `test/features/conversation/agent_context_provider_test.dart`
- `test/features/conversation/apology_opening_speech_test.dart`
- `test/features/conversation/voice/conversation_speech_controller_test.dart`
- `test/features/conversation/voice/result_speech_controller_test.dart`
- `test/features/conversation/permission_result_presentation_flow_test.dart`
- `test/architecture_test.dart`

实际 VoiceHost 合成生命周期验证了权限工具与首请求预检两条路径；尚不代表真实 Android/iOS 系统弹窗、后台或音频运行验收。原有 malformed 会话测试会输出预期的 session=s 失败诊断，对应断言通过。

格式化覆盖本 owner 的 15 个 Dart 文件及新增回归。文本使用 UTF-8，中文已读回；最终严格编码及 diff 检查结果由 root 集成记录汇总。

## 待验证与交接

- root 负责统一 analyze、全 change/直接调用方回归、独立复核及 OpenSpec/tasks/issue log 汇总。
- Android 通道将在 root 统一 Release 中编译，按 root 指示没有另行 compileDebugKotlin 或生成 Debug 包，避免插件注册混杂。
- 当前 Windows 无 Xcode，iOS Swift 编译及双端系统权限/设置/真实音频等待可用设备环境验证。
- settings 路由回读、首页入口与 Page 主动操作由 root/展示代理持有，详见各自验证记录。

## 独立复核 P2：过期预检 Future 复用

独立复核发现后台取消只使生命周期 epoch 失效，旧原生 Future 未完成时，原 session pending Future 仍会被新附近意图复用；旧 callback 还可能改写新轮拒绝缓存。先新增 `task_location_permission_owner_test.dart`，保留旧 pendingCheck/request 未完成后执行 background→resume→新 command，RED 三项均失败；日志 `.local/permission-resume-owner-red.log`。补充 `isPending` 仅应报告有效 owner 的断言，另见 `.local/permission-resume-owner-pending-red.log` 两项 RED。

最小修复只涉及两个纯 Dart domain 文件：`ConversationPermissionResume` 暴露只读 generation；`TaskLocationPermission` 将 pending 记录为包含有效谓词的 attempt，新请求只共享有效 attempt，结束时只删除同一 attempt；缓存回写校验 turn、binding、generation 和调用方 current，过期结果不写入新轮。原生请求仍由原通道管理，未取消、清空或绕过系统 pending/busy 保护。

新 owner 三项 GREEN；重新执行上述原 15 目标并加入 owner 测试，**16 个目标共 97 项全部通过**，日志 `.local/permission-resume-owner-regression.log`。两个 domain 与新增测试已格式化，Controller 仍为原 508 行；补充 strict UTF-8/中文读回与 diff 检查通过。生产文件再次停写，交 root 复核及最终集成验证。

## 复核追加：旧逻辑 token 与全部联系人入口

第二次独立复核发现旧原生 Future 未完成时，Resume 内部 `_pending` 仍残留：background 取消一次，resume 后普通输入不运行权限，再次 background 会错误取消普通轮。新增纯 domain 测试保留旧 Future 未完成，RED 为 abandon 计数实际 2、期望 1，日志 `.local/permission-resume-token-red.log`。最小修复仅在 `ConversationPermissionResume.background` 清除已失效逻辑 token 一行，不触碰原生 pending/Future 或 busy 保护。新回归与原 97 项重新执行，**16 目标共 98 项全部通过**，日志 `.local/permission-resume-token-regression.log`。

按用户“所有入口包括联系人”的补充要求，对 root 新增的 `contact_actions.dart`、`shell_task_navigation.dart` 和 `task_entry_permission_guard.dart` 做只读复核。联系人 origin Route、账号 epoch、sheet finished 防重与共享 Route singleflight 已覆盖旧页面返回/切号/重复操作。发现设置返回后的异步回读期间再次后台缺少前台守卫，已反馈 root，由 root 在同一 settings helper 补充生命周期保护及正式 RED/GREEN；此处没有修改 root 的生产文件或新测试。

执行 `flutter test test/features/contacts --reporter expanded`，**171 项全部通过**，日志 `.local/permission-resume-contacts-regression.log`，未修改联系人旧测试，也未通过生产默认授权掩盖门禁。root 设置守卫最终差异另按主线程验证记录复核。
