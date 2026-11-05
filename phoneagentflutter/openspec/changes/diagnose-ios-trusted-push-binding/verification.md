# 2026-10-22 本地验证与复测说明

基线：PhoneAgent codex/dev，HEAD 6f0fcec0；修改前工作区干净。本次只修改本 Flutter 仓库的桥接、白名单、测试与专项规格，不修改供应商源码或其他仓库，不提交推送，不安装设备。

## 结果

- 供应商 BJ_3.5.0/KXSSDK：bindRid 包含 apnsDeviceToken；服务端 code=1 映射为 callback status=1。当前桥接使用 callback code==1 判成功，与供应商实现一致。
- 原 diagnostics.jsonl 32 无可信推送事件，不能判成功或失败。缺失原因未确定，不把日志过期或订阅时机假设当作现场根因。
- Foundation：push_binding_state、push_binding_driver、push_registration、incoming_diagnostics 四程序通过，使用合成数据，无真实 APNs/SDK。
- Dart 脱敏专项 5 项通过；可信目录 145 通过、1 失败。失败：trusted_caller_settings_flow_test 的 iOS 缺 SDK 场景在销毁后残留 Timer；单独重跑仍失败，不改变产品 UI。
- flutter analyze 无问题；OpenSpec strict 验证通过；git diff --check 通过。
- Xcode 真机 SDK Debug arm64 的 PhoneAgentTrustedCaller target 编译成功，包含本次 Plugin、PushRegistration、Driver、State。
- 完整 Runner 构建失败：Pods/Manifest.lock 与 Podfile.lock 不一致（崩溃诊断依赖差异）。未运行 pod install 或改变依赖锁，不把插件编译称作完整 App 构建。
- 本次没有取得修改后真机运行证据，不能宣布真实 Token 已设置成功，也未验证推送送达。change 保持未归档。

## 新日志判读

构建诊断级别需 INFO 或 DEBUG；WARN/ERROR 沿用既有过滤，不保证保留成功/快照事件。登录目标账号后恢复 App 前台，再通过原日志上传入口取日志，筛选 operation=trustedCaller、stage=pushBinding。

| code | 证据含义 |
| --- | --- |
| IOS_APNS_TOKEN_RECEIVED | 系统已返回格式合格 Token，尚不代表 SDK 绑定成功 |
| IOS_BIND_STARTED | 已调用 SDK 绑定 |
| IOS_BIND_SUCCEEDED | 本次 SDK 绑定回调成功码 1 |
| IOS_BIND_STATE_CONFIRMED | 当前完整账号/登录代次/环境/Token 与本进程成功回调确认的一致，无待清理请求 |
| IOS_BIND_STATE_PENDING | 绑定或解绑请求尚未返回，不自动重发 |
| IOS_BIND_STATE_UNCERTAIN | 请求失败，远端是否生效未知，保留原显式重试门禁 |
| IOS_BIND_STATE_INITIALIZING / INIT_FAILED | 初始化中 / 初始化失败 |
| IOS_BIND_STATE_UNCONFIRMED | 尚无当前身份成功确认 |
| IOS_BIND_WAIT_OWNER / PERMISSION / TOKEN | 等待账号 / 通知权限 / Token |

快照 result 固定为 received，表示只读观察；不是新的服务器查询或推送送达证明。旧账号成功不得生成当前账号 CONFIRMED。快照不导出账号、号码、Token、SDK 返回正文，不修改通知权限、绑定/解绑参数、重试规则或 UI。
