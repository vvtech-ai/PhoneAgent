# 六类高风险能力完善与验收矩阵

2026-10-06；实施基点`8b17fb1`，当前分支`codex/dev`。用户确认执行七批计划；本轮覆盖自动核查、共享代码修复和连续流程预检，真实平台/业务验收仍单列。规格见[本轮change](../../openspec/changes/high-risk-capability-hardening/proposal.md)。原生固定来源及全部38项业务差异仍以[新版台账](NATIVE_FEATURE_PARITY_MATRIX.md)为准，本轮不代表其余W工作包完成。

## 实际修改

1. [录音控制器](../../lib/features/translation_history/presentation/controller/recording_audio_controller.dart)停止期间保持busy，实际stop成功才idle；失败显示“音频停止失败，请重试”并将错误交给互斥层。旧加载/播放回调先失效，新操作不能在旧stop尚未结束时开始。
2. [普通录音互斥](../../lib/features/conversation/domain/recording_playback_arbiter.dart)保留失败停止回调；下次显式claim/stop先重试旧停止，成功后才交接。队列可以继续使用，当前调用仍收到失败；没有自动恢复播放。
3. [翻译工厂](../../lib/app/translation_session_factory.dart)与[正式装配](../../lib/app/translation_finished_providers.dart)在当前账号终态通知后去重刷新钱包，不依赖记录/归档成功，不制造扣费/奖励或覆盖历史余额。准备失败也只是只读查询，不认为已收费。
4. [完整App演练](../../tool/previews/shell_invite_ports.dart)为新增邀请宿主补内存存储及无系统链接/剪贴板/文件副作用设备适配；保留禁止真实安全存储和系统链接调用的断言。正式邀请存储、链接与奖励行为未改。
5. 更新4个过期翻译页面断言；IO回环明确等待服务端收到stop再断言。测试只使用合成账号、回环服务和模拟设备端口。

## 功能与六类场景核查

“自动通过”仅指相应Dart/controller/widget/模拟通道或IO回环；没有真实服务或硬件结论。

| 能力/正式入口 | 正常与重复 | 权限/网络失败 | 退出、后台、账号及迟到 | 本轮结论 |
|---|---|---|---|---|
| ASR/TTS：[输入工厂](../../lib/app/conversation_voice_providers.dart)、[播报工厂](../../lib/app/conversation_speech_providers.dart) | ready后PCM；松手最多2秒收尾，单手势单提交；complete与实际drain分开 | 拒绝/迟到授权不采集；主识别错误或8秒未ready只回退一次；备用失败/释放失败不再启动 | 页面/账号generation隔离；后台/取消停止；切文字取消输入，但不因控件模式错误静音TTS | voice与core/audio定向覆盖，保留既有接线；真实声音未验 |
| 单路：[监听装配](../../lib/app/call_monitor_providers.dart)、[监听控制器](../../lib/features/calls/presentation/controller/call_monitor_controller.dart) | 监听只收PCM；静音清队列，恢复不重放；路由真实结果才更新；票据不等于接通 | 有界重连；路由失败保留原状态；输出/释放失败不假静音 | 返回仅停本地观察/监听；显式挂断单飞；终态不被迟到运行态降级；恢复不重发confirm_call | calls定向及连续挂断/恢复通过；真实外呼/蓝牙未验 |
| 国外翻译：[设备工厂](../../lib/app/translation_device_media_providers.dart)、[协调器](../../lib/features/translation/domain/translation_session_coordinator.dart) | create→media ready→merchant-call；LiveKit失败释放后AppAudio回退；仅明确409媒体门禁有限重试 | 权限失败不创建；双媒体失败不外呼；未知网络结果不重发；归档失败只重试归档 | 准备取消回收晚到会话；旧媒体事件隔离；停止排在已开始merchant之后；当前账号归档/记录 | HTTP/LiveKit/AppAudio/字幕/归档与回环定向通过；修复旧断言与收件等待；双向真实声音未验 |
| 身份SDK：[克隆装配](../../lib/app/clone_flow_providers.dart)、[保护采集](../../lib/features/voice_clone/data/focused_identity_capture_port.dart) | SDK1000/2006仍读后端PASS；候选/确认/计费独立幂等 | 初始化未知不重建attempt；未PASS不生成；失败持有资源，允许显式清理 | 过期账号不启动SDK/生成；业务取消与waitForRelease分开；iOS不能超时假释放 | voice_clone/identity与焦点定向覆盖；未采集真实身份；供应商无回调仍可能持续busy |
| 录音：[普通回执](../../lib/app/call_recording_providers.dart)、[翻译历史](../../lib/app/recording_providers.dart) | 普通点击取新播放源，保存独立新源；翻译历史缓存/文件校验；取消保存无成功 | 无效/过期源需显式重试；有界下载与失败临时文件清理；stop失败先重试后交接 | 加载、导出及播放检查归属；退页/账号变化不接迟到文件；停止完成前禁止新操作 | 修复两种停止问题，普通/历史直接调用方与下载/保存定向通过；系统导出文件回放未验 |
| 积分/评价：[共享钱包](../../lib/app/points_providers.dart)、[同步器](../../lib/app/wallet_settlement_providers.dart)、[条件评分](../../lib/app/task_rating_providers.dart) | 准入读服务端；历史回执只GET当前余额；评分先保存幂等key，已接受提交不因清理/钱包失败变成可重提 | 失败保留旧快照且标非最新；未知不当0；失败不重放收费/发奖 | 账号缓存/回执去重隔离；旧GET不覆盖较新权威余额；旧翻译终态无效 | 补翻译终态只读同步；记录失败、重复通知及换账号测试通过；实际账单/奖励未对账 |

直接回归入口：[停止交接](../../test/features/translation_history/recording_stop_handoff_test.dart)、[互斥重试](../../test/features/conversation/recording_arbiter_retry_test.dart)、[翻译终态钱包](../../test/features/translation/translation_wallet_terminal_test.dart)、[连续流程预检](../../test/extended_device_stage_test.dart)。新增4项录音失败测试先在修改前失败，修复后通过；翻译钱包另2项覆盖记录成功/失败。

## 双端工程配置与未验证项

| 配置 | Android当前源码 | iOS当前源码 | 需要完善/验证 |
|---|---|---|---|
| 工具链/身份 | Flutter3.32/Dart3.8；min26；Java/Kotlin目标11不代表运行JDK11；Dev包com.vvtech.aiassistant.dev | min15.5；Debug/Profile com.chaken.phoneagent.test，Release com.chaken.phoneagent | 本轮未改构建基线或升级工具；运行时配置沿用已验证模板 |
| 权限与媒体 | Manifest已有录音/相机/MODIFY_AUDIO_SETTINGS；MainActivity注册PCM与认证/导出，onPause停止PCM | Info.plist已有相机/麦克风描述；AppDelegate注册PCM/认证/导出，系统中断停止且不自动恢复 | 双端首次拒绝/永久拒绝/设置恢复、来电打断、耳机/蓝牙及声道真实验收 |
| SDK取消 | Android固定AAR，通过自己会话取消/释放 | 本地PhoneAgentIdentityCapture Pod；取消关闭自己的容器，但vendor inFlight未结束仍busy | iOS须确认供应商回调、相机/麦克风实际停止后再入；不添加强制超时解锁 |
| 生命周期/后台 | 当前普通页面离开停本地媒体；后台电话不因普通退出挂断 | 同一共享策略，独立AVAudioSession适配；本轮未新增Background Modes/Live Activity | 按批准语义验证后台/锁屏/中断；新版后台产品能力需要独立规格，不能只加权限声明 |
| 录音与文件 | 系统选择目标后写入；失败/取消清理本次输出 | 系统导出/文件选择与播放器薄端口 | 授权非私人测试录音，两端实际导出后回放、过期授权与账号切换验证 |
| 发布与数据 | Release签名为空且保护保留；生产com.vvtech.aiassistant，Dev不当OTA产物 | 无OTA；Release签名及SDK分发独立验收 | 正式Android同签名更高版本/旧数据升级、iOS发布签名另做；未安装设备，不触碰现有登录 |

配置检查是源码检查，没有把旧构建或本轮Dart测试冒充双端本批构建/真机结果。本轮未修改平台、插件、依赖或构建链，按当前验证节奏未重打双端包。

## 自动验证记录

- 原源`pub.flutter-io.cn`、`pub get --enforce-lockfile`成功；Flutter3.32.0/Dart3.8.0。初次默认源产生的无关lock变化已还原，最终依赖锁无差异。
- OpenSpec CLI1.2.0：33项通过，0失败；CLI在仓库外运行。
- 录音首修复相关128项通过；互斥追加修复及直接调用方28项通过。两组有重复，不相加冒充独立测试总数。
- 翻译终态钱包/正式provider/同步器14项通过。
- 六类阶段定向首轮1338项：1333通过、5失败。4项旧文案断言及1项回环收件时序已修正，相关25项复验通过；不是全仓库全量回归。
- 连续流程首次10通过、8失败，修复演练邀请隔离后8项复验通过。最终强化系统链接禁止断言、连续流程及邻接邀请回归25项通过；不与此前复验相加计数。
- 最终`flutter analyze --no-pub`无问题（2.5秒）；格式化单独记录为机械批次。手写修改文件均小于500行，`git diff --check`通过，新增文档链接在提交前检查。

定向命令范围：`test/core/audio`、`test/features/conversation/voice`、`calls`、`translation`、`voice_clone`、`identity`、`translation_history`、`points`、`feedback`，以及普通回执API/下载/保存/播放/宿主/规则/控件。连续流程使用`test/extended_device_stage_test.dart`、`keyboard_device_stage_test.dart`、`confirmation_device_stage_test.dart`、`test/conversation/task_error_status_flow_test.dart`；这些是flutter test模拟配置预检，没有驱动真实设备。

## 真实验收矩阵（均未执行）

从[集中主清单](MIGRATION_HANDOFF.md)M06–M11沿以下顺序执行，Android/iOS分别记录通过/失败/未执行/不适用；不将自动通过勾成真实通过。

| ID | 操作和通过条件 | Android | iOS | 外部前置 |
|---|---|---|---|---|
| R01 | 说话松手仅提交一次；上滑、切文字、退页、后台后不继续采集；TTS尾音、按住打断、回退失败/释放失败无假空闲 | 未执行 | 未执行 | 手机及可用测试语音网关，非私人语句 |
| R02 | 授权单路监听→静音→恢复不播旧队列→听筒/扬声器/蓝牙；普通返回不挂断，显式挂断与后台状态一致 | 未执行 | 未执行 | 明确测试账号/接听号码及次数、费用边界 |
| R03 | 授权国外双向翻译，字幕方向正确；LiveKit/AppAudio受控回退不重复外呼，结束当前call归档；钱包读数与后台一致 | 未执行 | 未执行 | 节点/账号/接听号码、受控媒体故障、费用边界 |
| R04 | 认证拒绝/取消/后台/再入；SDK成功后后端PASS才生成，候选/确认只执行一次；相机/麦克风实际释放 | 未执行 | 未执行 | 合法测试身份与采集同意，供应商环境/后台核对 |
| R05 | 普通/翻译录音各播放/暂停/导出取消/成功；导出文件实际回放属于当前call；过期源、退出下载和换账号不串文件 | 未执行 | 未执行 | 授权测试录音、双端系统选择器及文件回放 |
| R06 | 准入→通话结束→钱包→eligible评分→奖励，后台余额/流水/关联ID对账；断网同key重试无重复扣/发 | 未执行 | 未执行 | 测试账号、服务端账单/评分证据和费用边界 |

设备执行保留现有数据：构建、保留数据安装、启动、附加分别进行；驱动只用[run_shared_stage](../../tool/run_shared_stage.dart)的`--use-existing-app`并保持`--keep-app-running`，禁止默认flutter drive卸载。Android安装失败不卸载回退，结束核验安装时间及普通App登录。已有暂缓Android27点不在本轮自动重试。

记录模板：`Rxx | 平台/系统/版本/commit | 测试环境/时间窗 | 预期/实际 | 脱敏关联ID | 状态 | 证据位置 | 后续`。不要记录token、证号、媒体grant、签名URL、录音正文。真实测试前置与用户验收未完成，change保持active。
