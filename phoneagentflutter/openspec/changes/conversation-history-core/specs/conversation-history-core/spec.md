## ADDED Requirements

### Requirement: Agent索要文档必须独立续接
系统 MUST 对live IMPORT_DOCUMENT_REQUEST展示单文件选择交互，使用请求MIME过滤及大小限制，复用解析接口，通过submit_document动作回传完整解析状态。MUST NOT 将其伪装为主动文档批次或从历史恢复自动选择文件。

#### Scenario: 解析成功或失败
- **WHEN** 用户选择文件后解析成功、超限或解析失败
- **THEN** 回传对应状态和原有结果字段，继续原session的voice通道，界面仅展示摘要而非文件正文

#### Scenario: 取消和晚到
- **WHEN** 用户取消弹层或系统文件选择，或者解析过程中离页、恢复历史、切换账号
- **THEN** 取消回USER_CANCELLED；失效会话不继续上传或续发动作；重复工具不得重复处理

### Requirement: 权限工具必须按有效平台能力回传并隔离会话
系统 MUST 只处理当前live请求的microphone、contacts、location、document_picker，使用共享Dart规则及薄平台授权端口。MUST NOT 接受任意Android权限字符串、申请拨号或后台定位权限、在授权动作中读取联系人/坐标/录音，或从历史恢复自动重放系统提示。

#### Scenario: 权限可用、拒绝与不可用
- **WHEN** 收到有效REQUEST_PERMISSION
- **THEN** 已授权或文档选择可用回OK；系统申请拒绝回DENIED；平台不支持或无申请标识且未授权回SETTINGS_REQUIRED
- **AND** 通过同一session的permission_result动作继续voice通道，不伪造用户文字、不自动打开设置或拨号

#### Scenario: 重复请求或页面退出
- **WHEN** 同一tool重复到达，或系统授权期间页面关闭、账号改变
- **THEN** 不重复申请/回传；退出后丢弃晚到结果，旧流结束不得提前结束新的续接流

### Requirement: OCR正式对话接线必须使用源时间线锚点与成功上下文
系统 MUST 将相册、识别、上传、历史图片及后续AgentCommand装配在同一会话租约内。anchorStepCount MUST 根据v65源step边界计算，再映射为Flutter显示位置，不能直接使用可见消息数。图片与处理状态 MUST 使用独立共享控制器，页面不得执行图片IO。

#### Scenario: 首轮前选图或穿插文字
- **WHEN** 用户选图成功后发送首轮或后续文字
- **THEN** 只发送已持久成功附件的ocrAttachments上下文，保留原首轮skill/contact/channel契约，不伪造图片用户轮次
- **AND** 在系统选择返回时捕获源锚点，不因后续识别耗时移动图片

#### Scenario: 重建会话和历史图片失败
- **WHEN** 恢复历史，图片读取成功或失败
- **THEN** 成功项按持久锚点显示；失败项按v65跳过，不展示成功卡或进入可用上下文，但保留序号边界
- **AND** 历史图片串行读取，同页同步不无限重试；关闭或账号变化后停止续发及晚到回写

### Requirement: OCR平台适配必须保持用户选择和资源边界
系统 MUST 仅处理用户在当前会话选择的单张照片，按10MiB上限读取；Android/iOS本地中文识别 MUST 使用同一Dart端口和v65文本行投影。Web MUST 明确不支持真实本地识别，不能静默返回模拟成功。

#### Scenario: 取消或选择超限
- **WHEN** 用户取消或文件为空、超限、格式不支持
- **THEN** 不执行本地识别或上传；取消不作为识别失败消息

#### Scenario: 识别失败或进程重建
- **WHEN** 识别抛出异常或Android丢失原选择会话
- **THEN** 前者释放识别资源；后者不得自动将遗留照片上传到新会话，需用户重新选择

### Requirement: OCR持久附件必须保持身份和受保护内容边界
系统 MUST 按v65元数据上传图片及识别结果，保持attachment/command/idempotency/trace身份；鉴权刷新 MUST 重建multipart而不是重复消费旧流，未知失败不得自动重传。历史图片 MUST 通过当前账号的固定同源接口有界读取，不直接使用服务端URL携带凭据。

#### Scenario: 受保护附件刷新或退出账号
- **WHEN** 上传或图片读取返回401，或等待期间登录账号变化
- **THEN** 前者最多刷新一次并重建请求体；后者丢弃结果且不以新账号续发旧请求

#### Scenario: 历史图片排序与失败
- **WHEN** 多次OCR提交事件到达或恢复中存在损坏项
- **THEN** 按合法schema/当前session恢复有效记录，同一附件取最新事实并按createdOrdinal排列，保留选择锚点；损坏项不伪装成功，不挪到提交时位置

### Requirement: OCR页面保留只读结果和明确模拟边界
系统 MUST 以共享组件展示选中图片、识别处理状态、字段与完整文字；长于50字符的文字支持展开/收起，MUST NOT 新增编辑确认或点击识别号码拨号。演练 MUST 与真实文件、账号、HTTP和Agent隔离。

#### Scenario: 识别成功和失败
- **WHEN** 合成识别与整理成功或出现空文字、识别失败、整理失败、保存失败
- **THEN** 分别显示只读成功卡或对应错误；只有成功附件进入可用上下文，失败不伪装成功

#### Scenario: 连续图片与退出
- **WHEN** 处理期间再次选图或退出页面
- **THEN** 不启动重复任务且晚到结果不更新已销毁页面，图片保留选择时的位置边界

### Requirement: 主动文档添加必须整批校验且保持会话契约
系统 MUST 保留统一页文档多选入口，仅接受docx/xlsx且默认单文件不超过5MiB，全部解析成功后以user_document_batch.v1和inputKind=document发送原session。MUST NOT 将部分失败文件批次冒充成功、显示原始JSON为消息或把调试演练写入真实账号。

#### Scenario: 多文件与失败
- **WHEN** 用户选择多个文件，任一格式不支持、超限或解析失败
- **THEN** 显示失败并不向Agent提交部分文档，用户可重新选择

#### Scenario: Android 文件提供方使用宽泛 MIME
- **WHEN** Android 系统文件提供方未把 `.docx` / `.xlsx` 标记为精确 Office MIME
- **THEN** 选择器仍允许用户点选该文件，并在选取后按扩展名及 5MiB 上限校验；其他平台保留原有精确类型过滤

#### Scenario: 取消和销毁
- **WHEN** 系统选择取消或解析期间关闭页面
- **THEN** 不产生新的文档用户轮次，晚到结果不得续发Agent请求

### Requirement: 姓名候选不得把输入模式或拼音当作确定身份
系统 MUST 在Dart共用姓名查询与v65评分规则，typed/unknown精确匹配，只有asr才追加拼音；输入来源不能从语音按钮的当前显示模式推断。结果MUST携带原请求姓名与候选，交给后台的现有候选交互。

#### Scenario: 重名与多号码
- **WHEN** 匹配得到多个姓名号码组合
- **THEN** 回传MULTIPLE_CANDIDATES及全部候选，不自动选第一个或本地直接外呼

#### Scenario: 单项拼音匹配
- **WHEN** 仅拼音fallback得到一个候选
- **THEN** 仍回传MULTIPLE_CANDIDATES，由现有SHOW_OPTIONS确认

#### Scenario: 文本姓名和权限
- **WHEN** typed姓名与系统姓名仅繁简或大小写有差异，或设备拒权
- **THEN** 前者按精确候选处理；后者按请求姓名逐项回传PERMISSION_DENIED，而不是NOT_FOUND

### Requirement: 号码联系人查询必须真实回传并隔离生命周期
系统 MUST 将当前会话LOOKUP_CONTACT_REQUEST交给共享本机联系人查询，结果通过v65 contact-lookup-result接口返回同一pendingToolCallId；MUST NOT 上传整本通讯录、制造用户输入或以拒权冒充未找到成功。

#### Scenario: 权限或读取失败
- **WHEN** 系统拒绝通讯录权限或读取异常
- **THEN** 分别回传found=false及PERMISSION_DENIED或DEVICE_LOOKUP_FAILED，浏览器不伪造联系人权限

#### Scenario: 重复与退出
- **WHEN** 同一工具信号重复或查询期间退出页面
- **THEN** 重复工具不得再次POST；退出后不得继续回传或应用晚到响应，网络失败不得自动重复提交

#### Scenario: 后端继续补问
- **WHEN** 回传结果返回ASK_USER或SHOW_OPTIONS
- **THEN** 使用原统一页补问或候选，并保留新的pendingToolCallId，而不是另开会话

### Requirement: 任务入口不以终态过滤
系统 MUST 保留所有带 sessionId 的普通会话任务恢复入口，并以现有时间排序合并任务；翻译记录 MUST 使用独立详情，不伪造 Agent session。

#### Scenario: 完成或异常任务
- **WHEN** 列表项为 COMPLETED、CLOSED 或 EXECUTION_ERROR 且具有 sessionId
- **THEN** 用户仍可打开该会话，不因状态新增禁用门禁

### Requirement: 历史时间线完整且隔离
系统 MUST 先加载详情再同步所有 timeline 页，按 sequence 和 eventId 去重；缺口和冲突 MUST 有界重同步，未知事件 MUST 保留但不臆造显示。账号或会话不匹配 MUST 失败关闭。

#### Scenario: 多页历史与重复事件
- **WHEN** 时间线 hasMore=true 且存在重复事件
- **THEN** 继续读取到完整历史，重复项只保留一次

#### Scenario: 旧数据与鉴权异常
- **WHEN** timeline 明确无 ledger 或因 503/网络不可用
- **THEN** 使用无消息且无待处理工具的限定兼容快照；401/403 和协议损坏不得走此 fallback

### Requirement: 统一文字与流式事件
系统 MUST 将同一统一页文字作为 channel=voice 提交并保持 session/skill 上下文；SSE 分块解析 MUST 不丢 UTF-8 字符；done MUST 只结束一轮传输，不能声称业务成功。

#### Scenario: 从语音按钮切换文字
- **WHEN** 用户在统一页切换为文字并发送
- **THEN** 仍使用同一个 session 和 voice 通道，不创建旧文本模式

#### Scenario: 普通对话退出
- **WHEN** 退出正在处理的普通对话
- **THEN** 取消本地流并拒绝晚到更新，不隐式删除历史或挂断后台电话

### Requirement: 统一页阶段必须由当前事实驱动
系统 MUST 按 v65 统一页规则展示当前阶段，基于已接入的消息和回执实时更新及恢复，MUST NOT 固定第一阶段、将传输结束当结果或通过阶段变更触发外呼。

#### Scenario: 收到通话结果后继续交互
- **WHEN** 历史含通话结果且用户提交新一轮普通需求
- **THEN** 处理中不能仅因旧终态保持执行结果阶段；当前轮次明确结果可以进入结果阶段

#### Scenario: 空会话或普通传输结束
- **WHEN** 仅有 CLOSED 会话状态或 done，没有通话结果事实
- **THEN** 不据此显示执行结果，文字输入仍按已有规则可用

#### Scenario: 窄高度布局
- **WHEN** 阶段区域随键盘布局移入时间线
- **THEN** 与正常布局使用相同当前阶段，并向辅助技术提供当前阶段名称
