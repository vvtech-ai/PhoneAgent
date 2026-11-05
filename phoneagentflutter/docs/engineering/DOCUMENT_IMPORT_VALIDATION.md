# 统一对话主动文档导入（2026-09-17）

## 基线与调用链

Android固定v65 `4c781e3`：PureVoiceAttachmentSheet → AssistantAgentDocumentActionHandler.onUserDocumentPicked → AssistantAgentDocumentImportUseCase → AssistantUserDocumentTurnCoordinator。静态设计为 `0cd58de:memory/index.html` 与 `memory/css/multimodal.css`，按用户授权先交互后视觉。未改旧工程。

Flutter：ConversationRoute → AttachmentMenu → DocumentImportSheet → DocumentImportController.choose → DocumentPicker / DocumentParser → DocumentTurn → ConversationController.sendDocument → 原AgentGateway。UI不访问网络、文件或账号存储。

正式选择器使用固定 file_selector 1.0.3；docx/xlsx多选，iOS配置对应UTI。接口 POST `api/documents/parse`，multipart字段file，文件名和MIME保留，账号Header复用AccountApi。结果读取status/fileName/mimeType/content/charCount/truncated/message。没有OCR、数据库、SIP、ASR、TTS或提示词修改。

## 状态和副作用

idle → picking → parsing → ready；取消回idle并关闭，失败到failed供显式重新选择。任一扩展名不支持或已知大小超过5MiB，整批读取前拒绝；实际字节再检查。全部解析OK才提交 `user_document_batch.v1`，保留documentBatchId与有序documents；任一失败不提交部分内容。

Agent命令沿用sessionId、channel=voice、首轮skill/context规则，inputKind=document，不携pendingToolCallId。界面临时消息只呈现文件名/字数/截断提示，绝不显示原始文档JSON；ledger持久消息当前为“已上传文档”。

关闭使代际失效，后续解析结果不得提交；已发出的上传不能据此承诺后台已撤销。账号变化由AccountApi丢弃迟到响应。异常不输出文档正文；不自动重试POST。完成解析时对话已关闭/忙碌则本地明确“文档未发送”，不重放。

## 验证结果

- 新增27项：12控制器/模型、6HTTP、8Widget、1对话命令。全量570项通过，analyze无问题，19项OpenSpec通过。
- Web验证脚本：491共享测试 + Chrome流2项 + Node代理1项通过；这491项不是全部在浏览器运行，真实Chrome专测流传输。
- Web Debug、Android Debug及Mac独立目录PhoneAgentFlutterDocuments.7cEpVH的iOS Debug无签名构建通过。插件依赖仅新增9项，不升级既有包或Flutter。
- 浏览器从首页会议邀请进入新菜单，正常两份合成文件显示安全摘要，部分失败显示重选。MOCK独立端口不调用选择器、不上传、不提交真实Agent。
- 本批未安装真机或上传实际文件；构建证据不等于签名、系统选择器或真实后台联调通过。原解锁Mac会话未触碰。

## 集中人工验收

1. 专用测试环境、测试账号、明确可上传的合成docx/xlsx各一份；进入统一页 → 添加内容 → 文档 → 选择文件。Web使用支持多选的浏览器；Android/iOS使用各自文件提供方。
2. 取消选择不生成消息；多选按顺序解析并只提交一个文档轮次。随后文字追问在同一会话继续，不触发真实外呼。
3. 选择PDF、超过5MiB、损坏文档、含部分失败的批次；预期有明确提示，无部分内容发送、无自动重试。
4. 上传/解析期间关闭、退出对话、切账号；预期新页面不接收旧结果，网络日志不出现文档正文、账号令牌。不能把关闭窗口当作服务端取消证明。
5. 核对parse接口与Agent command的sessionId/commandId/inputKind，任务列表恢复后不得显示JSON正文。记录平台文件提供方、系统版本和可复现样本，不提交用户原始文档到仓库。

## 待办

图片OCR、Agent请求importDocument及USER_CANCELLED回传、原生文件选择器/真实后端集中验收、文档消息专用卡和整体视觉校准。当前进度sheet比v65多一次“选择文件”点击，列入交互差异；HTML无文档行时以v65为准。当前只完成主动文档入口，不标整个统一对话或迁移完成。
