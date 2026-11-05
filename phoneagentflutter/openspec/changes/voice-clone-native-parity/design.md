## Context
参照Android0f8879e4baf1d56fe6d7f8f356101fdf61d602ed、iOSbb9ff34966f40a3c2794a9a8b8e935669a9faa12。iOS AIAliyunFaceAuthAdapter验证前在录音已授权时设PlayAndRecord/Default/DefaultToSpeaker，无VoiceChat、Measurement或Bluetooth。其注释要求SDK空闲时才配置；不复制原生成功分支误打印error的日志。

## Decisions
1. 优先复用正式创建/认证/候选/管理端口，先证据矩阵后修差异。共用UI已有clone组件与原生纯参考，保持统一风格。
2. iOS权限准备在显式capture阶段执行，注册/prepare不申请权限、不改音频；相机/麦克风均授权后，在SDK verify紧前配置认证音频。单capture一次配置，失败不调用SDK；取消后晚到权限回调不得再配置或启动。SDK持有期间不恢复旧音频设置，reset只清内部配置所有权。下一业务获取共享租约后自行配置音频，试听明确Playback。
3. Dart FocusedIdentityCapturePort已有不可抢占租约及waitForRelease，维持取消回执与释放分离。iOS无public abort时不能虚构释放；SDK回调及容器关闭后reset/释放等待者。
4. ready候选未确认退出均恢复系统音色；仅本次认证有可保存录音且保存勾选时警告。成功退出准备去重；失败保留重试。已确认退出不恢复。
5. 每手写源码批最多3文件，文档/格式化独立。不归档未验收change。真实身份/音频/费用需明确授权，自动测试/隔离UI不代替真实验收。

## Validation
定向clone/call_models/identity/钱包/共享媒体及Shell测试、analyze；原生音频策略用注入session的模拟器可执行测试，不加载vendor。平台编译使用固定Flutter3.32，不卸载/清数据。双端同状态截图按隔离工具能力验证，工具失败有限恢复并继续其他工作。

## 已证实的补充差异
候选映射原先丢弃lastError，本次补齐可选字段及失败反馈策略；processing不展示旧错误，HTTP/供应商未知转友好提示。证据矩阵见`docs/engineering/VOICE_CLONE_NATIVE_PARITY_20261009.md`。隔离运行不申请真实身份/上传/收费授权。

## 身份页导航修正
iOS AISettingsViewController的onOpenVoiceClone直接presentVoiceCloneModelPicker，不pop身份控制器；Android MY_IDENTITY入口openPicker保留入口来源。Flutter原先通过IdentityDestination.models先pop身份页再由Shell启动，破坏返回栈并暴露设置页。改为从身份页当前context压入克隆流程，Shell只负责完成后的共用刷新，保留身份页。取消选择或返回流程恢复身份页；显式身份返回才回设置。

## 模型目录空值与失败恢复
原生iOS AIJSONDecodeGsonModel允许current/candidate为null或缺省；Flutter此前强制current对象并校验modelId，合法未创建状态被误报加载失败。current为空映射未创建，非空继续严格归属验证；candidate为空不生成资产。将目录错误映射到纯Dart分类，不显示原始异常/服务端正文。原生iOS picker无额外重试按钮，以关闭重新进入恢复；Android VoiceCloneModelPickerSheet同样没有额外重试按钮，统一关闭重新进入。真实报错位于真机，设备待选择，不猜测账号/请求，也不把协议缺陷当作已证实现场根因。

目录models列表null/缺省按iOS空目录处理，不伪造默认模型；移除双端原生都没有的额外空态文字。未知模型过滤、重复模型、错误available类型和非空跨模型资产仍拒绝，保留安全准入。

## 新包数据异常复现
用户确认XFeng iPhone15新包仍显示数据异常，证明null-current修复未覆盖现场全部格式。核对原生目录mapper不调用候选操作DTO校验，仅读取摘要；Gson兼容字符串Boolean、空缺Boolean=false、标量String，并允许摘要modelId缺省。Flutter目录不应调用严格CloneCandidateMapper：改为摘要映射，非空跨模型ID仍拒绝，READY仅对应原生明确条件；完整候选/认证/确认/计费端口严格校验不改。未知摘要状态不被视为ready，有候选仍走只读恢复，不创建收费请求。真机调试等待前台连接，现场结构未取得时不宣称根因确认。

## 仅关闭模型选择不刷新身份
原生closeFlow单纯关闭picker不调用onFlowChanged。Flutter Shell此前await openCloneCreation返回后无条件invalidate身份/克隆状态并刷新钱包/音色，导致从身份关闭picker后重新加载和闪动。创建路由仅在真正选择并进入后续克隆流程时通知来源；Shell在未进入流程的关闭（X/遮罩/返回、重认证确认取消）不触发业务刷新。保留实际克隆流程结束后的刷新，不改业务/账号隔离。

## 2026-10-09 完整流程复核与生成异常对齐
用户确认本轮修改计划。固定原生共同流程为模型/积分→认证→创建候选→轮询→试听/确认→录音保存、管理与退出。iOS创建异常保留模型选择表面显示安全错误；Android认证完成处理异常留在认证失败状态。Flutter必须删除创建失败时自有的“原生成请求结果未知/同步本次状态”独立页，不以自动重提收费请求恢复。
候选接收与录音授权分离：有效候选继续生成/展示，缺失或无效授权不得用于下载/保存，不伪造授权。保留跨模型/跨候选归属、就绪计费和确认幂等保护。未知结果的内部标记保留，不据只读恢复发布原请求计费结算。真实错误原因通过枚举诊断记录，不输出服务端正文、身份或录音材料。
原生差异以iOS返回模型选择、Android保留认证页特殊处理。复核完整链路时记录源码证据与实际测试范围，不把源码比较冒充双端真机视觉验收。

### 本轮复核补充
- iOS工作区实际HEAD为bf2b65245c89ba45b90207486a34166c8f346c5b，Android仍为固定0f8879e；本轮按用户指定实际源码复核，未改参考工程。
- 处理中/失败候选共用结果卡片与导航标题，未就绪禁止试听/设默认，生成中禁止退出；保存勾选和重新录制按原生保留。
- 原生MFVC_MATERIAL、AUDIO_QUALITY、ASR_PROVIDER、ASR_CONTENT、CLONE_PROVIDER、CLONE_SUBMISSION_UNKNOWN仅通过白名单stage转换为类型化失败。iOS模型面错误和Android认证错误分别呈现。
- 确认时并行准备录音下载，确认成功才提交存储；成功立即返回，不因可选录音失败停留额外重试页。账号绑定仓库跨路由存活、切账号失效，旧录音只在新文件校验通过后原子替换。
- 重新录制保留旧候选/录音选项；新候选接收后释放旧状态，取消或新生成失败可恢复。旧轮询和旧work完成回调不能覆盖新流程。
- Candidate展示映射与替换快照按职责拆分；主流程Controller保持500行以内。严格候选身份/计费保护保留，不复制原生缺失字段可能引起的崩溃。

## 操作DTO对齐（diagnostics-7/8反馈）
iOS AISettingsModels.m/AIJSONModel.m及Android VoiceCloneModelModels.kt采用Gson兼容字符串和Long解析。后端本地VoiceCloneCandidateTransactionService.candidateId使用accountId + ":" + modelId，现有Flutter identifier正则拒绝冒号；原生无该限制。候选ID不进入URL/header，应作为不透明返回值保留，请求attempt/key继续独立校验。返回modelId缺省按当前请求模型处理，明确跨模型仍拒绝。未知status/source/billing保留unknown，不伪造READY/CHARGED。可空文本按空串呈现，积分兼容整数数字字符串和原生Long范围；类型失败仅记录白名单字段和JSON类型。此次证实源码冲突，不将本地后端版本冒充线上实际响应。覆盖旧文中“完整操作DTO严格校验不改”的历史决定。
