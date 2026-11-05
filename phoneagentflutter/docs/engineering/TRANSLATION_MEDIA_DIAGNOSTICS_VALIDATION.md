# 国外翻译媒体诊断与验收边界

2026-09-21；基点6366e0a后的增量，settings-interactions 2.1b7b。复用现有双端媒体实现，不新增翻译业务或调用真实电话。

## 已实现

`LiveKitTranslationMedia`、`AppAudioTranslationMedia`记录固定组件、阶段、结果和原因；两个正式工厂在创建实例时绑定原账号Journal与本地trace。账号切换后的旧回调不转投新账号。每个媒体实例独立trace；LiveKit回退AppAudio不保证同trace，合法UUID sessionId可关联。非UUID会话ID丢弃，不能把本地trace当后台callId。

| 观察 | 能证明什么 | 不能证明什么 |
|---|---|---|
| connect/succeeded | 当前连接返回且生命周期仍有效 | 服务已ready、对端已接听 |
| LiveKit roomReady/succeeded | 初始化并发布web_client_ready返回 | 后端已收到或realtime_ready已到 |
| ready/received | 当前会话接受对应后端ready，重复不多记 | 全部本地准备完成 |
| ready/succeeded | 原有媒体准入条件完成 | 商户已接通或声音质量合格 |
| AppAudio merchantReady/received | 收到merchant_audio_ready，开始原有采集流程 | 录音启动成功 |
| start/succeeded | PCM start正常返回 | 已采集可听音频 |
| read/received、send/succeeded | 首个有效PCM返回／交给socket.send | 服务端已收到、ASR成功 |
| play/succeeded | 首次底层play返回且实例仍有效 | 整通播放完成、实际扬声器有声 |
| microphone/succeeded | LiveKit控制返回／AppAudio本地上行门禁已修改 | AppAudio物理麦克风被关闭 |
| speaker/received、succeeded | AppAudio采集前偏好已接收／已有桥接路由返回 | 实际音源正确、蓝牙兼容 |
| dtmf/succeeded | LiveKit控制消息发布返回，不存按键内容 | 远端IVR收到；AppAudio仍不支持DTMF |
| close/succeeded | 本媒体资源清理完成 | 后端电话已挂断、所有模块都无音频 |

权限失败、初始化路由失败、ready超时、传输中断、无效PCM及释放失败分别记录阶段和固定reason。准备失败可能同时有底层protocol与上层ready失败，应按同trace串联，不当作两次电话失败。`start`失败还可能是音频租约或创建桥接失败；只有PCM start/succeeded证明实际启动返回。清理失败保留重试，不以诊断改变既有异常和呼叫顺序。

日志不保存票据、URL、字幕、音频、号码、DTMF数字或原始异常。PCM首帧每方向只记一次，不逐帧写盘。诊断sink失败不影响原行为，上传仍须显式触发。

## 自动验证

- 14项新增：LiveKit双ready/错会话/重复ready、迟到取消、控制失败、释放重试、传输故障与虚拟时间超时；AppAudio分阶段ready、静音不发上行、三个首帧只记一次、实际播放返回、路由失败、无效PCM与释放重试；双平台正式工厂账号更换、Journal重建/实际ZIP、安全session/未知字段与sink失败。
- 首轮9/10通过，超时测试对象建在fakeAsync外导致虚拟时间无法驱动；改为在该时钟内构建测试对象后通过，未改业务超时或放宽断言。
- 最终13个相关测试文件共99项通过，测试输出约6秒，包含新14项、原媒体/工厂、Runtime/Session/Coordinator及普通语音诊断直接调用方。不是全量回归。`flutter analyze`无问题（5.9秒）。
- AppAudio源文件459行，其余本批手写源文件低于500行。未改平台、插件、依赖、UI和后台契约，因此本批无新构建/安装/截图、SMS、真实采集、播放、外呼或上传。

## 未覆盖与集中人工验证

本批不新增LiveKit SDK内部RTP/设备音频逐帧遥测，不修改原生崩溃捕获。普通ASR/TTS/PCM已有独立诊断；克隆录音、历史录音播放器、单路监听等其他媒体路径不能据此声称具有同一套底层诊断，它们仍使用已有结果/共享音频占用记录。是否需要更深遥测应以实际故障证据驱动，不能阻塞已有页面迁移或把所有底层遥测无限扩展成首版门槛。

真实声音、授权、耳机/蓝牙、来电打断、原音混音、DTMF及服务端接通/计费按[MIGRATION_HANDOFF](MIGRATION_HANDOFF.md) M06–M10集中验证。本报告仅补齐上述共享诊断接线，不代表真实媒体验收。匿名/未绑定日志用户导出仍缺实现；初始化正式门禁选择、Android普通包登录证据和生产升级仍独立未完成。
