# 设计

## 事实与边界
- 开始时 codex/dev@900b64cc 干净；fetch 后 origin/codex/dev 同提交，不切分支、不合并。已读取 AGENTS 与相关任务结果设计，外部导航属于 OMS，不作为 App 事实。
- 只读旧 a0bedb12 和 App 8f235920：PureVoiceCallRecordingCard 左排最大 280，内边距 12/10，圆角 22；RecordingPlaybackCardMetrics 最小高 81、波形高 38、主按钮 50。81 已与当前一致，不能凭截图擅自缩小。
- 当前 ReceiptShell 最大 280，而普通录音复用翻译页 RecordingAudioCard 的外边距 20/8/20/16、没有同宽约束；CallRecordingControl 为空波形传入 24 个 .12，盖掉现有旧版默认高低图形。旧截图为待播状态，其高低图形是静态默认，不能当作真实声音采样。
- 当前 Android 使用同 MediaPlayer.audioSessionId Visualizer，iOS 用 AVPlayer PCM tap；播放进度各 200ms，波形约 15Hz。现有异常冻结采样策略含降级图形，本批不调整或宣称所有图形都是精确音量。双方均无用户 seek，play 回零与 resume 原位置不变。

## 文件职责与状态
1. RecordingAudioCard 新增可覆盖外边距参数，默认保留翻译页参数；不改下载/播放回调。
2. CallRecordingControl 普通单路左排并按 ReceiptTokens.singleWidth 约束，底部仅保留 8 间距。81 高与大字体自然增长保持。缓存本展示控件最近播放帧，暂停沿用，idle/loading/processing/ready/failed 清除；无帧时用静态默认图形，不开时钟生成声音。
3. CallRecordingRoute 以 (manager, callId) 作为控件 key；更换录音、任务/账号宿主时重建缓存，不跨身份残留。

这是三个文件的展示微批，不新增业务状态机或抽象。保存仍先选目的地、重新取源、私有临时下载、导出并清本次文件；播放仍按操作取源、暂停续播复用、结束重新取源，互斥与生命周期保留。

## 验证
先写真实 CallReceiptCard + CallRecordingControl 布局失败回放，覆盖 Android/iOS × 320/390 × 正常/大字体，核对三卡左右边界、81 正常高度、回调可操作。再回放真实 levels、暂停、idle/结束、媒体身份替换与销毁。保留下载、播放互斥/暂停/结束、旧采样隔离及翻译布局相邻回归；不新增 seek，不把本地自动回放当设备可听音频。固定 Flutter 3.32.0 --no-pub、analyze 与当前 change 校验，无 APK 构建/安装/真实请求。
