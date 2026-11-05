# Tasks
- [x] 1. 平台队列、排空、取消和细分诊断。
- [x] 2. 翻译桥和提示音排空接线，保留共用及iOS契约。
- [x] 3. 定向测试、analyze、OpenSpec、Android构建。
- [x] 4. 匹配签名覆盖安装USB手机并核验数据保留。
- [ ] 5. 用户真实通话复现验收（不自动外呼）。

## 验证记录（2026-10-09）
- 61 项音频输出、翻译设备桥/聚焦桥、提示音gate、媒体/协调器/工厂、诊断、普通TTS及海外媒体定向测试通过；analyze无问题；Android Dev2026100921构建8.3秒通过。OpenSpec及diff校验通过。
- Android原生Logcat固定tag TranslationPcm记录bufferFrames、thresholdFrames、firstWrite、firstPlayed与释放原因；导出诊断保留output_stalled/output_focus_lost/output_cancelled。
- 首次静态分析发现可选接口类型需要显式转换、白名单重复及代码块lint，核对修复。新测试mock曾将Future作为返回对象交给codec，改为await后重验。
- 源码均500行内，按平台输出、桥接、提示音/诊断职责分微批；未改依赖，保留外部pubspec.lock。纯模拟定向不代替Android硬件听感或真实外呼验收。

## 安装记录
USB手机zpojayr8x4he6dbm同签名adb install -r成功；Dev包2026100921，firstInstallTime保持2026-10-08 11:03:08，lastUpdateTime2026-10-09 18:17:19。MainActivity启动，实际截图确认已登录首页、积分与历史任务可见；首张为启动过渡帧，重新截图确认稳定页面。未清数据、未卸载、未外呼。签名材料/密码未提交或打印；产物.local/android-diagnostics/app-playback-fix-2026100921.apk。真实通话待用户复现，不归档。
