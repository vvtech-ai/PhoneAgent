# Tasks
- [x] 1. 双端翻译专用入队/排空及原生安全统计。
- [x] 2. 本机提示音连续提交、设备桥和诊断接线。
- [x] 3. 定向测试、analyze、OpenSpec与双端构建。
- [x] 4. 双端USB保留数据安装与中文提交推送。
- [ ] 5. 用户提示音/句尾听感及日志验收。

## 实施与验证（2026-10-09）
- iOS翻译专用enqueue高水位500ms、原生硬上限2秒；旧缓冲实际播放回调提供背压，drain仅实际待播归零完成，取消释放ordinary/admission/drain全部等待。普通play实际完成语义保持。Android复用连续写入能力，新增硬件及队列统计。
- 本机提示音按最多200ms连续块提交，取消/真实排空门禁保留；远端提示音和模型触发的20ms协议流保持。本机模型连续队列不再在iOS等待每块播完；尾音不因完成事件提前清队列。统计周期5秒、提示音段尾及关闭前采样；诊断失败不阻塞段尾完成或改变播放租约。
- 103项定向测试通过（普通TTS及海外媒体直接调用方包括在内）；analyze无问题3.9秒。实际Swift admission规则提取编译执行通过：高水位背压、未播空提前放行、真实drain、取消恰好一次。Android debug构建7.3秒、iOS Profile构建32.8秒通过，codesign深度严格校验通过。未执行全量Flutter回归或真实外呼。
- OpenSpec1.2.0专项valid；全量55通过/3既有MODIFIED遗漏scenario错误，仍为incremental-validation-policy、login-presentation、native-feature-parity-audit，不改无关规格。首次读取focused桥路径误猜，rg核实data/sip路径后恢复；无未恢复工具故障。
- Android2026100924匹配既有证书，USB install -r成功；firstInstallTime保持2026-10-08 11:03:08，lastUpdateTime2026-10-09 19:33:40，启动截图确认已登录首页和既有数据。iPhone15测试com.chaken.phoneagent.test Profile2026100924覆盖安装及独立启动成功，后续进程仍在；正式com.chaken.phoneagent 1.0.46(11)保持。两端无卸载清数据，iPhone登录未读屏验收。
- 源码<=3文件职责微批；格式化机械批独立。Swift344、Kotlin343、DomesticSipMedia498、factory386行，无新增超500行例外；保持无关pubspec.lock未提交。不提交真实诊断日志、截图、签名或私有配置。
- 实际提示音与句尾听感待用户复测，本change及此前音频change均未归档。
