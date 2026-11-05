# 翻译 AppAudio 回退交互与验证

2026-09-20。继续执行用户批准的“现有 HTML/CSS 和组件先完成交互，视觉差异后续统一校准”。本节点是共享协议与同页交互，不是实际翻译外呼交付。

## 已完成的共享部分

- `AppAudioTranslationMedia.connect` 复用 VoiceSocket 和现有 codec，验证 wss 地址并保留原查询授权参数；只读麦克风授权，不主动弹权限。
- `app_audio_ready` 放行会话协调器后续呼叫步骤；`merchant_audio_ready` 才调用 PCM 端口。WS 打开、worker_ready、普通接通不提前采集。
- 静音丢弃上行，译音和字幕继续；恢复不补发旧帧。译音支持返回采样率、非负序号去重、两秒未消费队列上限。AppAudio 不支持 DTMF，点击数字明确提示，不显示发送成功。
- 结束、账号失效、传输/输出故障作废旧回调；真正关闭资源才释放音频占用，关闭失败保留占用供显式重试。
- `PreviewLiveKitTranslation` 只替换外部 room/socket/权限/PCM，复用正式协调器、媒体适配和 `TranslationSessionRoute` / `TranslationCallPage`。没有第二套生产页面。

## 可点击预览

启动入口沿用 `tool/previews/livekit_translation_preview.dart`，本次地址 http://localhost:8117/ 。原 8080 登录会话未修改。

1. 点击“开始AppAudio回退演练”。旧 LiveKit 房间连接失败并关闭，然后进入 AppAudio 等待。
2. 点击“AppAudio就绪”：进入振铃，显示“采集未启动”。
3. 点击“采集就绪”“模拟接通”“模拟双语”：显示同一正式通话页与双语字幕。
4. 点击“静音”“模拟译音”：静音保持开启，译音消费数增加。这里是合成消费计数，不是真机出声证据。
5. 点击“扬声器”；打开拨号盘并按数字，应提示当前通道不支持按键；再收起拨号盘。
6. 点击“挂断”：返回，显示 merchant 1 / hangup 1、音频占用已释放；轨迹中 room.close 必须在 AppAudio fallback 之前。

窄屏展开拨号盘时收起顶部演练按钮，保留正式四按钮，避免演练面板挤压页面。视觉精修仍待办。

## 验证证据与未验证项

- 新增共享协议 11 项、共享页面三宽度 3 项；覆盖实际本地 WebSocket 握手及二进制译音、就绪门禁、静音、顺序、容量、晚到、关闭失败和回退页面。
- 当前完整工作区 `flutter test` 1,989 项通过，包含尚未提交的原生桥接方法通道 3 项；不能据此称 iOS 原生已通过。
- `flutter analyze` 无问题，lib/test 共 898 文件格式检查通过，OpenSpec 19 项通过。
- Web 演练构建 20.3s、Android Debug 构建 32.2s 通过。Android 构建包含本地原生在制改动，不是本共享节点的已安装产物。
- 浏览器实测上述媒体门禁、字幕、静音下行、音源及挂断返回；没有真实网络外呼、录音、播放、权限或账号写入。
- Mac SSH `192.168.1.49:22` 连接超时，未执行本批 iOS 构建；既有解锁会话未操作。双端真机未安装。

## 后续工作与集中人工验收

最新iOS增量：两个Swift双工端口已由Xcode15.2编译、签名、安装和调试启动；Android/iOS共用同一完整Dart设备工厂，Web/桌面仍不可用。8条工厂/运行时/PCM定向测试及analyze通过；没有实际开麦或外呼。iOS共享PcmDuplexSession持有采集/播放引擎，最后持有者释放后恢复会话；普通ASR/TTS不默认开启duplex。设备证据见[阶段记录](DEVICE_STAGE_20260920.md)。下方此前“iOS草稿/工厂为空”仅为历史状态，不再是待实现项。

2026-09-20后续增量：`DeviceTranslationPcmBridge`、既有DevicePcmCapture/Output显式duplex参数及Android采集通信路由已纳入完整设备工厂提交；Android Debug9.9秒、66条定向回归及正式默认provider复核通过。仅iOS两个Swift草稿仍留在本地，iOS正式工厂继续为空。回声处理、采样率切换连续采集、扬声器/听筒、系统中断/后台及实际释放均需真机听音验证。

Android工厂、拨号前麦克风门禁与既有归档现已接线，iOS待编译后复用同一Dart组合。授权测试号码和设备集中验证：默认音源、双方声音、静音只停本地上行、切音源、LiveKit失败后无双重采集、锁屏/中断/挂断停止指示器、返回后普通语音可用。按实际海外协议核对钱包，不复制已排除的国内SIP计费，也不能用模拟计数或构建成功代替这些结论。

OpenSpec 父项 2.2/2.2e/2.3/2.4 保持未完成；本批不新增国内 SIP、真实回退拨号或视觉验收结论。
