# 单路监听：实现、演练与集中验收

日期：2026-09-19。`single-call-session` 2.3；本批完成正式按钮到共享媒体、双端输出端口的接线，不代表真实声音或整个迁移验收完成。页面继续复用既有设计组件，视觉统一校准后置。

## 行为依据

- Android 固定 v65 `4c781e3`：`TaskCallMonitorController`、`CallMonitorAudioSocketClient`、`CallMonitorAudioRouteManager`。Playing 点击停止是本地静音，不挂断电话、不重取票据；Muted 恢复当前连接，音源只在 Playing 可选。
- iOS 参考 `ddb996a` 中 `AIVoiceCallViewController` 的监听实现：保留 API 路径构造 WS、PCM 输出、通信音频会话。仅借鉴平台实现，不复制旧 UI/业务编排。
- 不新增接管、麦克风静音、双工声音或多路通话页。监听只接收数据，没有麦克风采集和上行 PCM。

## 实际装配与责任

| 位置 | 方法/职责 |
|---|---|
| `app/call_monitor_providers.dart` | 当前登录绑定工厂、真实票据仓库、既有 IO WebSocket、全局音频租约和设备输出 |
| `ConversationRoute → ConversationCallHost` | 为现有三按钮注入控制器；绑定当前 callId，前后台/退出/终态停止；挂断前先停止本地监听 |
| `CallMonitorController` | `bind/toggle/select/refreshRoute/stop`；单次操作、最多 3 次/800ms 重连、旧目标及账号回调隔离 |
| `CallMonitorStream` | `start/setPlaybackEnabled/route/close`；验证票据、保留 API 上下文路径、只读二进制 PCM、有界未消费数据 |
| `FocusedCallMonitorMedia` | 播放及静音期间持有共享占用；清理真正完成才释放，失败保留以供显式重试 |
| `DeviceCallMonitorOutput → DevicePcmOutput` | 只给监听启用 communication 参数、清播放队列和音源查询/切换；普通 TTS 默认行为不变 |
| Android `PcmOutputChannel/PcmCommunicationRoute` | AudioTrack 通信用途、播放头消费确认、pause/flush；API31+ communicationDevice，旧版本 SCO；停止恢复原 mode |
| iOS `PcmOutputChannel/PcmCommunicationRoute` | AVAudioEngine 输出、实际播放完成回调、清队列；playAndRecord/voiceChat/allowBluetooth，preferredInput/扬声器覆盖，停止恢复原会话类别 |

首次点击：已登记 callId → 原 `monitorTicket` HTTP → `wss://<配置主机>/<API路径>/ws/assistant/call/monitor?ticket=...` → PCM 输出。ticket 不进入页面、日志或磁盘。文本帧不作为声音；格式只接受单声道 PCM_S16LE/8–48k，未消费数据最多两秒。普通 Web 正式入口明确不支持真实设备监听，不偷偷请求票据。

静音：先作废旧播放回调，再清空原生队列，后续到达的 PCM 丢弃。恢复不重放静音期间内容。网络丢失释放旧输出再有限重连；系统播放中断不自动重启声音。退出、后台、换目标/账号、终态、挂断前都停止；返回前台必须用户再次点击。停止不发送 hangup。

音源每秒查询且不重叠；晚到查询不能覆盖较新的用户切换。API31+/iOS 展示原生返回的实际路由，系统可能异步切换；旧 Android 沿 SCO 请求状态，实际接通需要真机确认。通信设备不可用/切换失败不假装成功。仅展示系统当前支持的通信蓝牙，不将纯 A2DP 输出设备当作已接通的 SCO。没有新增蓝牙扫描、配对或权限申请。

平台依据：[Android AudioManager](https://developer.android.com/reference/android/media/AudioManager)、[通信设备选择与异步路由](https://developer.android.com/develop/connectivity/bluetooth/ble-audio/audio-manager)、[Apple 音频路由](https://developer.apple.com/documentation/avfaudio/audio-routing)。当前使用已有 MODIFY_AUDIO_SETTINGS；不根据模拟结果推断所有机型/耳机兼容。

## Web 演练与自动验证

既有“对话到通话全流程演练”中的单路场景复用正式 Host、页面、控制器、媒体解析及租约装饰器。`PreviewCallMonitor` 只替换票据/socket/硬件输出，不连接真实服务，不出声。工具入口 `tool/previews/call_result_speech_preview.dart`；本次静态预览 `http://localhost:8116/`，原 8080 登录会话未变。

可重复操作：发送合成需求 → 自动进入单路页 → 开始监听 → “监听演练/注入合成PCM” → 停止监听 → 再注入 → 恢复 → 音源选择。首次注入显示 3200 字节，静音注入仍为 3200，恢复票据仍为 1；断开才重取票。可模拟持续取票失败/蓝牙移除/远端结束。计数是合成输出消费，不是实际扬声器采样。

- 新增 26 项回归：真实本地 IO WebSocket 握手/只收不发、格式/期限/容量、静音清队列、迟到 socket、关闭失败、音频占用、初始加三次重试、目标/账号变化、路由乱序、原生中断、双端方法通道契约、320/390/430 宽度、后台恢复和返回。
- `flutter test`：1,972 项通过；`flutter analyze` 无问题；915 文件格式检查、OpenSpec 19 项通过。
- Web 演练构建 26.9s、Android Debug 11.2s、Mac iOS Debug 无签名 18.2s 通过。构建不等于安装/真机声音通过。Web 有既有 Cupertino 字体树摇提示，未出现构建失败。
- 首轮 Widget 测试修正平台生命周期顺序、暂停不重绘和登记 callId 的等待；业务门禁未为测试放宽。浏览器菜单动画期间暂不可定位，等待真实可见状态后操作。
- 浏览器连续验证：票据1/播放3200 → 静音注入仍3200 → 同票据恢复 → 蓝牙选择；持续取票失败并断线后只增加3次至票据4、停在失败态；解除故障不自动开启，显式重试到票据5；物理结束显示“等待任务结果”且监听关闭、三按钮禁用。

## 集中人工验收（仍待执行）

前提：经用户确认安装对应双端测试包，测试环境和授权通话号码，明确允许建立测试通话。当前未安装新包、未真实外呼/挂断/取票/播放/录音，不改 Mac 保留解锁会话。

| 场景 | 操作及通过标准 | 禁止情况 |
|---|---|---|
| 首次监听 | 单路接通后点监听，听筒可听到后端当前声音；后台时间窗核对同 callId 的票据及 WS | HTTP200/票据成功不能当作有声；不能开麦上传 |
| 静音恢复 | 播放时点停止，等数秒再恢复，只听恢复后的实时内容；网络连接保持 | 不补播静音队列、不挂断、不重新执行电话 |
| 扬声器/蓝牙 | 切换听筒/扬声器/支持通信的耳机，核对实际出声位置与页面；拔除耳机回退 | 不以 UI 已选证明硬件已切换；旧 Android SCO/蓝牙 LE 各测 |
| 网络故障 | 断开网络观察有限重连，持续失败最终可重试；恢复后明确点击 | 不无限重试，不重发外呼/挂断 |
| 生命周期 | 后台/锁屏/退出/账号变化/远端结束时停止；回前台不自启 | 不残留声音、旧票据晚到重播、跨账号声音 |
| 音频冲突 | 系统来电或其他 App 抢占，监听停止；再显式开启；结束后普通回复/录音试听正常 | 不自动抢回声音；释放失败不能冒充空闲 |
| 多路与结果 | 多路留在对话页；单路物理结束后等待 Agent 结果，监听已停 | 不因监听结束显示任务成功，不新增多路单路页 |

Debug 日志关键字 `CALL_MONITOR_STATE taskId=… callId=… phase=… attempt=…`；关联 `CALL_STATUS_APPLIED`、后端同时间窗的 callId。禁止输出 ticket、完整 WS URL、PCM、号码、转写或异常原文。Release 诊断仍归项目整体日志验收。

真实声学效果、iOS 会话切换与有线耳机、Android OEM/旧 SCO、音频全局抢占及阶段安装均未验证。钱包结算/其他通话未完成事项继续见 CALL_FLOW_VALIDATION；2.4/2.5 保持待办，不归档父变更。
