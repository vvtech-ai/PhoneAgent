# 统一对话输入交互与集中验收

最新回退增量（2026-09-20）：已按固定v65补共享后端转写单次回退，并非原生SDK；69项定向测试、真实本地WebSocket回环、正式工厂与8122浏览器成功/失败两路径通过。实现及人工步骤见[ASR回退验收](ASR_FALLBACK_VALIDATION.md)。下文历史“SDK回退未实现”由此纠正，真实声音/路由仍未验。

最新增量（2026-09-20）：普通VOICE断网后的业务句冻结、完整ledger核对、重复原句去重/新补充/修订、按住恢复前缀已接正式共享路径；19新增/2034全量、Web及Android构建、8120浏览器两条恢复路径通过，详见[网络恢复实现与集中验收](VOICE_TURN_RECOVERY_VALIDATION.md)。下文历史“网络失败恢复文本策略未完整实现”由此更新；SDK回退、真实音频与双端验收仍未完成，既有TTS进度以REPLY_SPEECH_VALIDATION/RESULT_SPEECH_VALIDATION为准。

日期：2026-09-18。复用现有统一页和视觉组件，先完成可自动验证的交互，不做逐像素视觉验收、不申请真实权限或录音。输入接线不等于完整语音交付。

## 来源纠偏

固定 v65 `4c781e3`：`VoiceManualControlHandler.onManualAsrRelease` 保持采集最多2000ms，`VoiceTaskAsrEventHandler` 在有效final时提前结束，`ManualAsrTranscriptPolicy` 合并累计/重叠片段，`VoiceAsrWatchdogController` 按住60000ms按已有文本规则结束；`PureVoiceStageVisuals` pointer down立即开始，向上58dp松开取消，不引入最短录音时长。

**此前 PCM/传输文档中的“松手立即停止上行”仅适用于底层 release/stop 演练，不是 v65 手势要求。** 正式手势松手不会立即调用 AsrCaptureSession.release，而先等待final/2秒截止，再cancel关闭本轮。历史验证记录保留，新实现以本说明为准。

## 实现与数据流

| 文件/组件 | 职责 |
| --- | --- |
| `VoiceHoldButton`、`VoiceComposerBinding` | pointer down/up/cancel、58dp撤销、收尾禁入；复用原按钮资源/尺寸 |
| `ConversationPage` / Composer | 同页识别片段、状态、语音/文字切换，紧凑布局不挤出输入栏 |
| `ManualVoiceTranscript` | 纯Dart重叠/累计片段合并、模型元数据排除、release/timeout选择 |
| `VoiceInputController.press/release/cancel` | 权限→连接→采集→收尾→实际停止→单次提交；旧轮和晚到隔离 |
| `conversation_voice_providers.dart` | 装配已有采集/ASR/音频租约，提交到ConversationController.send(source: asr)，不复制准入/Agent规则 |
| `ConversationVoiceHost` | 正式Route绑定、前后台取消；切文字/会话关闭由provider作废；无后台自动重录 |
| `PreviewVoiceInput` / `VoiceInputPreviewPage` | 合成权限/识别/Agent历史端口，共用输入控制器、对话控制器与正式页面，不读取或写入真实账号 |

状态：idle → permission → connecting → recording → finalizing → stopping → idle/failed。按住期间final只缓存；停止硬件成功前不提交。取消/关闭/切文字不提交。停止失败保留清理机会，不假报已释放。普通Web入口明确提示使用文字，不发语音连接或权限请求。

## Web入口和验证范围

开发者功能演练 → **统一对话输入演练**；独立预览 `tool/previews/voice_input_preview.dart`，本次本地地址 `http://127.0.0.1:8110/`。顶部始终显示MOCK，按钮可模拟final、断开、拒绝权限。按住时350ms后生成合成partial，松手后沿正式规则提交，随后可切文字继续。

自动回归包含累计合并/元数据过滤、2秒截止、60秒截止、空结果、ready晚到、重复final、权限晚到、拒绝、断开、停止中取消、释放失败重试、准入变化、销毁，以及正式provider/host切文字取消。320/390/430宽及键盘高度检查为布局健壮性，不是视觉一致性验收。

最终验证（2026-09-19收尾）：22项新增专项、1,841项全量测试通过；analyze无问题、855个Dart文件格式检查无变化、OpenSpec19项通过；Web/Android Debug/Mac iOS Debug无签名构建通过。浏览器8110确认识别收尾→一条用户消息和回复→切文字→续聊，控制台无error。追加正式provider回归验证“停止期间切文字再切回”作废旧结果，修正原先跳过stopping取消的竞态；最终全量和构建均在修正后重跑。

## 尚未完成及集中人工验收

- **TTS真实输出/播报打断、SDK回退、网络失败恢复文本策略**未完整实现，不把本批称为整个语音模块完成；失败目前明确提示，不能当作v65全部错误恢复已复刻。
- 真实双端ASR音质、延迟、权限弹窗、路由/系统中断仍未验证；静态构建/合成事件不能证明真实声音成功。
- 默认语言沿v65 zh-CN；历史语言偏好兼容需后续核对迁移，不新增产品设置入口。
- 视觉统一校准后置：录音活动样式、字体/间距、设计运行态对齐继续记账；允许系统差异。

集中人工步骤（后续设备安装获准且测试环境可用时）：

1. 默认语音按住说一段话，确认授权/录音指示器和实时文本；正常松手最终只出现一条用户消息，Agent正常继续。
2. 按住期间上滑58dp并松手：不产生用户消息、麦克风释放；下一轮不含旧片段。
3. 收尾中切文字、退出、切后台；授权框出现后松手再允许：均不得晚到自启/提交；返回不自动录音。
4. 按住超过60秒、无声、网络断开：分别自动结束一次、提示重试、明确中断，不伪造识别或重复提交。
5. 其他播放占用时按住应先停旧播放；释放失败不得假报空闲；双端原生声音/路由另依PCM验证文档执行。

排查关联sessionId/commandId和既有语音方法通道错误类别；不得记录原始PCM、识别正文、凭据。不新增后端API、日志敏感字段、数据库、提示词或SIP规则。
