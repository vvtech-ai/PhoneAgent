# 分模型克隆候选：真实协议与生命周期

更新：2026-09-18。此批完成正式协议实现与独立状态编排，不等于正式克隆创建入口、认证SDK或真实扣费已验收。

后续进度：共享认证录音下载/校验、Android/iOS加密私有存储及身份删除清理现已实现，见[录音存储记录](CLONE_RECORDING_VALIDATION.md)。下文“存储待实现”为候选协议批次时的边界；正式SDK/钱包/页面装配、真机与OTA导入仍未完成。

## 代码证据与接口

依据Android固定4c781e3的VoiceCloneModelApi、VoiceCloneModelModels、VoiceCloneModelRepository、VoiceCloneModelFlowCoordinator，以及同提交后台VoiceCloneModelController/ModelDtos/CandidateSnapshot。iOS固定ddb996a的EnrollmentRepository把认证交给服务端；不复制旧activate接口覆盖v65分模型协议。

| 操作 | 路径（共同前缀api/account/settings/voice-clone/models） | 语义 |
|---|---|---|
| 认证后生成 | POST /{modelId}/candidates/from-verification/{attemptId} | 无请求体；返回candidate及recording下载凭据；attempt必须匹配 |
| 认证录音生成 | POST /{modelId}/candidates/from-recording | JSON audioBase64/audioSha256/personFingerprint/scriptVersion/receipt/displayName；返回candidate |
| 同步候选 | GET /{modelId}/candidate | 只观察/推进后台已有候选，不新建、不确认、不切换音色 |

两个创建请求携带X-Idempotency-Key。AccountApi只接受POST的非空受限键，不开放任意HTTP头；单次401刷新后重放保留同一键/请求体/账号，刷新请求不附带该键。网络或服务端失败不会自动重试创建。原确认、删除接口继续使用既有实现，本批不调用它们。

## 共享实现与边界

- `domain/clone_candidate.dart`：候选状态/来源/计费、不可变录音输入、短时下载凭据和仓库端口；无Flutter/设备/第三方包依赖。
- `data/clone_candidate_mapper.dart`：模型与候选身份、状态、来源、计费数值和下载attempt校验；未知状态失败关闭，不补造余额。READY且CHARGED才是可确认候选，CONFIRMED与READY不同。
- `data/api_clone_candidate_repository.dart`：真实受保护请求。上传前SHA-256核对不可变音频；仅两条明确的身份/receipt失效响应转为重新认证信号，其他后端原文不暴露。
- `presentation/controller/clone_candidate_controller.dart`：一个实例绑定一个模型/打开或生成操作；单飞、只生成一次、2秒间隔至多60次读取（测试可注入时钟）；退出不续查、不接晚到；已知candidate ID/model/source变化进入冲突，不覆盖旧事实。
- 录音、receipt与grant不进入UI状态/普通日志。控制器销毁或候选冲突时丢弃grant引用。此处没有实现私有文件保存、下载、权限或音频播放。

初次创建响应未知时，后续GET只返回“当前候选”，没有generationRequestId可关联；因此`creationUncertain`保持true，即使查到READY，也不宣称本次生成/扣费成功。已知候选的轮询失败则保留候选并允许只读同步；轮询耗尽不篡改服务端为FAILED。

## 自动验证

36项新增：18项候选HTTP/解析/摘要与实际仓库+控制器串联；16项生命周期；2项公共请求幂等键。全部请求通过合成HTTP适配器，无外网身份、录音或模型写入。验证跨模型/候选/来源、401键保留、账号切换、未知写只读恢复、失败计费状态、重复操作、关闭期间请求与延时。

架构测试首次指出domain引用crypto违背现有门禁；已把摘要计算移到data而未放宽测试。全量最终结果记录于tasks.md。Web Debug同源测试代理配置与Android Debug测试环境构建通过；没有新增UI，不伪造新的浏览器端到端截图。没有新增iOS构建或设备安装证据。

## 剩余实现与集中人工验收

1. **生产装配仍需完成**：SDK认证PASS → 钱包准入 → 本机账号/身份绑定录音（或认证attempt）→ 本控制器 → 共享候选页。当前正式创建入口未装配此链路；现有演练仍使用明确MOCK端口，不会偷偷访问真实录音或发POST。
2. **存储与采集**：下载grant有有效期，必须校验录音摘要并写App私有存储；旧录音替换、身份失效清理、账号归属和保存任务完成等待不能由这个内存DTO代替。真实SDK成功不等于服务端PASS。
3. **准入与结算**：生成前每次300积分检查、生成结果真实扣费/钱包刷新、显式重录的新操作ID、结果未知恢复与后端日志关联需在装配时验证。不允许直接复用MOCK的“重试生成”作为生产重试。
4. **确认/离页**：候选已就绪但未确认的系统音色恢复、试听停止、保存选项、确认结果未知只读同步仍按源流程接线；不以此次生成协议代替这些流程。
5. **真实联调**：授权测试账号/模型和一次操作后，人工完成认证或提供可复用私有录音。后台按时间窗、模型、candidateId、attemptId和generationRequestId核对一次创建、一次计费、只读轮询；禁止把录音Base64/receipt/grant/身份证写日志。再验断网、401、身份失效、切账号、离页、双端系统行为。

本批不需要用户再次验证码，不改变现有登录，不调用真实SDK/相册/麦克风、生成、扣费或外呼。整体迁移继续进行，视觉仍待统一校准。
