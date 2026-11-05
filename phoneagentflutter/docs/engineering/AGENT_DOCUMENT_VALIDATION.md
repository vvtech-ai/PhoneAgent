# Agent索要文档：实现与集中验证

2026-09-21；开发基点5735d47。本批补此前实际遗漏的live工具，不能与主动文档多选混为一谈。

## 固定源与正式链路

v65 4c781e3：FinalHomeAgentSheets、AssistantAgentDocumentPickerActions、AssistantAgentDocumentImportUseCase、AgentStreamUserActionPolicy.documentSubmit；后端DocumentParseService。HTTP/SSE请求字段为documentImportRequest（兼容同层字段）。历史恢复只保留pending事实，不自动打开选择器。

正式ConversationRoute装配AgentDocumentHost；会话Provider创建独立AgentDocumentController。IMPORT_DOCUMENT_REQUEST经ConversationActionCoordinator去重，展示标题/原因及选择按钮，用户选择一个文件后复用file_selector与api/documents/parse。Dart共享状态/解析编排/取消协议，Android与iOS只由现有插件交接系统选择器；无新依赖或原生代码。

- 选择MIME白名单沿v65；无合法过滤项回默认text/plain、text/markdown、text/*、docx、xlsx。服务支持md/markdown/txt/docx/xlsx；主动添加仍只允许docx/xlsx多选。
- 请求maxBytes缺省5MiB，并受后端固定5MiB上限限制；元数据和读取后字节均校验。超限不上传，格式不支持不解析。
- 成功与失败都用submit_document续接原session、voice通道，payload含status/fileName/mimeType/charCount/truncated/content/message。不附message/inputKind/pendingToolCallId，符合源action协议；本地回显只有源摘要。
- 弹层关闭、系统选择取消或选择器不可用回USER_CANCELLED。解析异常回PARSE_FAILED，不泄露异常正文。已发出的上传无法撤回；取消/离页后不继续提交解析结果。没有后台无限重试。
- 退出、恢复历史或账号代际销毁使等待与解析失效，不发取消或成功动作到新会话。重复工具、双击选择防重；旧流done不结束新续接。

## 自动化证据与范围

- 62项定向：Agent文档域/控制器/连续流程、实际HTTP multipart、已有主动文档/权限/对话回归。新增16项；三种竖屏宽320/390/430覆盖成功、取消、失败、超限、继续文字。不是全量回归。
- 最终flutter analyze无问题（3.7秒）、4项架构检查和OpenSpec 30/30通过，git diff --check通过。
- 浏览器8122迁移目录新增“Agent索要文档与取消续接”（27个入口）：实际点击请求→选择→OK→再次请求→关闭→USER_CANCELLED→继续文字成功；已查看真实渲染弹层。文件、解析服务和Agent均为明确MOCK。
- 原实现批未重打双端包；后续增量阶段已完成iOS共享MOCK验证，见下节。Android与真实系统选择器仍待，不把MOCK当真实上传。

## 后续增量设备验证（2026-09-21）

基于正式实现c93e783，仅增加测试入口/驱动分组，不改正式lib。`migration-increment`复用既有步骤，Android计划只补22–38、47–52及59–62，iOS只跑新增文档59–62，避免重复全部页面。

- Preconditions：两端真机已识别；iOS沿已解锁screen，Android先留当前普通main包。所有样例明确MOCK，禁止设备安全存储、文件选择、拨号与PCM端口调用。
- Build / Install：Android普通main构建10.3秒、阶段包16.2秒，保留数据安装成功；启动并附加命令被执行策略拒绝，因此Android27点没有运行。当前普通包已恢复，15:32:45更新，UID10496/首次安装时间09-20 16:56:07不变，两份安全偏好摘要与阶段前相同。本次恢复后未重新冷启动，不扩大为新的登录实测。
- 自动操作：iOS签名构建60.1秒后，自动请求文档→选择合成文件→OK回显→再次请求→取消→USER_CANCELLED→继续文字；无需人工选文件，未发SMS或真实上传。
- Expected Logs / Pass Criteria：驱动退出0，结果`completed=true`、`forbiddenNativeCalls=0`，四个截图点齐全且750×1334；[结果JSON](../../.local/migration-increment-stage/ios/result.json)及59–62四图已查看。定向预检9项、analyze无问题；没有全量回归。
- Forbidden Logs：不得出现测试断言失败、未处理Flutter异常或非零禁止端口计数；真实系统选择/媒体/存储访问一律失败，不静默回退。
- 图像检查：请求弹层选择/关闭可达，成功摘要、取消回执及续聊回复可读；列表随新增消息滚动，黄色MOCK条不属于正式设计，视觉精校与系统键盘仍未验。
- Failure Follow-up：Android仅缺本组执行，安装成功不是用例成功；保留普通包，不卸载、不清数据或绕过策略。真实系统选择、后端收件及双端系统键盘仍按下方集中验收，不以本阶段替代。

iOS普通入口已恢复：同一c93e783正式main重新构建24.7秒、签名核验通过、安装启动45.5秒，调试服务已发布；[USB整屏截图](../../.local/migration-increment-stage/ios-normal.png)已查看，为无MOCK条的普通登录页。iOS此前未登录，不声称已登录，不发验证码；保留已解锁screen的migration-normal-run窗口。

## 集中人工验收（待执行）

1. 两端测试包从真实Agent触发importDocument，核对标题/原因、MIME过滤；选择本人授权的无敏感合成TXT/Markdown及DOCX/XLSX样例。
2. 在系统选择器取消、上传弹层关闭，后台核对同session只有一个submit_document/USER_CANCELLED；继续文字不受阻。
3. 选择超过请求限制、损坏文档或模拟解析失败，确认对应结果，不伪造成功或显示JSON正文。
4. 解析中退出/切换账号再进入另一会话，确认不产生旧结果续接；恢复旧任务不能自动再选文件。
5. 对照Android/iOS系统选择器可用性与云盘授权、取消后返回。Web MOCK不是这些系统行为的证明；生产升级包另有签名/OTA发布门禁。
