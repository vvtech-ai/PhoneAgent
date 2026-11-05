# 翻译历史录音：共享交互与集中验收

更新：2026-09-18。共享交互 **2.9a** 之后，已接通 **2.9b** 的文件缓存/播放器/系统导出和正式翻译历史页；真实录音、双端系统行为和普通单路/批量复用仍属 **2.10**，未完成集中验收。用户批准现有 HTML/CSS/组件先完成交互，精细视觉随后统一校准。

普通单路/批量的2.10a控件、显隐与明确MOCK回执演练已经续接，见[普通回执录音验证](RECEIPT_RECORDING_VALIDATION.md)。普通接口没有本页翻译录音的服务端size/SHA256契约，真实端口仍待2.10b，不允许直接套用本页自动预加载规则。

## 现在能查看什么

正式 App 的设置 → 开发者功能 → 进入隔离交互演练 → 翻译历史录音演练。开发者入口沿用既有本地拨号串 `20142014*#`，不拨电话、不上传号码。五个场景：正常播放暂停/保存取消、处理中、加载失败、播放失败、保存失败。每个都复用 `TranslationHistoryPage`、`RecordingAudioCard` 和 `RecordingAudioController`，能关闭回到场景列表。

演练页面固定标示 **MOCK**：字幕为合成文本，12秒计时只是状态演练，无网络、真实声音或文件写入。保存弹窗模拟系统选择；取消无成功提示，模拟确认才返回成功或合成失败。

正式 Android/iOS 任务 → 翻译详情在有效录音元数据到达后独立预加载，点击播放才出声，保存打开系统选择器。Web 正式页明确提示使用 App，不创建原生端口或下载真实录音；Web 演练仍完全隔离，不暗换为真实请求。本轮验证未打开任何真实录音详情。

## 实现边界

| 层 | 本批实现 | 尚未完成 |
| --- | --- | --- |
| 共享 UI/状态 | 预加载但不播放、处理中、播放/暂停/续播、完成归零、剩余时长、失败重试、保存/取消、离页与旧账号晚到隔离；正式Route装配 | 真实声音及系统行为验证 |
| 共享接口/文件 | 刷新详情与授权；账号头/签名URL隔离；账号/API/通话缓存键、大小/SHA256复核、Range/200覆盖/416一次恢复、跨实例串行 | 真实HTTP联调、设备断网/磁盘压力、缓存配额/长期淘汰治理 |
| 媒体/保存端口 | 现有audioplayers6.4.0串行本地文件播放；Android CreateDocument / iOS export-as-copy；本次文件再次校验后导出，可取消 | 系统选择器/导出文件实际回放、焦点中断及跨模块音频资源协调 |
| 页面/资源 | 现有翻译详情插槽、设计源保存SVG补内联CSS描边、资源显式打包、底部自适应 | 装饰波形、细节阴影/间距、双端最终视觉校准 |

`RecordingAudioController` 只编排端口；UI不读Repository/网络/文件。文件路径只在repository/player/exporter之间传递，不进入可显示状态；授权、签名URL、原始异常不显示。显式重试失效此前文件、重新解析授权；串行stop/prepare/play/close防止旧stop打断新播放。插件默认错误会带私有文件路径，因此本适配器关闭其全局原文日志，控制器仅呈现脱敏失败；未新增敏感日志。

实现位置：`lib/app/recording_providers.dart`、`translation_history/data/recording_source_resolver.dart`、`recording_file_downloader.dart`、`io_recording_repository.dart`、`plugin_recording_player.dart`、`device_recording_exporter.dart`；条件导出隔离Web，`RecordingAudioRoute`接原页插槽。磁盘只用SHA256文件名，URL/请求头不落盘；校验前半文件只能续传，不能播放或导出。当前系统缓存不做承诺永久保留，尚无额外容量配额/自动淘汰策略。

Android `RecordingExportChannel.kt` 和 iOS `RecordingExportChannel.swift` 仅校验私有目录资产、复制本次快照并调用系统文件选择器，不含账号/下载/业务状态。源大小及SHA256再次核对，操作ID限定取消范围，不请求广泛存储权限。Android仅在本次新建文档写失败时尝试清理该URI；提供者拒绝删除可能留下不完整文件，列入人工验收，不保证系统提供者行为。

平台依据：[Android Storage Access Framework](https://developer.android.com/training/data-storage/shared/documents-files)；[Apple export-as-copy选择器](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller/init(forexporting:ascopy:))。不支持在Web伪装原生保存成功。

## 固定源证据

- Android/backend基线 `4c781e3ccfcd148c1f205921534907ee0c5aa864`：`RealtimeTranslationHistoryRoute/ViewModel`、`RealtimeTranslationHistoryPresentation`、`RealtimeTranslationRecordingSaveCoordinator`、`WorldCallRecordingApi/Repository`、`RecordingDownloadRepository`。
- 后端 `RealtimeTranslationRecordingController` 路径是 `/api/realtime-translation-calls/{callId}/recording-content`，不是猜测的`/recording/content`。Android把该相对路径拼接至配置应用上下文；Flutter解析保留`/aiassistant-api/`且不向外部域名附带账号头。
- WORLD_CALL仅`RECORDING_NOT_READY`可按`retryAfterMillis`等待，累计延迟最多120秒；过期grant等其他失败不自动循环。下载URL只接受HTTPS，无userinfo/fragment；其请求头不含账号或grant。该解析器已接正式Android/iOS页面，未执行真实授权请求。
- v65没有进度拖动；本批没有添加seek或新呼叫操作。录音错误不删除已有字幕。
- 设计 `0cd58de9bb578845517aeb54bef8ab6970392b81` 的 `v64HistoryDetail/v64Recording` 与 `memory/css/v64.css`。保存SVG原path未变，内联CSS的白色stroke、2线宽、round端点与连接；原始/处理后hash分存Manifest。未重新采集或宣称像素验收。
- iOS参考 `ddb996a28f98559ea7d8b76ca9d7712703dedbc1` 的Objective-C `AISettingsRealtimeCallVoiceViewController`，有本地AVAudioPlayer与离页释放；未找到同等翻译历史录音卡，不据此删掉Android既有功能。

## 2.9a 历史验证证据

- 新增49项：状态机16、源解析23、Widget/入口/资源10；全量 **1,269项通过**。
- `flutter analyze --no-pub` 无问题；570个Dart文件格式校验；OpenSpec **19项通过**。
- Web Debug及Android Debug构建通过，未新增依赖或原生代码。**本批没有iOS新构建、没有双端安装/真机验收**，没有触碰Mac保留的解锁会话。
- Widget覆盖320/390/430宽、字幕保留、无seek、弹窗取消、三种失败后重试、离页停止；协议测试覆盖真实路径形状、空POST、账号头边界、错误码有界等待、错误hash/大小/身份拒绝。
- 浏览器`localhost:8080`：正式导航进入演练，播放→暂停（剩余时间变化）→保存取消，无成功误报；保存失败→重试→可播放，字幕仍在。登录保留，没有新短信/真实录音请求。
- 初轮全量发现旧开发者页小屏测试假设按钮已构建；新增入口后需先滚动，已修正定位，未删除断言或改变业务。保存dialog有持续spinner，Widget按有限帧推进而非等待所有动画永久结束。
- 浏览器曾发现旧开发服务器资源包对新增SVG返回404；显式pubspec登记已通过资源测试，完整重启8090服务后复核图标显示。8080代理和账号存储未更改。

## 2.9b 自动验证证据

- 新增36项：下载/磁盘19、IO组合3、播放器5、导出通道5、正式Route4；全量 **1,369项通过**。只使用合成字节、临时测试目录和模拟播放器/通道，无真实录音。
- `flutter analyze --no-pub`通过，617个Dart文件格式检查通过；Web Debug通过。Android Debug与Mac Xcode15.2 iOS无签名构建均以测试API的`/aiassistant-api/`上下文验证，最终产物结果同步至任务记录。
- iOS首轮发现FlutterPlugin要求标准register方法，补充标准入口后构建通过；真实注册仍显式传入宿主。无工具链升级、签名、安装或Mac保留会话操作。
- 自动回归覆盖缓存篡改/重用、强制失效、跨账号隔离、并发单飞、200/206/416、错范围/长度/超长/坏hash/关闭，播放结束/暂停/旧事件隔离，以及正式页无录音不挂载、失败保留字幕、退出释放。
- 本轮未重启现有真实Web会话或重复录制相同演练截图；原演练不变，正式入口新增行为以Widget回归验证，不宣称新浏览器/真机验收。

## 后续集中验收（2.10，未执行）

1. 接线：真实详情存在录音时独立预加载、绝不自动出声；缺失/格式错误录音不影响字幕，失败按钮可重试。
2. 授权：分别核对World US/JP和已有PHONE_AGENT历史；授权过期重试刷新详情/grant。日志不得输出grant、完整签名URL或私有路径。
3. 文件：校验大小/SHA256、正确缓存命中与篡改失效；断网Range恢复、服务器忽略Range返回200、416只一次全量重试、半文件和坏hash处理。
4. 声音：播放/暂停/续播/结束重播、后台/来电/其他App抢占、拔耳机、退出停止。确认与统一对话、克隆试听、通话监听不互相争用音频。
5. 保存：Android创建文件、iOS导出选择器，确认/取消/返回、低空间/写失败、导出文件可播放；取消不能误报成功，失败不能误删用户其他文件。
6. 归属：换账号/退出页面时未完成下载和导出不更新新页面，不复用别人的文件；普通单路和批量录音仍需独立接入验收，不能只测翻译页。

安装需先恢复设备安装授权。可用合成录音先测文件流程，真实通话录音播放/导出应在用户授权的样本上集中执行。不以Web MOCK、产物构建或端口接口存在代表真实能力完成。
