# 首页入口快照验证（2026-10-20）

## 来源与实现

Flutter 基线 `codex/dev@8445d06f21f04d3511498b73aa16d7d32bc39867`。随包卡片复用原 `HomeConfigDefaults`；五条启用普通 Skill 开场逐字取自 `test/v66.0.3@a0bedb12` 的 `backend/src/main/resources/skills/restaurant-booking.md`、`meeting-notification.md`、`event-invitation.md`、`sales-recommendation.md`、`meeting-notification-v2.md` 的 opening frontmatter。道歉不复用普通开场，继续专用 Consent。

生产修改仅：home_defaults（完整随包内容）、home_config_mapper（普通入口完整性）、dio_home_repository（缓存优先/后台单飞/关闭失效）、home_controller（快照先发布/标语异步），business_providers 的 homeRepositoryProvider 增加 loginEpoch 依赖。公共配置缓存 namespace 保留，权益、模型、版本、在线与麦克风门禁不变。

## RED 与回放

固定工具 `D:/tools/flutter-3.32.0/bin/flutter.bat`，所有 test/analyze 使用 `--no-pub`。

- 首批四条测试在生产修改前 RED：默认 restaurant 开场为空；网络未返回时缓存尚未发布；500 丢弃有效缓存；slogan 未结束时 snapshot 仍为 builtin。
- mapper 的缺普通开场输入原本被接受，独立 RED 后增加完整性校验。
- 真实 ProviderContainer 在账号 epoch 改变后仍返回同一 HomeRepository，独立 RED 后增加正式 provider 的 epoch 依赖。
- 最终新增 **12 条唯一用例**：随包五开场同快照；缓存早于网络；500 保缓存；slogan 不阻塞；mapper 完整性；正式 provider 账号替换；传输异常被消费；损坏缓存兜底；慢写不阻塞且单飞；关闭后旧响应零写入；坏后台快照保留旧缓存；缓存读取 pending 时点击 HomePage 并经真实 ConversationVoiceHost 仅播一次。

## 命令与结果

- `test --no-pub test/features/home/home_snapshot_readiness_test.dart test/features/home/home_snapshot_lifecycle_test.dart test/features/home/home_repository_test.dart`：最终 **19/19 PASS**（12 新增 + 7 原 repository）。
- 原 repository 保留并验证 SDK 路径、签名、无 Authorization、图片前缀/安全校验、minClientVersion、304/If-None-Match；200 先写后台缓存、下次 load 生效；500 保留原版本。测试通过真实 `refreshPublished` 单飞 Future 等待操作结束，不用固定时长假定 HTTP 已处理。
- `test --no-pub --reporter json test/features/home test/features/contacts/contact_skill_opening_parity_test.dart test/features/conversation/apology_opening_speech_test.dart`：扩查 **71 PASS / 0 FAIL**。该轮开始于最后账号 provider 微批前；最终新账号回放已在上述 19 条中另证实，完整集成由父级统一执行，不累加重复用例充数。
- `analyze --no-pub lib/app/business_providers.dart lib/features/home test/features/home/home_repository_test.dart test/features/home/home_snapshot_readiness_test.dart test/features/home/home_snapshot_lifecycle_test.dart`：**No issues found**。
- `openspec validate repair-home-entry-snapshot-readiness --strict`、指定路径 `git diff --check` 与中文 UTF-8 读回通过。

扩查另包含 `test/features/contacts/contact_task_entry_test.dart` 时有一项失败，单独运行仍复现：`MOCK contact task shares unified page without account or real gateway`，第 115 行 `tester.element` 收到多个 `find.textContaining('MOCK：已收到您的文字')` 匹配（第 131 行调用）。该 fixture 用固定 preview ConversationEntry，不调用 home repository/mapper；本批未改它，也未弱化断言，交整体消息回归核查，未声称基线已证实。

## 证据边界

ENTRY-01/02/03 已取得客户端源码、真实 repository/controller/VoiceHost 加可控外部端口的自动证据。账号安全证据明确为两段：正式 ProviderContainer 的 epoch 变化替换旧仓库（原 onDispose 负责 close），真实 DioHomeRepository 的 close 后迟到 HTTP 不写入；没有称为同一个完整账号 HTTP 链。

语音回放证明正式 Speech/VoiceHost 只提交旧开场一次，音频端口为合成替身，不证明设备实际可听。导航入口测试使用正式 HomePage 回调构造既有 ConversationEntry，并非完整 shell/权限/网络真机回放。后端发布版本、Android/iOS 首屏与实际音频未验收；不构建、不联网到真实业务、不外呼、不部署、不提交推送，本 change 不归档。
