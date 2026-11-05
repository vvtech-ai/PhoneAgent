## 设计
正式移动任务语音工厂对 Android 和 iOS 主/备用 AsrCaptureSession 启用现有 captureBeforeReady；原生 speechInput 参数仅在 iOS 为真。按钮已是 pointerDown，无需修改手势或新增等待。语言仍由偏好源按原契约读出后绑定本轮，失败不默认为中文；本次没有证据表明语言读取导致每次延迟，保留其行为。
采集成功即发本地 VoiceReady，识别网关握手并行。已有缓冲最多64000字节（2秒16k PCM16 mono），ready后先按序送缓存再送实时帧；超过上限淘汰最旧帧，取消/停止/故障清空，备用不重放主连接音频。不能恢复实际麦克风启动前的声音，不以常驻录音或共享旧PCM绕过边界。
## 验证
先运行真实正式 Android 工厂，受控方法通道模拟硬件、受控签名连接模拟网络，复现握手期间没有native start；修复后验证采样/缓冲/上传顺序与取消。两端工厂配置和已有语言、ASR/备用、按住UI、音频租约定向测试/analyze/OpenSpec。AndroidAPK构建与真机听检单列，当前Mac尚无AndroidSDK/JDK且仅连接iPhone，不把合成验证表述为Android听检。
