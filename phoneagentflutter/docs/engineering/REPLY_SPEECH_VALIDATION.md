# 统一页普通回复播报：实现与集中验收

2026-09-19，voice-protocol-foundation 4.3d。普通回复已接正式provider/统一对话控制器与页面；Web演练使用同一共享逻辑，仅网关/输出/采集为显式MOCK。没有请求线上TTS、实际出声、申请权限或安装真机。

## 已核对的行为来源

固定Android v65 `4c781e3ccfcd148c1f205921534907ee0c5aa864`：

- `AgentTtsBridge`：句号/问号/感叹号/换行分句，超过80字符才考虑逗号、顿号、分号；首片800ms随delta重置，正在合成或有待合成句时不安排该定时器。signal整段入队，flush送出余部。
- `MarkdownText.stripMarkdownForTts`、`QwenTaskTtsApiClient`：分句后、请求前清理Markdown，纯代码清理为空则不发请求。
- `AssistantViewModel`构造`AgentTtsBridge`未指定speaker，实际使用固定`zh_male_taocheng_uranus_bigtts`。不跟随外呼模型音色。
- `AgentStreamEventHandler`/`AgentStreamInteractiveResponsePolicy`：TEXT_REPLY的final正文整段播报并flush；补问按问题数、候选按“第一个/第一家”等摘要、联系人带号码。没有添加按正文相等去重。
- `SingleFlowNativeDemoScreen`的`onInputModeChange`只更新本地SfInputMode；键盘仍属于VOICE会话。因此输入切换不等于静音。初步方案曾误将Flutter的voiceMode当作业务语音模式，继续阅读回调链后已纠正，测试明确覆盖键盘回复播报。
- `VoiceManualControlHandler`在ttsPlaying时允许按住并打断当前Agent流；非播报中的思考仍按原发送门禁处理。

## 实现位置和状态

| 文件/组件 | 职责 |
|---|---|
| `domain/voice/speech_text_policy.dart` | 分句、固定音色和Markdown清理，纯Dart |
| `domain/voice/speech_prompt_policy.dart` | 普通final/补问/候选/权限/导入提示，不把通话回执任意正文当播报来源 |
| `domain/voice/reply_speech_playback.dart` | 共享播放端口、状态和工厂 |
| `data/voice/conversation_tts_stream.dart` | 每句独立TaskTtsSession串行合成，共用一个PCM队列；首音保护一次、结束尾块一次，2秒原生在途/16MiB音频与64Ki字符待合成上限 |
| `presentation/controller/conversation_speech_controller.dart` | delta缓冲、800ms定时器、事件转发、生命周期与晚到隔离；不发Agent请求 |
| `app/conversation_speech_providers.dart` + conversation provider | 正式自有TTS网关/双端输出/全局占用，Web普通入口不自动打开音频 |
| ConversationController/VoiceHost/Composer | 当前事件转发；播报时允许按住中断旧流再进入既有采集；后台/关闭/历史恢复/单路通话停播，键盘切换不静音 |

合成完成只推进下一句，不等待上一句播放排空。Agent回复结束封口，最后所有PCM实际消费、设备释放后才结束播放状态。合成失败计数可见且沿v65继续已排队下一句；输出失败则终止整个播放，释放失败仍由全局音频租约保护。失败不删除已显示文字，不自动重发Agent请求、重试TTS或录音。

主控制器由500行降为493行：候选/补问消息投影移入已有MessageStore，候选选择合法性移入已有PresentationProjection。不是把音频编排塞进原控制器或放宽规模检查。没有新依赖、原生改动、后台/数据库/提示词/权限变更。

## 自动和浏览器证据

- 新增23项：规则5、流水播放7、播报控制器6、正式控制器与同页集成5（320/390/430宽度）。验证串行合成不等播放、同输出/起始尾块次数、800ms、失败/取消/账号失效、旧流取消、历史静默、键盘不静音及手势切换。
- 全量1908项、analyze无问题、888文件格式、19项OpenSpec、git diff检查通过；Web构建28.3秒、Android Debug10.4秒、Mac iOS Debug无签名18.0秒。Web既有Cupertino字体提示保留视觉阶段核对，不冒充视觉验收。
- 初轮测试fixture误用音频租约getter，按真实接口修正；同页测试输入后需pump更新发送按钮，并修正手势按钮key，随后三宽全流程通过。没有修改生产断言来放过失败。
- `http://127.0.0.1:8113/`，既有`tool/previews/voice_input_preview.dart`：键盘输入→MOCK回复→正在播报→模拟播完→文字输入；再发→模拟失败→失败提示、文字保留；继续新一轮→重新播报；切语音仍保持播报→点击按住按钮中断→识别收尾→MOCK语句提交→新回复播报→模拟播完回到按住说话。浏览器AX状态直接验证，不把MOCK当实际扬声器。

## 未完成边界

父项4.3仍未完成。通话结果关联已由后续4.3e接续，见[通话结果播报](RESULT_SPEECH_VALIDATION.md)，不以final.text或恢复历史朗读替代业务。SDK回退、更完整的网络恢复/可恢复语句策略和真实设备仍继续单列。

现有采集与PCM输出已真实实现，但真实声音、音色有效性、延迟、系统打断/路由、阶段安装仍待授权后集中验收。没有新安装，也未改变8080登录和Mac保留解锁会话。整个迁移和视觉校准未完成。

## 集中人工验收

| 场景 | 操作及预期 |
|---|---|
| 普通回复 | 在App按住提交或键盘提交；同页显示回复并播报，模型选择不改变需求TTS固定音色；实际网关音色兼容性需确认 |
| 流式长回复 | 短句/80字符逗号/无标点/多句；顺序正确、下一句及时合成，不出现逐句重建播放器的空隙；不能只看complete日志判断听完 |
| 交互提示 | 一问/多问、联系人多个号码、商家候选；提示与选项一致，没有朗读JSON、接口地址或未知工具原文 |
| 键盘切换 | 播报中切键盘，既有回复继续；键盘提交新一轮取消旧播报并播报新回复，不新增静音语义 |
| 按住打断 | 回复还在流式返回时按住，旧声音和旧回复流终止；进入采集，不串旧句；上滑取消不提交新语句 |
| 失败恢复 | 断网/首音超时/输出故障：保留文字，状态可解释，下一轮可重试；不得自动重发用户指令或伪装成功 |
| 页面和账号 | 后台、退出、切账号、恢复历史、进入单路通话：旧播报停止，无历史自动重播；音频释放后才能交给下一owner |

日志只记录阶段/关联session或trace和清洗后的错误码，不提交正文、音频、token。真实声音失败请记设备/系统、时间和当前步骤，结合既有网关诊断定位。
