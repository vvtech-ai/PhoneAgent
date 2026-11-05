- [x] 阅读任务规则、现有 TTS / provider / 设置 API 与诊断证据。
- [x] RED → GREEN：空闲 ready/pong、请求完成后心跳、预热不合成、过期快照有限重连。
- [x] RED → GREEN：A→B→C 独立回复复用物理连接，60 秒空闲、旧租约、打断旧 PCM 隔离。
- [x] 正式 family owner 接线，进入 / 输入预热，账号 / 任务 / 音色 / 生命周期 / 网络失效。
- [x] 定向测试、静态分析及确认 / 结果语音连续回归。
- [x] 执行扩大回归并如实记录整仓未通过边界；Release 1.0.52(45) 构建与身份、签名校验通过。

提交 / 推送结果及产物校验值由主任务最终交付清单记录；扩大回归边界见 regression-boundaries.md。

## 追加：任务 TTS 首包静默与结果漏播诊断

- [x] 从测试环境现有诊断区分首包静默重试和最终结果未发起 TTS；不把两者归为同一根因。
- [x] 各环境的任务 TTS 首包静默等待统一为 2 秒；保留一次 fresh retry、迟到 PCM 隔离和原播放门禁，并增加定向回归。
- [x] 对已显示的持久结果增加无正文的 TTS 门禁、匹配和入队诊断；不改变播报资格。
- [x] TTS 定向测试 64/64、10 个 Dart 文件静态分析、两项 OpenSpec strict 与格式 / diff 检查通过；test Debug 1.0.52 (45) 的包名、版本、登记签名、test 邀请配置与 JNI 字节校验通过。现有 Debug 构建仍含其他 ABI；单 ABI 分包触发 Gradle 配置冲突，本批未改构建配置。
- [x] 用户要求各环境首音等待与 test 一致：先以 local/dev/test/prod 均为 2 秒的测试复现 dev 实际 5 秒，再统一任务 TTS provider；8 个相关测试文件 63/63、10 个 Dart 文件定向分析及两项 OpenSpec strict 通过。未以自动测试代替真实生产首包验收。
- [x] 同一测试手机保留数据覆盖安装，手机 base.apk SHA256 与交付包一致，版本和首次安装时间读回，应用已启动。
- [ ] 真机复测实际首声、最终结论播报；用新诊断定位未发起 TTS 的具体门禁。

## 2026-10-27 批量结论漏播续查

- [x] test 批次 `batch-665cbc9a6e5b35fcaee43e0b93c927aa` 的服务端终态与手机结论诊断对齐：结论可见，结果资格在终态前丢失；旧日志未记录造成资格丢失的入口。
- [x] 先复现底层自动取消旧音频后批量结论无法入队，以及前台过早入队；保留明确停止后批量、单路结论静音的相反回归。生命周期和底层取消分离，批量原因码区分用户停止、显式中断和播放失败。
- [x] 10 个相关测试文件定向 99 项通过，4 个改动 Dart 文件定向 analyze 无问题。
- [ ] 新包真机批量外呼复测：核对实际扬声器、批量门禁原因和生命周期；现场触发入口确认前不宣称该批次根因唯一确定。

## 本批验证

- 固定 Flutter 3.32.0：`flutter test --no-pub test/features/conversation/voice test/features/conversation/apology_opening_speech_test.dart test/features/conversation/apology_voice_flow_test.dart test/features/settings/task_voice_preview_wire_test.dart test/core/audio/media_diagnostics_provider_test.dart`，306 / 306 通过。
- 修改范围静态分析无问题；所有手写生产文件小于 500 行，UTF-8 中文读回正常。
- 真实 RED 包含：完成后不发 idle ping、过期配置未重连、软完成复用旧 wire、回复结束关闭健康连接、换模型未停止排队 PCM、晚建 reply 错过离线快照无限等待、复用 wire 的首 PCM 未关联本轮 trace、任务 close 未关闭 owner。
- 扩大回归发现既有语音预览测试在 PCM 未消费时期待发送按钮。单补重建帧仍失败，定位为真实 stop / drain 门禁；测试改为使用已有“模拟播完”控制并断言 stop 消失，再继续文字，不改生产门禁。
- 自动测试没有证明真实供应商静默已消失。主任务已构建并校验 APK；未执行设备音频、后端部署或真实外呼。
