# 旧语音识别语言兼容

2026-09-21，基于805392c追加；迁移台账L01。与国外翻译模型无关，初始化仍是身份→通话模型→首页，不添加语言选择页面。

## 来源与实现

固定Android v65 `4c781e3ccfcd148c1f205921534907ee0c5aa864` 的VoiceLanguage、AssistantVoiceLanguageState读取index9_native_screen.voice_language_code；VoiceRuntimeSessionController的主识别和VoiceRuntimeLifecycleController的后端回退都实际使用该值。

1. LegacyPreferencesChannel仅读现有生产包内固定字段；DeviceLegacyPreferences.readVoiceLanguage校验类型。沿legacyPreferencesSourceProvider的非Web Android及精确prod API门禁，其他平台不访问旧偏好。
2. SecureVoiceLanguageStore按环境/API隔离设备级安全key，复用PreferenceOperationQueue同key跨实例串行。新值优先且损坏拒绝覆盖；首次命中旧值先保存再返回。en/en-US→en-US，ja/jp/ja-JP→ja-JP，未知旧字符串沿v65为zh-CN；没有旧值才用默认中文且不写默认。
3. voiceLanguageStoreProvider接正式语音工厂。FallbackVoiceInputSession.start在传输启动前最多等3秒，一手势读一次；主ASR与备用识别的languageCode使用同一快照，保留userId等参数。
4. 读写失败/超时使用VoiceInputController既有语音失败与重新按住重试路径，不静默启动中文。取消、释放或账号/页面失效后的晚到结果不启动传输，不提交文字。

Android仅偏好读取不同；新存储、语音语言快照、失败与取消逻辑均为共享Dart。没有改变TTS、翻译语言、提交协议、尾句等待或计费。

## 自动证据

71项相关定向测试通过（14新增，测试阶段约6秒），不是全量：

```text
test/features/conversation/voice/voice_language_store_test.dart
test/features/conversation/voice/voice_language_session_test.dart
test/features/conversation/voice/voice_language_provider_test.dart
test/features/conversation/voice/fallback_voice_input_session_test.dart
test/features/conversation/voice/voice_input_factory_test.dart
test/features/conversation/voice/voice_input_controller_test.dart
test/features/conversation/voice/voice_input_page_test.dart
test/features/conversation/voice/asr_fallback_loopback_test.dart
test/core/audio/media_diagnostics_provider_test.dart
test/features/app_update/legacy_preferences_test.dart
test/features/attachments/ocr_route_test.dart
```

覆盖语言归一、新值优先/损坏、旧源与目标失败重试、并发隔离；正式工厂精确prod门禁、主/备用URI同快照、取消/释放/失效、3秒超时进入现有重试状态及原语音页面/回退/诊断/OCR调用方。新测试的虚拟时钟等待未结束，主动终止后改为真实有界3秒超时测试；随后上述定向集合完整退出0，不以被终止结果充数。

`flutter analyze`通过（61秒），Android Debug构建通过（10.5秒，JBR，APP_ENV=dev、测试API）。仅增加原生偏好字段，无iOS原生变动，未重打iOS。

未采音、未调用真实WebSocket/业务HTTP、未发送短信或安装真机；不因合成协议测试通过就声称真实识别音质通过。旧数据只读保留，超时不强行取消底层安全存储事务；事务稍后完成仍只写原设备偏好槽位，已取消的手势不恢复。

## 集中人工验证

按[迁移主清单](MIGRATION_HANDOFF.md)的同签名高版本覆盖前提，在专用旧版测试设备分别准备中文/英文/日文语言偏好，不修改真实业务账号数据来制造样例。旧版当前没有语言选择入口时，使用可控测试夹具准备，不为此给新App增设页面。

- 升级后直接进入统一对话按住说话；对应语言识别结果应与旧版一致，冷启动后仍保留。首次新安装无偏好时为中文。
- 在可控测试语音服务中使主识别出现既有可回退错误，确认备用识别仍为同语言，不通过真实外呼制造故障。
- 按住后上滑取消、切文字、退页；不应出现晚到录音或自动发送。iOS无旧Android来源，正常按住/释放仍沿共享逻辑。
- 存储失败时显示现有语音错误，可以重新按住重试；不得要求清数据或重新获取验证码来掩盖问题。

真实旧偏好读取、升级及三种语言声音效果仍待集中验收。本项不是全部语音能力或所有旧数据迁移完成声明。
