# 自动确认与积分准入共享核心

2026-09-21增量：已补Android生产同包旧积分不足已提示标记，沿共享存储与正式Service保持再次不足分流；43项相关Dart（12新增）、3项JVM、analyze及Android Debug通过。实现与真实升级步骤见[旧标记专项](LEGACY_CALL_ADMISSION_VALIDATION.md)；不等于已进行真实外呼或同签名升级。

日期：2026-09-17。本文件记录核心阶段；后续正式ConversationController/Route装配、发送前余额拦截、单路页面和ledger同步已实现，最新证据及未完成边界见[对话到通话验证](CALL_FLOW_VALIDATION.md)。不代表真实外呼、媒体或所有交互页面完成。以下未接线描述是当批历史，不覆盖最新记录。

## 固定依据

Android固定v65 `4c781e3ccfcd148c1f205921534907ee0c5aa864`：AgentStreamConfirmCallHandler、TaskCallPointsAdmissionPolicy、TaskCallPointsRetryPolicy、TaskCallConfirmationIdentityAliasPolicy、TaskCallPointsNoticeCommitter；后端同提交TaskCallPointsNoticeApplicationService。旧仓库只读，未切分支或修改。

## 共享实现与调用边界

| 文件（lib/features/calls下） | 方法与职责 |
|---|---|
| domain/call_launch_request.dart | stableAlias按ordinal/scene/name/phone/goal/显式人数/原始summary分隔构造；sameTask按v65判断；不把显示裁剪后的summary当幂等原文 |
| domain/call_admission.dart | 首分钟模型点数100/110/150 × 至少1路；已知不足返回首次或再次决定；未知余额交给后端；无本地扣费 |
| domain/call_admission_service.dart | evaluate查询当前与历史同任务alias、再次不足刷新；record尽力保存alias和首次提示；每个异步边界检查请求有效性 |
| domain/call_launch_coordinator.dart | schedule仅实时请求延迟1500ms；取消/关闭忽略晚到；同session/tool只处理一次；submit前记账，异常uncertain，不自动重发 |
| data/secure_call_admission_notice_store.dart | 环境/API标识、账号、session、alias按JSON分帧后SHA-256，安全存储只写哈希键及1；独立alias键避免并发覆盖 |
| data/api_call_admission_notice_repository.dart | 单次POST既有task-call-points-notices，body仅confirmationKey哈希和recipientCount；验证session/event/sequence/created；保护账号归属 |

首次不足先给页面本地提示决定，再尽力保存和提交幂等提示；再次不足刷新后仍不足只给弹框决定、保存alias，不新增时间线提示POST。已知余额不足不会因存储错误放行；持久化异常独立标记。未知余额不是0，也不是“积分充足”，最终必须走后端原子准入。

只有幂等提示的网络/服务器暂不可用最多3次，间隔300ms；认证/账号变更、已知404/409/422、非法响应等不重试。**这不是confirm_call重试机制。** 确认的返回成功仅表示提交端口完成，不表示电话接通。未使用定时轮询伪造任务成功。

新引用的crypto 3.0.7此前已锁定为传递依赖，本批改为直接声明，版本/校验和不变；没有新增原生插件或升级SDK。

## 自动验证

- 新增27项，分布call_admission_test、call_admission_data_test、call_launch_coordinator_test；全部合成数据，无真实网络/电话/短信/积分写入。
- 覆盖稳定alias保留空summary分隔、同任务/不同会话、模型边界与多路人数、余额未知、首次/再次/刷新、存储失败、提示有界重试/取消、API路径/哈希/归属/非法响应、安全存储重建/并发/隔离。
- 虚拟时钟覆盖1499ms不提交、1500ms提交一次、重复事件、新请求替换、恢复/输入取消、退出/异步读取/余额刷新晚到、提交结果未知不重试、回调期间关闭、多路保留人数而不选择单路路由。
- `flutter analyze`、全量`flutter test` **669项**、`openspec validate --all` **19项**通过。
- 测试配置`flutter build web --debug`和`flutter build apk --debug`通过。没有本批iOS构建/新真机安装，不能将旧设备证据复用为本批验收；没有新页面，未伪造浏览器端到端截图。

## 下一步接线与验收（尚未完成）

1. App按登录epoch装配准入服务，环境scope包含API地址；余额读取/刷新需区分账号失效与余额未知。
2. 统一页只对实时MAKE_CALL_REQUEST调度，历史只恢复，不执行。ordinals与历史消息身份保持一致；新输入/恢复/退出取消待提交任务。发送confirm_call沿用voice业务channel与既有命令/幂等字段，不重放用户输入。
3. 首次不足消息/再次不足弹框接共享UI；提示HTTP结果与后续ledger合并，不能制造重复持久消息。
4. 单路提交前打开既有CallSessionPage并观察登记，多路留统一页。终态同步ledger/回执；退出、挂断、网络不确定三种行为不能混淆。
5. Web隔离端口完整演练上述链路后，再做双端阶段验证。真实电话只使用集中验收授权号码；首次不足/再次刷新/弱网不能导致多次外呼。监听媒体和音源仍是独立待办。

本批没有改提示词、数据库、后端计费、SIP、ASR/TTS。OpenSpec仅2.7核心完成；2.1/2.2正式接线以及整个迁移目标保持未完成。
