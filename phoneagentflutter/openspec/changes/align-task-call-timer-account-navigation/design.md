## Context

基于 codex/dev 的现有任务外呼与设置流程。CallSessionController 已按 session/attempt 验证推送并投影到 CallProgress，但 CONNECTED 没有保留；ConversationCallController、文案和监听只认 snapshot.CONNECTED。已有归零测试仅覆盖查询先到。用户已批准本设计并要求实现、测试、中文提交推送，不打包。

## Goals / Non-Goals

目标是统一接通事实、首次归零与账号入口位置。保持正常挂断、结果观察、音频权限及计费边界；延迟优化和服务端变更不在范围内。

## Decisions

1. 在 CallProgress 保留单次通话的 connectedObserved；仅已有合法 CONNECTED 推送/快照能建立，字幕、launchReady 和预览不能代替接通。CallSessionState 提供统一 connected getter，兼容已有快照构造。
2. 控制器等待期不启动计时，首次 connected 才归零并启动。重复推送和迟到 DIALING 不撤销接通事实；新观察沿用已有 dismissCall 清理全部计时与身份，终态继续停止。
3. CallPresentation、CallSessionPage 与 ConversationCallHost 复用统一 connected；不改变监听的用户操作、音源或前后台停止约束。
4. SettingsPage 移除账号行，AboutPage 在更新项之后增加账号管理回调，AboutRoute 接原 AccountRoute，AccountPage 标题一致。系统返回和页面返回均回到关于页，登录失效继续按原路径回登录页。

## Files / Micro-batches

- 状态批：call_progress.dart、call_session_state.dart 与状态回归，职责是事实投影。
- 展示批：conversation_call_controller.dart、call_presentation.dart、conversation_call_host.dart；随后 call_session_page.dart 与对应回归。控制器虽已超过行数信号，本批只替换判断及删除提前计时，不扩充流程或顺手重构。
- 设置批：settings_page.dart、about_page.dart、about_route.dart；随后 account_page.dart、settings_route.dart 和导航回归。UI 只回调，route 负责导航，原账号控制器不变。

## Risks / Trade-offs

跨通话旧推送 -> 保留既有 session/command/attempt 过滤并回归。结束后迟到事件 -> 保留关闭和终态门禁。隐藏等待秒数是用户本次批准行为，原计时测试预期需同步。关于页新增项改变旧“更新最后”断言，更新为“账号管理最后”并保留更新能力。

## Validation

先执行新增回归观察 RED，再按微批实现。覆盖等待、推送先到、查询先到、重复连接、旧 DIALING、错身份、连续两通、终态停表、页面重建以及关于页顺序/返回/账号操作。执行定向 flutter test、flutter analyze、OpenSpec 与 UTF-8/diff 检查，最终独立只读复核。只说明自动测试证据，不声称真机验收。
