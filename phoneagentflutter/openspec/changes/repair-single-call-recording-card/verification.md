# 验证记录

## 基线与只读对照
- 实际 Flutter 检出 `D:/work/04phoneAgent/_isolated/phoneagent-task-flow`，`codex/dev@900b64cc`。开始干净，fetch 后左右计数 0/0；本项不切分支、不合并、不提交推送，保留其他任务的 AGENTS v1.3、知识库和 TTS 诊断修改。
- 只读旧业务基线 `a0bedb12` 的 android/.../PureVoiceCallRecordingCard.kt，以及 App `8f235920` 的 app/... 同类文件。两版共同为左排 max280、内边距12/10、圆角22，RecordingPlaybackCardMetrics 为 min81、波形38、主按钮50。App 旧卡关键布局在 PureVoiceCallRecordingCard.kt:74-124；结果区间距见 PureVoiceThreadList.kt:171-183（spacedBy8）。
- 当前确认的偏移：ReceiptShell 为280，普通录音继承共享外边距20/8/20/16且没有280上限。真实 Widget RED 得到蓝卡 left38，对照字幕/结果 left18。
- 新旧截图均为待播三角图标。旧高低图形来源于 RecordingWaveformDefaults，不能当作真实录音全段波形；当前平线来源于 CallRecordingControl 的 List.filled(24,.12) 覆盖。旧播放器暂停保留最后帧，当前媒体层会重置采样；本项只缓存本卡最后显示帧，不改媒体层。

## 精确范围
- CallRecordingControl：普通卡左排max280/底8；待播固定旧高低图形，播放按输入levels更新、暂停保留最近帧，其他状态清展示缓存。无计时生成音量。
- CallRecordingRoute：以(manager,callId)键控上述缓存，覆盖同通话ID跨任务/账号宿主替换与录音切换，销毁自然释放。
- RecordingAudioCard：新增外边距可覆盖参数，默认值仍是RecordingTokens.outerPadding，翻译页与失败布局默认不变。
- 仅以上三份生产源码；其余是两份测试和本项记录。81最小高度不改，大字体按内容自然增高，保留48操作热区。

## RED、GREEN 与身份反证
命令：`D:/tools/flutter-3.32.0/bin/flutter.bat test --no-pub test/features/conversation/single_call_recording_layout_test.dart test/features/conversation/conversation_recording_host_test.dart`。

- RED：6通过/11失败。八个Android/iOS × 320/390 × 1/2倍字号几何用例确认left38≠18；默认波形、暂停保留及替换宿主场景失败。
- 修复后：17项全部通过。几何同时核对上下卡左右、宽280、正常字号高81、下方间距8和保存/播放操作回调；真实宿主覆盖采样后暂停、进度00:09、自然结束回idle和默认图形、生命周期及保存独立性。
- 额外反证：临时移除route的(manager,callId) key后，仅跑 `--plain-name 'same call in a replacement host cannot inherit paused waveform'`，明确失败（期望新卡静态默认，实际继承旧卡levels）。恢复key，最终相邻集合包含该项并通过。没有保留临时突变。
- 原宿主测试“pause clears them”的平线断言按用户确认改为“pause preserves the last frame”；播放器层原先的暂停重置/迟到采样隔离测试仍保持并通过，不篡改媒体事实。

## 相邻集合与静态检查
以下 PowerShell 选择器解析为24个测试文件，实际执行 `flutter test --no-pub --reporter json`，**152项通过、0失败**（36.917秒）：

```powershell
$paths = @(rg --files test/features/conversation | Where-Object { $_ -match '(recording.*test|receipt_recording_widgets|call_receipt_widget|receipt_entry_isomorphism)' }) +
  @(rg --files test/features/translation_history | Where-Object { $_ -match '(native_recording|plugin_recording|recording_audio_controller|recording_on_action)' }) +
  @('test/shell_recording_save_context_test.dart','test/features/conversation/reported_call_receipt_media_test.dart')
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' test --no-pub --reporter json @($paths | Sort-Object -Unique)
```

覆盖普通录音API、按操作新源、元数据、下载/保存/清临时文件、播放暂停恢复/自然结束、切换互斥、旧代次隔离、宿主/账号替换、字幕→录音→结果插槽与只读历史一致、正式Shell保存上下文；翻译录音布局/失败/动画/播放器/控制器原回归保持。

- `flutter analyze --no-pub`：No issues found（34.2秒，包含当时并发已写入的TTS诊断代码）。
- `openspec validate repair-single-call-recording-card --strict`：valid。
- 本项文件UTF-8严格读回、中文与 `git diff --check` 通过。
- 主会话整合后独立复验：本项两文件与首声诊断、speech controller / integration、TTS stream、pause controller 合计 7 文件 50 项全部通过；再次运行全工程 analyze，无问题（19.7 秒）。

## 保留的真实媒体边界
- 普通播放仍POST新play-token并交MediaPlayer/AVPlayer远端流，不引入下载缓存；暂停续播复用原源，自然结束后下次点击取新源。保存仍独立选择目的地→取新源→私有临时下载→导出→清理，不复用过期播放源。
- Android Visualizer挂同audioSessionId，约15Hz波形/200ms播放器位置；iOS PCM tap约15Hz采样/200ms位置。既有异常/冻结采样降级策略未改，静态待播图形与降级图形均不承诺精确声音振幅。
- 只读确认双方无用户seek方法或进度拖动入口，只有play回零、resume原位置；本项不新增seek。
- 自动回放使用合成媒体事件和受控端口，不等于设备可听音频、真实导出或现场同一通话证据。真机布局/实际声音和采样同步待最终测试包验收；本子任务未构建、安装、真实下载/外呼，未归档。
