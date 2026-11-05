# 国外翻译共享会话事件与页面接线

后续增量（2026-09-19）：LiveKit SDK 薄端口、双 ready、实际资源占用/释放和同页演练见 [LIVEKIT_MEDIA_VALIDATION.md](LIVEKIT_MEDIA_VALIDATION.md)。下方“未增加媒体 SDK”仅描述本文件原 2.2b 批次；AppAudio 与生产装配仍待完成。

2026-09-18，OpenSpec `overseas-translation-ui` 2.2b。行为依据固定 v65 `4c781e3ccfcd148c1f205921534907ee0c5aa864` 的 BackendRealtimeProtocol、BackendTranscriptAccumulator、BackendTranslationCallRuntimeSession、BackendLiveKitReadyProtocol。视觉沿用共享组件，本批不是视觉验收或真实翻译完成。

## 实现边界

原演练使用独立 TranslationPreviewController 手动推进阶段。本批增加协议驱动演练，实际使用共享会话协调器、控制器和通话页，仅外部服务与媒体端口为内存 MOCK。原纯 UI 演练仍保留，不改变生产门禁。

| 层 | 主要方法 | 责任 |
|---|---|---|
| TranslationRealtimeCodec | text/binary/start/media/stop/roomReady/dtmf | java-v1、LiveKit control、4字节大端音频头；无网络/日志 |
| TranslationTranscriptAccumulator | apply/items | leg+segment，原文/译文独立append/replace，final不丢后到译文 |
| TranslationSessionCoordinator | start/_prepare/_message/stop | 语言→create→ready→merchant、事件归属/状态、回退、取消/单次回收 |
| TranslationInteractiveMediaPort | events/setMuted/setSpeaker/sendDtmf | 媒体事件/控制薄契约；connect负责实际ready，准备失败由connect Future报告以便回退 |
| TranslationSessionController | start/mute/speaker/digit/hangup | 页面单一状态源、计时、控件单飞/失败保留、字幕快照 |
| TranslationSessionRoute/Page | initState/build/dispose | 页面生命周期、准备取消、活动期禁止直接返回、终态回来源 |
| PreviewTranslationSession/Media | create/ready/wire/close | 内存外部端口，使用相同codec和协调器，不访问用户资源 |

## 状态规则

- `started=true`仅进入振铃。`call_connected`或非空merchant字幕触发Connected→Translating，首次接通开始计时。重复证据不重置，迟到HTTP响应不降级。
- 所属端口且sessionId匹配才接受，沿v65允许空ID。回退先取消旧订阅；旧端口晚到不可影响新端口。未知/ready事件不能当接通，environment仍交原回调。
- 原文先final后仍接收译文；同segment的user/merchant独立，connect_prompt使用稳定system段。解析异常不携带原文/票据；音频仅解码，不在本批播放。
- 静音/音源成功才更新，操作单飞但不阻止挂断，晚到成功不更新结束页。AppAudio沿v65不支持DTMF，明确提示而不假装发送成功。
- 结束立即停计时/按钮和订阅；hangup排在已开始merchant-call之后，清理一次。失败/断线/结束状态待确认明确返回，不自动重复电话/挂断，没有国内结算。
- 准备页面可取消。新共享链路用不确定进度；旧UI-only演练的35%仍是明确的合成展示。

## 自动验证

- 新增29项：协议/字幕7、控制器13、模拟端口2、页面7；全量1672项通过。三宽度320×568、390×844、430×844，包含乱序、其他会话、旧连接、挂断并发、失败和计时。
- analyze无问题，766个Dart文件格式、OpenSpec19项通过；正式Web、Android Debug、Mac iOS Debug无签名构建通过。Web既有Cupertino字体树摇警告仍存在，本批未把构建通过作为所有图标视觉验证。
- 首轮模拟测试中Dart已完成取消/close Future跨fake-clock zone使清理等待逃出测试时钟；内存端口改单订阅及显式zone-local取消，不改变正式清理契约。结果文本改普通Text便于可访问定位，未跳过断言；临时定位输出已删除。

## 浏览器演练

`tool/previews/translation_session_preview.dart`，本次本机 http://localhost:8105/；开发者功能演练也有“翻译共享会话演练”入口。

正常场景在10秒内点击“注入媒体就绪”，振铃后注入接通/字幕，操作四按钮，远端挂断返回。浏览器确认create/merchant/hangup各1，DTMF进入内存端口。回退场景确认close:liveKit先于connect:websocket、ready后才merchant；按键显示不支持且无dtmf发送记录。全程无真实网络/电话/录音/麦克风/账号写入。

## 剩余实现与集中人工验收

2.2、2.3及整体迁移仍未完成；正式拨号继续提示媒体未接入。

1. 真LiveKit room+realtime就绪、AppAudio ready/merchant_audio_ready、PCM录放音与路由。本批只有端口/codec，未增加媒体SDK。
2. 正式拨号装配、可信位置/账号生命周期、全局音频独占、原音混音和中断。Web固定语言GET代理不扩展POST、不绕过CORS。
3. 终态本机App记录、服务端录音/字幕授权、归档与历史刷新；本批不伪造记录。
4. 授权号码下双端验证：未发起准备前和结束后不采集；v65 LiveKit在用户发起通话准备、已获授权后便开麦完成ready，不是等对方接通才开麦。核对静音/扬声器/耳机、来电中断/后台/拒权、回退、远端终态与录音一致。
5. 新安装仍遵循已有授权门禁；本批没有安装、发短信、动真实账号或Mac保留解锁screen。构建不等于安装、媒体或视觉验收。
