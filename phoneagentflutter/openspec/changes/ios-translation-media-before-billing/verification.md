# 验证记录（2026-10-23）

## 基线与范围

源码基线 codex/dev `d5a793c6445371f501ebff527783c2adbe4019e9`，开始时工作区干净。验证阶段未切分支、提交或推送；随后用户明确授权提交并推送 codex/dev。仅生产 iOS LOCAL_SIP 工厂启用新顺序；Android 原生、海外路径、文案与 UI 文件未修改。共享 Dart 仅增加可选能力，默认关闭。

修改前回归实际失败：模拟媒体启动失败，trace 明确是 `points.connected → media.start → points.terminal`，断言不得发送 connected 失败。修复后 iOS 准备失败 terminal 使用 connected=false、duration=0；正常只 connected 一次；挂断、远端结束、账号失效后的迟到准备不启动计费；计费上报失败不运行媒体。

后台只读核对 PointsUsageSessionRules.billableDuration 与 PointsUsageSessionApplicationService.terminal：无服务端 Connected 时 terminal(false,0) 结算 0 并释放预占；已有服务端 Connected 不能反向改为未接通。此为本地源码合同，未验证实际部署与本次历史流水。

## 自动验证

- 固定 Flutter 3.32.0，`flutter analyze --no-pub`：无问题。
- 最终定向 226/226：core/audio、iOS 新顺序、coordinator、media、PCM、focused bridge、controller、factory、录音 session、积分 owner、错误文案、通话 route、设备媒体工厂、SIP，以及原生崩溃/身份诊断 Dart 投影。含 Android 默认顺序、普通 ASR/TTS 不使用新参数、正常字幕/媒体/静音/扬声器/DTMF/结算/取消等既有回归。
- 扩大 translation 模块：935 通过、27 个实际测试失败；另一次命令误传不存在的 conversation/data/voice 测试目录产生 1 项加载失败，最终定向命令已改为真实 core/audio 路径。
- 用修改前 HEAD 的 git archive 隔离快照复跑 7 个失败文件：23 通过、27 失败。按测试文件与用例名比较，27 个失败集合完全一致，无新增实际失败；不删除断言或扩大修改这些既有问题。
- 既有失败文件：domestic_model_sheet_test、translation_access_pages_test、translation_pages_test、cross_border_translation_dial_test、domestic_model_quality_test、native_translation_model_panel_test、translation_diagnostics_binding_test。

## Mac 编译和符号

`flutter build ios --debug --no-codesign --no-pub` 成功，生成 `build/ios/iphoneos/Runner.app`，未签名、未安装，不是可交付 IPA。构建中 pod install 自动补写了当前基线遗漏的本地崩溃诊断依赖锁和工程集成；已恢复这两份本次自动生成的 tracked 差异，不把无关锁文件/工程变化混入提交。

本次二进制与 dsymutil 生成的符号保留在 build/ios/ios-media-validation-symbols/，dwarfdump 验证：
- Runner arm64：EE7AB58A-CEB0-3C7F-BC7B-C93D89CF58DE。
- Runner.debug.dylib arm64：BA2D337C-5693-3030-8A1F-A9FF8C160B2D。
- Runner 启动壳缺少调试符号；供应商静态库存在其构建机器 PCH/module 路径缺失警告，UUID 匹配不代表供应商符号完整。

## 待验收

未安装或操作用户手机，未发起真实外呼、认证或克隆操作。iOS 真机音频、权限与前后台、连续拨打、真实结算及历史回看仍需验证；原生处理器共存、SDK 正常流程和崩溃重启回放也未完成。Dart 与 Mac 编译不能替代这些证据，不声称其他功能已全量真机验收。

保持 change 未归档。当前错误提示继续沿用原兜底；按用户要求没有新增或替换用户可见文案。
