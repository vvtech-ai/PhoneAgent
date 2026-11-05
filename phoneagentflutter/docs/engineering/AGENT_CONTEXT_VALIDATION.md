# 对话时间与权限快照：实现及集中验收

2026-09-18；settings-interactions 2.2d3。沿固定 v65 行为；页面交互优先，视觉后统一校准。本批不是整个迁移完成报告。

## 已确认的契约

- Android `AssistantUserContextHolder.currentTimePayload/currentPermissionStatusSnapshot` 在普通轮次和动作续接提供当前时间与权限。后端 `AgentService.appendCurrentTimeContext/resolveCurrentDate` 按 ISO_OFFSET_DATE_TIME 解析本地日期。不能硬编码北京时间或把服务器时间当设备时间。
- microphone、contacts、location 的已授权为 `OK`，未授权为 `NOT_GRANTED`；取样失败/平台不可用为后端支持的 `UNAVAILABLE`。定位精确或近似任一可用均按可用；document_picker 由系统选择器交接，不申请全盘文件权限。
- 只读快照与权限工具的用户授权流程分开。发送文字不自动申请权限、不采集录音或联系人；开发者模拟状态不能充当 OS 事实。
- 指定 iOS 参考提交未发现等价 Agent 上下文，采用共享 Dart 契约，不把播放器 currentTime 当作设备时间。旧预留联系人字段没有现用入口，不随 DTO 历史字段复活。

## 实现路径与边界

`conversation_providers` → `DioAgentGateway.userContextProvider` → `AgentContextBuilder.prepare` → 已有位置 Controller → 并发读取设备时钟和四项权限 → 合并 userContext → 重验账号/取消 → 原 Agent HTTP。

- `domain/context/agent_clock.dart`：验证 epoch、偏移和时区，编码含偏移的 ISO 时间。Android/iOS 的 `DeviceClockChannel` 只回传当前 epochMillis/offsetSeconds/timezone；每轮重读，支持系统时区/DST 变化。
- Web 条件实现从浏览器 Intl 获取时区，不走原生。读取失败用 Dart 当前时间及明确数字偏移，不能伪造地区。依据 [Dart JS interop](https://dart.dev/interop/js-interop/usage) 与 [Intl resolvedOptions](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/DateTimeFormat/resolvedOptions)。
- `AgentContextBuilder` 先等待原有有界位置，再取新时间，避免位置等待跨午夜导致旧日期。时钟和权限每项最多等待 2 秒；单项失败不抹除其他结果。没有新权限缓存、磁盘记录或敏感字段日志。
- `agent_context_providers.dart` 按登录代次销毁旧 builder，权限源与正式工具共用；关闭后丢弃未完成结果。Gateway 等待后再次检查账号及 cancel，不发送迟到 POST。OCR、首轮技能、工具结果与幂等 ID 不变。
- 当前实现没有新增后端协议/数据库/提示词或 ASR/TTS/SIP 行为。

## 自动验证

- 新增 18 项 VM 测试：跨日与五种偏移、畸形数据、每轮刷新、位置等待顺序、单项失败/超时、关闭与账号切换、native 只读参数、Web 不调用 native、Dio 普通/工具真实序列化以及合成页面。
- 全量 `flutter test`：1,635 项通过。增加入口后，历史录音入口测试首次滚动落在屏外；补 settle/ensureVisible 后定向及全量复测通过，未改业务。
- Chrome 纯 Dart 专项 1 项通过，实际调用浏览器 Intl 并校验 epoch/偏移。最初 Flutter Chrome 测试卡在加载，已停止该测试进程，改用不依赖 Flutter 引擎的 `dart test ... --platform chrome` 验证纯 Dart 浏览器模块；不把前次卡住记为通过。
- `flutter analyze` 无问题、747 个 Dart 文件格式无变化、OpenSpec 19 项通过。正式 Web、Android Debug、Mac iOS Debug 无签名构建通过；没有安装到设备。
- `tool/previews/agent_context_preview.dart` 独立 8103，复用正式组装器、全部输入合成。浏览器确认初始 +08:00，切换 Kathmandu +05:45、推进一天、权限读取失败后第二轮输出新日期及 UNAVAILABLE，document_picker 仍 OK。可从开发者演练入口访问；不发真实 HTTP、定位、短信或权限请求。

## 集中真机验证（取得阶段安装授权后）

1. Android/iOS 先保持原账号登录，发送一轮文字或权限工具续接；服务端收到 currentTime/permissionStatus，原 OCR/技能/工具身份仍完整。查测试环境关联 traceId/sessionId，不把请求正文、位置或凭据粘贴到公共文档。
2. 在系统设置手动改变时区后再提交；偏移、时区和本地日期应一致，不沿用前轮时间。覆盖跨日、正负偏移和非整点时区；验完恢复原系统设置。
3. 分别拒绝/允许麦克风、联系人、定位；只读提交不能弹出授权框。通过原权限工具授权后，下一轮读到新状态；Android 近似定位、iOS limited contacts 的可用语义保持现有端口逻辑。
4. 不授予全盘文件权限时 document_picker 仍 OK；这是选择器能力，不代表可以随意读取设备文件。Web 其余原生权限为 UNAVAILABLE，不冒充浏览器已授权。
5. 快照等待时返回对话或退出账号，不得出现迟到请求/旧账号数据。失败或超时后原文本流程继续，无无限等待、无自动重复 POST。
6. 日志只保留既有结构化 Agent 事件与关联 ID；不新增经纬度、联系人、令牌或完整上下文日志。失败信号：迟到请求、误报 OK、时间偏移错误、权限弹窗、OCR/工具字段丢失。

## 仍待完成

双端运行态验收、开发者列表本地记录清空/模拟权限重置、真实媒体能力、正式 OTA 旧数据升级及统一视觉校准仍独立跟踪；不因该子项完成而关闭父任务或迁移目标。
