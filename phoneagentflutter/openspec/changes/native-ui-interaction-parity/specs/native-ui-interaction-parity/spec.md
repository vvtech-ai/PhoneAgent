## ADDED Requirements

### Requirement: 公共详情标题和背景必须依据原生结构统一
Flutter MUST 共用原生56正常详情标题高度、28左标题与48返回热区；首页、设置、模型及身份等共享浅色径向背景，专用积分、语言和通话背景保留各自已核对目标。

#### Scenario: 公共组件传播与回归
- **WHEN** 用户切换主标签或在详情页面返回，或放大字体
- **THEN** 共用白色至F5F7FA至EAF0F6的上中径向背景，标题按内容自然增高而不压缩字体，返回热区始终有效
- **AND** 背景不影响滚动和手势；跨模块传播需定向连续检查与里程碑全量回归，不能仅凭组件测试验收

### Requirement: 邀请必须共用钱包活动卡规则弹层与海报流程
Flutter MUST 在积分余额之后内嵌活动卡和名额进度，以规则弹层和独立海报页复现原生主流程；MUST 保留已批准的邀请码复制与分页记录能力及当前服务端权威和设备操作确认。

#### Scenario: 活动到海报并返回
- **WHEN** 用户查看名额、打开或关闭规则、打开海报、复制或取消保存后返回
- **THEN** 共用18白卡、名额状态、进度说明、蓝色邀请按钮、24规则弹层及海报结构，返回保持钱包活动状态
- **AND** 未知资格不当零、过期不可分享、取消保存不报成功，复制处理中不显示保存中；记录与复制扩展使用相同原生样式

### Requirement: 原音设置必须共用原生控件和保存反馈
Flutter MUST 使用共用详情标题、14边距24圆角原音卡、蓝色开关及带刻度的滑杆；开关和滑杆的操作不改变当前设备持久化与下一通生效规则。

#### Scenario: 修改原音并返回
- **WHEN** 用户启停原音、调节音量或混声比例、返回后重入
- **THEN** 以10%步进分别限制0至100和0至50，关闭或读取未就绪时滑杆禁用
- **AND** 保存失败保留草稿并提供重试，短屏大字体可滚动且不调用媒体或电话

### Requirement: 积分页面必须共用原生余额与流水结构
Flutter MUST 使用统一左对齐28详情标题、原生余额卡及同排右侧流水入口；邀请入口置于余额之后，流水采用收支明细标题与说明。缓存、失败、刷新与分页继续沿用现有账户契约。

#### Scenario: 余额与流水连续返回
- **WHEN** 用户从余额进入流水并返回
- **THEN** 使用共享原生卡片顺序、余额格式、带箭头入口和明细布局，返回保留同一账户状态
- **AND** 大字体和短屏下入口可操作，离线余额不能用于消费准入，失败不得清掉已有流水

### Requirement: 身份与设置必须共用原生页面结构
Flutter MUST 使用原生身份空态、资料卡、顶部编辑/删除操作、卡外声音克隆入口及分区表单；设置 MUST 使用左右排布的半透明卡片与原生退出确认样式，保留当前业务门禁和失败重试。

#### Scenario: 身份编辑与返回
- **WHEN** 用户填写或编辑身份、取消编辑或打开删除确认
- **THEN** 使用共享28详情标题、原生字段分区及不透露/男/女性别顺序，已认证姓名仍锁定
- **AND** 取消不保存、失败保留草稿，删除确认仍走原清理契约

#### Scenario: 设置与退出
- **WHEN** 用户打开设置、子页或退出确认
- **THEN** 设置标题、左右卡片、退出按钮及确认弹窗使用共享原生结构；小屏大字体仍可读可操作
- **AND** 返回取消不退出，处理中不得重复提交，失败可重试；Android更新和iOS无OTA继续局部适配

### Requirement: 最终一致性必须按唯一目标与运行证据验收
Flutter MUST 为每个有效页面、子页面、弹层及适用状态建立唯一布局与交互目标，并依据原生两端运行截图和操作序列形成差异闭环；MUST NOT 用源码参数、自动测试或编译通过替代最终一致性验收。

#### Scenario: 原生两端普通业务差异
- **WHEN** Android与iOS同一场景的普通布局或交互存在差异
- **THEN** 依据当前用户决策形成并记录唯一Flutter目标，双端共用且逐项核对
- **AND** 必要系统差异注明依据并局部适配，业务冲突不能随机混搭

#### Scenario: 完整流程验收
- **WHEN** 实现或复核一组业务页面
- **THEN** 对照全部有效入口、状态、操作反馈、导航返回及动效，修复可见或可感知差异并保留运行证据
- **AND** 已有S/A批次重新验收，没有V或完整交互证据不得标为整体一致

#### Scenario: 运行条件缺失
- **WHEN** 参考包、设备、账号、SDK或具体测试授权不足
- **THEN** 记录缺失条件、受影响场景与后续动作，继续其他独立场景
- **AND** 不制造成功、不以合成样例冒充真实系统效果、不提前验收缺口页面

#### Scenario: 本次计划尚未确认
- **WHEN** 用户要求重新生成修改计划并确认后执行
- **THEN** 仅更新计划与规格，不启动该修订计划的代码修改、构建安装或业务操作
- **AND** 等待用户确认后按运行基线、公共流程、逐组修复、最终验收顺序实施

### Requirement: 翻译历史必须共用原生详情展示并保持只读
Flutter MUST 共用历史标题、号码、时间时长、关闭入口和双语字幕气泡；MUST 保留有效非最终字幕、语言投影和独立录音状态，界面调整不得重放外呼或自动播放。

#### Scenario: 大字体阅读与关闭
- **WHEN** 用户放大字体、滚动字幕或关闭历史详情
- **THEN** 双语内容可读、关闭入口可操作，并沿原来源返回
- **AND** 记录或录音加载失败仍保留已有字幕与独立重试，不制造录音成功

### Requirement: 翻译选择必须共用原生样式并保留取消语义
Flutter MUST 共用翻译模型按钮、区域卡片与语言选择行，保持持久化失败可见、七种语言范围与原生返回入口；MUST NOT 因界面调整放宽地区门禁或自动发起电话。

#### Scenario: 从拨号提示选择语言或返回
- **WHEN** 用户选择某一方语言，或使用返回取消
- **THEN** 只修改对应语言或保留原值，并恢复原提示及号码
- **AND** 大字体下名称、原文与选中状态保持可读，不触发电话

### Requirement: 任务列表必须共用原生卡片与恢复入口
Flutter MUST 共用任务标题、卡片、顶对齐状态及可读说明，保持刷新和部分失败时已有记录；MUST 沿用现有会话恢复和翻译历史入口，不因展示调整发起通话。

#### Scenario: 长记录与历史打开
- **WHEN** 用户放大字体或打开历史记录
- **THEN** 状态与标题保持可读，说明使用完整内容区，列表可滚动
- **AND** 仅执行既有恢复或只读详情操作，不产生新的电话或计费

### Requirement: 会话输入与候选必须使用统一原生交互规范
会话 MUST 使用共享文字输入胶囊、模型入口、按住说话与模式切换展示；文字草稿 MUST 在模式切换时保留，发送成功后才清除。候选 MUST 展示编号及选中反馈，继续使用现有消息动作且防止重复点击。

#### Scenario: 输入模式与短屏
- **WHEN** 用户切换输入模式、收起键盘或放大字体
- **THEN** 控件与内容适应可用空间，保持可操作热区和草稿
- **AND** 动画不创建第二个输入控制器或重复开始采集

#### Scenario: 点击有效候选
- **WHEN** 用户选择当前轮次的候选
- **THEN** 显示该项选中反馈并交给现有“第N个”消息流程
- **AND** 旧候选和忙状态不得重复发送，不新增确认执行按钮

### Requirement: 模型目录必须保持原生选择与音色入口
正式模型目录 MUST 展示选中描边、可用性、倍率、推荐及各模型音色入口；切换 MUST 以服务端响应为准。首页快速选择保持独立，不混入创建克隆流程。

#### Scenario: 从非当前模型进入音色
- **WHEN** 用户点击其他可用模型的音色入口
- **THEN** 先提交模型选择，成功确认当前模型后再打开目标音色
- **AND** 失败保留原模型及错误反馈，不进入另一模型音色

### Requirement: Flutter 必须统一风格并适配必要平台差异
Flutter MUST 参考指定新版原生正式可达页面的布局、状态、动作和返回行为，建立跨平台统一视觉与交互规范，并以用户最新明确规则解决业务冲突。颜色、字体层级、间距和通用业务组件 MUST 共用；必要平台差异 MUST 有对应依据并局部适配。

#### Scenario: 页面存在平台差异
- **WHEN** Android 和 iOS 原生同一页面的视觉或操作不同
- **THEN** 普通视觉差异收敛为 Flutter 共用规范，系统能力、平台交互及已确认必要差异特殊处理
- **AND** 两端共用已有领域规则和接口，不因 UI 对齐改变计费或账号契约

#### Scenario: 登录和首页品牌及普通视觉
- **WHEN** Android或iOS展示登录与首页
- **THEN** 共用PhoneAgent品牌文本、登录浅色对角背景、首页标题字重与网格边距
- **AND** iOS协议准入及系统键盘安全区继续局部适配，普通视觉不得仅因平台不同分叉

### Requirement: iOS 登录必须展示并验证协议选择
iOS 登录页面 MUST 展示用户协议和隐私政策选择及原生链接，首次未选中，未同意时不得发送验证码或提交登录。

#### Scenario: 未选择协议
- **WHEN** iOS 用户未同意协议并点击发送验证码或登录
- **THEN** 展示需要同意协议的反馈
- **AND** 不调用发送或提交操作

#### Scenario: 阅读协议或同意
- **WHEN** 用户点击协议链接或选择同意
- **THEN** 链接交给可注入的导航操作，选择仅改变当前展示状态
- **AND** 同意后保留现有发送冷却、忙状态、验证码验证和邀请码流程

### Requirement: 对齐证据必须区分静态与真实验证
交付记录 MUST 分开标注源码核对、离线自动交互检查和双端真实视觉验证，不将固定源码数值或合成数据标记为真实能力通过。

#### Scenario: 缺少运行态截图
- **WHEN** 页面只有原生源码证据
- **THEN** 可以实施可确认的布局和操作
- **AND** 真实视觉精校保持待验，不伪造测量结果

### Requirement: 平台 UI 对齐必须保持可访问和安全返回
页面 MUST 保持安全区、键盘可见性、短屏滚动、动态字体和有效操作热区，返回沿用既有业务生命周期。

#### Scenario: 键盘或大字体压缩布局
- **WHEN** 键盘弹出或字体放大
- **THEN** 内容可以滚动且关键操作不溢出
- **AND** 不通过禁用字体缩放或固定整页高度掩盖问题

#### Scenario: 翻译模型节点质量展示
- **WHEN** 模型弹层展示节点检测结果或等待检测
- **THEN** 使用双端共用颜色的延迟胶囊和可访问说明，等待结果不冒充不可用
- **AND** 保留真实地区准入、刷新防重复及测速不代表通话就绪的提示

### Requirement: 开发者页必须同步原生分区并保持配置门禁
Flutter开发者页 MUST 共用详情标题、原生分区和卡片选择控件，统一列表数据、外呼调试、设备位置、翻译调试和模拟能力结构，保留配置持久化和权限边界。

#### Scenario: 开发者页未解锁或调试能力关闭
- **WHEN** 未解锁或构建不允许翻译调试
- **THEN** 不读取或修改翻译调试配置；进入已解锁页面仅观察已有定位快照，不采样或发起电话

### Requirement: 正式日志入口必须直接执行用户请求的上传
Flutter正式设置日志入口 MUST 在用户点击后直接打包上传并防止重复，按账号生命周期隔离，保留失败原快照、仅清理成功批次及清理失败重试。

#### Scenario: 上传完成或失败
- **WHEN** 用户点击日志入口，当前没有上传进行中
- **THEN** 控制器按状态执行打包上传或清理重试，在同页显示状态和结果；不要求再次点击上传，不自动处理剩余批次或泄露旧账号结果

### Requirement: 关于页必须提供真实版本和完整原生协议入口
Flutter MUST 在统一关于页显示原生品牌、实际安装版本、三项固定公共协议及显式日志入口；元数据读取不触发OTA或权限，iOS继续无OTA。

#### Scenario: 关于页读取版本或打开协议失败
- **WHEN** 安装元数据读取或系统协议展示失败
- **THEN** 显示可重试版本状态或明确协议失败提示，不填入推测版本，不附带账号信息、不发送日志

### Requirement: Android 更新沿用原生直接入口与同弹窗状态
Flutter Android SHALL 从设置版本更新入口直接检查，不要求进入检查页面再次点击；新版本确认、下载、校验、授权及安装交接 SHALL 保持弹窗展示。iOS SHALL 不显示 OTA 入口。恢复任务 SHALL 不未经新操作自动交接安装器。

#### Scenario: 用户点击版本更新
- **WHEN** Android 用户点击版本更新
- **THEN** 入口显示忙状态并直接检查，最新版本或失败显示短提示，新版本打开原生风格弹窗

#### Scenario: 用户确认更新
- **WHEN** 用户点击立即更新
- **THEN** 弹窗进入下载状态，不增加下载确认页面，保留取消清理与强制更新返回门禁

### Requirement: 国家选择复用原生有效目录与分组索引
Flutter SHALL 共用两端已实现的CN/JP/SG/US目录，呈现原始旗帜、G20与字母分组、点击/拖动索引及短反馈。搜索 SHALL 忽略空格并显示去重匹配结果。

#### Scenario: 默认浏览或搜索
- **WHEN** 用户打开国家选择或输入搜索
- **THEN** 默认显示G20与完整字母分组，搜索时隐藏分组和索引；选择结果及定位不会自动覆盖手动区号

### Requirement: 声音克隆呈现原生步骤与结果交互
Flutter SHALL 共用认证步骤标题、浅蓝说明卡、整行协议勾选、身份字段及结果卡；试听 SHALL 区分读取中和播放中，取消或后台不得晚到播放。正式确认成功 SHALL 返回来源，录音保存失败 SHALL 保留仅重试保存入口。

#### Scenario: 认证与候选确认
- **WHEN** 用户完成说明同意、身份认证并得到可用候选
- **THEN** 结果卡提供保存录音、试听、设为默认和重新录制，保留认证/替换/费用及确认门禁

#### Scenario: 确认已完成
- **WHEN** 正式候选确认与录音保存均已完成
- **THEN** 返回来源页面；保存失败只重试保存，不重复确认或扣费

### Requirement: 音色克隆区共用原生选择和管理结构
Flutter SHALL 共用克隆标题、单选行、删除操作和空态创建布局，删除仅作用于当前模型且保留候选门禁、未知结果同步及其他模型状态。未接通的试听 SHALL 明确记录缺口，不提供假成功控件。

#### Scenario: 克隆选择删除或创建
- **WHEN** 用户选择可用候选、取消删除或进入创建
- **THEN** 沿既有控制器确认/删除/创建，不重复提交且取消保留音色
- **AND** 短屏大字体内容可滚动，创建入口不重复出现

### Requirement: 图片识别结果保持原生字段和展开结构
Flutter SHALL 共用图片识别标题摘要、字段与完整文字结构，首字段12间距、后续8间距，标签和字段值采用原生半粗字；长内容 SHALL 在短屏大字体下完整可读并保持展开收起。

#### Scenario: 阅读图片识别结果
- **WHEN** 用户展开或收起长识别内容
- **THEN** 只改变展示状态，不重新识别/提交或发起通话，更新同一附件保留展开状态，换附件恢复收起

### Requirement: 图片识别处理中使用原生思考卡
Flutter SHALL 在真实识别处理中展示原生渐变思考卡与步骤，三星彩色动效采用1350ms周期和错相参数；减少动态效果 SHALL 使用静态展示，展示动画不启动识别或提交。

#### Scenario: 识别状态切换
- **WHEN** 识别完成、失败或附件移除
- **THEN** 移除处理中卡并释放动画，按同一附件状态展示实际结果，不制造成功

### Requirement: 图片识别失败展示原生错误气泡
Flutter SHALL 使用原生浅红错误气泡展示附件失败原因，保留四类真实失败及重新选择提示，不自动重试或上传。

#### Scenario: 识别失败
- **WHEN** 识别、整理、空文字或云端保存失败
- **THEN** 移除处理中卡，展示对应失败原因，短屏大字体可读且不展示成功结果

### Requirement: 正常音色克隆区不额外增加状态操作行
Flutter SHALL 在正常可用或空态使用原生选择/创建结构，以单选状态表达当前使用；异常同步、失败及处理中 SHALL 保留必要状态与刷新恢复。

#### Scenario: 正常与异常切换
- **WHEN** 音色正常就绪或变为需要同步
- **THEN** 正常不显示重复状态/刷新行，需要同步时只允许同步而不重复确认

### Requirement: 主动文档从附件菜单直接选择
正式Flutter SHALL 从附件菜单直接打开现有多文件选择端口，解析进度显示在同一会话，不要求第二次选择。取消 SHALL 不创建卡、错误或提交；解析中 SHALL 阻止重复附件、输入与候选提交，退出/切号后的晚到结果不得发送。

#### Scenario: 文档选择解析与返回
- **WHEN** 用户选择文档并成功、失败或取消
- **THEN** 仅整批成功按既有文档轮次提交，失败短提示后允许重新选择，取消保持会话
- **AND** 保留docx/xlsx、5MB限制、草稿及原账号生命周期

### Requirement: 文档成功与恢复显示同一资料卡
Flutter SHALL 依据现有成功DocumentTurn及document类型事实的user_document_batch.v1投影文件名/类型/字符数/截断状态，同批次实时和历史使用同一卡片。非法payload SHALL 安全回退，不展示原始JSON/正文，不重新解析或提交。

#### Scenario: 文档提交与恢复
- **WHEN** 成功文档轮次获得事实确认或从历史恢复
- **THEN** 显示相同任务资料卡，沿现有命令去重，文件元数据只取现有载荷
- **AND** 文档内容不进入展示模型，空/损坏元数据不制造解析成功

### Requirement: 会话图标按钮独立可访问
会话关闭、语音模式添加内容及切换文字按钮 SHALL 提供独立的操作名称、按钮角色及点击动作，同时保留48逻辑像素热区及既有业务动作。

#### Scenario: 语音模式查找并执行按钮
- **WHEN** 用户使用辅助功能或设备UI树查找会话控制
- **THEN** 关闭任务对话、添加内容、切换到文字输入分别可识别且操作一次只触发原回调一次

#### Scenario: 文字模式按钮与发送禁用
- **WHEN** 用户切换到文字输入或内容为空
- **THEN** 添加内容、切换到语音输入及发送文字各有独立按钮名称，禁用发送不提供点击动作

### Requirement: 普通会话思考活动时间线展示
普通会话 SHALL 在正在发送且现有活动为正在思考时展示一个统一瞬态思考卡，不生成模型推理正文或持久事件。

#### Scenario: 思考完成或退出活动
- **WHEN** 收到thinkingDone、其他活动、失败、完成或恢复历史
- **THEN** 思考卡移除并释放动画，恢复不重新请求或显示过期处理卡

### Requirement: 工具卡共同显示参数
工具卡 SHALL 采用原生共同工具徽标和正文6间距、11字号16行高；仅非空服务display result展示原生结果标记，不由流结束推导结果。

#### Scenario: 空结果或未知工具
- **WHEN** 工具尚无结果或工具名称未知
- **THEN** 无结果标记，未知徽标按显示名称首字符回退，保持既有生命周期与服务文字

### Requirement: 单路结果卡原生色阶
单路结果卡 SHALL 按现有业务完成、待确认、失败状态使用原生绿黄红20%描边、对角渐变及14字号18标题行高，不更改业务结果判定。

#### Scenario: 物理结束但业务未完成
- **WHEN** 服务通话已结束但既有业务结果为失败或未确认
- **THEN** 保持失败或待确认色阶与原结果文案，不显示成功色阶

### Requirement: 部分通讯录授权工具语义
系统 SHALL 在现有limited授权快照查询中保留accessScope=limited；未找到以PERMISSION_LIMITED回传并提示范围受限，已找到及多候选保留原结果，普通授权不受影响。

#### Scenario: 部分授权未找到联系人
- **WHEN** 当前授权为limited且号码未找到或姓名状态NOT_FOUND
- **THEN** 回传PERMISSION_LIMITED并提示可在系统设置允许更多联系人，不自动打开设置或重请求权限

#### Scenario: 会话关闭或失效
- **WHEN** 查询等待期间会话关闭或账号失效
- **THEN** 不提示、不提交旧结果，多候选仍由Agent通用候选交互处理

### Requirement: 评分入口和弹层共同布局
评分 SHALL 按原生共同入口卡和94%/22角弹层呈现，使用右侧必填选填标签、原生分数/建议/提交样式，保留既有资格、无默认、草稿、互斥、只读和提交门禁。

#### Scenario: 未完成评分和已提交查看
- **WHEN** 用户打开未评分或已提交的任务
- **THEN** 未完成时无默认且提交禁用，已提交只能查看，奖励依既有后端字段显示

#### Scenario: 短屏大字体和键盘
- **WHEN** 用户使用短屏大字体输入建议
- **THEN** 标题/说明可阅读，评分和建议可滚动，提交/退出门禁保留且视口高度非负


#### Scenario: 遮罩取消和保存中保护
- **WHEN** 用户点击评分弹层外背景
- **THEN** 非保存时关闭并保留草稿，保存中仍禁止退出，不重复提交

### Requirement: 评分成功底部面板
评分成功 SHALL 使用两端共同24顶角白色底部面板、勾选图标和完成操作，奖励仅依据已确认的grantedPoints展示，遮罩不可关闭，内容短屏可滚动。

#### Scenario: 未发放积分的成功提交
- **WHEN** 评价已成功且grantedPoints为空
- **THEN** 显示成功标题和完成/关闭，不显示积分已发放或推测奖励数量

### Requirement: 赞踩卡共同状态样式
赞踩卡 SHALL 使用共同描边、轮廓图标和选中色，按钮30×29视觉并保留48操作区，保存中禁用且失败保持原有回退和服务提示。

#### Scenario: 保存中和提交失败
- **WHEN** 用户选择赞踩后请求等待或失败
- **THEN** 等待中按钮无操作，失败回到原评分且显示原错误，不生成成功奖励

### Requirement: 模型和语音控制语义隔离
会话 SHALL 将模型选择和按住说话作为独立具名控件，模型映射现有选择动作，语音只保留现有按住生命周期，不新增点击录音流程。

#### Scenario: 语音取消或识别等待
- **WHEN** 用户上滑取消或识别处于结束等待
- **THEN** 标签和禁用状态反映当前状态，不因语义事件额外开始或发送语音

### Requirement: 身份删除确认共同布局
身份删除确认 SHALL 使用原生小圆角白卡和右下文字操作，保持完整身份/音色/录音清理说明、既有确认和取消返回值；字体补偿仅依据原生明确的平台字宽处理。

#### Scenario: 取消删除或短屏大字体
- **WHEN** 用户取消或在短屏大字体阅读确认说明
- **THEN** 取消不执行删除，说明及确认可滚动访问，不截断清理范围

### Requirement: 克隆未保存返回显式选择
克隆未保存返回 SHALL 仅通过确认返回或继续完成退出提示，保持原生完整提示及重新录制说明，普通确认共享文字按钮样式且不改变计费或认证门禁。

#### Scenario: 未保存录音时点击背景或返回
- **WHEN** 未保存返回确认已打开且点击遮罩或系统返回
- **THEN** 提示保持打开，不恢复系统音色或关闭克隆流程，继续完成只关闭提示

#### Scenario: 仅删除当前模型音色
- **WHEN** 用户打开当前模型克隆音色删除确认
- **THEN** 原生红色文字确认保留完整范围说明，取消不调用删除，确认沿既有当前目标门禁处理

### Requirement: 系统音色本地试听
系统音色 SHALL 使用指定两端共同映射的本地音频，显示独立加载/播放/停止和错误状态，试听不修改选中音色；页面退出、后台、切号及音频焦点抢占必须停止旧播放。

#### Scenario: 缺少参考资源或晚到读取
- **WHEN** 音色ID无资源或页面已关闭后资源读取返回
- **THEN** 无资源不可试听，晚到不开始播放，不使用其他音色代替

### Requirement: 模型卡操作区域隔离
模型卡 SHALL 将选择模型及打开音色作为独立具名操作，保持布局和既有选中/忙态门禁，不合并为一个点击中心无动作的节点。

#### Scenario: 已选模型打开音色
- **WHEN** 当前模型已选且用户打开音色入口
- **THEN** 只调用原音色回调，不重复提交模型选择，忙态无操作

### Requirement: 克隆音色试听独立于确认和计费
克隆音色试听 SHALL 按既有ready状态读取当前或候选音频，保持账号/模型作用域和既有WAV下载门禁，试听不得生成/确认或扣费，音色突变前必须成功停止播放。

#### Scenario: 候选已就绪或停止失败
- **WHEN** 候选已就绪或确认/删除前停止失败
- **THEN** 就绪候选使用candidate预览，停止失败显示错误且不继续确认/删除，不用系统样音替代

### Requirement: 联系人备注取消门禁
联系人备注 SHALL 允许非保存态点击背景取消，并使用共同错误与字数统计行，保留草稿、2000限制及保存协议。

#### Scenario: 备注保存中点击背景
- **WHEN** 备注正在保存且点击背景或系统返回
- **THEN** 编辑器保持打开，不取消请求或重复保存，失败后保留草稿且可显式取消或重试

### Requirement: 监听音源选择原生共同布局
监听音源弹层 SHALL 使用原生共同把手、图标底块、选中勾和分隔行，仅显示现有可用设备，取消不修改选中音源。

#### Scenario: 无蓝牙或背景取消
- **WHEN** 当前无蓝牙或用户点击背景取消
- **THEN** 无蓝牙行不展示，取消不触发设备切换，原监听状态保留

### Requirement: 单路通话共同头部和禁用反馈
单路通话 SHALL 使用原生共同头部间距、文字层级和整列禁用反馈，保留可滚动短屏展示和既有监听/挂断/音源门禁。

#### Scenario: 终态或短屏大字体
- **WHEN** 通话终态禁用操作或短屏大字体显示
- **THEN** 禁用图标及标签均反映不可用且无操作，头部转写可滚动，不提升物理结束为业务成功

### Requirement: 备注取消仅关闭编辑弹层
备注取消 SHALL 仅关闭当前编辑路由，退出动画期间的状态监听不得再次关闭底下联系人详情。

#### Scenario: 背景取消后清理草稿
- **WHEN** 编辑弹层已被背景取消且controller清理草稿
- **THEN** 联系人详情保持显示，重新编辑使用已保存备注，不发生第二次返回

### Requirement: 单路通话覆盖对话焦点隔离
单路通话覆盖期间 SHALL 阻止隐藏对话输入获得焦点，保留挂载和草稿，音源弹层返回不得自动打开对话键盘。

#### Scenario: 文字发起后取消音源选择
- **WHEN** 文字发起单路通话且音源弹层返回
- **THEN** 隐藏对话无编辑焦点，通话视口保持完整，监听和当前音源不因取消改变

### Requirement: 单路深色通话系统栏可读
单路深色通话 SHALL 使用两端原生共同浅色系统栏图标并仅作用于当前通话区域，返回后恢复承载页面样式。

#### Scenario: 打开或关闭通话覆盖
- **WHEN** 单路深色通话打开或关闭
- **THEN** 通话状态图标可读，关闭后不将深色样式扩散到首页或对话

### Requirement: 批量任务进度共同外壳
批量外呼进度和结果 SHALL 使用原生共同标题分隔外壳、同排说明计数和进度过渡，保持完成数与成功数不同及现有录音/展开行为。

#### Scenario: 零总数或减少动画
- **WHEN** 批量总数为零或系统要求减少动画
- **THEN** 零总数显示零进度及真实状态，减少动画直接显示目标进度，不造成功数或额外终态

### Requirement: 批量单项共同操作行
批量单项 SHALL 在共同操作行显示既有转写展开和compact录音，compact仅提供加载/播放/暂停/重试，不新增保存或改变录音资格。

#### Scenario: 加载中或单项无录音
- **WHEN** 录音加载中或单项无可用录音锚点
- **THEN** 加载无重复播放动作，无锚点不造按钮，转写独立展开且保留当前目标

### Requirement: 紧凑录音状态图形
紧凑录音 SHALL 使用原生共同播放三角、播放中方块和失败重试图形；方块动作保持暂停，不转换为结束或保存。

#### Scenario: 播放中点击方块
- **WHEN** 紧凑录音正在播放
- **THEN** 显示白方块并保留暂停提示及既有暂停回调，加载中无重复动作

### Requirement: 批量单项共同头部
批量单项 SHALL 使用左姓名及说明、右状态胶囊；空姓名按号码及未命名联系人回退，空业务结果按真实状态回退，保留额外业务字段。

#### Scenario: 缺少姓名及业务结果
- **WHEN** 姓名和业务结果仅包含空白
- **THEN** 显示非空姓名回退及真实状态标签，短屏大字体不溢出，不修改服务端数据

### Requirement: 联系人详情直接系统拨号
联系人详情拨号 SHALL 直接交给系统电话确认入口，保持详情及应用内拨号草稿，归一化前导加号和数字/*/#；空值和失败反馈不得伪造接通。

#### Scenario: 系统返回或账号切换
- **WHEN** 系统返回详情或账号已切换
- **THEN** 保留当前详情；旧请求结果不向新账号显示，系统交接不记接通或费用

### Requirement: 位置权限共同提示
位置权限提示 SHALL 使用双端共同圆角卡、并列操作和背景取消，短屏大字体可滚动，取消后翻译关闭且普通拨号可用。

#### Scenario: 取消提示
- **WHEN** 用户背景取消或系统返回
- **THEN** 提示关闭且不重新弹出，不请求系统定位，保留当前拨号配置页面

### Requirement: Agent文档共同选择弹层
Agent索要文档 SHALL 使用原生共同渐变及虚线选择区，解析中禁止重复选择，背景和返回允许取消且只提交一次当前请求结果。

#### Scenario: 解析中取消
- **WHEN** 当前文档正在选择或解析且用户取消
- **THEN** 关闭弹层并提交一次当前取消结果，晚到解析不覆盖结果或发送重复命令

### Requirement: Agent文档动效与退出隔离
Agent文档弹层 SHALL 双端共用有来源的入场动效，减少动画时直接显示；退出中的绘制快照不得获得焦点、触发新请求动作或改变取消结果。

#### Scenario: 旧弹层退出时出现新请求
- **WHEN** 旧请求已完成而旧绘制仍在退出
- **THEN** 旧层无点击和读屏动作，只有当前controller和request可选择文件

#### Scenario: 键盘退场期间打开文档
- **WHEN** 对话键盘正在收起且文档弹层入场
- **THEN** 使用全屏坐标及稳定底部安全区，键盘不得改变弹层目标位置或造成跳动

### Requirement: 翻译模型刷新动效
翻译模型选择器 SHALL 使用共同刷新图形，检测中禁用重复刷新并旋转，减少动画时静态显示忙态。

#### Scenario: 关闭检测中的模型选择
- **WHEN** 刷新尚未完成且用户关闭弹层
- **THEN** 释放绘制动画，晚到结果不得重新打开弹层或修改已选模型

### Requirement: 翻译模型共同选项行
模型选择 SHALL 使用共同圆角选项、名称倍率延迟与单选几何，保留地区禁用及选中语义，字号增大时自适应。

#### Scenario: 禁用模型点击
- **WHEN** 地区尚不允许选择该模型
- **THEN** 不选择或关闭弹层，显示原地区状态；延迟读数不放宽准入

#### Scenario: 模型头部具名操作
- **WHEN** 模型弹层可见
- **THEN** 刷新和关闭为独立具名按钮，忙态刷新无动作且关闭仍可用

### Requirement: 拨号固定底部操作
拨号 SHALL 在底部安全区上方完整显示关闭、呼叫和删除，内容及键盘在剩余区域滚动；翻译开启使用共同紫色，普通呼叫使用绿色。

#### Scenario: 短屏配置与系统导航
- **WHEN** 配置内容较长或字号放大且系统底部安全区非零
- **THEN** 操作完整可见且可点击，滚动内容不覆盖操作，原呼叫与长按清空门禁不变

### Requirement: 翻译拨号摘要与设置入口
翻译拨号 SHALL 使用模型与语言摘要独立入口，完整配置在设置弹层编辑；关闭不呼叫，确认呼叫沿原预检且不重复展示同次提示。

#### Scenario: 手动语言设置后确认或取消
- **WHEN** 用户从语言摘要打开设置并调整配置
- **THEN** 取消返回保留配置且不创建呼叫；确认只发起一次原流程，缺号码或地区/权限不满足仍明确阻止

### Requirement: 翻译语言选择独立语义
语言选择 SHALL 为独立具名按钮，包含选中状态；选择与返回只操作当前路由。

#### Scenario: 选择回调重复执行
- **WHEN** 语言选择已返回且旧回调再次到达
- **THEN** 不再次关闭底下设置或拨号，不重复修改配置

### Requirement: 拨号共同号码头部
拨号 SHALL 使用共同国旗区号单行头部、号码字体及平面背景，长号码可受限缩放/裁切但完整读屏，选择区保留具名操作及忙态门禁。

#### Scenario: 长号码和字号放大
- **WHEN** 号码较长或系统字号放大
- **THEN** 头部不溢出，国家选择仍可用，保留号码格式与完整读屏信息，不改变实际目标号码

### Requirement: 国家选择独立操作与单次退出
国家列表 SHALL 提供具名按钮及选中状态，返回 SHALL 为独立按钮；列表选择和返回只操作当前路由一次。

#### Scenario: 搜索后重复选择
- **WHEN** 搜索国家并选择后旧回调再次执行
- **THEN** 返回所选国家一次，不关闭底下拨号页；完整国家名与区号仍可读屏

### Requirement: 拨号删除输入门禁与呼叫阴影
拨号 SHALL 在无输入或忙态禁用删除和长按清空，呼叫 SHALL 使用共同颜色阴影，空号码呼叫仍沿既有恢复与验证路径。

#### Scenario: 删除输入状态切换
- **WHEN** 号码从空变为非空再进入忙态
- **THEN** 删除仅非空且非忙时可操作，空号码不影响既有呼叫入口

### Requirement: 可信定位结果选择按钮
支持目录的可信定位结果 SHALL 为独立具名按钮，包含位置来源、国家和区号；忙态不可选择，旧回调不得重复返回；未知或未支持地区保持原获取/失败/重试规则。

#### Scenario: 选择已退出定位页
- **WHEN** 用户选择可信地区后旧回调再次执行
- **THEN** 只返回所选地区一次，不关闭底层页面或发起新定位

### Requirement: 首页通话模型质量刷新
首页模型弹层 SHALL 使用有效原生共同后端质量接口、共同刷新及读数胶囊，独立于模型可用性和音色保存；关闭和账号变更 SHALL 抑制晚到结果，工具演练 SHALL 使用隔离合成端口。

#### Scenario: 刷新失败与关闭后晚到
- **WHEN** 探测失败或刷新尚未结束时关闭弹层
- **THEN** 失败显示不可用读数且可再次刷新，关闭后旧结果不修改下一次弹层，不自动改模型或发起呼叫

### Requirement: 首页模型弹层背景隔离
首页模型弹层打开时 SHALL 阻止背景首页和底栏的点击、焦点及读屏操作，关闭后恢复。

#### Scenario: 弹层打开和关闭
- **WHEN** 用户打开模型弹层再关闭
- **THEN** 打开时只有弹层操作可达，关闭后原首页和底栏操作恢复且选择状态保留

### Requirement: 联系人备注删除共同流程
两平台已有AI备注条目 SHALL 提供共同删除入口和确认，取消不写；确认 SHALL 使用原生共同DELETE端口且只删除AI备注条目，保留系统联系人，成功返回列表，失败保留详情。加载/保存/删除 SHALL 互斥，账号或详情变更的晚到结果不得关闭新页面。

#### Scenario: 取消和失败
- **WHEN** 用户取消备注删除或删除请求失败
- **THEN** 条目与系统联系人保持，失败明确展示且不自动重试

#### Scenario: 重复确认与退出后结果
- **WHEN** 同一确认回调重复执行或删除后返回结果时已更换详情
- **THEN** 不重复请求或二次关闭页面，只更新原备注键；旧账号结果不能写回

### Requirement: 联系人选择与返回独立操作
联系人行 SHALL 为包含完整姓名与号码的独立按钮，详情返回 SHALL 为具名按钮；同一旧回调重复执行不得打开两页或二次返回。

#### Scenario: 连续打开和返回
- **WHEN** 同一联系人选择或返回回调连续执行两次
- **THEN** 只打开或关闭一个详情，底层列表和拨号/任务入口保持

### Requirement: 公共详情返回独立按钮
公共详情栏 SHALL 为具名返回按钮且保留热区/布局；禁用时不可操作，已退出或不在当前路由的旧回调 SHALL 不关闭底层页面。

#### Scenario: 详情返回重复执行
- **WHEN** 同一详情返回回调在退出后再次执行
- **THEN** 原详情只退出一次，底层页面保留；独立组件无路由时仍可执行有效返回回调

#### Scenario: 首页未打开模型弹层不初始化质量端口
- **WHEN** 用户只操作首页或切换其他业务且未打开模型弹层
- **THEN** 系统不创建模型质量Repository或其AccountApi依赖
- **AND** 打开弹层才加载，关闭与账号切换继续隔离晚到读数

### Requirement: 首页模型弹层按内容收缩
首页模型弹层 SHALL 共用原生内容高度、500最大高度、20角及420最大宽度，普通内容不得强制占屏幕68%；列表 SHALL 在短屏大字体滚动，刷新关闭保持可操作。

#### Scenario: 普通与短屏弹层
- **WHEN** 用户打开首页通话模型选择
- **THEN** 弹层按实际内容收缩且包含“切换引擎后将在下次通话时生效”
- **AND** 遮罩为45%黑，长列表可滚动且不超出安全区

### Requirement: 共享录音卡默认波形
共享录音卡 SHALL 展示两端共有24根静态默认波形、38高度和92%白圆头线条，常规字号采用84宽标题列；短屏大字体允许波形换到操作行下方。实际媒体事件未接线时 SHALL NOT 将装饰波形伪称实时音量或自行播放。

#### Scenario: 默认波形与大字体
- **WHEN** 录音卡显示且没有实际波形采样事件
- **THEN** 显示静态原生默认图形，播放和保存门禁保持原逻辑
- **AND** 大字体文本可完整显示且主操作仍有48最小热区

#### Scenario: 录音动作独立节点
- **WHEN** 用户在普通回执或翻译历史操作录音
- **THEN** 保存、播放/暂停/重试具有独立具名按钮和与实际门禁一致的可用状态
- **AND** 不得与整张回执的静态文字合并为无法单独操作的节点

### Requirement: 主底栏独立操作
主底栏 SHALL 以独立具名按钮呈现四业务入口及拨号入口，并排除装饰图标图片语义，选中Tab状态正确；320窄屏 SHALL 保持48最小Tab操作宽度及60居中拨号圆面。

#### Scenario: 主底栏操作与选中状态
- **WHEN** 用户切换首页、联系人、任务或设置
- **THEN** 最终系统交互树呈现独立可点击按钮且仅当前入口选中
- **AND** 短屏大字体不遮挡拨号热区或缩窄Tab至48以下

### Requirement: 独立演练录音保存位置
工具端口的录音保存选择 SHALL 使用当前账号App路由的有效Navigator，不依赖外层工作台。

#### Scenario: 独立完整App演练保存位置
- **WHEN** 仅工具端口的完整App没有外层工作台Navigator且用户演练录音保存
- **THEN** 合成选择弹窗使用当前App账号路由的Navigator
- **AND** 取消仍在原详情，不产生真实文件或伪造保存成功

### Requirement: 任务列表独立且单次进入
任务卡 SHALL 以包含完整标题、状态和详情的独立按钮呈现，保持当前正式来源/恢复规则；旧回调在详情已进入或网络采样晚到离开原入口时 SHALL NOT 再次打开详情。

#### Scenario: 连续任务选择
- **WHEN** 用户快速选择同一任务两次，或详情显示后触发旧入口
- **THEN** 最多打开一次当前详情，关闭一次即返回任务列表
- **AND** 返回后仍可重新选择该任务，切换Tab晚到不打开旧任务

### Requirement: 录音状态采用原生共同布局
共享录音卡 SHALL 保持普通81高度且控件垂直居中；失败态 SHALL 采用64最小高、16角、12标题/9副标题及30波形、40主圆面，字体随系统字号缩放，48操作热区保留。加载/处理 SHALL 明确呈现录音加载中，失败 SHALL 保留通话录音标题并提供重试加载录音。

#### Scenario: 失败和大字体
- **WHEN** 录音加载失败或处于加载/处理中
- **THEN** 失败使用紧凑共同形态，加载使用原生进度图形及具名忙态
- **AND** 大字体允许自然增高换行，不裁切文字，不改变播放保存门禁或制造成功

### Requirement: 录音重试过渡保持失败形态
显式失败重试等待资源时 SHALL 保持共同紧凑卡和音频加载失败副标题，主操作禁用并显示19进度，保存图形不显示初次加载圆环。展示标记 SHALL 不改变播放保存协议。

#### Scenario: 失败后重试
- **WHEN** 用户从失败卡显式重试且资源仍在等待
- **THEN** 卡保留失败形态，禁止重复加载，保存操作仅沿既有加载提示
- **AND** 进入处理、成功、失败或停止后清除重试展示标记，翻译不自动播放，普通回执保留既有显式播放规则

### Requirement: 录音显示波形跟随播放生命周期
共享录音波形 SHALL 仅随既有播放器playing状态运行原生15fps显示动画，暂停保留当前帧、恢复续帧，终态复位默认图形。无播放状态 SHALL NOT 制造活动波形或把显示图形声称为真实采样。

#### Scenario: 播放暂停及生命周期
- **WHEN** 播放进入暂停、恢复、结束，或宿主隐藏/退出前台/销毁
- **THEN** 显示帧分别保留、续帧、复位或停止，隐藏和销毁不留后台计时
- **AND** 系统减少动画关闭活动帧，不改变实际媒体播放、保存或音频焦点协议

### Requirement: 会话品牌与翻译详情关闭一致
会话可见品牌 SHALL 使用共同PhoneAgent及31字号/32行高。翻译详情关闭 SHALL 是具名关闭翻译记录的独立48按钮，旧页面回调 SHALL NOT 关闭新页面。

#### Scenario: 翻译记录连续关闭
- **WHEN** 用户关闭当前翻译记录并再次触发旧关闭回调
- **THEN** 只返回一次任务列表，仍可重新打开
- **AND** 大字体保持可访问按钮和完整品牌，不改变退出取消及任务恢复规则

### Requirement: 首页任务通知与任务角标
Flutter SHALL 从现有真实任务源派生有效通知，在首页顶栏后显示原生共同通知条及四类状态色、关闭当前和更多数量，任务底栏显示最多99的红色计数；不得借此请求系统推送权限或编造结果。通知候选 SHALL 按稳定业务身份、最新优先并先去重后过滤已读，普通任务catalog合并不得丢失通知输入。

#### Scenario: 关闭通知与进入任务
- **WHEN** 用户关闭当前通知、点击通知进入任务列表或切换任务Tab
- **THEN** 分别标记当前或当前已呈现候选已读，通知/角标随之更新，仍能进入原任务详情
- **AND** 已读写失败保留可重试候选，未见的未来任务不被提前标记

### Requirement: 通知已读状态按账号环境隔离
已读存储 SHALL 采用环境、后端地址和账号隔离，90天/512清理保护当前候选；未登录、未配置或读取失败 SHALL NOT 伪造全部未读。账号/环境切换后的旧读取或写入 SHALL NOT 更新新账号视图。

#### Scenario: 重入与账号切换
- **WHEN** 用户重启或切换账号/环境，或刷新期间任一任务源失败
- **THEN** 只恢复当前owner的已读状态，保持各源现有缓存/错误规则，稳定身份的状态变化不重复提醒
- **AND** UI只派生状态与提交操作，不直接读取存储、网络或设备

#### Scenario: 首页滚动与通知读写失败
- **WHEN** 用户滚动首页技能区域或重试通知已读保存
- **THEN** 普通布局顶栏与通知条固定，短屏大字体有效操作仍可滚动到达
- **AND** 保存重试只处理原失败身份，后到通知保持未读；角标缩放不遮挡Tab名称和48热区

#### Scenario: Conversation stage bars retain earlier progress
- **WHEN** the existing conversation projection advances through its four stages
- **THEN** the current and preceding bars use the unified blue fill, remaining bars stay inactive, and each bar is 6 logical pixels high with 8 logical pixels between bars
- **AND** only the current stage label is highlighted and selected; progress remains presentation without altering call permissions or outcomes

#### Scenario: Home model capsule displays confirmed multiplier
- **WHEN** the current confirmed call model supplies a finite positive multiplier
- **THEN** the home capsule displays that multiplier as × followed by one decimal, together with the current model name
- **AND** missing or invalid multipliers stay hidden without fabricated defaults or billing changes; model selection and narrow large-text layouts remain usable

#### Scenario: Voice rows keep compact layout and independent actions
- **WHEN** a system or clone voice row displays its selection and preview controls
- **THEN** the normal row uses 67 logical pixels including its separator, retains a 38-pixel preview surface inside a separate 48-pixel hit target, and grows for larger text
- **AND** selection and preview expose independent named actions; selected voices cannot be selected again and disabled preview never selects a voice

#### Scenario: Setting actions remain named during busy states
- **WHEN** settings, about, translation region or outbound-number action cards are displayed
- **THEN** each action exposes one named button with its meaningful current value, busy log and update actions remain disabled buttons, and read-only location summaries remain noninteractive

#### Scenario: Voice sheet close does not act after its route ends
- **WHEN** the voice sheet close action is invoked
- **THEN** it exposes the name 关闭音色选择 with a 48-pixel hit target and closes only while its own context is mounted and its route current
- **AND** a retained callback from a closed sheet does not close a later sheet or its parent page

#### Scenario: Clone entry remains one button with declared points
- **WHEN** the model directory or empty clone voice section offers clone creation
- **THEN** the entry exposes a single named 声音克隆，300积分 button with its actual enabled state and excludes decorative image semantics
- **AND** invoking it opens only the existing model-selection workflow while its own context is mounted and route current; old background callbacks do not reopen creation

#### Scenario: Identity and clone return icons retain independent actions
- **WHEN** identity icon actions or clone candidate return controls are displayed
- **THEN** they expose named independent buttons with actual enabled state and at least 48-pixel hit targets, excluding decorative SVG and glyph semantics
- **AND** decorative back glyphs keep their fixed native size while surrounding text scales; retained callbacks do not operate from a closed or background route

#### Scenario: Clone model picker exposes one named close action
- **WHEN** the clone model picker is open on either platform with normal or enlarged text
- **THEN** its close control SHALL be a named 48 logical pixel button with fixed decorative glyph size
- **AND** repeated or stale callbacks SHALL NOT dismiss the underlying page or a subsequently opened picker.

#### Scenario: Document and translation picker cancellation preserves the host
- **WHEN** a user closes a document importer or translation model picker and opens it again
- **THEN** duplicate, background and stale close callbacks SHALL NOT pop the host or the new picker
- **AND** each active close control SHALL retain a named independent 48 logical pixel action on both platforms.

#### Scenario: Invite rules preserve native paragraph layout and safe dismissal
- **WHEN** invite rules contain numbered items, blank separators or continuation lines
- **THEN** Flutter SHALL preserve the original wording and numbers with 14/21 text, 12 paragraph spacing and 4 numbered hanging indent gap
- **AND** rules SHALL remain readable on short screens and enlarged text without introducing a selection toolbar
- **AND** duplicate or stale acknowledgement callbacks SHALL NOT dismiss the host or another rules sheet.

#### Scenario: Translation call health reflects versioned native environment data
- **WHEN** the existing call coordinator emits a valid versioned environment patch
- **THEN** Flutter SHALL project network, SIP and model states without inventing available results, preserve missing fields and reject older versions
- **AND** the call page SHALL show named 10 font size health indicators with 16 by 4 bars, 4 internal and 8 external spacing using native state colors
- **AND** risk text SHALL appear only in an empty transcript area, while terminal or disposed calls ignore late environment updates.

#### Scenario: Task list synchronization uses native states and compact records
- **WHEN** tasks load initially, refresh cached results or partially fail
- **THEN** Flutter SHALL display native text loading, blue refresh or red retry surfaces while retaining existing records
- **AND** retry SHALL be disabled during loading and loading dots SHALL stop for reduced motion or disposal
- **AND** normal task titles and details SHALL use compact single lines with full accessible text, allowing larger text to grow.

#### Scenario: Native component references remain isolated and traceable
- **WHEN** native post-login visual components are staged without a test session
- **THEN** the debug-only reference harness SHALL invoke fixed native source components with synthetic state in an independent application id without network or device business actions
- **AND** component screenshots SHALL be labelled as component references rather than complete native business flow acceptance.

#### Scenario: 配对纯组件对照不冒充业务验收
- **WHEN** 在隔离模拟器运行原生与 Flutter 纯组件参考入口
- **THEN** 两者使用相同合成状态，Flutter 直接调用生产组件且使用独立 debug 包
- **AND** 对照只验证组件显示，不表示登录后业务流程或 iOS 已验收

### Requirement: 翻译字幕更新必须显示最新内容
Flutter SHALL follow the fixed native latest transcript key and reset the reverse transcript list to its newest item when the latest segment text or final state changes.

#### Scenario: 新字幕与无字幕刷新区分
- **WHEN** 用户阅读较早字幕后末条新增、文字更新或成为终稿
- **THEN** 字幕列表回到最新条目，保持说话人方向、原文译文规则和原生气泡样式
- **AND** 仅计时或环境变化不会重置用户阅读位置，组件销毁释放滚动控制器

#### Scenario: 少量字幕从顶部开始
- **WHEN** 字幕总高度不足可用视口
- **THEN** 两端共用从字幕区顶部开始的布局，条目间距10且末条没有额外尾间距
- **AND** 超过视口后仍可阅读历史并在末条更新时回到最新

### Requirement: 通话内拨号盘必须遵循原生共同网格
Flutter SHALL use a centered 72-percent content-width DTMF panel, four 42-pixel normal rows with one-pixel gaps, 21-pixel white digits, translucent navy background and a 12-pixel gap before call controls.

#### Scenario: 展开收起与业务门禁
- **WHEN** 用户展开或收起拨号盘，或控制动作忙/通话终止
- **THEN** 数字为独立具名按钮且忙/停止/终态禁用，发送仍沿现有确认协议
- **AND** iOS采用原生200ms展开收起，Android即时，减少动画时均即时，大字体只增高保持可读

### Requirement: 国际按键反馈必须区分输入与发送确认
Flutter SHALL derive enhanced keypad availability from the active media capability and keep local entered digits separate from backend-confirmed DTMF state.

#### Scenario: Android国际按键反馈与回退
- **WHEN** Android当前媒体支持DTMF且用户按下有效可操作按键
- **THEN** 面板显示末32位本地输入历史、90ms的88%按压反馈和通过平台适配的选择触感
- **AND** 失败不伪造发送确认，关闭重开清空本地输入；WebSocket回退/iOS采用普通盘，忙/终态不输入或触感，减少动画即时变化

#### Scenario: 短屏大字体增强盘可操作
- **WHEN** 展开的拨号盘和输入提示超过短屏或大字体可用空间
- **THEN** 控制区可独立滚动且默认显示底部挂断和主操作，用户可访问全部数字键
- **AND** 正常字号常规屏保持固定布局，不通过缩字或隐藏按键解决溢出

### Requirement: 深色翻译通话必须使用原生系统栏图标对比
Flutter SHALL locally apply light status/navigation icons and transparent system bars to the translation call page, preserving the existing light-page global style.

#### Scenario: 深色翻译页与返回
- **WHEN** 用户进入深色翻译通话页并返回普通浅色页面
- **THEN** 通话页使用浅色系统图标和透明背景，不叠加导航对比遮罩
- **AND** 返回恢复浅色页面深色图标，局部样式不留下全局副作用，iOS使用原生LightContent对应设置

### Requirement: 翻译身份文字必须采用明确统一字距
Flutter SHALL explicitly use the selected native 0.5 logical letter spacing for the translation target, phase label and elapsed timer, without inheriting unrelated Material 3 typography spacing.

#### Scenario: 两平台身份文字与大字号
- **WHEN** 显示翻译目标、通话状态与计时
- **THEN** 两平台统一显式字距且保留现有字号、权重、长名称省略和系统字体缩放
- **AND** 不改全局字体主题或字幕、控制区状态，短屏大字仍可操作

### Requirement: 任务文字必须显式匹配选定原生字距
Flutter SHALL use zero letter spacing for task card title, status and detail, and 0.5 logical letter spacing for synchronization surfaces and initial loading text.

#### Scenario: 紧凑任务卡与同步状态
- **WHEN** 显示任务、初载、缓存刷新或同步失败
- **THEN** 使用明确原生字距，保留既有字号行高、单行普通卡和大字可读性适配
- **AND** 不修改任务状态、已读策略、刷新计时和请求

### Requirement: 邀请规则弹层必须采用统一原生遮罩与内容上限
Flutter SHALL use the selected native iOS 40-percent black rules overlay and a content-fitting sheet capped at the screen height minus a 20-logical-pixel top margin, including the bottom safe area.

#### Scenario: 长规则短屏与大字体
- **WHEN** 规则内容超过短屏可用空间或系统字体放大
- **THEN** 正文可滚动到末条且确认按钮固定可操作，底部安全区只计算一次
- **AND** 关闭仍只退出当前弹层，不修改规则正文、邀请归因或积分状态

### Requirement: 邀请规则路由必须保留必要平台呈现差异
Flutter SHALL use the shared rules content and style with iOS fade presentation and Android bottom-sheet slide/drag interaction, while reduced motion removes both transitions.

#### Scenario: iOS规则固定底部淡入淡出
- **WHEN** iOS打开或关闭邀请规则
- **THEN** 底部面板位置固定并以透明度过渡，不加入原生没有的滑动关闭
- **AND** Android保留底部滑入与拖拽，两端背景点击和确认只关闭当前弹层，共享正文及安全区不变

### Requirement: 邀请规则入口必须避免重复路由堆叠
Flutter SHALL open the rules overlay only from a mounted current host route and SHALL preserve legitimate reopening after dismissal.

#### Scenario: 连续点击与过期入口
- **WHEN** 同一规则入口连续触发，或旧入口所属页面已在后台/销毁
- **THEN** 不创建重复弹层或从无效宿主打开，关闭一次返回原页
- **AND** 返回后合法再次打开可用，邀请活动及积分状态不变

### Requirement: 积分余额页必须遵循原生共同布局与入口
Flutter SHALL place the balance card 18 logical pixels below the existing header without an extra list top inset, use the native 32-size bold balance text, and omit the unreferenced standalone refresh button.

#### Scenario: 刷新能力与余额显示保留
- **WHEN** 用户显示余额、下拉刷新或进入积分流水
- **THEN** 保留既有刷新端口、错误重试、缓存真实性说明和独立流水入口，短屏大字体仍可操作
- **AND** 不改变余额权威、积分估算、邀请数据或计费结算

### Requirement: 公共系统栏必须与页面背景和亮度一致
Flutter SHALL use shared transparent status and navigation bar styles with dark icons on light pages and light icons on dark call pages, disabling contrast overlays and restoring the host style on route exit.

#### Scenario: 浅色页与深色通话连续切换
- **WHEN** 用户从浅色页面进入普通或翻译通话并返回
- **THEN** 系统栏透出当前页面背景且图标亮度对应，返回恢复宿主，不遗留固定白色导航条
- **AND** 不改变登录、路由栈、安全区、媒体状态或平台包身份，iOS状态栏亮度单独适配

### Requirement: 邀请操作反馈必须短暂替换且不拦截导航
Flutter SHALL use the shared transient notice for invitation feedback, replace the previous notice, and show new feedback only on a mounted current invitation route.

#### Scenario: 连续复制后立即返回
- **WHEN** 用户连续复制有效邀请码或链接并立即返回积分页进入记录
- **THEN** 反馈不排队延长、不拦截底部点击，后台或已销毁海报不展示后续旧反馈
- **AND** 保留复制内容、保存结果、活动事件和积分状态，不添加真实业务请求

### Requirement: 积分卡字体布局必须采用实测目标且保留放大
Flutter SHALL use explicitly measured balance and summary line heights without inheriting unrelated global body typography or clipping scaled text.

#### Scenario: 余额卡运行尺寸复核
- **WHEN** 显示同状态余额卡或用户放大系统字体
- **THEN** 数字和说明使用确定的局部行高，实机复核字形和卡片尺寸，大字体自然换行
- **AND** 保留缓存提示、流水入口和下拉刷新，不改变余额和结算规则

### Requirement: 积分流水差异必须按有效运行状态核对
Flutter ledger parity SHALL be checked against the native ledger component using matching synthetic normal, empty, initial-loading and unavailable-error states before marking visual parity.

#### Scenario: 流水组件隔离对照
- **WHEN** 对照积分流水的布局与状态呈现
- **THEN** 直接复用生产组件和同数据，区分已加载空结果与尚未取得数据，核对零变更可见性
- **AND** 不连接账户、计费、奖励或真实网络，组件对照不能替代完整业务与iOS运行验收

### Requirement: 流水页面必须区分未取得与已取得空结果
Flutter SHALL maintain an explicit ledger-available presentation fact set by a successful ledger read or valid cache restoration, and SHALL show centered initial-loading or unavailable-error content without the detail card before a ledger snapshot exists.

#### Scenario: 空结果与余额独立刷新
- **WHEN** 积分余额单独同步、初次流水请求失败，或成功取得空流水
- **THEN** 余额同步不伪造流水已取得，未取得显示居中加载/重试，成功空结果显示正常明细空态
- **AND** 已知缓存/记录在再次刷新失败时保留，错误采用原生固定网络说明，大字可操作，不改变钱包权威、分页、缓存格式或结算

### Requirement: Ledger full-height presentation and safe final actions
The Flutter ledger SHALL match the reference full-height body and white-card background while keeping its final scroll actions above each platform's system inset. Both platforms SHALL use the same ledger empty, row and paging typography selected from the effective native reference.

#### Scenario: System inset and large text preserve the ledger geometry
- **WHEN** a ledger is shown with a bottom system inset or large text
- **THEN** its card background extends through the inset, unavailable-state content centers within the full remaining body, and the last scroll action remains reachable above the inset without overflow

### Requirement: Settings comparison shall preserve effective entry evidence
Settings parity SHALL use the effective native home component and current iOS mounted rows, preserving entry-set differences in evidence. Isolated references SHALL avoid account, logging, update, identity and SDK side effects.

#### Scenario: Matching synthetic settings summaries
- **WHEN** settings cards are compared across the native and Flutter references
- **THEN** matching synthetic summaries and font conditions are used, missing effective entries are recorded, and no SDK or account capability is claimed from no-op callbacks

### Requirement: Settings title height shall follow measured native layout
The shared Flutter settings-home title SHALL use the effective measured native title region, keeping its font size and weight and not altering unrelated detail headers.

#### Scenario: Normal and enlarged settings heading
- **WHEN** the settings home is displayed with normal or enlarged text
- **THEN** its title and first-card origin follow the selected shared native layout, remain readable, and all implemented entries remain scrollable and actionable

### Requirement: Settings home cards shall preserve native summary placement
The Flutter settings-home cards SHALL match the selected measured native title line region and keep summaries beside their content whenever both columns fit. Other card contexts SHALL preserve their existing layout defaults.

#### Scenario: Enlarged settings summary and extreme narrow content
- **WHEN** settings text is enlarged
- **THEN** a fitting summary remains in the right column as in both native homes, while a summary that would leave fewer than 48 logical pixels for content plus spacing uses a readable stacked fallback without overflow or loss of actions

### Requirement: Settings summaries shall use native presentation and installed facts
Flutter settings SHALL use the effective native compact model name and valid multiplier, original-audio navigation summary, and developer entry summary. Android manual-update display SHALL use installed version metadata when available and the native checking state, without an extra navigation arrow.

#### Scenario: Settings loading and installed version
- **WHEN** model or installed metadata is loading or unavailable, or an update check is in progress
- **THEN** stale model pricing is not presented, unknown installed metadata is not fabricated, repeated update checks remain disabled, and no update check is issued solely to render the version summary

### Requirement: Model-list reference shall use effective production composition
Model-list comparison SHALL use the effective native provider page and Flutter production list with matching synthetic catalog data. Effective clone entries and derived voice summaries SHALL be included; omissions or incorrect static composition assumptions SHALL be corrected before comparison.

#### Scenario: Synthetic model catalog comparison
- **WHEN** model card geometry and enlarged text are compared
- **THEN** catalog names, pricing, selection and descriptions match, callbacks do not access model or media services, and the comparison does not claim clone or complete model-to-voice flow acceptance

### Requirement: Model voice rows shall anchor their disclosure at the trailing edge
Full model cards SHALL align their voice summary and disclosure with the native trailing edge. Empty or short summaries SHALL NOT leave unused flex space after the disclosure. Long summaries SHALL remain bounded without removing the capability description or action.

#### Scenario: Voice summary lengths and enlarged text
- **WHEN** an empty, short or long voice summary is rendered with normal or enlarged text
- **THEN** the disclosure remains at the trailing inset, capability text can wrap, and the separate voice action retains its existing busy and availability guards

### Requirement: Model clone entry shall describe current readiness facts
The effective clone entry SHALL use the common native ready or empty message based on all supported models' usable current clone assets. Candidate readiness alone SHALL NOT be considered a usable current clone. Reads SHALL remain scoped to the login and active model page.

#### Scenario: Loading, failure and returning from clone flow
- **WHEN** clone readiness is unknown, fails, or a user returns from a clone flow or deletes identity
- **THEN** unknown state is not represented as an empty result, readiness is re-read after relevant changes, and existing clone entry authorization and duplicate-navigation guards remain intact

### Requirement: Model geometry shall preserve native visual and touch regions
The clone action SHALL use the common native star glyph with scalable typography and separate its compact painted surface from a minimum 48 logical pixel touch region. Full model card text SHALL use explicit measured line regions without changing quick-model defaults.

#### Scenario: Normal and enlarged clone action
- **WHEN** the clone entry renders at normal or enlarged text size
- **THEN** the painted action and card use the selected native geometry, the points glyph scales with text, the action remains at least 48 logical pixels tall for interaction, and text remains readable

### Requirement: Shared detail heading shall reserve the measured native line region
Shared detail headings SHALL reserve the selected native title line region at normal and enlarged text sizes without changing the minimum return target or stale-route callback protection.

#### Scenario: Enlarged detail heading and body origin
- **WHEN** detail text scales to twice its normal size
- **THEN** the heading expands with its native line region and positions body content below that region, while the return action remains available and cannot pop an obsolete host

### Requirement: Model voice summaries shall follow native read-only presentation precedence
Full model pages SHALL show the active model's matching voice response before a server summary and use the common native default label when a supported model has no summary. Presentation defaults SHALL NOT issue voice writes or become authoritative selection facts. Other models' voice responses and unconfirmed clone candidates SHALL NOT contaminate the current label.

#### Scenario: Missing summary and changed voice response
- **WHEN** a supported model summary is missing or a matching voice response changes after selection
- **THEN** the native default or current voice is visible and named identically in semantics, while nonmatching model responses are ignored and unknown model defaults are not fabricated

### Requirement: Voice-sheet comparison shall include effective modal composition
Voice-sheet comparison SHALL render the native effective sheet and Flutter current modal container with matching synthetic voice and clone facts. Internal media ownership SHALL be inspected before reference execution and no preview, selection, clone or service operation SHALL be invoked by capture.

#### Scenario: Voice sheet reference capture
- **WHEN** normal or enlarged sheet bounds and content are compared
- **THEN** matching voice names, descriptions, current selection and clone state are used, modal geometry is measured from runtime, and capture is not presented as media or complete business acceptance

### Requirement: Voice sheets shall size to effective content within a scrollable maximum
The common voice sheet SHALL shrink to short content and cap long content at the selected native maximum. It SHALL omit nonnative footer content while preserving state messages, accessible close actions and existing media ownership.

#### Scenario: Short catalog and enlarged long content
- **WHEN** a short voice catalog or enlarged long clone and voice content is presented
- **THEN** short content does not reserve a fixed empty sheet, long content remains scrollable to the last action, and close, preview, selection and retry gates retain their existing semantics

### Requirement: Voice catalog status shall preserve unknown, loading and failed facts
The voice sheet SHALL use the effective native loading and empty messages and error color. Loading and errors SHALL NOT be represented as successful empty catalogs; explicit retries and existing cached rows SHALL remain available according to existing action gates.

#### Scenario: No catalog, failed read and cached refresh
- **WHEN** a catalog is initially loading, finishes without voices, or fails with cached voices
- **THEN** the corresponding native status is visible, retry does not occur automatically, and cached voice rows are not discarded

### Requirement: Clone actions shall share native cost typography across entries
Model and voice-sheet clone actions SHALL share the native scalable points glyph and compact painted button while retaining a minimum 48 logical pixel interaction target and each entry's route guard.

#### Scenario: Enlarged clone cost in the voice sheet
- **WHEN** system text size increases
- **THEN** the cost glyph scales with the label and amount, the action remains readable and reachable, and no clone operation is started by presentation

### Requirement: Original-audio comparison shall isolate device preferences
Original-audio runtime comparison SHALL use matching enabled and level facts with native local state and a Flutter in-memory store. It SHALL reuse effective pages without accessing device preferences or translation/media services.

#### Scenario: Reference toggle and slider feedback
- **WHEN** a capture exercises enabled and disabled original-audio controls
- **THEN** only synthetic local state changes and normal/enlarged page geometry and action reachability are recorded separately from platform media acceptance

### Requirement: Original-audio page shall use the common native surface without redundant idle status
The original-audio page SHALL use the common full-screen native background and omit nonnative permanent success summaries. Genuine loading, saving and failed preference operations SHALL retain feedback and explicit retries.

#### Scenario: Preference write fails after toggling
- **WHEN** a preference write is pending or fails
- **THEN** saving or error feedback remains visible with retry, while idle success adds no extra permanent status row

### Requirement: Original-audio sliders shall render the selected native track geometry
Original-audio sliders SHALL use a constant native track thickness and thumb-sized visual feedback bounds while preserving the 48 logical pixel interaction height, range, discrete steps and disabled behavior.

#### Scenario: Physical slider actions at enlarged text size
- **WHEN** a user taps the discrete level positions or a disabled slider
- **THEN** level changes retain the native 10 percent increments and range, disabled actions produce no change, and enlarged labels remain readable

### Requirement: Identity runtime comparison shall use synthetic effective profile states
Identity comparison SHALL reuse the effective native and Flutter pages with matching synthetic filled, verified and empty profiles. Capture SHALL NOT save, delete, authenticate, clone or access identity services.

#### Scenario: Identity profile and empty-state capture
- **WHEN** normal and enlarged identity content is compared
- **THEN** matching visible fields and verification facts are used and profile geometry is recorded separately from authentication or complete identity business acceptance

### Requirement: Identity profile shall use effective native field spacing and verification presentation
Identity profiles SHALL have one native divider gap before each field and common native verification colors. Profile actions SHALL use the chosen rounded native edit and outlined delete symbols without changing their 48 logical pixel targets, route guards or busy behavior.

#### Scenario: Filled or verified profile actions at enlarged text size
- **WHEN** a filled or verified profile is shown and actions are activated or become busy
- **THEN** no duplicate first-field gap appears, verification stays readable, independent actions retain minimum touch bounds, and busy actions do not invoke callbacks

### Requirement: Identity editor comparison shall use effective native fields
Editor comparison SHALL capture matching synthetic drafts and verified-name locking without invoking save or authentication. Source and runtime evidence SHALL distinguish editor presentation from route behavior.

#### Scenario: Verified draft capture
- **WHEN** a verified identity editor is compared at normal and enlarged text size
- **THEN** the matching name, phone and gender are shown and no identity write occurs

### Requirement: Identity editor shall share native required-field and return interaction
The identity editor SHALL omit the extra inline cancel action, show the native required-name indicator and muted hints, and prevent verified-name focus or editing. Header and system back SHALL first discard an idle edit and restore the authoritative profile, and SHALL exit on the next back. Pending identity operations SHALL block leaving the route.

#### Scenario: Discard edited identity without a write
- **WHEN** header or system back is used while an idle identity draft is open
- **THEN** the draft and errors are discarded without a repository write, the profile remains on the same route, and reopening uses authoritative values

#### Scenario: Back during an identity operation
- **WHEN** an identity write or cleanup is pending
- **THEN** header and system back do not leave the route or discard the pending draft

### Requirement: Identity mutation notices shall match native completion facts
Successful identity saves SHALL use the common native saved message in a short nonblocking notice and preserve existing return behavior. Deleted/default-voice completion SHALL be announced only after local cleanup completes, including successful explicit retries without another delete request.

#### Scenario: Local cleanup fails after an identity delete
- **WHEN** the server delete succeeds but local cleanup fails
- **THEN** the explicit local retry and error remain available and no default-voice completion notice is shown until cleanup succeeds

#### Scenario: Existing identity save returns to settings
- **WHEN** an existing identity save succeeds
- **THEN** the short native notice remains visible after returning and navigation underneath it remains usable

### Requirement: Identity status comparison shall retain matching cached facts
Identity loading and error comparison SHALL reuse actual pages with matching synthetic cached profiles and status text without identity services or writes.

#### Scenario: Cached identity with a failed refresh
- **WHEN** the reference shows a failed identity load
- **THEN** the same cached profile and failure fact remain visible and presentation evidence is kept separate from actual retry acceptance

### Requirement: Identity status shall distinguish loading and mutation failure
Identity status SHALL use the selected native hint-card geometry for cached profiles and mutation feedback. An uncached load SHALL show the selected native standalone loading or failure state without an empty-profile action. Actual load failures SHALL retain explicit retries and cached profile facts; mutation and local cleanup failures SHALL not be reclassified as load failures.

#### Scenario: Failed cached identity refresh
- **WHEN** a cached identity load fails and the user explicitly retries
- **THEN** the cached profile remains visible, one load is retried, and no identity write or deletion is triggered

#### Scenario: Leave during an uncached read
- **WHEN** back is used during a read-only identity load
- **THEN** the route may close and a late result does not repopulate the released route, while writes and cleanup still block leaving

### Requirement: 克隆认证说明须以有效原生组件建立对照
认证说明的正常、大字、未同意、已同意及进入忙态 MUST 使用有效原生与Flutter组件、相同合成状态建立显示证据；原生平台存在的标题与间距差异 MUST 明确记录后选择共同目标，参考回调不得触发身份SDK或业务请求。

#### Scenario: 认证说明参考不触发真实认证
- **WHEN** 使用独立参考入口核对认证说明和同意状态
- **THEN** 页面使用正式展示组件并保持状态相同，下一步与SDK回调为空，截图只作为展示证据

### Requirement: 克隆认证说明须统一原生背景和说明分组
Flutter两端的有效克隆认证流程 MUST 使用共同原生全屏背景；认证说明 MUST 在页面20外边距内增加10横向缩进，三条说明独立排版以保留各自换行边界；同意勾选与开始认证 MUST 保留48可操作区域及忙态禁用，修改不得触发自动认证。

#### Scenario: 大字号独立说明和认证门禁
- **WHEN** 未同意的用户在短屏大字号打开认证说明
- **THEN** 三条说明完整可滚动阅读，开始认证禁用，同意后方可进入填写信息，忙态不得重复进入

### Requirement: 克隆认证阶段须使用有效原生专有标题几何
认证说明、填写信息、采集核验和生成阶段 MUST 采用共同22标题与32有效行区（对齐原生24标注在运行时的字体边界）、40横占位及下8间距；说明正文顶部 MUST 为0、其余认证步骤为12。返回 MUST 保留48操作区域、当前路由与忙态门禁，候选结果标题不得随此批改变。

#### Scenario: 字号放大后认证阶段仍可返回
- **WHEN** 未忙的用户在短屏大字号查看认证阶段
- **THEN** 标题单行省略但语义保留完整文字，返回装饰不放大且点击区域至少48，返回执行原有退出规则

### Requirement: 克隆填写状态须区分预填姓名与已认证锁定
克隆填写的显示对照 MUST 明确区分未取得姓名、已填写但未认证和已认证三个事实，不得将普通预填姓名误当已认证。参考核验 MUST 使用有效原生/Flutter字段组件与同合成状态，禁止触发身份SDK或真实身份提交。

#### Scenario: 空表及已认证字段参考
- **WHEN** 在独立参考包展示空表或已认证合成姓名
- **THEN** 记录两平台原生字段样式与Flutter正常及大字效果，已认证姓名锁定与业务入口门禁分别核验，参考不发身份请求

#### Scenario: 未认证姓名预填与认证锁定提交
- **WHEN** 用户同意说明后进入填写页
- **THEN** 系统 MUST 通过同次身份读取取得姓名与认证事实，普通姓名预填且可修改，已认证有效姓名锁定并在提交中优先使用服务端值
- **AND** 初载失败 MUST 保留说明阶段重试，旧账号晚到结果 MUST NOT 回写，重新开始 MUST 清空旧预填并重新读取，不触发未经授权的真实认证

### Requirement: 克隆填写说明须使用有效原生专有排版
填写页认证说明 MUST 采用专有13字号/21行距/原生次要色和已核对字距，不得误复用导致断行差异的通用副标题。统一排版 MUST 保持原文、认证动作、普通预填和认证锁定事实，系统大字按钮 MUST 保持完整可读和可达。

#### Scenario: 系统大字填写说明
- **WHEN** 用户在正常或两倍字号打开填写页
- **THEN** 认证说明 MUST 使用同一专有排版，输入与操作保持可达，参考对照不得触发真实认证

### Requirement: 克隆说明填写错误须在相关内容之后展示
说明读取错误 MUST 位于授权行后、开始动作前，填写校验错误 MUST 位于身份卡后、提交说明前，统一13/18红色提示且不得重复。UI MUST 保留输入与授权事实，禁止校验失败启动认证SDK。

#### Scenario: 填写校验失败后恢复
- **WHEN** 用户提交无效身份证号
- **THEN** 页面 MUST 保留姓名和号码并在卡后显示单一红色错误，认证准备调用为零，修正后通过现有流程提交

### Requirement: 克隆处理中参考须区分采集核验生成事实
处理中对照 MUST 使用有效原生与Flutter组件，区分采集中、核验中、生成中和错误，不得以静态解释图冒充真实摄像头或认证完成。所有参考业务回调 MUST 为空且不得调用权限、身份SDK、录音、克隆或积分端口；两原生装饰差须明确记录统一目标。

#### Scenario: 合成四态运行对照
- **WHEN** 开发者采集正常和系统大字处理状态参考
- **THEN** 系统 MUST 使用同一合成跟读文案与状态，动画帧差须与布局差区分，不触发真实认证

### Requirement: 克隆处理中错误须单一展示并保留恢复事实
采集、核验和生成失败恢复期间 MUST 保留状态卡，错误 MUST 仅在状态卡内展示一次，保持13/20红色提示和单一错误语义。结果未知的显式同步 MUST 只重读本次结果，不得重新初始化认证、重新采集或重复生成。

#### Scenario: 认证结果未知后同步恢复
- **WHEN** 首次读取认证结果失败
- **THEN** 页面 MUST 显示单一错误和现有显式恢复动作，同步成功后进入候选且初始化/采集次数不增加

### Requirement: 克隆填写处理专有字距须随系统字号缩放
填写提示、认证说明和处理中说明 MUST 使用随TextScaler缩放的专有0.5字距，保持原生自然断行，不得手工换行或改变文案来掩盖差异。UI MUST 保留动态字号、输入锁定、48操作区域、错误恢复及认证端口事实。

#### Scenario: 两倍字号自然断行
- **WHEN** 系统字号从正常放大到两倍
- **THEN** 专有字距 MUST 按实际字体缩放，参考须复核同数据自然断行，所有操作与完整内容仍可滚动到达

### Requirement: 克隆结果参考须使用有效结果入口
克隆结果参考 MUST 使用正式ModelFlow结果组件并覆盖候选、试听、确认忙态及错误，不得以旧完成页代替。合成ready和计费字段 MUST 仅用于隔离展示，参考不得访问音频、账户或计费端口。

#### Scenario: 结果四态同数据比较
- **WHEN** 正常与两倍字比较克隆结果
- **THEN** MUST 核对实际结果卡和操作可达性，并将展示证据与业务执行证据分开记录

### Requirement: 克隆确认忙态须保持明确进行中反馈
克隆结果确认期间 MUST 保持蓝色主动作和进行中反馈、禁止重复确认及退出；禁用重新录制 MUST 保持半透明蓝色，禁用返回 MUST 提供视觉反馈。正常、大字和忙态内容 MUST 可达，认证及计费契约不得改变。

#### Scenario: 等待确认响应
- **WHEN** 合成确认响应尚未完成
- **THEN** MUST 显示确认中反馈，重复确认、重新录制与返回不得产生新请求

### Requirement: 克隆结果播放图形须随字号保持原生表现
克隆结果试听 MUST 使用匹配原生播放/停止形状的单色图形并随字号缩放，保留40圆形视觉和48触控区域；保存认证录音结果复选框 MUST 使用20可见尺寸及结果主色。说明授权复选框不得被结果样式修改。

#### Scenario: 试听状态在两倍字下展示
- **WHEN** 同数据结果页从待播放切到播放中
- **THEN** MUST 展示随系统字号变化的单色播放/停止图形，音频调用门禁和忙态不得改变

### Requirement: 克隆阶段验收须覆盖来源返回与状态接线
克隆阶段验证 MUST 在冻结源码下执行跨模块里程碑回归，并通过普通保留安装验证合成结果返回来源及模型接线；不得将合成端口或iOS仅构建称为真实认证、音频、计费或双端运行验收。

#### Scenario: 普通合成克隆确认后返回
- **WHEN** 已明确隔离的普通演练确认合成候选
- **THEN** MUST 回到来源并核对模型状态，保留安装数据且恢复系统字号

### Requirement: 克隆正式结果背景须与有效原生保持一致
正式克隆候选及结果错误页 MUST 使用F8F9FC纯色背景，说明/填写/处理页 MUST 保留其原生背景目标。组件参考与正式route背景 MUST 分别核对，不得以局部截图代替正式接线。

#### Scenario: 从认证进入结果页
- **WHEN** 普通合成认证进入候选
- **THEN** MUST 以普通route截图确认纯色结果背景，状态及操作门禁保持

### Requirement: 联系人列表参考须区分记录展示与系统能力
联系人列表参考 MUST 复用正式列表组件并核对长姓名、副标题、分隔和已授权空态；合成参考不得读取真实通讯录、发起拨号或权限请求。列表显示、系统权限及详情动作 MUST 分开验证。

#### Scenario: 同数据列表与已授权空结果
- **WHEN** 正常与两倍字号核对合成联系人
- **THEN** MUST 使用相同姓名号码及已授权事实，记录未关闭差异而不得宣称完整系统能力通过

### Requirement: 联系人列表授权空态与行展示对齐
Flutter MUST 将有效本机联系人姓名和副标题呈现为单行省略，副标题包含号码和本机通讯录联系人说明，最后一行不显示分隔线。已授权且读取成功的空态 MUST 显示居中的暂无联系人，并保留下拉刷新；权限和读取错误 MUST 保留各自操作。

#### Scenario: 大字长姓名与空态刷新
- **WHEN** 系统字号放大且列表存在长姓名，或授权成功后列表为空
- **THEN** 行保持单行可点击进入详情，空态不添加额外刷新按钮但仍可下拉触发刷新，读取失败与权限操作不被空态替换

### Requirement: 联系人详情参考来自有效列表入口
Flutter MUST 以两原生实际本机联系人列表打开的详情页面核对档案、备注和底部动作，并单独记录备注删除与头像阴影的平台源差。

#### Scenario: 合成详情参考
- **WHEN** 核对空备注、加载和已存备注详情展示
- **THEN** 使用相同合成姓名号码和本机说明，正常及放大字号核对，展示参考不得触发真实联系人、拨号或备注服务

### Requirement: 本机联系人详情档案说明
Flutter MUST 在本机联系人详情号码下方显示两原生有效入口提供的本机通讯录联系人说明。

#### Scenario: 列表进入详情
- **WHEN** 从本机联系人列表进入详情
- **THEN** 姓名、号码、本机说明按原生顺序展示，备注加载、编辑及详情返回流程保持有效

### Requirement: 联系人备注删除动作顺序
Flutter MUST 对已存联系人备注保留删除能力，并采用有效iOS详情页删除位于编辑左侧的统一动作顺序。

#### Scenario: 已存备注动作
- **WHEN** 详情存在有效目录记录
- **THEN** 删除在编辑左侧，忙态不得重复操作；删除取消或失败保留详情，成功按既有规则返回列表

### Requirement: 联系人详情返回栏统一目标
Flutter MUST 采用有效iOS详情56高顶栏和固定30返回字形，保留48点击区域、返回联系人语义及正文动态字号。

#### Scenario: 大字号详情返回
- **WHEN** 用户放大字号并进入联系人详情
- **THEN** 返回栏保持统一高度，正文随系统字号变化且可滚动，点击返回只导航一次

### Requirement: 联系人备注操作可见尺寸和可达性
Flutter MUST 对齐备注编辑按钮正常60×36可见背景和14圆角，并保留至少48点击区域与字号放大时文字可读；备注副标题按有效iOS单行省略。

#### Scenario: 正常与大字备注操作
- **WHEN** 在详情编辑或删除已有备注
- **THEN** 正常可见尺寸对齐且点击有效，放大字号不裁切操作，忙态仍阻止编辑删除

### Requirement: 联系人备注动作独立语义
Flutter MUST 为详情编辑和删除提供独立具名按钮语义，范围对应各自点击区域，忙态不得提供可用点击。

#### Scenario: 无障碍操作备注
- **WHEN** 在普通App通过无障碍选择编辑或删除
- **THEN** 可按名称单独定位操作，不与备注标题正文合并，点击和禁用规则保持一致

### Requirement: 联系人备注编辑四态运行核对
Flutter MUST 核对有效原生备注编辑的空草稿、已有草稿、保存忙态和失败展示，使用合成数据且不得以展示参考触发真实备注请求。

#### Scenario: 编辑弹层合成参考
- **WHEN** 核对正常和放大字号编辑弹层
- **THEN** 展示同样草稿、计数、忙态和失败反馈，输入、取消、保存真实交互须另经正式route验证

### Requirement: 联系人备注编辑统一可见尺寸
Flutter MUST 对齐正常四行108输入高度、18圆角浅灰边框及保存36可见背景，保留48点击区域、动态字号和保存中白色文字。

#### Scenario: 保存忙态与大字号编辑
- **WHEN** 用户编辑或等待备注保存
- **THEN** 输入与动作正常尺寸对齐，字号放大仍可读可达，忙态禁止重复提交且失败保留草稿

### Requirement: 联系人备注已接受保存回执
Flutter MUST 在当前联系人的备注已被后端接受且编辑弹层关闭后显示“已保存联系人备注”短提示，取消、失败、不匹配或过期结果不得显示成功。

#### Scenario: 备注保存结果反馈
- **WHEN** 保存结果返回并匹配当前草稿与有效详情
- **THEN** 关闭编辑并显示可自动消失的成功提示，不阻挡返回操作；其他结果继续按既有规则保留草稿或退出

### Requirement: 联系人Skill选择统一弹层
Flutter MUST 按有效原生展示内容驱动的Skill弹层、具名关闭、单行标题两行描述和列表分隔；首加载仅在无可用项时显示加载文案，已有项刷新中仍可选。

#### Scenario: 联系人技能选择与关闭
- **WHEN** 从联系人详情发起任务并选择或关闭Skill弹层
- **THEN** 保持有效技能和版本过滤、联系人上下文与单次导航，取消不创建任务，正常与大字号内容均可达

### Requirement: 联系人Skill字体自然断行
Flutter MUST 对齐Skill专有文字随系统字号缩放的字距，并按原生单行标题和两行说明自然省略，不插入硬换行或裁切字号。

#### Scenario: 大字号技能列表
- **WHEN** 系统字号放大并浏览技能
- **THEN** 标题与说明自然断行省略，列表可滚动至最后一项并可取消或选中

### Requirement: 联系人Skill关闭完整语义
Flutter MUST 为Skill弹层关闭提供独立“关闭Skill选择”按钮语义，不能仅暴露装饰字形，保持48点击区域及取消行为。

#### Scenario: 通过无障碍关闭Skill弹层
- **WHEN** 用户按操作名称选择关闭
- **THEN** 可独立定位并关闭弹层回到联系人，不选择技能或创建任务


### Requirement: 任务会话顶部统一品牌和关闭动作
任务会话顶部 SHALL 以有效 SingleFlowHeader 和 AIAssistantViewController.pageHeader 为参照，采用统一固定30字号品牌与52关闭热区内40圆形可见表面，保持正文动态字号、完整品牌语义与现有关闭生命周期。

#### Scenario: 窄屏放大字号关闭任务会话
- **WHEN** 用户在窄屏两倍字号从联系人选择有效技能进入会话
- **THEN** 品牌完整显示，关闭任务对话具有独立按钮语义且可点击，返回原联系人详情
- **AND** 展示修正不发送消息或创建真实任务


### Requirement: 任务会话共同背景
任务会话 SHALL 使用两原生共有F1F4FA至E8EDF5纵向背景，在SafeArea外统一绘制，正文和输入区不得以额外白底遮住背景。

#### Scenario: 关闭会话恢复原页面
- **WHEN** 用户正常或放大字号从联系人进入会话后关闭并返回首页
- **THEN** 会话完整body保持共同背景及可见关闭表面，输入和关闭可达
- **AND** 返回后不残留会话背景或系统栏状态


### Requirement: 会话阶段须区分完成当前与未来
阶段展示 SHALL 将已越过阶段显示绿色标签与绿色渐变、当前阶段显示蓝色标签与蓝色渐变，未来阶段保持灰色且无填充，采用统一原生色阶；既有领域进度投影不得因展示改变。

#### Scenario: 实际会话阶段前进
- **WHEN** 已有消息投影使当前阶段从需求确认进入执行通话
- **THEN** 前两阶段展示绿色，执行通话展示蓝色，执行结果展示灰色
- **AND** 当前阶段辅助技术语义保持，绿色不得被视为拨号授权或成功回执


### Requirement: 会话顶部几何须以实际显示复核
会话顶部 SHALL 在字体30保持的前提下按正常字号原生可见文字边界校准行框及阶段区域边距，保留完整语义、动态正文及紧凑视口滚动，不以相同fontSize替代实际运行对照。

#### Scenario: 正常字号几何校准后放大字号
- **WHEN** 正常字号完成品牌、副文与阶段条实际位置复核后切换放大字号
- **THEN** 固定品牌完整、副文可读且关闭可达，阶段语义和实际进度投影保持
- **AND** Android原生放大品牌换行与统一固定品牌的差异明确记录

### Requirement: 空会话待机波形
空会话待机展示 SHALL 采用有效两原生共同的58框、4柱宽、1.25间距与九柱对称高度及蓝色，使用统一淡柔光；不得改变发送、附件或语音状态机。

#### Scenario: 没有消息附件且没有思考反馈
- **WHEN** 会话正文为空并符合既有待机展示条件
- **THEN** 显示完整对称待机波形，放大文字不拉伸波形
- **AND** 有消息、附件或思考反馈时沿用既有隐藏条件，不触发录音或播报

### Requirement: 会话模型胶囊可见与点击尺寸分离
会话模型胶囊 SHALL 采用共同12字号、上下6横12内边距、18圆角及原生色边影，内容自适应正常约28可见高度，保留透明点击扩展及完整模型语义。

#### Scenario: 放大字号并打开模型
- **WHEN** 用户放大字号后按模型胶囊或其透明点击扩展
- **THEN** 只调用一次原有模型入口，长标题保持完整辅助技术语义
- **AND** 切换输入模式或关闭模型页不清除尚未提交草稿

### Requirement: 语音识别等待三点反馈
语音结束识别等待 SHALL 复现两原生共有三白点、5直径4间距、900ms相位错开150ms的4抬升与透明度反馈，尊重减少动态效果设置，不改变识别状态机。

#### Scenario: 等待识别再次按压
- **WHEN** 既有状态为finalizing或stopping且用户重复按压
- **THEN** 保持识别中禁用语义和三点反馈，不触发新采集/提交/取消
- **AND** 开启减少动态效果时动画停止，控件释放后不保留活动ticker

### Requirement: 按住说话显示共同原生反馈
按住说话 SHALL 显示三层1500ms淡光圈及原生提示胶囊，上滑58切换取消红色和松手取消，取消后已取消提示1200ms自动消失；减少动态效果停止循环动画，反馈不接收触控。

#### Scenario: 活动手势转入外部识别等待
- **WHEN** pointer尚未释放但权威状态已进入finalizing或stopping
- **THEN** 清理UI活动指针和取消反馈并展示禁用等待，后续旧up不得再次release或cancel
- **AND** 不改变当前识别轮次或提交协议

#### Scenario: 上滑取消与正常释放
- **WHEN** 当前有效按压上滑并释放取消，或在阈值内正常释放
- **THEN** 每次仅调用已有对应回调一次，提示与光圈显示当前真实交互状态
- **AND** 关闭控件后移除反馈timer及ticker，不遮挡其他输入控件

### Requirement: 输入模式切换采用共同六点圆图标
语音输入区 SHALL 用两原生共有的描边圆内六点表达切换文字，并使用原生添加图标，保持独立热区和操作语义。

#### Scenario: 切换输入模式保留草稿
- **WHEN** 用户点击文字切换或添加内容图标及透明点击扩展
- **THEN** 只调用相应既有动作一次，不触发麦克风或消息发送
- **AND** 草稿与减少动态效果规则保持，长按语音依旧由独立控件处理

### Requirement: 语音输入按钮共享原生行位置
语音输入行 SHALL 保持麦克风水平居中，按共同原生布局定位两侧图标中心，48透明点击扩展不得改变可见图标位置或相互遮挡。

#### Scenario: 短屏点击侧按钮外缘
- **WHEN** 用户在短屏大字号点击添加或切文字按钮的透明外缘
- **THEN** 仅触发对应动作一次，不触发居中麦克风或另一侧操作
- **AND** 取消指针不调用业务动作，模型入口与尚未提交草稿不变

### Requirement: 首次开场展示使用统一助手气泡
空会话已有首次开场文案 SHALL 复用统一助手消息气泡样式，保留现有展示门禁，不将仅展示文案新增为服务端历史事实或发送请求。

#### Scenario: 开场后出现实际消息
- **WHEN** 空会话显示开场并随后收到实际消息、附件或思考状态
- **THEN** 沿既有空态规则移除独立开场展示，不与实际历史重复
- **AND** 页面显示不改变messages、TTS轮次或任务提交协议，短屏可滚动读取完整文案

### Requirement: 首条消息布局切换保持可见定位
会话从空态切到反向消息列表 SHALL 在新布局完成后显示首条消息尾部，回空态回到开场顶部，滚动展示不得改变消息事实。

#### Scenario: 长开场已滚动后收到首条消息
- **WHEN** 用户在短视口滚动空态开场后收到首条消息
- **THEN** 新反向列表定位到消息尾部且无需用户反向滚动寻找
- **AND** 快速切回空态或离开页面时旧布局回调不得访问已销毁滚动控制器

### Requirement: 完整会话参考复用正式布局结构
会话整页参考 SHALL 复用有效原生Header与Stage、Flutter实际ConversationPage的完整布局结构，合成状态使用空业务回调，不以居中控件容器作为整页验收证据。

#### Scenario: 获取开场完整会话对照
- **WHEN** 相同AVD与字号捕获合成开场原生和Flutter页面
- **THEN** 记录完整页标题、状态、波形、消息、模型和输入区的位置差异
- **AND** 参考过程不调用采集/业务SDK或写入真实历史，统一目标及系统差异分别记录

### Requirement: 会话波形与短消息共用原生层级
会话 SHALL 在正常视口将待机波形固定于状态下方、与可滚动消息分离；短线程置顶，消息内边距遵循统一原生目标，受限视口保留滚动可达回退。

#### Scenario: 标准屏幕大字显示已有消息
- **WHEN** 标准竖屏显示开场或短历史并放大字号
- **THEN** 副标题保留、待机波形仍在状态下方，消息不会因反向列表压到输入区
- **AND** 滚动长历史不会移动正常视口波形，展示不改变消息事实或触发音频

#### Scenario: 短屏键盘及思考反馈
- **WHEN** 键盘或短视口使固定内容过多，或会话正在思考
- **THEN** 受限内容可滚动而输入/关闭仍可达，思考时不显示待机波形
- **AND** 初次布局切换继续显示消息尾，退出不留下滚动回调

### Requirement: 会话状态行使用双原生共同样式
会话状态 SHALL 使用共同12粗体2196F3、8点圆点与6点间距，并按实际文字行框校准后续波形位置。

#### Scenario: 正常和放大字号状态显示
- **WHEN** 会话状态文字更新或字号放大
- **THEN** 状态行采用共用原生色与间距，保留完整辅助技术语义和既有状态投影
- **AND** 行框校正不改变语音轮次或发送门禁

### Requirement: 会话动态波形须由现有活动状态驱动
会话波形 SHALL 用现有录音与回复活动状态驱动蓝色监听和绿色回复动画，共用经核对的动画曲线，空闲保持固定；不得把装饰波形当实际音量或启动音频。

#### Scenario: 录音回复和思考转换
- **WHEN** 既有状态在recording、回复活动和思考之间转换
- **THEN** 监听优先蓝色动画、回复活动绿色动画，只有思考时隐藏待机图
- **AND** 转回空闲不留动画ticker，展示不修改采集或播报生命周期

#### Scenario: 减少动态效果和离开页面
- **WHEN** 系统开启减少动态效果或波形离开页面
- **THEN** 停止循环动画，活动颜色仍表达状态，销毁后不留下timer或ticker

### Requirement: 新消息和键盘展开定位会话尾部
会话 SHALL 在新增消息或末条文字变化后呈现最新内容，在键盘展开完成布局后定位消息尾部；同内容的普通展示状态刷新不得打断历史阅读。

#### Scenario: 阅读旧历史后收到新消息
- **WHEN** 用户已滚动读取历史，随后新增消息或末条文字更新
- **THEN** 消息列表定位最新内容，减少动态效果时不启动滚动动画
- **AND** 模型名称或语音状态刷新不触发定位，业务消息事实不变

#### Scenario: 键盘展开及退出
- **WHEN** 键盘展开减少消息视口或页面在定位回调执行前关闭
- **THEN** 展开后最新消息可达，关闭后没有晚到滚动或ticker错误
- **AND** 收键盘不重置历史阅读位置，草稿和发送规则保持

### Requirement: iOS局部运行参考隔离业务SDK
iOS局部运行参考 SHALL 复用实际原生与Flutter控件并隔离业务SDK、账号和权限，单独标记证据范围。

#### Scenario: 正式模拟器宿主缺少真机SDK切片
- **WHEN** 纯控件可独立编译并取得原生与Flutter运行对照
- **THEN** 使用独立reference身份，记录固定源及SDK、同模拟器和局部布局差异
- **AND** 不覆盖正式App，不将局部参考当作完整流程或业务SDK验收

### Requirement: 普通消息正文不得继承无依据的字距
普通语音业务消息 SHALL 使用有效原生共同14点字体和22点行框、默认字距，避免Material默认字距改变断行；字体差异必须按运行证据处理。

#### Scenario: 正常和放大字号的普通消息
- **WHEN** 显示普通用户或助手消息
- **THEN** 正文显式使用共同字距和行框，保留文字选择与完整语义
- **AND** 不改变工具、候选、确认和回执的专用展示及业务事实

### Requirement: iOS普通消息排版适配须隔离业务
iOS普通消息 SHALL 用纯展示平台适配复用系统字体排版，保持共同气泡与业务事实；平台测量不得调用账号、采集、网络或存储。

#### Scenario: 系统字体与Flutter回退字体度量不符
- **WHEN** 相同条件的运行证据证明默认Flutter字形度量不同
- **THEN** iOS使用经独立运行验证的系统文本渲染，保持只读选择、统一字体层级、完整语义和业务动作
- **AND** Android/Web保留共同Flutter展示；原生文本不可修改或启动输入键盘

#### Scenario: 快速更新和通道不可用
- **WHEN** 文本、字号或约束变化，或测量失败、晚到及页面销毁
- **THEN** 只应用当前布局结果，失败保留可读Flutter展示，关闭后不更新已销毁widget
- **AND** 不保留跨账号的全局文本缓存，不宣称失败fallback已达到原生视觉验收

### Requirement: 普通消息使用共同原生行间距
普通消息列表 SHALL 使用有效双原生共同10点气泡间距，字号缩放不重复放大外边距，平台排版适配不改变消息事实。

#### Scenario: 连续短消息和放大字号
- **WHEN** 显示连续用户或助手普通消息，或系统放大字号
- **THEN** 相邻气泡可见装饰框之间保持10点间距，正文仍按既定字号与行框缩放
- **AND** 专用工具、候选、确认和回执卡须分别核对，不因普通气泡微批改变其布局或操作

### Requirement: 工具与候选展示更新定位最新内容
会话 SHALL 按可见普通文字、工具展示和候选内容的值识别更新，不依赖对象身份或只观察末条文字。

#### Scenario: 原位更新工具结果或候选详情
- **WHEN** 已显示消息的工具body/result/status或候选label/detail改变而末条文字不变
- **THEN** 列表按既有尾部定位规则呈现最新内容，工具或候选业务动作不自动执行
- **AND** 等值对象重建不重置历史阅读；专用确认/回执/附件另行核对

### Requirement: 工具候选和单路确认共用会话外间距
工具、候选及单路确认消息 SHALL 遵循有效双原生共同10点row间距，保留卡内布局和业务动作边界。

#### Scenario: 混合消息列表
- **WHEN** 工具、候选和单路确认卡与普通消息相邻
- **THEN** 三类卡外间距保持10点，字号只影响内容而不重复放大外间距
- **AND** 候选只提交对应ordinal且防重复，确认卡不新增执行入口；运行视觉验收独立记录

### Requirement: 极短普通消息保持统一气泡尺寸
普通消息 SHALL 在既定iOS宽比共同目标上使用44点最小气泡宽度，Android与iOS Flutter共用，专用卡不继承这一尺寸。

#### Scenario: 单字符和不足44点的可用空间
- **WHEN** 显示单字符普通消息或可用最大气泡宽度小于44点
- **THEN** 普通气泡按正文自然宽度收缩且正常空间至少44点，受限空间最小宽度不得超过其最大约束
- **AND** 保留文字选择、完整语义与角色方向，原生Android未设置该最小值的差异明确记录

### Requirement: iOS完整Flutter演练运行须保持隔离
iOS完整Flutter UI运行参考 SHALL 复用已存在的纯合成业务端口和生产页面，独立身份仅注册必要纯UI通道，不绕过正式SDK验收。

#### Scenario: 独立宿主验证导航和键盘
- **WHEN** 正式模拟器因真机SDK切片无法编译而纯Flutter页面可运行
- **THEN** 以独立reference身份验证完整Flutter导航、系统键盘、合成草稿与返回，使用无API/内存合成端口
- **AND** 不覆盖普通App、不执行真实短信/语音/认证/外呼/收费，结果只标Flutter运行而非原生整页或SDK通过

### Requirement: 确认卡原位展示更新必须跟随会话尾部
Flutter MUST 根据单路与批量确认卡实际展示值识别内容更新，以本地不可变按值快照复用会话尾部定位；MUST NOT 用模型identity、执行源参数或全局缓存判断显示变化。

#### Scenario: 确认目的或批量规则原位更新
- **WHEN** 已有确认消息的实际展示内容变化而末条id和文字不变
- **THEN** 布局稳定后按照既有动效及减少动态规则定位尾部
- **AND** 等值重建和非展示sourceSpec变化保留历史阅读位置，不发送消息或发起执行；内部展开与回执独立验证

### Requirement: 批量确认面板必须共用原生标题和字段结构
Flutter MUST 共用批量确认白色面板43点正常标题结构、1点分隔线及14横向/12纵向内容内边距，大字体按内容增高；绿色摘要及字段按已选共同原生样式呈现。

#### Scenario: 普通或放大字体阅读确认面板
- **WHEN** 用户查看摘要、执行规则、联系人检查或积分说明
- **THEN** 使用共同圆角、边框、标题/状态与compact或普通字段样式，受可用宽度限制且不挤压大字体
- **AND** 样式改变不影响联系人展开、草稿、确认与计费规则；原生固有差异明确记录、真实整卡另验

### Requirement: 批量确认局部参考必须使用实际原生控件
隔离批量确认参考 MUST 直接链接固定原生控件与纯策略，Flutter使用生产widget，以同一合成内容和明确共同宽度目标运行；MUST 与业务SDK及正式整页验收区分。

#### Scenario: 同内容观察批量面板
- **WHEN** 启动明确iOS模拟器的独立batch参考
- **THEN** 记录实际源hash/身份并观察稳定标题、分隔线、字段及面板间距
- **AND** 不调用业务服务，原生固有配色/宽比差异不得伪称相同，未完成观察不能勾选验收

### Requirement: 批量确认状态必须贴齐标题栏右内边界
Flutter MUST 让状态区域填满其弹性宽度并右对齐，使状态显示在14点右内边界；标题与状态仍能按可用宽度换行。

#### Scenario: 双平台正常或大字查看状态
- **WHEN** 批量面板显示等待确认或其他状态
- **THEN** 状态Text布局右边界距面板右边界14点，不在中间留下末尾空闲
- **AND** 修正使用实际运行对照和自动边界检查，不影响业务决策或发送

### Requirement: 批量确认有效说明必须复用普通助手气泡
Flutter MUST 在批量确认面板之后以现有普通助手气泡呈现非通用说明，内部相邻面板/说明及后续消息实际外间距为10点；MUST 去除叠加的整卡尾部空白。

#### Scenario: 带或不带有效说明的确认混排
- **WHEN** 批量确认后出现普通消息，或确认包含有效助手说明
- **THEN** 相邻实际装饰框间隔10点，说明复用普通字体、宽比、选择和单次语义
- **AND** 通用说明继续隐藏，无额外执行/发送，普通消息与工具布局回归验证；真实局部运行和整页验收分开记录

### 真实系统键盘尾部定位 H27

V4W冻结5e70752全量3210通过/1跳过（7分33秒），Android保留安装成功；iOS完整合成流程037发现阅读历史后打开系统键盘未归尾，V4W整体保持未完成。Scaffold消费body的MediaQuery底部inset，既有内部模拟inset测试遗漏实际路径。新增真实Scaffold/viewInsets专项先复现；timeline以WidgetsBindingObserver监听所属FlutterView键盘指标增长，保留原MediaQuery路径、减小inset不归尾和销毁epoch保护。仅滚动presentation与独立测试微批，不改业务。定向会话验证、analyze/OpenSpec后重建隔离iOS shell实际复验；刚结束全量不重复，不将其声称覆盖H27。

### Android合成批量流程输入 V4X

Android现有保留数据ADB演练输入不能可靠输入中文口令，未将其作为业务缺陷或批量流程通过。仅tool in-memory ShellConversationPorts增加精确ASCII别名UI_BATCH_CONFIRM，映射现有同一合成确认fixture，不进入lib或真实业务，不新增网络/执行能力。tool/已有ports测试两文件微批验证中文与ASCII都生成同样pending confirmBatchTask、没有拨号。随后最新普通preview构建保留-r安装，正常/两倍字批量展开、阅读历史、键盘归尾、模型草稿及返回；恢复font1与首页，核验首次安装不变。复用刚结束全量范围与H27定向，不重复全量，不把合成流程作为业务SDK或原生整页验收。

### 批量联系人检查卡 H28

固定两原生均统计18bold数字分类色172033/187A3A/8A4F00、10bold灰标签，称呼11bold且靠右，issue上下9/横10，展开12bold左对齐（iOS最小44、Android自然11竖padding）。Flutter统计全部默认黑、称呼regular居中余白、issue10竖padding、展开默认14居中。仅contacts组件/独立专项两文件微批共享原生参数，保留已批准48热区（比iOS44明确适配），按钮前9间隔、12bold/16行高/左对齐；recipient边框使用foreground避免吞掉10内边距，名称202938同iOS，长字自然换行，detail10/14与既有展开状态保留。四平台字号专项先复现颜色/称呼右边界/按钮位置，定向确认/滚动/跨页、analyze/OpenSpec；iOS隔离batch补相同synthetic audit与原生actual card局部截图另微批，不声明正式整页或业务SDK闭环。

### 批量统计块行高 H29

041/042实际同条件统计块约52与58点，Flutter继承主题默认Text行高导致18数字/10标签扩大。统一数字22点、标签12点正常行高（随TextScaler同比扩大）及既有上下9，正常目标52、两倍字86，不固定容器高度、不压缩字；选iOS自然紧凑统计层级作为两端共同目标。仅contacts/既有layout专项两文件微批，用实际metric容器高度先复现，并保持四字号展开/边界和会话定向；重新构建Flutter隔离batch对照同原生041，明确仍存在已选Android行/摘要差异和字体栅格差异，不能称全像素一致。H28行数记录更正为源184/测试106（均<500），前次173/116为错误手填数，不影响检查结论。

H29补充：320窄屏两倍字原始联系人标签自然两行，86仅单行基准，实际目标110；修后正常两例通过，大字两例110不应判布局缺陷，修正专项预期保留换行，不改业务/挤压字号。

### iOS实际批量单项回执对照 V1O

扩展隔离参考--result，与batch/shell/short/dynamic互斥，独立native-result/flutter-result身份。原生链接固定actual AIBatchCallItemResultView、纯presentation/计费展示依赖及Masonry，不注册业务SDK，recordingHandler/展开回调nil；Flutter actual BatchReceiptItemCard同纯合成SUCCESS/联系人/合成结果/业务结果确认参加/事项字段，无transcript/callId/计费/录音操作。宿主308宽（共同目标）、top200+原生外层12间距，Flutter实际owner既有margin12；tool script/Host/Flutter入口三文件微批，source hashes覆盖参与源。两实际编译和稳定图逐张核对状态pill、header、字段、边框/内距、缺失或重复；仅纯UI局部参考不称正式整页/SDK验收，analyze/脚本语法/OpenSpec，不重复正式双端或全量，差异另开小批修复。

### 批量单项回执展示范围 H30

V1O044/045实际同payload确认Flutter显示额外purpose行；固定Android BatchPlusCallResultItem与iOS actual item均heading=name fallbackphone、summary=headline/detail/status，businessResult仅状态pill，不另列phone/detail或通用receiptFields。仅BatchReceiptItemCard去上述额外行，保留原始domain/facts/普通单路/textformatter；foreground边框保持10点实际内距（Container现隐式11）。共同Android紧凑右侧pill保留，iOS实际pill布局差异已记录不复制两套样式。独立专项正常/两倍字双主题验证不存在重复电话/详情/原始字段表、summary/phone fallback及business状态仍可见、实际10内距，受影响回执/录音/独立展开/业务状态/跨页定向+analyze/OpenSpec，重建Flutterresult稳定046对照044；不动HTTP/结算/播放，不重复全量/普通双端包，原生整页仍待验。

### Android实际批量单项回执对照 V1P

在既有隔离reference新增scene=batch-result，直接调用固定原生internal BatchPlusCallResultItem同模块组件，不复制body；合成与V1O相同SUCCESS/联系人/摘要/businessResult+purpose，无callId/transcript/billing，recording route准入为null不创建业务端口。Flutter同场景直接生产BatchReceiptItemCard，共同308/18side/top200，背景仅宿主不用于整页验收。nativefixture/Activity/Flutterfixture三文件微批，随后Flutter入口单文件接线；新tool默认<500。原生现有JDK11/固定Gradle显式init、纯Application/隔离id/配置String清空/8业务权限移除，Flutter固定3.32/已验JDK21独立id；保留-r不动普通dev，正常/两倍字稳定实际截图，最后font1/普通首页和首次安装时间核验。只局部native与Flutter证明pill/字段，重用H30定向、analyze/OpenSpec/两reference编译，不重复全量/普通正式构建，不称业务SDK或原生正式流程验收。

### Requirement: 批量单项状态自然宽度
Flutter批量单项回执 MUST 按内容分配状态标签宽度，保留左侧剩余空间与右侧内距，长状态自然换行。

#### Scenario: 两倍字号四字业务状态
- **WHEN** 308点卡片展示合成联系人、合成结果：已完成和确认参加，字号为两倍
- **THEN** 状态保持单行，不因固定左右比例提前换行
- **AND** 长状态仍在可用宽度一半以内自然换行，不截断或缩小字体

### Requirement: 批量通话记录共用原生列布局
Flutter批量记录 MUST 使用两原生共同的60点说话人列、8点正文间隔、11点行间距及5/6上下内距；普通单路记录不受批量样式修改影响。

#### Scenario: 展开合成批量记录
- **WHEN** 展开含AI与对方两句记录的批量结果
- **THEN** 说话人使用11点heavy及16点行高，正文13点及21点行高
- **AND** 大字号自然增高，收起与原位数据更新保留既有规则，不触发录音播放

### Requirement: 批量记录首末字行不额外扩张
Flutter批量记录 MUST 核对实际文字布局，去除可选择编辑控件带来的额外首末行leading，不通过缩小字体或固定文本容器高度实现对齐。

#### Scenario: 同条件记录行高核对
- **WHEN** 合成普通及两倍字号记录与原生配对
- **THEN** 逐行核对实际边界和第二句起点，多行正文保留自然换行、21点行间规则及可选择能力

### Requirement: 批量回执与文档原位可见更新归尾
Flutter MUST 将批量回执和用户文档的可见内容纳入会话变化判断，并沿用既有归尾行为；隐藏业务参数变化 MUST NOT 打断历史浏览。

#### Scenario: 同一消息内容原位更新
- **WHEN** 同id和相同普通文字的批量回执状态、摘要、转写、结算展示或文档文件信息发生变化
- **THEN** 不依赖对象身份识别可见变更并归尾
- **AND** 相同展示值重建对象或隐藏业务字段变化保持历史位置，本地展开生命周期不变

### Requirement: 单路回执原位可见更新归尾
Flutter MUST 将单路回执实际状态、正文、字段、转写和结算展示纳入会话变化判断，不使用对象身份或整份隐藏元数据判断。

#### Scenario: 单路业务状态改变
- **WHEN** 同一消息回执的业务语义状态、展示正文或结算发生变化
- **THEN** 识别可见变化并沿用既有归尾行为
- **AND** 无可见影响的执行身份和隐藏元数据变化保留历史浏览位置，不触发播放或修改业务事实

### Requirement: 会话结果阶段状态点完成色
Flutter MUST 在结果阶段使用共同绿色状态点，其他阶段保留蓝色，状态文字继续蓝色；此展示 MUST NOT 改写业务结果或增加操作许可。

#### Scenario: 从结果回到新需求阶段
- **WHEN** 会话展示结果阶段后进入新需求阶段
- **THEN** 状态点从绿色恢复蓝色，装饰点不重复读屏文本

### Requirement: 上传资料卡边框保留实际内距
Flutter MUST 使用不增加布局内距的资料卡边框，标题、文件图标的实际横向内距为14点；文件正文维持自然换行和原有信息。

#### Scenario: 正常与大字号资料卡
- **WHEN** 同卡显示长文件名、已解析字数和截断提示
- **THEN** 保留14点横向内距、34点图标和10点正文间隔，分割线全宽且大字号自然增高
- **AND** 不触发文件读取或上传，不缩小字体掩盖布局差异

### Requirement: 资料卡标题和数量自然分配宽度
Flutter MUST 让资料卡数量保持右对齐并按内容分配至多一半宽度，标题使用剩余宽度自然换行，不缩小或截断字体。

#### Scenario: 两倍字号资料卡标题
- **WHEN** 上传状态标题和文件数量无法按原宽度同排展开
- **THEN** 标题自然换行、数量保留尾距14点，解析标题切换不改变对齐规则

### Requirement: 资料卡共同字间距独立于主题
Flutter MUST 显式采用共同资料卡0.5点基础字间距并按每种文字字号的缩放倍率增长，两平台共用同一规则，不继承环境主题字间距。

#### Scenario: 大字号和主题切换
- **WHEN** 资料卡使用正常或两倍字号，环境主题文字字间距发生变化
- **THEN** 标题、数量、图标和文件信息保持共同tracking和自然换行，不缩小字体或改变原始内容

### Requirement: 餐厅候选保留原生业务展示字段
Flutter MUST 将原生餐厅候选的评分、人均、菜系、商圈/距离、营业状态及时间投影为共同紧凑卡；没有餐厅字段的候选继续通用卡，不推断营业或评分。

#### Scenario: 餐厅候选与大字号
- **WHEN** 服务端候选带餐厅分类或原生高级字段
- **THEN** 显示共同评分/价菜系和位置营业信息，未知评分为“--”、未知营业无状态，长文自然换行
- **AND** 沿用编号选择、接受后选中及旧轮次门禁，不增加业务动作，新展示值原位变化纳入既有会话归尾判断

### Requirement: 候选编号与评分行高保持可读
Flutter MUST 保持正常字号26点编号圆，大字号随文字行高增长，编号不裁切；餐厅评分12点文字使用16点基础行高。

#### Scenario: 两倍字号候选
- **WHEN** 通用或餐厅候选使用两倍字体
- **THEN** 编号完整位于圆内，评分行高不会因继承11点详情样式额外增长，内容仍自然换行且沿用原选择门禁

### Requirement: iOS候选对照使用真实组件
候选验收 MUST 使用固定UIKit真实候选组件及Flutter生产组件，同合成数据和宽度记录实际选择与重置状态，不能用复制实现或静态参数替代运行证据。

#### Scenario: 四状态候选参考
- **WHEN** 运行隔离iOS候选参考
- **THEN** 初始、第一项选中、第二项防重及重置分别记录当前UI与原图
- **AND** 回调只改变本地示例状态，不执行Agent、网络或外呼

### Requirement: 候选标题保留多行节奏并收紧首尾
Flutter候选标题 MUST 保持15点字号、24点基础多行基线间距，并移除首尾额外height leading，不通过截断或缩小标题实现对齐。

#### Scenario: 正常及大字标题
- **WHEN** 标题为短文或多行长文且文字正常或两倍缩放
- **THEN** 单行不补整行首尾空白，多行保留缩放后的24点基线节奏，全部文本与选择行为不变

### Requirement: 普通短回复采用真实渲染宽度
Flutter普通消息气泡 MUST 在视口上限内保留短文本的自然单行宽度，且用户与助手使用相同计算边界；长文本可自然换行，不因测量器与实际SelectableText渲染差异而截断或多换行。

#### Scenario: 候选选择的短回复
- **WHEN** 会话显示“第 1 个”或“已收到你的选择。”且视口足够
- **THEN** Android与iOS保持一行，并保留文字选择、语义、最大宽与动态字号边界

### Requirement: 未完成状态点循环呼吸
Flutter会话状态点 MUST 在非结果阶段以900ms单程从不透明到0.3透明度反向循环，结果阶段绿色静止；减少动画、隐藏或后台时停止并保持可见，销毁释放资源，恢复从不透明重新开始。

#### Scenario: 状态点生命周期
- **WHEN** 会话阶段、系统减少动画、TickerMode或App生命周期改变
- **THEN** 仅装饰点的呼吸启停改变，8点几何、文字语义与业务状态保持不变

### Requirement: 候选卡采用共同原生层级阴影
Flutter候选卡 MUST 使用共用的白色表面和2点阴影层级，保留18/18/18/6圆角、284最大宽和选择门禁；同条件原生运行图的边缘衰减用于验证，不以参数同名替代运行验收。

#### Scenario: 候选初始与接受选择
- **WHEN** 候选卡初始显示或第一项接受选择
- **THEN** 两平台沿用同一阴影样式，白色表面不被主题着色，布局和回调次数不因阴影调整改变

### Requirement: 候选更新运行证据保持组件身份
候选更新验收 MUST 保持同一组件key和消息id，分别核对隐藏字段保留选择及可见评分变化重置选择，使用本地合成回调计数核验防重，不提交真实Agent动作。

#### Scenario: 已选候选更新
- **WHEN** 已选候选先更新隐藏字段，再更新可见评分
- **THEN** 隐藏更新后的其他候选不能重复提交，评分更新后可重新选择一次，局部运行证据不代替完整会话归尾验收

### Requirement: 任务列表首卡阴影完整显示
任务列表 MUST 在滚动区域内部预留顶部阴影绘制空间，保持列表裁剪和共用卡片样式，首卡静止或滚动回顶不出现顶部阴影硬切，滚动卡片不覆盖标题。

#### Scenario: 列表首行和回顶
- **WHEN** 有任务的列表初始显示或滚动回顶
- **THEN** 第一张卡片顶部阴影完整渐变，普通字号/大字/短屏、刷新和错误提示仍保持可用，任务顺序及恢复业务不变


### Requirement: 参考演练必须使用固定源码对象
隔离原生参考工具 SHALL 从已确认提交的 git 对象读取所需纯UI源码，不因原生HEAD前进替换基线，不修改原生工作区。报告 SHALL 记录固定提交与实际编译源SHA；导出范围不得包含账户服务、凭据或签名材料，Flutter演练不依赖无关原生工作区状态。

#### Scenario: 参考仓库HEAD已前进
- **WHEN** 原生工作区当前版本与已确认参照不同
- **THEN** 隔离参考仍以指定提交导出纯UI输入并核验哈希，保持工作区及普通App数据不变

### Requirement: 无业务组件演练使用独立宿主
Android显式纯UI演练 SHALL 使用独立FlutterActivity和普通Application，取消业务Activity、设备通道及插件注册，移除网络、电话状态/号码/通话记录、通知、悬浮窗、录音、相机、联系人和定位权限。普通构建 SHALL 保持原宿主及能力，不因演练改变身份或数据。

#### Scenario: 启动纯凭据组件参考
- **WHEN** 构建显式纯UI参考并核对独立包名/入口/权限后运行
- **THEN** 仅展示合成数据的正式presentation，不初始化SDK或账户设备端口
- **AND** 截图只作为运行布局证据，未完成点击/滚动/返回时仍保持交互待验

### Requirement: 翻译历史字幕必须可读且可选择
每条非空实际主/次字幕 MUST 提供独立明确文本语义，MUST 保留原生Flutter文本选择，不以空只读输入节点替代可访问文本。标签必须对应当前显示内容，不重复公告旧内容。

#### Scenario: 浏览器辅助技术读取或字幕更新
- **WHEN** 打开翻译历史或同页内容更新
- **THEN** 主/次文字在辅助树中可读且不重复，长按文本仍能选择
- **AND** 不改变双语投影、显示顺序或产生电话、录音文件操作

### Requirement: 任务回执可选文本可读取
任务回执的转写、状态、联系人、字段、结果摘要及详情 MUST 暴露实际文本语义，保持原有可选文本样式与长按选择能力。单路及批量共用字段不得以空只读输入节点替代文本。

#### Scenario: 辅助读取与文本更新
- **WHEN** 用户进入单路或展开批量任务回执
- **THEN** 每个可选文本独立提供当前文本语义，且内容更新后旧语义不残留
- **AND** 长按仍可以选择实际文本，不改变回执结果、结算或反馈行为

### Requirement: 原声滑块具有独立可访问名称
原声设置两个滑块 MUST 分别提供纯原声声音大小与混声原声比例的名称和当前百分比，并保留系统增减语义及10%步进；禁用时不得允许修改。

#### Scenario: 用户通过辅助功能调节原声
- **WHEN** 用户聚焦任意原声滑块
- **THEN** 可分辨其控制的比例、读取当前百分比并按10%增减
- **AND** 禁用状态不提供可执行增减操作

### Requirement: 身份编辑输入具有独立名称
身份编辑姓名与手机输入 SHALL 各自提供可访问名称，保留真实可编辑文本、格式限制与只读/忙碌门禁，不以值或外部标题代替输入名称。

#### Scenario: 辅助功能编辑身份
- **WHEN** 用户聚焦姓名或手机输入
- **THEN** 能分辨字段并编辑当前草稿
- **AND** 已认证姓名只读、保存中输入不可编辑

### Requirement: 克隆试听仅暴露一个可操作节点
声音克隆候选试听 SHALL 暴露唯一具名按钮并提供对应点按语义，开始/停止随播放状态更新，忙碌与加载时不能调用试听；保留原物理按钮样式和48触达范围。

#### Scenario: 辅助功能操作候选试听
- **WHEN** 用户激活具名开始或停止试听按钮
- **THEN** 对应控制器动作仅调用一次，不留下无名子按钮
- **AND** 加载或确认忙碌时动作不可用

### Requirement: 克隆认证输入名称和编辑门禁
克隆认证姓名及身份证号输入 SHALL 分别具有独立可访问名称，保留当前值、18位身份证输入上限与原提交回调；已认证姓名和忙碌输入 SHALL 不提供编辑动作。

#### Scenario: 辅助功能填写认证信息
- **WHEN** 用户聚焦姓名或身份证号
- **THEN** 可读取字段名称并编辑可用字段，提交仍取当前两字段值
- **AND** 已认证姓名锁定，忙碌时两字段不可编辑且不可提交

### Requirement: 外呼号码表单采用共同原生样式
外呼号码编辑页 SHALL 使用共同返回大标题、14点横向内距、具名圆角输入卡及至少48点保存/危险删除按钮，动态字号自然增高。

#### Scenario: 编辑保存或忙碌返回
- **WHEN** 用户编辑外呼号码或请求保存/删除
- **THEN** 表单沿用原草稿、账户及忙碌门禁，成功返回、失败留页、返回后迟到不能误弹上级路由
- **AND** 小屏与两倍字体不裁切文本，返回操作具有统一名称

### Requirement: 邀请码实际文本可读且可选择
邀请页 SHALL 为当前邀请码提供独立实际文本语义，保留长按选择能力及现有二维码、复制和分享门禁。

#### Scenario: 阅读当前邀请码或数据更新
- **WHEN** 用户打开邀请页或邀请码更新
- **THEN** 当前码在辅助树中可读且唯一，旧码不残留
- **AND** 长按可选择真实显示文本，不额外写剪贴板或保存图片

### Requirement: 外呼参考宿主必须隔离真实账户能力
外呼iOS运行参考 SHALL 编译固定原生正式UI及纯号码规则，账户DTO和服务仅使用明确合成替身，不导出真实账户服务或凭据、不联网、注册SDK或影响普通包。Flutter参考 SHALL 直接使用生产表单与相同合成状态。

#### Scenario: 四状态表单与返回对照
- **WHEN** 运行已保存、空、加载或错误参考
- **THEN** 显示固定正式布局，保存删除只拒绝合成动作，返回仅到独立参考根
- **AND** 记录源哈希、当前状态及实际运行图，不将纯UI参考作为真实配置服务通过


### Requirement: 外呼输入状态不继承主题默认边框
外呼号码表单 SHALL 在普通、聚焦和禁用状态保持共同浅色圆角边框，读取提示用灰色、失败提示用红色，字体度量明确且动态字号自然增高；既有重新读取与业务门禁 SHALL 保留。

#### Scenario: 聚焦或读取失败
- **WHEN** 用户聚焦字段或表单进入读取/失败状态
- **THEN** 字段不出现主题默认紫色或深灰边框，读取和错误文字有明确状态色
- **AND** 小屏大字不裁切输入，忙碌仍禁止编辑和写入


### Requirement: 翻译语种选择共同最小行高
翻译语种选择 SHALL 使用32×32勾选区域与上下16内距，使普通行至少64点；动态文字 SHALL 自然增长，已选和未选的占位规则一致。

#### Scenario: 选择或取消语种
- **WHEN** 打开正常或大字号语种列表
- **THEN** 已选和未选行采用相同最小几何，长本地名称完整可读
- **AND** 选择仍返回当前语种，取消不修改原值


### Requirement: 联系人备注输入独立名称
联系人备注输入 SHALL 有独立可访问名称与当前值，保存中 SHALL 不提供编辑动作；既有2000字上限、草稿及保存取消行为 SHALL 保留。

#### Scenario: 填写备注或等待保存
- **WHEN** 用户聚焦备注输入或保存正在进行
- **THEN** 可读取联系人备注名称和当前值，可用时编辑仍触发原控制器
- **AND** 保存中不可编辑，不改变返回、迟到和失败提示门禁


### Requirement: 联系人技能行具名可操作
联系人Skill行 SHALL 以一个具名按钮提供完整标题与说明，语义和物理选择 SHALL 各调用现有回调一次，不留下无名子按钮；当前有效卡及缓存刷新规则 SHALL 保留。

#### Scenario: 选择可用联系人技能
- **WHEN** 用户激活可用技能行
- **THEN** 选择原HomeCard并沿原路由继续，辅助树具有明确按钮角色
- **AND** 不引入新请求或重复选择动作


### Requirement: 联系人技能弹层只完成当前选择一次
联系人Skill弹层 SHALL 只允许当前路由完成一次关闭或选择；非preview流程 SHALL 冻结登录代际和来源路由，在弹层返回及准入后拒绝过期会话创建。

#### Scenario: 重复关闭或换账号后返回选择
- **WHEN** 关闭/选择回调重复，或登录代际/来源页面已改变
- **THEN** 不误弹下层页面，不以旧联系人创建新会话
- **AND** 正常选择与明确preview仍沿原流程继续


### Requirement: 语种参考隔离账户和模型服务
语种选择运行参考 SHALL 编译固定原生正式UI和纯语种策略，并直接运行Flutter生产选择页；选择和重新进入 SHALL 仅修改独立宿主内存，不注册SDK/访问服务/写真实偏好或影响普通包。

#### Scenario: 同条件正常字体选择与返回
- **WHEN** 运行语种参考并选择、重新进入或取消
- **THEN** 固定UI执行真正present/push及dismiss/pop，根页反馈对应实际结果
- **AND** 记录源hash及配对运行图，不将纯UI替身作为模型或业务服务通过


### Requirement: 历史隔离参考数据必须保持记录身份与时间一致
纯UI历史参考 MUST 按callId保持列表和详情的合成时间及字幕一致，不把参考数据矛盾解释为生产服务缺陷。

#### Scenario: 切换两条合成历史
- **WHEN** 从首条历史返回并打开第二条
- **THEN** 第二条详情与其列表时间一致且字幕独立，原记录播放状态不迁移
- **AND** 不请求真实录音或写入文件，normal参考不作为失败重试验收


### Requirement: 录音失败运行参考必须隔离场景与业务端口
录音隔离参考 MUST 白名单选择合成场景，默认normal，拒绝非法及非Flutter Shell组合，非normal使用独立参考包。

#### Scenario: 明确失败场景
- **WHEN** 构建加载、播放或保存失败参考
- **THEN** 复用正式历史UI与已有合成音频端口并核验重试及取消
- **AND** 不读取真实录音，不写文件，不将合成恢复当真实音频能力验收


### Requirement: 任务和翻译历史时间必须遵循共同原生日期规则
任务及翻译历史 MUST 共用纯Dart记录时间展示，按本地日历日显示今天/昨天、晚于七日前的中文星期、同年月日与跨年年月日；MUST 保留原无效时间fallback和排序。

#### Scenario: 日期边界和调用方
- **WHEN** 记录在六日前、七日前、跨年或含时区偏移
- **THEN** 两处遵循相同本地日期规则，今日与昨日优先，不用固定24小时差替代日历比较
- **AND** 不修改记录原始时间、时长、顺序或业务服务


#### Scenario: 共同记录时间实际调用方
- **WHEN** 在明确隔离的记录时间参考中进入和关闭两条记录
- **THEN** 生产任务列表与翻译历史详情显示相同合成时间，返回不串记录
- **AND** 此参考不装配网络、账户、音频或文件端口，不当原生整页验收


### Requirement: 翻译历史标题与电话必须遵循共同原生列结构
历史页 MUST 在关闭按钮旁的同一列排列标题和电话，电话在标题后6点，时间在该内容行后12点；MUST 保留48点关闭热区和原有返回门禁。

#### Scenario: 电话和大字体
- **WHEN** 显示正常或长电话号码并放大字体
- **THEN** 电话不得再排在完整关闭按钮行之后造成额外间隔，长号码自然增高且关闭按钮仍可操作
- **AND** 没有号码时仍保留48热区，不把与原生固定44/36差异称像素一致


### Requirement: 原生历史展示参考必须排除控制器业务副作用
历史隔离参考 MUST 只逐字抽取固定原生展示方法/UIView并记录原文件及范围哈希，不编译启动原网络和音频控制器；宿主固定数据与布局装配范围必须明确。

#### Scenario: 正常历史内容部件对照
- **WHEN** 对照同合成标题、电话和两条双语字幕
- **THEN** 原生使用实际抽取展示代码及纯模型策略，Flutter使用正式历史页，不装配录音或账户服务
- **AND** 记录实际两侧返回、原图和字节来源；部件/装配对照不得声称原控制器业务流程验收


### Requirement: 历史排版必须使用明确行高和字距
历史页面 MUST 共用电话15/18、时间与时长14/17、标题和双语正文零额外字距，字幕原16/23和14/20保持，避免Material默认body行高/字距泄漏。

#### Scenario: 主题及字号变化
- **WHEN** 主题文字行高/字距变化或放大字体
- **THEN** 本页明确排版按同一规则自然缩放，不影响文本选择、关闭、业务与录音
- **AND** 正常锚点实际复核，不将系统字形/阴影未验差异当已关闭


### Requirement: 历史字体诊断必须隔离业务和生产展示
历史字体诊断 MUST 只在纯参考宿主记录合成UILabel及CoreText字体/度量，不读取业务数据，不修改固定展示字节或替代正式可选文本。

#### Scenario: 字形差异定位
- **WHEN** 同条件历史截图存在字体宽度差异
- **THEN** 先记录实际系统字体及回退run作为证据，保留原始字号和业务边界
- **AND** 诊断结果不得称整页或真实通话验收


### Requirement: 翻译历史气泡必须使用共同平面外观
历史字幕气泡 MUST 采用固定UIKit实际展示的无外部阴影目标，两平台共用且保留现有宽度、圆角、内距和文本选择；Android原elevation差异必须明确记录。

#### Scenario: 气泡边界实际复核
- **WHEN** 运行同条件纯历史展示参考
- **THEN** 气泡边界外不得出现额外灰影，原有颜色与排版保持
- **AND** 不将局部外观一致当完整录音业务或Android原生像素验收


### Requirement: 历史大字参考必须保持场景与平台证据边界
历史大字参考 MUST 只在Flutter纯宿主局部放大并用独立参考身份，固定原生大字组合拒绝，不修改系统设置或普通App。

#### Scenario: 两倍字实际关闭
- **WHEN** 运行Flutter历史大字参考
- **THEN** 使用正式页及同合成内容，电话/字幕自然换行且关闭仍可操作
- **AND** 记录实际显示和返回，不称系统动态字体或固定UIKit大字已验


### Requirement: 历史空字幕参考必须使用固定实际展示与独立身份
历史空字幕参考 MUST 只抽取固定纯空态展示字节及记录范围哈希，使用独立.empty参考身份与正式Flutter空rows，不加载服务或录音。

#### Scenario: 相同空字幕数据
- **WHEN** 两侧参考显示无有效字幕但保留标题和元数据
- **THEN** 核验实际空态文案、布局及本地关闭，并记录未关闭差异
- **AND** 非history空态参数须在设备动作前拒绝，不称业务空记录/原控制器已验


### Requirement: 历史空字幕不得继承Material额外行高
历史空字幕 MUST 使用共同14字号/17行高与零额外字距，保留28内距、居中和缩放，不改变空字幕业务含义。

#### Scenario: 空态正常与大字
- **WHEN** 正式历史页没有有效字幕且放大文字
- **THEN** 空态按明确行高自然缩放，关闭仍有效，正常位置须实际对照
- **AND** 不将行框修正当系统字形宽度已一致


### Requirement: 历史首次加载和失败必须展示共同原生状态
历史首次无内容状态 MUST 只显示关闭及加载/失败提示，不显示未取得的标题或字幕；加载提示顶部28，失败居中提示与独立重试相隔12，按钮保留48热区。

#### Scenario: 首次加载失败和重试
- **WHEN** 历史没有内容且正在加载或失败
- **THEN** 显示正在加载记录或记录加载失败，失败才提供重试，关闭始终可操作
- **AND** 已有内容刷新仍保留原字幕与录音，不因本批新增首次空状态隐藏业务内容


### Requirement: 历史首次状态参考必须隔离服务和晚到结果
历史首次状态参考 MUST 只执行固定纯展示方法及本地合成恢复，不调用原loadDetail服务；独立状态身份、参数白名单与范围SHA必须可核验。

#### Scenario: 失败重试和加载中关闭
- **WHEN** 在纯参考失败态点击重试或关闭等待中的页面
- **THEN** 合成重试只切到加载再本地内容，关闭后的晚到不得复活旧页面
- **AND** 核验实际结果和两端已选热区/安全区差异，不作为真实后端或原控制器完整流程验收


### Requirement: 评分弹层返回必须只消费自己的当前路由
评分弹层及成功反馈 MUST 各自一次性返回并检查当前路由和生命周期，保存期使用最新状态禁止关闭，旧回调不得弹出底层结果或会话。

#### Scenario: 重复和过期回调
- **WHEN** 重复关闭、提交后旧回调、或保存中调用旧关闭回调
- **THEN** 只消费当前可关闭弹层一次，忙态不退路由，成功仍按原服务端提交事实显示
- **AND** 不新增提交/奖励/草稿或后端规则，不把单次平台点击当竞态验证

#### Scenario: 成功反馈期间旧入口回调
- **WHEN** 成功反馈尚未关闭且旧评分入口再次触发
- **THEN** 不叠加评分弹层，完成后仍停留来源会话

### Requirement: 身份性别按钮必须同时暴露选择与可用状态
身份编辑性别项 MUST 在同一具名按钮语义节点暴露当前selected及enabled，忙态不提供tap，不改变现有资料保存规则。

#### Scenario: 切换性别及保存忙态
- **WHEN** 编辑者切换性别或正在保存
- **THEN** 当前选中项唯一可读，保存期间所有性别按钮不可操作

### Requirement: 未登录初始化参考必须独立且无业务端口
完整Shell未登录参考 MUST 使用独立身份与既有合成认证/初始化端口，参数仅允许Flutter Shell，非法组合在设备动作前拒绝。

#### Scenario: 未登录参考启动
- **WHEN** 显式启用未登录Shell参考
- **THEN** 从无会话和空身份开始，不能发送真实短信或访问原生SDK

### Requirement: 登录和初始化选择项必须唯一具名并反映状态
登录协议 MUST 只提供一个具名checked控件并保留独立协议链接；初始化性别与模型 MUST 在各自同一具名按钮节点暴露selected/enabled，忙态和不可用项无tap。

#### Scenario: 合成登录和初始化选择
- **WHEN** 切换协议、性别或模型以及进入忙态
- **THEN** 辅助树无无名重复控件，当前选择可读且禁用不提供操作
- **AND** 不改变可见布局及已有认证/保存/初始化规则

### Requirement: 初始化原生参考必须保留固定展示字节并隔离原控制器业务
初始化原生参考 MUST 提取固定提交的纯展示方法并记录SHA，不编译账户、服务、原三步或保存控制器；本地合成宿主只按当前两步决策导航。

#### Scenario: 原生初始化纯展示对照
- **WHEN** 构建及操作独立UIKit初始化参考
- **THEN** 使用固定展示字节及合成目录，只改变本地展示状态，不触发SDK/认证/网络/存储
- **AND** 热区/字体差异和实际动作证据独立记录，不当作真实后端流程验收

### Requirement: 初始化模型卡必须使用共同紧凑布局及整卡操作
初始化模型卡 MUST 使用16横15纵内距、正常名称19行框/描述14行框及5间隔、20视觉单选圈和整卡至少48热区；长文本和字体放大自然增高，保持唯一具名选择、忙态和不可用门禁。

#### Scenario: 模型卡正常与大字
- **WHEN** 展示正常短两行或长文本大字模型卡
- **THEN** 短两行正常高度68，圆圈20且不额外撑高，内容可读并只触发一次整卡选择
- **AND** 禁用模型不显示可选中事实，不改变认证/目录/保存业务


### Requirement: 初始化顶部必须居中且保留完整操作热区
初始化顶部 MUST 移除额外18点纵向留白，使用至少48高及完整48按钮热区，标题在页面中心，大字自然增高并与操作区分离。

#### Scenario: 正常及大字初始化顶部
- **WHEN** 展示两步初始化或忙态
- **THEN** 标题居中，返回和跳过按既有可用状态呈现，忙态无操作
- **AND** 只调整展示，不改变草稿、保存和认证逻辑


### Requirement: 初始化字段必须显式共同样式并保留输入约束
初始化字段 MUST 显式浅色边框、蓝色focus与性别选中描边、占位13/16、输入15/18、至少48热区；不得继承默认深边或改变输入过滤与忙态门禁。

#### Scenario: 字段输入选择及忙态
- **WHEN** 展示或填写姓名电话、选择性别及进入保存
- **THEN** 样式在双平台一致，大字自然增高，电话仅数字最多11位，忙态不可编辑


### Requirement: 初始化能力说明必须只使用固定已知原生策略
初始化模型卡 MUST 显示Qwen系统音色和克隆、Seeduplex仅系统音色的固定原生说明，未知及V3不得推断；描述已相同不重复，能力纳入唯一语义且大字自然增高。

#### Scenario: 已知及未知模型能力说明
- **WHEN** 显示初始化模型目录
- **THEN** 已知说明按4间距12/14显示，未知为空，可用性仍由原目录决定
- **AND** 标签不等于实际SDK授权或克隆业务验收


### Requirement: 联系人备注旧入口和旧动作不得影响新编辑器
联系人备注入口 MUST 只在当前详情且未编辑时打开，编辑器动作 MUST 检查自身生命周期、当前路由与最新保存状态；旧回调不得重置新草稿或重复保存。

#### Scenario: 重复编辑及旧弹层回调
- **WHEN** 旧详情编辑入口或已关闭编辑器的取消、保存、输入回调再次触发
- **THEN** 不叠加编辑器、不改变新草稿、不新增服务端保存，现有返回与保存成功匹配规则保持

### Requirement: 普通拨号动作必须属于当前页面和账号
普通拨号 MUST 仅允许当前仍存活页面及当前controller执行号码编辑、国家入口、配置入口、关闭和拨号；异步国家返回 MUST 再核验归属。

#### Scenario: 旧拨号页被覆盖或销毁
- **WHEN** 已打开国家页或其他页面，或拨号页已关闭，旧回调再次执行
- **THEN** 不重复打开、不关闭覆盖页面、不修改号码或国家、不拨号
- **AND** 正常返回保留当前草稿，翻译拨号关闭仍只返回普通拨号

### Requirement: 翻译拨号异步推进必须保持当前页面归属
翻译拨号 MUST 在动作和异步返回时核验当前存活路由及配置controller归属；失效页面 MUST NOT 继续准备或打开通话。

#### Scenario: 国家页覆盖或准备期间页面退出
- **WHEN** 旧号码、关闭、国家或呼叫回调执行，或异步准备完成时原页面已失效
- **THEN** 不修改当前草稿、不误关闭覆盖页、不重复导航或继续通话
- **AND** 失效后已准备的会话controller释放，正常国家返回与预设配置保留

### Requirement: 翻译预设旧弹层动作不得修改新配置
翻译预设 MUST 仅允许当前存活且未结束弹层执行开关、关闭或语言入口；语言返回 MUST 验证来源页面及controller存活。

#### Scenario: 关闭后重开或语言页覆盖
- **WHEN** 旧弹层回调在销毁后或覆盖期间执行
- **THEN** 不改变当前配置、不误关闭新页、不重复打开语言页、不拨号
- **AND** 正常语言选择和取消返回保持现有配置语义

### Requirement: 翻译语言页销毁后的选择和返回必须无效
语言页 MUST 在访问路由前核验context存活，旧页面选择和返回不得影响重入页面。

#### Scenario: 选择完成后重入
- **WHEN** 已销毁语言页的旧选择或返回回调执行
- **THEN** 不访问失效context、不关闭新页、不改变选择结果
- **AND** 当前页正常选择和取消保留原结果语义

### Requirement: 翻译模型弹层旧动作不得操作其他页面
模型弹层 MUST 仅在当前存活页执行选择、刷新和倍率重试，真实动作 MUST 读取最新地区准入和加载状态；返回保存 MUST 核验来源存活。

#### Scenario: 旧弹层覆盖或销毁
- **WHEN** 旧选择或刷新回调执行
- **THEN** 不关闭覆盖页、不访问已释放State/ref、不重试新账号查询
- **AND** 当前选择和刷新保持现有结果、失败与取消语义

### Requirement: 海外翻译设置必须核验当前页面与地区
海外设置 MUST 仅在当前存活页面及当前可编辑controller时修改模型或区域；正式入口 MUST 即时核验地区策略。返回 MUST 不影响覆盖或重入页面。

#### Scenario: 旧设置页动作或地区变化
- **WHEN** 页面已覆盖或销毁，或地区已不允许海外设置而页面尚未重绘
- **THEN** 旧修改无效、旧返回不关闭新页，正常配置返回保留已选择结果

### Requirement: 翻译目录重试必须属于当前区域和页面
目录重试 MUST 核验当前存活路由、当前element区域及最新非loading失败状态；旧动作不得访问已销毁ref或重试其他区域。

#### Scenario: 旧目录动作或重复重试
- **WHEN** 页面覆盖、销毁、切换区域或同帧重复执行旧重试
- **THEN** 不访问失效ref、不重试旧区域，不重复读取当前正在加载的目录
- **AND** 当前失败仍可显式重试，成功和空目录保留真实结果

### Requirement: 预设海外设置入口必须属于当前弹层
海外设置入口 MUST 以自身弹层context和当前controller、地区门禁导航，不依赖被覆盖父页的current状态；旧入口 MUST 不重复push或在弹层关闭后打开页面。

#### Scenario: 设置页覆盖或预设关闭
- **WHEN** 旧海外设置入口再次执行
- **THEN** 不重复导航、不修改配置，正常设置返回仍回到原预设
- **AND** preview与正式页面继续使用原provider container和数据边界

### Requirement: 设置选择按钮必须提供唯一具名选中语义
共同选择按钮 MUST 在同一具名button节点提供selected、enabled及合法tap；MUST 保留视觉、至少48热区和大字自然增高。

#### Scenario: 选择或禁用
- **WHEN** 海外模型或开发者配置按钮展示当前选择
- **THEN** VoiceOver/TalkBack可读出唯一名称和选中状态，合法语义或视觉tap各执行一次
- **AND** disabled可保留已有选择但不可tap，不改变业务门禁


### Requirement: 退出确认动作必须属于自身当前弹窗
退出确认 MUST 核验自身mounted/current/未结束状态并以即时busy限制动作；旧取消、确认及异步成功不得关闭其他页面，退出期间原禁退与失败重试 SHALL 保留。

#### Scenario: 弹窗覆盖销毁或退出等待
- **WHEN** 旧取消或确认执行，或退出结果在其他页面覆盖后返回
- **THEN** 不误关闭覆盖页面，不因旧动作重复退出或更新失效State
- **AND** 当前弹窗正常取消、成功关闭和失败重试保持原行为


### Requirement: 原音原生参考必须隔离偏好及业务宿主
原音iOS参考 MUST 只抽取固定原生开关、滑杆、页面布局及纯样式字节并记录范围SHA；偏好读写 SHALL 只用独立宿主内存，禁止SDK/账号/网络及普通App存储。

#### Scenario: 原音开关比例和返回
- **WHEN** 独立原生参考显示、调节或返回重入
- **THEN** 仅执行固定展示回调和本地导航，保存只影响该宿主进程
- **AND** 实际图及必要热区/字体差异独立记录，不当业务偏好或整页通话验收


### Requirement: 原音排版不得继承主题额外行高字距
原音标题 MUST 使用16/19及零额外字距，说明13/18、level14/20、footer12/18 SHALL 保留并显式零字距；共同48热区及调节规则不变。

#### Scenario: 主题改变和字体放大
- **WHEN** 原音页使用额外主题行高字距或放大字体
- **THEN** 本页按明确共同排版自然缩放，开关及滑杆仍可操作
- **AND** 实际布局差异独立记录，不把标题修正当整页原生验收


### Requirement: 原音返回动作归属当前页面
原音设置顶部返回 SHALL 仅在页面仍存活、位于当前路由且Controller身份未变时生效；旧页面返回回调 SHALL NOT 关闭覆盖页面或访问已销毁context。

#### Scenario: 原音页被后来页面覆盖
- **WHEN** 调用覆盖前保留的原音顶部返回动作
- **THEN** 后来页面保持显示，原音偏好不变

#### Scenario: 原音页面已销毁
- **WHEN** 调用销毁前保留的原音顶部返回动作
- **THEN** 不导航、不访问失效context并且不抛异常


### Requirement: 翻译拨号业务页面必须隔离演练入口
正常翻译拨号页面 SHALL 不展示MOCK演练入口或专用演练说明，即使Debug全局迁移演练开关开启；原有模拟通话能力 SHALL 只经独立验收目录访问，真实拨号、模型、语言及返回规则保持不变。

#### Scenario: Debug正常拨号
- **WHEN** 用户经首页同传或底部拨号进入正常页面
- **THEN** 不显示“进入翻译通话演练（MOCK）”或仅本次演练配置提示，仍可使用原有配置和拨号操作

#### Scenario: 独立目录打开演练
- **WHEN** 从迁移验收目录进入翻译通话演练
- **THEN** 可选择正常双语、环境检测失败及挂断失败重试三个场景，明确MOCK且不使用输入号码或产生真实通话、录音、媒体或费用
