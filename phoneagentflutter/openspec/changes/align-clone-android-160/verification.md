# 声音克隆对齐验证（2026-10-16）

## 2026-10-21 iOS 真机续查
- diagnostics.jsonl 25 中三次试听下载成功、原生 prepare 返回 NSOSStatusErrorDomain / 561017449，确认仅调整 Playback 未解决问题。补充闭集 nativeStep、失败调用前的 sessionCategory / sessionMode / sessionOptions 与 nativeAttempt，兼容旧字符串 NSError，不记录音频、路径、设备名称或任意原生消息。
- diagnostics.jsonl 26 第 309 行进一步确认 nativeStep=setCategory、sessionCategory=playAndRecord、sessionMode=default、sessionOptions=0、nativeAttempt=3；尚未调用激活。针对该现场，在试听持有媒体租约、无采集 owner、应用在前台且无通话时，先停用录音类别会话，再设置 Playback 并激活。停用失败记录 deactivate 并停止准备；延迟重试重新核验采集 owner 与插件有效性。
- 认证采集前的 PlayAndRecord / Default / DefaultToSpeaker 配置保持，Android 临时 WAV 播放及 Flutter UI 不变；不恢复过期全局配置，不改变认证、生成、计费或默认音色业务。
- 试听相关 12 项和采集 / 释放相关 27 项定向测试通过，定向静态检查、原生语法检查及 iOS Profile 签名构建通过。
- 使用工程 cloud-test/ios-device-defines.json 安装到已授权 iPhone 15，用户确认连续两次试听均能正常听到声音。此结果覆盖已有克隆试听；重新认证完成后立即试听的完整链路仍待回归，不把 Dart 模拟测试等同系统音频交接验收。

## 基线和范围
Flutter 调查基线 414299ba；旧 Android 只读参考 origin/feature/test_v1.6.0 / 8f23592。仅客户端声音克隆及模型入口接线，工作区同期 OTA 修改由其他工作独立提交，不包含于本次补丁。

## 自动验证
- 先复现固定系统音色恢复、非当前模型旧快照、iOS 特有失败页、模型入口二次选择、试听无重试、播放排他配置及扣费提示缺失等失败用例。
- `flutter test --no-pub test/features/voice_clone test/features/call_models test/shell_clone_workbench_test.dart test/shell_clone_entitlement_entry_test.dart test/features/points/clone_wallet_provider_test.dart test/architecture_test.dart --reporter expanded`：699 项通过。
- 后续扣费去重改为生成操作 ID，以兼容旧响应缺省 candidateId；`flutter test --no-pub test/features/voice_clone/clone_charge_notice_test.dart test/features/voice_clone/clone_flow_controller_test.dart test/features/voice_clone/clone_flow_page_test.dart test/architecture_test.dart --reporter expanded`：40 项通过。
- `flutter analyze --no-pub`：No issues found。
- `openspec validate --all --json`：171 项通过、0 失败。
- 关键连续路径覆盖：全局选择不同模型并返回更新其音色；模型内直接进入；删除后复用录音再克隆；两端有效/失效录音页面一致；历史结果和恢复旧候选不重复扣费提示；非活动模型刷新后展示克隆音色。

## 运行态边界
诊断 ZIP 的三次 iOS 试听下载均 HTTP 200，随后 prepare 报 NSOSStatusErrorDomain / 561017449。已改为 playback + mixWithOthers，同时保留应用内音频租约、SDK waitForRelease 和真实清理确认；该修改尚不能证明设备错误已消失。
未修改原生 Swift/SDK，不在 Windows 宣称 iOS 编译成功；Android/iOS 真实认证、扣费、删除重建、试听与默认音色切换需真机验收。本次不打包、不安装、不触发付费接口。
