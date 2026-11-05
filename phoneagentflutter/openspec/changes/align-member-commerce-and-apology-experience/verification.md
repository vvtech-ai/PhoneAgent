# Task 1 实施者验证（2026-10-16）

基点：Flutter `d1a20cca`（codex/dev），Java `98a75836`（feature/test_v1.7.0）。仅实施会员恢复、积分包配置折扣与流水标题；道歉与Web时间留后续批次。

## 实现边界
- ProductOffer/DTO 保留可空 packDiscountBps；PointsOfferDiscount 只从权威字段生成配置折扣，缺字段旧响应不反算。7500bps的10分→7分、一分保底均显示7.5折；同价不划线；Apple当前显示和购买仍用真实SKU价，不二次折扣。FREE、无折扣、非积分商品不生成会员折扣。
- CommerceOrderHistory 为可选分页扩展，原CommerceRepository/调用签名不变。API与诊断装饰器向既有订单接口传 APPLE_IAP/page0/size1，不扫描历史；服务端认证账号与渠道条件先于分页。
- apple_restore_providers 独立管理账号历史和最终入口，会员页只接 showRestore。未加载/错误/支付宝历史隐藏；按 loginEpoch 销毁旧代，旧账号迟到结果无效；恢复完成刷新历史。
- AppleRecoveryEvidence 只接收当前账号付款材料发起的pending/匹配token交易，或服务端接受的Apple订单。自动补单不依赖历史已存在，未知原生交易/异账号拒绝不供证据；退出/切号不沿用。补单后即使历史仍空也能更新入口。
- 原生恢复循环移至已有AppleTransactionVerifier，主PurchaseController489行；归属规则、网络、显示分开，无新增大控制器。SDK/后台仅投影“订阅会员积分”，历史账务不改。

## 真实RED与最终GREEN
1. Java折扣18项先6失败→18通过；后台历史标题4项先1失败，SDK标题4项先1失败，订单HTTP过滤2项先1失败→10项通过。
2. Flutter折扣12项先9失败→12通过。恢复加载入口/缺过滤请求已复现；owned pending和补单证据4项先2失败→接线后9通过。
3. 商业化完整集合628项通过。后续新增空历史pending、补单后的入口、切号退出、迟到接受不finish及同价Apple组件回归；刷新断言发现监听与watch同源重建丢失，移到history provider后18项通过。初始漏导入/cascade/平台重置脚手架错误已修正，不计作业务RED。

固定 Flutter3.32.0/Dart3.8.0；命令：
```text
flutter test test/features/commerce --reporter expanded
flutter test test/features/commerce/apple_recovery_evidence_test.dart test/features/commerce/apple_restore_visibility_test.dart test/features/commerce/published_points_price_widget_test.dart --reporter expanded
flutter analyze
openspec validate align-member-commerce-and-apology-experience --strict
openspec validate --all
```
结果：628通过，追加18通过；analyze最终无问题（首轮3条提示已修正）；strict通过，all165通过。未无理由重复完整集合，也未扩大无关全仓测试。

Java固定JDK17/Maven3.9.14的受影响Commerce/价格/目录/流水集合退出0，共271项：225通过/46环境门禁跳过/0失败/0错误。两仓当前change strict通过；Java all74通过/1既有无delta失败（audit-v66-single-call-stop-ui-parity）。未用模拟结果声称MySQL或StoreKit真实验收。

UTF-8严格解码/中文读回、git diff --check通过。仅中文本地提交；本次测试命令结束后不继续跑Flutter，不终止会话前已存在的4个历史tester。未推送、部署、打包、安装、访问真实账号/凭据、改版本或触发真实业务。

## Task 1 独立复核
固定审查范围为Java `98a75836..2a205568`、Flutter `d1a20cca..d05b9ebf`；独立审查给出规格符合、质量Approved，无Critical/Important。审查完整差异及现有账号代次/自动恢复接线，未重复运行同代码测试。既有commons-logging及预期故障日志列为非阻断观察；真实MySQL/StoreKit与部署联调仍未验。Web时间与道歉流程尚待后续批次及完整复核。

## Task 3 实施者验证（2026-10-16）
基点 `a58ff486938f15d2e2129e7eae7dd4f81536a320`，codex/dev。仅修改Flutter道歉生命周期/候选权限，不改商业化价格恢复、Java/Web、默认音色或真实外呼准入。主会话Controller保持508行且未修改；新增33行ApologyCloneAccess负责授权适配，其余在已有binding/provider/speech host薄接线，手写微批≤3文件，格式化独立机械批。

真实RED：API权限7失败/2通过（READY当前/候选仍被false放行、null未知被放行、未知失败未重试）→初轮9通过；正式Provider生命周期4失败→4通过，追加同步完成与历史后6通过。实际VoiceHost道歉旧开场提前播报1失败，普通开场业务断言通过但首轮遗留钱包脚手架timer导致测试也失败；修复并排空后2通过。候选confirm后撤权误报接口失败1失败→正常空音色，随后确认仍为候选可见性回归1失败→保留重试。最终API含候选确认前/后撤权、旧卡、账号/关闭迟到、legacy证据重查15项通过。

脚手架问题不计业务RED：apply_patch重复目标被拒且未落盘；测试路由判断须用uri.path而非带query的path、三次API链需充分排空；同步OCR回调触发的无关钱包读取改离线端口；Shell初版把导航前网络read悬挂，改先通过在线入口后在检测阶段失败；失败提示实际两处文本故改findsWidgets。均已完成对应重跑，无生产绕过。

最终固定Flutter3.32.0/Dart3.8.0：23文件定向集合119通过、1项既有可选演练跳过、0失败，38秒。覆盖全部道歉、正式Provider/语音宿主/320真实首页道歉、普通会话导航320/390/430、技能编排、现有取消/请求字段/模型scope、检测、OCR owner/资料流程及语音播报。跳过为shell_agent_document_capture_test的capture widget，受shellAgentDocumentEnabled编译开关控制，非OCR回归失败。日志D:/Temp/phoneagent-task3-targeted-20261016.log；完整命令清单见外部task-3-report.md。

`flutter analyze`无问题；`openspec validate align-member-commerce-and-apology-experience --strict`通过；`openspec validate --all`165通过。UTF-8严格解码、中文读回及git diff --check通过。未跑无关全commerce/全仓、未构建签包安装、未读真实账号凭据、未真实外呼/交易或部署。此次环境检测仍是既有presentation语义，不能据此宣称供应商连接或真实外呼验收；Java requireClone保持。root独立复核及真实环境验收待后续。

本次测试全部自然退出，不终止会话前已存在的4个历史flutter_tester进程；不遗留此次测试。仅中文本地提交、不推送。root追加Task5规划保留，非本批实现范围。

## Task 3 独立复核
固定范围 `a58ff486..1c4792dc` 的规格与质量均通过，无Critical/Important。独立核对检测visible语义、同步owner/speech初始化、候选确认重查及账号守卫；119通过/1项capture开关跳过经冻结日志核对，未重复运行同代码测试。既有CALL_MONITOR_STATE日志噪声列为非阻断观察。
root只读核对Java既有边界：TaskCallVoiceSelectionService、SseBatchStartContext、SseCallStartAdmissionImpl在任务选择/发起调用requireTaskVoice；VoiceCloneSettingsService.resolve读取当前权益并requireClone，且common规则同时检查通话与克隆模型。不据源码核对声称已部署或真实供应商验收。后台时间Task2也已完成独立双复核（Web `69f14dd..69c7af3`，Node190通过/生产构建通过）；会员权益列表排序Task5单独Java实施中。
## Task 5 跨仓状态
Java `4c32149f..dcd935d7` 已完成会员权益列表推进时间倒序，原始datetime在分页前排序，NULL置后、同时间稳定，不改详情业务队列。14项回归通过/4项MySQL门禁跳过，独立规格与质量均通过；Flutter无需新增排序或接口字段。真实MySQL、部署及性能仍未验。

## 最终完整复核与代码交付（2026-10-16）
独立完整审查覆盖Java `98a75836..f2caec07`、Flutter `d1a20cca..de90e98f`、Web `69f14dd..6499c3a`，规格符合、质量Approved，无Critical/Important及新增代码Minor。七项修复及跨仓账号恢复、检测完成、正式发起授权、SDK时间投影与分页路由均已核对。本交付提交仅补验证和任务记录，不改变已审生产源码。
目标分支：Java/Web `feature/test_v1.7.0`，Flutter `codex/dev`；推送前远端仍为原始基点，工作树仅Web旧output未跟踪且保留。推送后实际远端读回以 `D:/work/04phoneAgent/.local-data/logs/member-experience-20261016/delivery-report.md` 为准。完整审查与实施证据同目录保留，change继续active，待用户验收。
验证：Java商业化225通过/46环境跳过，排序14通过/4环境跳过；Flutter商业化628及追加18通过、道歉119通过/1可选capture开关跳过，analyze无问题；Web190通过，Node16类型检查/生产构建通过。当前change strict与UTF8/diff通过，Java全量规格仅既有无delta项失败。
边界：没有部署、安装、真实MySQL/性能/StoreKit/设备音频/供应商外呼支付验收。旧规格缺delta和既有日志/包体提示未扩大修复；后台其余时间入口已定点核对，不作全仓安全审计。新签名包尚未构建，等待本轮版本答复，不自动递增。

## 本轮测试签名包完成（用户确认1.0.52 / 45）
用户在代码推送后明确本轮仍用 `1.0.52 (45)`。冻结 `codex/dev / c42c97f1799e95360fd66e548022e9a22aac7278`，构建前后HEAD相同且Git干净，无并行本次Flutter测试。本节仅补交付文档，不改已审生产源码。

- 产物：`D:/work/04phoneAgent/deliveries/member-experience-20261016-45/Phone_Agent_TEST_1.0.52_45_test_20261016_130751.apk`，78,974,560字节。
- SHA256：`12bf10844c0c26b1703bd743350c7e01b88587ec5df758955b4c55a078779aff`。
- 注册入口 `scripts/build-task-test-apk.ps1 -BuildNumber 45 -BuildMode Release -PlanOnly` 校验私有输入，随后使用其Release `--config-only --pub` 生成当前注册器并断言没有integration_test。JDK17/Flutter3.32、精确引擎哈希校验、离线Gradle assembleRelease退出0，3分16秒；仅ARM64，迁移预览关闭。
- 16项test_environment与dio_auth_gateway回归通过，测试全部结束后才构建。当前源码重新编译Dart product/AOT探针：独立测试服务可用且拒绝16种非法环境/地址。第一次PowerShell未完整传入-D参数导致CLI缺入口，确认未生成EXE后改用subprocess参数列表，重新编译并执行通过；不算生产缺陷。
- 当前SDK/Agent各一次合法和篡改C1只读请求分别AC0002/AC0009，证明签名进入账号认证及错误签名被拒；未用真实账号、未发短信。
- APK实际包名 `com.vvtech.aiassistant.test`、版本 `1.0.52 / 45`；apksigner验证通过，MD5 `ebd4c931de412bf5d9c3716815389097`、SHA256 `15478609ef2c9a268f154d345cdcc4d1cef17204ddac3e25f0d22a11e0fed6c7` 匹配登记证书。三个测试URL/邀请host与scheme正确，只有ARM64/AOT、无debuggable/调试kernel/校验库、11项保护库与来源逐字节一致，未混入签名或defines文件。新libapp.so哈希与上轮catalog-isolation交付不同。
- 交付目录包含七项修复README、SHA256SUMS、build-receipt、test-release-verification、runtime-config-probe及pushed-branches。用户要求修复清单已覆盖六项原请求与新增后台推进时间排序。

没有部署、安装、真实支付/外呼或iOS真机验证；Java/Web修复仍需构建发布对应分支后生效。本次不重复已通过的业务集合，文档更新仅做UTF8/中文读回、OpenSpec strict/all及diff检查。
