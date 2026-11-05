# 克隆认证协议与共享核验

更新：2026-09-18。真实 HTTP 适配与共享认证控制器已实现；后续已补两端固定 SDK 及薄端口（见 [SDK 验证](IDENTITY_SDK_VALIDATION.md)）。正式创建入口尚未装配，不能当作真实认证已完成。下方 1104 项及无 iOS 构建是协议批次历史证据。

## 固定代码依据

- Android/后端 `4c781e3`：VoiceCloneVerificationApi/Models、EnrollmentRepository、EnrollmentCoordinator/Reducer、AliyunIdProSdkResultClassifier、后台 VerificationDtos/Controller/ObservationController/Service。
- iOS `ddb996a`：AIVoiceCloneVerificationService 和 AIAliyunFaceAuthAdapter。两端都把 SDK 1000 和 2006 交给服务端查询；不照搬旧 iOS 的 complete/activate 覆盖 v65 分模型候选。
- 后台返回 `INITIATED`，旧 Android Reducer 写的是 `INIT`。Flutter 兼容这两个已知初始状态；未知字符串拒绝解析。后台 expiresAt 是无时区 LocalDateTime，只保留并校验格式，不用手机时区推断过期，最终采用后台 EXPIRED。

## 接口和代码位置

共同路径：`api/account/settings/voice-clone/verification`。

| 操作 | 方法/后缀 | 核心约束 |
|---|---|---|
| 替换检查 | POST /replacement-check | certType=IDENTITY_CARD、规范化 certNo；replacementRequired 必须为 bool |
| 初始化 | POST /init | consentVersion=voice-clone-enrollment-v2、姓名、证号、SDK metaInfo、显式 replacementConfirmed；不自动填真实手机号 |
| 核验 | GET /{attemptId} | 严格匹配 attempt；已知状态映射，只有 PASS 通过 |
| SDK 观察 | POST /{attemptId}/client-observation | 设备型号/网络枚举/validated、sdkCode/subCode、分类与有界耗时；不传 SDK 原文 |

`voice_clone/domain/clone_verification.dart` 定义纯 Dart 协议和 SDK 端口；`clone_sdk_diagnosis.dart` 复用 v65 分类规则。`data/api_clone_verification_repository.dart` 使用现有 AccountApi 固定源、账号绑定、Bearer 及单次 401 刷新，拒绝任意路径和响应对象；网络失败不自动重试初始化。

`presentation/controller/clone_verification_controller.dart` 独立管理认证，不聚合候选、钱包、播放或录音存储。每实例一次初始化：准备 SDK meta → init → SDK 采集 → 服务端核验。替换确认由已有共享页面门禁显式完成，控制器不能推断用户同意。

## 状态与失败规则

- 1000/2006 均需查询；1003 是取消，其他 SDK 失败不进入候选。只有匹配 attempt 的 PASS 才通过 `verifiedAttemptId` 向下游交付；不在页面状态存 certifyId/metaInfo/身份证/SDK 原文。
- INIT/INITIATED/PROCESSING 最多查询 60 次，间隔一秒。达到次数或请求失败进入 needsSync；再次同步只 GET 同一 attempt，不重新初始化、采集、生成或计费。
- FAIL/CANCELLED/EXPIRED/NEED_RETRY 终止。providerSubCode 仅保留 205 风险和 220 跟读两个已知诊断，不转发任意服务端原文。
- SDK 观察上报每实例最多一次、尽力而为，既不阻塞 PASS，也不覆盖认证结果；失败单独标记，不自动重试 POST。
- 所有异步阶段均检查关闭/账号租约；关闭请求 SDK abort，抑制晚到、不续发查询或观察。已经发出的请求不能撤回，实际 SDK 中止语义仍需双端适配与真机验证。
- 认证材料只短时驻留内存；不增加真实录音/身份文件、不写日志。SDK 不可用不得降级为模拟成功。

## 自动验证与范围

新增 43 项：14 项 HTTP/解析及生产适配器串联、25 项生命周期、4 项 SDK 分类。合成 SDK 返回 2006 后经真正 Repository/AccountApi 发 init → GET PROCESSING → GET PASS → observation；没有 complete/activate、候选或支付请求。

覆盖字段、固定源、授权、401 保留原身份请求、跨账号不重放、非法响应/attempt、取消、服务端失败、有界轮询、同步不重启、观察失败/迟到及退出/切账号。测试仅合成 SDK 与本地 HTTP 替身，不访问供应商或真实账号。

初次测试把 AccountCredentials.epoch 写成 loginEpoch，已修正；后续串联测试未等待异步观察收件，已改为显式 Completer 收件信号而非固定 sleep 或删除断言。最终全量/构建结果见根 tasks.md。无新增 UI，没有新增逐屏截图、设备安装或 iOS 构建；本批不修改原生/依赖。

最终验证：1104项全量通过，analyze无问题，522文件格式检查与19项OpenSpec通过；Web Debug同源测试代理及Android Debug测试环境构建通过。SDK实际弹窗、后台真实认证与双端授权行为不能由这些结果替代。

## 剩余装配与集中人工验收

1. **SDK 已实现、待真机核实**：Android AAR/iOS frameworks 固定集成及 prepare/capture/abort 薄端口；供应商 Bundle ID/包名配置、许可、权限和资源释放待验。iOS 关闭专属容器后仍须等 SDK 真正回调才解除单飞，公开 API 无可靠强制中止，见 SDK 验证文档。
2. **仍需装配**：正式共享授权/身份/替换确认页 → 本控制器 → 分模型候选控制器，配合钱包准入、录音保存/复用、试听/确认/离页恢复。现有演练端口不在本批偷偷切换。
3. **人工前提**：端口与页面已装配、标准安装授权、测试身份及认证操作获用户同意；保留已登录会话，不重复索要短信。
4. **操作/预期**：拒绝权限或取消应结束采集且不生成；SDK 完成但后台 PROCESSING 时仍核验中；PASS 才生成；FAIL/EXPIRED 不生成。断网恢复只查询同 attempt；切账号/离页不得续发旧流程。
5. **证据/禁止项**：后台按时间窗与 attemptId 关联 init/status/observation，后续候选按 modelId/candidateId 关联；禁止重复初始化或扣费、把 SDK 成功冒作 PASS、跨 attempt 通过、日志输出证号/metaInfo/certifyId/SDK 原文或 token。

本批无需用户操作，不声称整个身份/克隆或迁移目标完成。视觉继续按现有 HTML/CSS/组件先行、后续统一校准。
