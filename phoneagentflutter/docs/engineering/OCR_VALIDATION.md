# 图片识别共享交互与集中验收（更新于2026-09-18）

## 当前状态：正式统一页已装配

正式 `ConversationRoute` 的相册按钮现已接入移动端系统选择器、中文MLKit、真实图片Repository、共享OCR卡及历史恢复。Web普通相册明确提示不支持本地识别，不自动转为模拟成功。真实上传仍需用户选择照片；本批没有读取或上传私人照片。

- `app/ocr_providers.dart` 与 `conversation_providers.dart` 按登录代际装配；ConversationController只负责上下文和生命周期，图片IO由独立OcrSessionController协调，页面使用ConversationOcrHost和MemoryImage，不把凭据交给图片URL。
- `conversation_source_steps.dart` 重建v65源step计数，包含Flutter暂未展示的有效源项、文档去重、确认/回执更新及恢复修订；`conversation_ocr_boundary.dart`映射显示边界。OCR本身不占step，批量taskId即使晚于请求到达也不重复计数，不使用messages.length冒充协议锚点。
- 系统选择返回时取当前锚点；图片处理耗时不改变位置。`conversation_submission.dart`复用既有首轮skill/contact及voice channel，成功图片通过AgentCommand.userContext传递；先选图不会消耗首轮文字契约。
- 纠正上一批假设：固定v65历史图片下载失败会跳过整项可用附件，而非保留成功文字上下文。当前实现依此处理，元数据仍保留ordinal；历史图片串行读取、同页不自动无限重试，关闭后不续发下一张。
- 独立MOCK现在复用正式ConversationController/OcrSessionController/展示组件；增加“恢复本次演练历史”，从内存ledger重建控制器。图片、识别、上传和Agent均为合成端口，绝不写真实账户。

浏览器验证：已有登录直接复用，会议长图→展开→文字→回复显示1张成功图片→恢复→第二张名片→文字→回复显示2张→再次恢复，图片/文字顺序与主图/缩略图均保留；未重发短信、真实上传或外呼。实际Route Widget测试另覆盖添加菜单→相册→卡片→文字上下文→关闭，不只测试演练外壳。以上不是像素级校准或真实引擎识别证据。

本批新增17项回归：12项源边界、2项共享对话/恢复、1项正式Route、2项选图锚点/历史串行生命周期；全量972项、analyze、lib/test共490文件格式、19项OpenSpec通过。Web/Android Debug及Mac临时工程的iOS Debug无签名构建均通过；Web仍有既有Cupertino字体tree-shaking提示，Android仍提示x86支持将移除，均非本批失败。初次扩大格式检查发现旧integration_test/home_model_flow_test.dart格式差异，未混入本批修改；最终格式门禁范围为lib/test。正式接线完成不代表集中真机和后台验收完成，OpenSpec 3.15与3.17分开记录。未新安装设备，未触碰Mac已解锁screen。以下各“历史批次”记录用于追溯，当前范围以本节为准。

## 历史批次：双端平台适配与共享会话编排

已实现但尚未装配进正式Route：`PlatformOcrImageSource`单张系统相册、取消、10MiB有界读取、格式筛选；`MlkitOcrRecognizer`中文本地识别，按v65逐block/line去空、trim并始终释放识别器。Web明确拒绝真实本地识别，原独立MOCK页面保持不变。无相机、视频或全相册扫描，iOS不请求完整元数据。Android进程被系统回收时，在下次选择前消费遗留结果、提示重选，不能自动上传至新会话；未新增后台自动恢复图片授权。

`OcrSessionController`组合既有OcrController与图片Repository，保持处理状态单一事实源。选图/读取/识别/上传/历史图片下载都检查账号页面租约；关闭清空持有的图片和上下文，晚到结果不续发或更新。只把已持久成功的附件加入`ocrAttachments`；失败图片不加入。此批曾保留图片读取失败的历史文字，已按上方源码纠偏修正。重复历史同步不无限重试图片，提供控制器retryImage（未新增产品重试按钮）；成功历史可替代正在处理的同ID项并保留本地选择锚点，恢复后新图ordinal继续递增。

兼容锁定：Flutter3.32.0、image_picker1.1.2、google_mlkit_text_recognition0.13.0；Android中文模型16.0.1；iOS GoogleMLKit/TextRecognitionChinese6.0.0及实机编译生成的Podfile.lock。实际Mac为macOS13.7.8/Xcode15.2，仓库最低iOS15.5，旧段落中的16.7不是当前工程最低版本。本次不升级系统或工具链。识别桥接插件由社区维护，非Google维护；参考[版本兼容说明](https://pub.dev/packages/google_mlkit_text_recognition/versions/0.13.0)和[系统选择器说明](https://pub.dev/packages/image_picker/versions/1.1.2)。

验证：23新增（11平台适配契约、12共享生命周期），全量955项、analyze、481文件格式、19项OpenSpec；Web/Android Debug和Mac临时OcrPlatform.PonfUn的iOS Debug无签名构建通过。平台测试模拟MethodChannel响应，验证调用、投影与释放，不代表真实识别准确率。未读取/上传私人图片，未安装新包或执行真机识别，未触碰旧工程和已解锁screen。

剩余正式接线：源ClarificationStep→Flutter展示边界映射、正式相册按钮/provider、共享图片卡与历史装配、AgentCommand.userContext。包装器虽已实现，不代表正式页面能选图。原Android适配器先排除OCR项再映射step，显示投影会合并候选/工具卡，不能使用Flutter当前消息数代替源anchor。完成这些后再按文末清单集中真机验收，3.15仍未勾选；不要求用户现在测试尚未接通的入口。

## 历史批次：真实持久协议和历史数据层

已新增 `ApiOcrAttachmentRepository`：multipart的image和application/json metadata、10MiB限制、稳定ocr-command/ocr-trace/idempotency身份；返回核对session/attachment/文件大小/锚点/序号及持久事件身份。`OCR_AI_REFINEMENT_FAILED`映射为整理失败，其余未知服务错误不透传正文。网络未知结果不自动重传，401仅一次刷新；AccountApi每次复制FormData及MultipartFile，避免已finalize的流无法二次发送。

`PersistedOcrAttachment`是跨端纯Dart值对象；`OcrHistoryProjection`从当前session、schema1的OCR_IMAGE_COMMITTED恢复，同一附件最新有效事实去重，按createdOrdinal排列，保留选择时anchorStepCount，不按事件晚到位置重排。还未接到正式ConversationRoute，不能据此宣称历史图片已显示。

历史二进制通过固定同源`api/agent/conversations/{session}/attachments/{attachment}/content`读取，不执行返回contentPath URL、不使用带Bearer的NetworkImage。读取校验媒体类型、正数文件大小和实际字节数；接收进度与消费侧双重限制。Dio可能提前缓冲，因此接收预算为max(预期大小,64KiB)，为小图片的鉴权错误体留少量空间；超限立即取消，最终返回仍必须严格匹配预期大小（最多10MiB）。账号/登录世代变化丢弃结果，关闭/超时/失败中止流，不新增磁盘缓存。

Web二进制单独复用FetchStreamAdapter，明确`redirect:error`/`credentials:omit`；普通JSON和multipart继续既有客户端，未改变其他接口处理策略。Android/iOS使用Dio原生流适配；此批无新插件/原生代码/后台协议/真实图片上传。Chrome测试注入合成Fetch响应，并直接使用默认AccountApi，验证实际Web适配器选择及超限中止，不是只测替代Repository。

源码补充：Android PureVoiceOcrBindingFactory以ClarificationStep的源边界计算锚点，PureVoiceThreadRenderState再映射展示边界。不能直接把Flutter可见消息数当相同协议；相册/识别、正式committer绑定、源step映射、ledger同步及后续Agent userContext仍待接线。真实OCR链路完成之前，普通相册入口继续说明尚未接入，MOCK依然独立。

验证：25项新增单元/协议测试、932项全量测试通过；Chrome新增2项二进制测试及原2项流式测试通过；analyze、475文件格式、19项OpenSpec、Web与Android Debug构建通过。测试使用合成字节/接口响应，不是实际识别准确率或云端收件证据。本批无新UI，未进行新手工浏览器逐屏验证、iOS构建或设备安装。测试确实发现Dio接收提前缓冲问题并补接收层中止；另修正日志隐私测试误把时间戳数字片段当手机号，改为精确字段集合与完整手机号断言。

## 历史批次：首轮共享页面结果和边界

已实现的是共享OCR状态机与页面、只读结果卡、多图/文字顺序和隔离演练；后续持久接口与历史数据层见上方追加段。**正式相册、本地OCR、页面上的云端提交/历史图片恢复和真实Agent上下文尚未接线**。演练不是实际图片识别，也不代表整项OCR迁移完成。

入口：首页任一任务 → 添加内容 → 图片交互演练（MOCK）→ 添加内容 → 场景；场景含合成名片、会议长文字、无文字、本地失败、整理失败、保存失败。原真实对话不会写入这些消息，返回仍回原页；无新短信、账号变更、真实文件/图片读取、HTTP或外呼。

## 源码结论

- v65 `4c781e3` PureVoiceOcrCards/Models/Coordinator：选择后自动处理，图片在右、结果在左；结果字段只读，完整文字超过50个UTF16单位截断，展开/收起。没有编辑、确认提交或点击号码拨号。
- 相册单选本地识别，Android MlKitPureVoiceOcrProcessor使用中文TextRecognition，逐block/line收集segments，rawText空则失败。
- PureVoiceOcrAttachmentHandler限制图片最大10MiB；ConversationOcrAttachmentRepository上传image+JSON metadata到 `api/agent/conversations/{sessionId}/ocr-images`。metadata含attachmentId/commandId/idempotencyKey/traceId/anchorStepCount/createdOrdinal/initialOpening/rawSegments/rawText。返回整理后的fields/segments/fullText与持久身份。
- 云端 `OCR_AI_REFINEMENT_FAILED` 与普通保存失败不同；成功附件才进入OCR上下文。不是向普通聊天发送文件JSON，不是自动电话。
- 历史通过 `api/agent/conversations/{sessionId}/attachments/{attachmentId}/content` 获取受保护图片；选择时anchor保留，不能按晚到提交时间移到最新消息末尾。
- iOS参考 `ddb996a` 的Swift检索未找到OCR识别实现，不能声称已有iOS复用路径；平台实现后续选型和验证，不借本批引入新系统版本要求。

## Flutter实现位置

- domain/ocr_attachment.dart：结果/字段/失败、50字摘要与识别/整理接口。
- presentation/controller/ocr_controller.dart：单飞选择、两阶段异步、空文字/四失败分支、关闭丢弃晚到；不含图片IO。
- widgets/ocr_attachment_card.dart：ImageProvider图片、字段、完整文字、展开收起；core/design/ocr_tokens.dart来自固定CSS。
- conversation_timeline_attachment.dart：UI消息边界插槽；正式源step映射已由conversation_source_steps.dart/conversation_ocr_boundary.dart接入，不能把UI消息数当协议。
- data/preview_ocr.dart、preview_ocr_session.dart与pages/ocr_preview_page.dart：明确MOCK端口，只读取打包的设计合成资源，完全独立于真实账号；共用正式控制器，普通生产Route未注入模拟数据。

## 验证

新增14项：9状态/边界、5Widget。全量584项、analyze、OpenSpec19项通过；Web脚本505共享测试+Chrome流2项+Node代理1项通过。Web/Android Debug/Mac临时Ocr.s1hIW2 iOS Debug无签名构建通过。未新安装双端，不触碰原Mac解锁会话。

浏览器：普通入口→独立演练→会议图→成功卡/展开收起→切文字→合成回复，随后失败图不覆盖成功图片。截图检查主图/缩略图、布局、没有系统栏重复；这是交互/资源验证，不是像素级视觉验收。

首轮发现Web旧服务404及测试资源包漏新图。以前仅takeException不足以发现errorBuilder吞掉的资源失败；补“不得显示图片暂不可用”断言后测试确实失败。显式登记新增资源并重建，三宽度/全量重新通过，浏览器确认图片真实呈现。没有移除该断言或降低门禁。

## 后续接线与集中人工步骤

1. 前置实现已具备：双端选择/中文识别薄适配、Repository/ledger/userContext及正式Route。先获得阶段安装授权并安装独立测试包，保留原安卓App和已有登录；确认连接测试环境，不能把Web模拟结果作为原生引擎证据。
2. 使用经授权可上传的合成图片，测试照片权限允许/拒绝/有限访问、系统相册取消、旋转方向、中文/中英混排、小字、模糊、无文字、HEIC和10MiB边界。不可把设计演练场景当识别准确率证据。
3. 识别成功需同时验证后台持久化和卡片；断网/401/整理失败/保存失败分别呈现正确状态。禁止自动重复上传；受保护multipart若鉴权刷新需重建body，不能复用已finalize的FormData。
4. 连续两图并穿插文字，第一图识别过程中继续输入、退出/切账号、历史重入；核对attachmentId/sessionId、anchorStepCount/createdOrdinal和ledger sequence，无跨账号图片、重复卡或错误位置。
5. 后续文字/语音只能使用已成功附件上下文，图片中的姓名号码不等于可信联系人，不能点击后自动外呼；本地失败/保存失败图不得冒充成功上下文。
6. 日志只记关联ID/状态/耗时/长度，禁止图片、正文、电话/邮箱或令牌。验收涉及图片上传前明确测试数据与测试环境，系统UI差异允许，视觉校准另列。

当前本页区分已实现接线与尚待集中验收；不要求现在逐项配合，也不代表整个Flutter迁移已完成。
