## 设计
AsrCaptureSession 支持提前采集模式。保持原生麦克风授权、音频租约和账号有效性前置，麦克风启动成功即通知 UI 进入录音；WebSocket 建立与采样并行，上传仍严格 gated by ASR ready/start_capture。只在本轮内存保留最多 64000 字节 PCM16 mono（2 秒），超过容量丢弃最旧帧，ready 后先按序 flush 再发送实时帧。取消、底层 release、失效或 transport failure 清缓存并停止原生，不把旧音频移交备用、不重复开麦。Android 正式工厂显式关闭提前采集，Web 不获真实麦克风。
任务语音独立 speechInput 标记由 iOS 工厂传到 DevicePcmCapture，再到原生；普通任务录音使用 playAndRecord/default/defaultToSpeaker/allowBluetooth，保持系统选路和 16k mono 转换；非任务录音保持 measurement，全双工保持已有 voiceChat/VoiceProcessing。停止恢复原会话配置。
## 验证
先执行旧实现的缺开头回归 RED；覆盖慢握手期间 native start、ready 前不上传、缓冲顺序/边界、早 release、启动与连接失败、取消/切换后不重放；原 Android ready gate 专项保留。方法通道验证 speechInput 范围，现有语音输入/ASR fallback/音频独占/语言工厂/UI 定向回归和 analyze，iOS 开发包构建及 USB 安装。音量、噪音及真实 ASR 识别质量仍需当前 iPhone 听检。
