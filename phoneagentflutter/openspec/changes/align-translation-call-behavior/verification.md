# 实时翻译四项行为对齐验证

## 版本与范围
Flutter起始0c7f77e2，aiassistant_app参考8f23592；本地codex/dev_zys实现，无分支切换、提交或推送，参考项目和后端未修改。Flutter3.32.0/Dart3.8.0。仅模型/承载/号码、计时、字幕收尾及其质量反馈接线；Flutter现有布局和共用控件保留，国内账单不在范围。

## 已实现
- 国家绑定模型的transport决定实际通话承载；WebRTC QWEN请求与诊断映射qwen3.5-livetranslate-flash-realtime，偏好可恢复；LOCAL_SIP按主被叫国家决定租约类型。
- 号码目录规则提醒复用共用确认弹窗；确认绑定登录、号码、国家、设置、模型及目录快照；只允许受限纯数字兼容，保留国家/模型/语言和实际配置门禁。取消或重复点击不创建会话。
- connected/translating建立唯一接通起点，毫秒向上取显示秒，非负及Int上限保护，不改变后端计费。
- 已有片段可接收最终修正，挂断冻结key、终止500ms内更新旧归档；页面dispose仍可归档、不同session及过期账号隔离。底层关闭期间只转发字幕，不延长采集或播放；已关闭事件源取消排空定时器。归档seal后新观察不自动重试失败请求。environment unavailable拒绝字幕。
- 面板质量依据实际transport，SIP精确ID/WebRTC引擎分别读取，避免千问国际站永久加载和同名覆盖。

## 验证
1. 关键流程末轮48项通过：号码确认、路线、SIP装配、预览关闭、归档幂等及拨号页。
2. 翻译/拨号模块和Shell翻译入口回归987通过/10失败（77秒）。失败全部在下述原始快照复现，不将此集合称为全仓通过。
3. 回归后微批18的环境/字幕/控制器/归档/号码/节点等66项定向通过。
4. 回归后微批19–21的质量/混合承载/模型面板/号码/页面及正式契约55项定向通过（6秒）；后续未再跑全模块，集合重叠不累计。
5. analyze、OpenSpec和diff最终结果见tasks.md末尾；手写修改源码均不超过500行，无新增例外。

## 原始基线失败复现
以git archive HEAD=0c7f77e2建立临时源码快照，独立package_config指向快照自身，共22项：12通过/10失败，与修改工作区对应失败一致。
- domestic_model_sheet_test.dart：目录失败重试、同协议ID、Android/iOS两字体倍率组合，共6项；倍率语义标签断言与既有页面不一致。
- domestic_model_quality_test.dart：Android/iOS面板刷新，共2项；现有测试查找器未找到行。
- translation_persistence_pages_test.dart：偏好恢复、读取失败重试，共2项；既有页面文本断言不一致。
- 同快照translation_dial_flow_pages_test.dart原本通过；本轮发现的dispose观察引发失败归档重复请求已修正并复验通过。上述10项既有测试和页面未扩展修改。

## 工具恢复记录（记录时间2026-10-16 20:09:50 Asia/Shanghai）
OpenSpec初次因PATH无node未运行，定位已安装缓存node后170项通过；未安装或升级工具。临时基线首次Flutter native assets找不到项目package，读取当前package_config后改为快照相对rootUri及canonical工作路径，有限重试完成。质量样本内联表达式一轮Dart解析失败，6个测试文件加载失败而非业务失败；拆独立sample函数后format及55项复验通过。中间rg旧路径/空glob已根据文件清单校正；所有实际修改保留在本change，无真实副作用。

## 未验证
Android/iOS真实设备、当前后台启用模型与媒体效果、真实外呼/录音、生产升级均待独立授权验收。此次无平台/插件/依赖/构建链改动，未构建或安装。
