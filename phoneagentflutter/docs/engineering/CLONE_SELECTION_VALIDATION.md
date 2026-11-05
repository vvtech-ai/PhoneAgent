# 克隆目录与选择：实现和验收边界

## 当前状态（2026-09-17）

共享接口、Controller 和正式音色页克隆选择卡已接通；支持分模型显示、当前/候选选择、空/错误/处理中/等待同步和返回。创建、认证、录音、试听、重录、删除尚未完成，不能理解为声音克隆全功能完成。

历史 Design2App 复核发现 voiceIdentity.png 为初始化身份引导而非音色页。2026-09-17 用户已明确批准现有 HTML/CSS/组件优先，解除实现前置；新卡片消费静态 cloneVoiceGroup 参数和现有选择组件，不把错配截图当视觉证据。视觉差异后统一校准。

## 固定来源

- Android v65 `4c781e3ccfcd148c1f205921534907ee0c5aa864`。
- `AssistantTaskSettingsPageHost`：READY 且已扣费候选优先走 candidate confirm；其他当前克隆走 realtime-call-voice CLONE。
- `AssistantRealtimeCallVoiceCatalog`：仅 QWEN_OMNI_PLUS / DOUBAO_SEEDUPLEX_3_0 支持；旧 QWEN alias 归一，旧 DOUBAO 不支持。
- `VoiceCloneModelFlowContract.ready`：候选必须 READY + CHARGED；不是只凭 READY 或资产 ID 判断。
- `VoiceCloneModelApi`、`VoiceCloneModelFlowCoordinator`：confirm 激活候选，之后同步配置，不再重复 PUT 或生成；本入口不保存认证录音。

## 实现位置

| 层 | 文件 | 责任 |
|---|---|---|
| 共享 Domain | `lib/features/call_models/domain/clone_voice.dart` | 分模型 current/candidate、可用与候选门禁；不保存录音或提供方资产明文 |
| 共享 Data | `lib/features/call_models/data/api_clone_voice_repository.dart` | GET models、PUT CLONE、POST candidate/confirm；复用账号请求隔离 |
| 共享状态 | `lib/features/call_models/presentation/controller/call_model_controller.dart` | 目录和系统音色并行读取、互斥写入、代际隔离、确认后同步失败只重试 GET |
| 装配 | `lib/app/business_providers.dart` | 当前账号 API 和 Controller 注入，随账号代际重建 |
| 页面 | `presentation/pages/call_voices_page.dart`、`presentation/widgets/clone_voice_card.dart` | ShellRoute 绑定 selectClone；支持模型才显示克隆卡；选择、刷新与 AI 音色共用写入门禁 |

没有原生差异代码或插件新增；HTTP、状态和门禁全部为 Flutter 共享。没有修改后端、签名、媒体、模型计费或认证 SDK。

## 失败和重试

- 目录缺少当前模型、重复模型、current/candidate 串模型或格式非法均报错，不伪装“未克隆”。
- 目录失败不阻断已读取的系统音色；克隆操作要求目录和音色都可用。
- 切换模型使旧音色和克隆请求失效；退出账号/销毁 Controller 后不发布旧结果。
- 克隆与系统音色写入使用同一互斥门禁；当前 CLONE 且无新候选时不重复写。
- 候选 POST 成功后刷新失败，或写入结果不确定：`cloneNeedsRefresh=true`，再次选择不重发写入，先显式只读同步。显示仍以服务端音色响应为准，不乐观标成功。
- 尚未接入创建、删除、试听、认证采集、重录、媒体本地保存及其页面。不得通过本批绕过同意、余额或认证门禁。

## 自动验证

- 2026-09-17 新增 11 项实际页面测试：三宽度选择/返回；未克隆、处理中、读取失败、等待同步、当前使用、候选可确认；不支持模型隐藏及保存中操作互斥。
- 当前全量 359 项测试通过，analyze 无问题。页面操作使用合成回调/端口验证，不修改真实账号的模型或音色。以下 323 项为上一协议批次历史记录，不是本批计数。
- 普通浏览器保登录，从设置→语音大模型→当前 Seeduplex 音色只读加载两项并返回；该旧模型不支持克隆，卡片正确隐藏，没有为验证而切换真实模型。Web/Android 测试环境构建、17 OpenSpec及一键Web 241项+2Chrome+1Node通过，未重装双端。

- 18 项新增合成测试：8 项 API/账号隔离，10 项 Controller/互斥/刷新/候选/晚到。
- 全量 323 项 Flutter tests 通过，analyze 无问题，17 项 OpenSpec 通过。
- 普通 `lib/main.dart` Web debug 构建通过；这不是新增克隆 UI 的浏览器验收。
- Android 测试环境 Debug APK 构建通过；仅构建，没有覆盖安装或新增设备验收。
- 没有发送短信、修改真实模型/音色、确认真实候选、采集身份或发起外呼。
- UI 与真机结果不由合成接口测试替代；本批未重装设备，既有安装限制没有绕过。

## 已接入选择页的集中人工验收（真实写入仍待执行）

1. 在测试环境选择支持克隆的模型，打开音色页：应显示该模型 current 与 candidate，不显示别的模型资产。
2. 已确认音色选择：仅一次 PUT CLONE，读取成功后显示当前；切回系统 AI 后仅下一次通话使用新音色，不自动拨号。
3. 存在 READY + CHARGED 候选：用户选择后仅一次 confirm POST；不能走旧 activate 或重复生成/扣费。未 CHARGED 候选不能确认。
4. 模拟提交成功后断网：不能显示确定切换成功，也不能自动重新 POST；恢复网络点击同步仅 GET。
5. 模型切换、返回、账号切换和进程重启后以服务端配置为准；保留登录，不重复短信。
6. 联调按 account 代际/modelId/requestId 关联请求，禁止记录 token、录音、身份证或提供方资产凭据。当前仅 API 合成 evidence，未宣称生产日志验收完成。

真实采集/录音/试听和双端系统行为要在其实现后另行验证。总迁移目标保持未完成。
