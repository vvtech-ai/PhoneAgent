## Why

2026-10-06用户反馈运行界面与交互仍不一致，要求重新生成修改计划、确认后执行。此前源码参数与自动测试批次保留为局部实现证据，不代表最终效果一致。运行态闭环计划现已获得用户“执行”确认，开始分批实现和运行验证；视觉验收未完成。

用户确认把新版 Android 和 iOS 的 UI、UI 交互同步到 Flutter，并批准执行修改计划。当前 Flutter 的视觉基线仍主要来自旧 HTML，不能据此声明新版原生 UI 已对齐。

## What Changes

- 固定 Android 0f8879e4 和 iOS bb9ff349，只读核对正式入口、布局、状态、操作和返回行为。
- 以两端有效原生页面为参照建立 Flutter 统一视觉与交互规范；颜色、字体、间距、卡片、按钮和普通业务流程共用，仅对有依据的平台能力、系统交互及必要控件差异适配。依次推进公共组件、登录初始化首页、会话工具、联系人拨号翻译、通话结果、身份钱包设置和平台适配。
- 保留用户已明确的两步初始化、默认按住说话、文字 VOICE channel、退出规则、平台权限及后端权威规则。
- 将源码对齐、自动交互检查、真实视觉验收分别记录；缺少真实能力的界面不得模拟成功。
- 补齐每页唯一目标、原生运行截图/操作序列、Flutter双端对照及差异修正闭环；按完整流程交付，不再仅按控件参数批次宣称一致。已改页面也重新验收。

## Impact

涉及 presentation 与 core/design；不升级 Flutter/Dart，不变更账号、签名、接口契约或生产 OTA 策略。真实短信、身份采集、外呼和收费继续需要具体测试授权。

### 确认卡原位更新尾部定位 H23

有效iOS AIPureVoiceThreadRenderPolicy contentSignature包含displayPayload；Flutter H20仍未纳入单路/批量确认显示内容。独立纯presentation投影仅选CallConfirmation实际rows/isBatch、BatchConfirmation面板sections、audit计数/问题/联系人显示字段、rules/decision及非通用assistantText和billingAlias生命周期键，按值平铺且带结构数量，冻结本地snapshot，不读sourceSpec或记录日志。新增helper/revision/既有tail专项三文件微批；等值模型重建和非展示源字段变化不归尾，原位目的/批量规则更新按既有180ms、reduceMotion、IME与销毁规则定位。先四平台字号复现，再定向会话/确认/联系人邻接、analyze/OpenSpec；不修改样式/执行/计费，卡内部展开与回执另验，不重复刚完成全量/双端包。

### 批量确认面板样式 H24

双原生LargeTaskCardShell/AIBatchTaskConfirmationCardView shell均白底16圆角/E4E9F0边框、14横向内边距、正常43点标题行、14bold标题/11bold状态、1点EEF1F5分隔线、内容上下12。Flutter BatchConfirmationPanel没有分隔线且标题13/状态regular，全卡统一padding14。仅面板owner修正：采用Android自然标题高度19+24，iOS正常同43、大字自然增高；green summary延续已共用单路确认Android渐变EDFAF0→D6F5DC、16/14内边距和2E7D32标题（iOS实色E4F8E8差异记录），普通panel308/green280可用宽度上限。Rows按compact12/16与3间隔、普通11/16与8间隔，原生Android权重0.7:1.3与1:1.35为共享目标，iOS0.32/0.40布局差异不伪称相同。card/panel/rows仍单职责小文件可直接保留；本批不改整体外间距、助手说明、联系人内部/计费状态流，独立测试先复现divider和实际字段样式，再修正，定向确认/计费/尾部/analyze/OpenSpec；不以源码和widget证据声称真实整卡验收。

### iOS实际批量确认控件对照 V1N

扩展独立reference --batch场景（与shell/short/dynamic互斥），原生直接链接固定AIBatchTaskConfirmationCardView和纯Foundation policies/points/receipt contract及Masonry，不注册业务SDK；Flutter直接复用生产BatchConfirmationCard。两端相同纯合成sections/rules/空audit/无billing/无assistantText，宿主普通panel目标308宽（共同Android目标，不伪称正式iOS308/360宽比），SafeArea+top200。独立native-batch/flutter-batch身份、ignored产物日志与全部参与源码hash，最多script/Host/Flutter入口三tool文件微批。稳定截图逐张观察字段、header43、divider、两panel间10与末部，明确原生摘要实色与统一Android渐变/宽280的已选差异。非正式整页或计费SDK验收，语法/analyze/OpenSpec与两隔离编译；不改固定原生、不重复全量或普通双端包。

### 批量面板状态靠右 H25

V1N028/029实际native对照发现BatchConfirmationPanel状态Flexible loose导致文字在中部、末尾空闲；两原生状态在14点右内边界。仅card/既有panel layout测试两文件微批设置状态FlexFit.tight，四平台字号实际Text框右边界14断言先复现，保持title剩余宽/大字增高、不改变文本或业务。定向确认/计费/尾部/analyze/OpenSpec，并重建同Flutter隔离batch、稳定030对照028；不重复普通包或全量，其他已选统一差异与整卡外间距继续独立。

### 批量确认外间距与助手说明气泡 H26

有效iOS batch_task_confirmation内部stack以10点连接actual card和普通assistant bubble、会话row外10；Android共同容器亦10且非通用说明同消息显示。Flutter每panel底10再outer底12，无说明末部22；说明是裸Text+4/6padding，与普通气泡不同。三生产文件微批提取现有普通消息精确样式为NativeConversationTextBubble，仅presentation text/user/key与10底距，tile复用、BatchCard去360外限/12额外margin并以同owner显示有效说明，各panel既有10底距保留；不引入tile↔batch循环，不改tool/普通字形规则/业务。独立组合测试正常两倍字双平台实际panel→说明→user边界10、无说明panel→user10、摘要/规则内10、单条说明语义与通用文案隐藏，定向正文/tail/确认/计费/跨页/analyze/OpenSpec。随后同batch原生+Flutter参考增加合成说明和末条用户点号，仅tool微批独立，actual运行边界与语义核对；不宣称整批联系人/SDK已验收，不重复正式双端/全量。

### 真实系统键盘尾部定位 H27

V4W冻结5e70752全量3210通过/1跳过（7分33秒），Android保留安装成功；iOS完整合成流程037发现阅读历史后打开系统键盘未归尾，V4W整体保持未完成。Scaffold消费body的MediaQuery底部inset，既有内部模拟inset测试遗漏实际路径。新增真实Scaffold/viewInsets专项先复现；timeline以WidgetsBindingObserver监听所属FlutterView键盘指标增长，保留原MediaQuery路径、减小inset不归尾和销毁epoch保护。仅滚动presentation与独立测试微批，不改业务。定向会话验证、analyze/OpenSpec后重建隔离iOS shell实际复验；刚结束全量不重复，不将其声称覆盖H27。

### Android合成批量流程输入 V4X

Android现有保留数据ADB演练输入不能可靠输入中文口令，未将其作为业务缺陷或批量流程通过。仅tool in-memory ShellConversationPorts增加精确ASCII别名UI_BATCH_CONFIRM，映射现有同一合成确认fixture，不进入lib或真实业务，不新增网络/执行能力。tool/已有ports测试两文件微批验证中文与ASCII都生成同样pending confirmBatchTask、没有拨号。随后最新普通preview构建保留-r安装，正常/两倍字批量展开、阅读历史、键盘归尾、模型草稿及返回；恢复font1与首页，核验首次安装不变。复用刚结束全量范围与H27定向，不重复全量，不把合成流程作为业务SDK或原生整页验收。

### 批量联系人检查卡 H28

固定两原生均统计18bold数字分类色172033/187A3A/8A4F00、10bold灰标签，称呼11bold且靠右，issue上下9/横10，展开12bold左对齐（iOS最小44、Android自然11竖padding）。Flutter统计全部默认黑、称呼regular居中余白、issue10竖padding、展开默认14居中。仅contacts组件/独立专项两文件微批共享原生参数，保留已批准48热区（比iOS44明确适配），按钮前9间隔、12bold/16行高/左对齐；recipient边框使用foreground避免吞掉10内边距，名称202938同iOS，长字自然换行，detail10/14与既有展开状态保留。四平台字号专项先复现颜色/称呼右边界/按钮位置，定向确认/滚动/跨页、analyze/OpenSpec；iOS隔离batch补相同synthetic audit与原生actual card局部截图另微批，不声明正式整页或业务SDK闭环。

### 批量统计块行高 H29

041/042实际同条件统计块约52与58点，Flutter继承主题默认Text行高导致18数字/10标签扩大。统一数字22点、标签12点正常行高（随TextScaler同比扩大）及既有上下9，正常目标52、两倍字86，不固定容器高度、不压缩字；选iOS自然紧凑统计层级作为两端共同目标。仅contacts/既有layout专项两文件微批，用实际metric容器高度先复现，并保持四字号展开/边界和会话定向；重新构建Flutter隔离batch对照同原生041，明确仍存在已选Android行/摘要差异和字体栅格差异，不能称全像素一致。H28行数记录更正为源184/测试106（均<500），前次173/116为错误手填数，不影响检查结论。

### iOS实际批量单项回执对照 V1O

扩展隔离参考--result，与batch/shell/short/dynamic互斥，独立native-result/flutter-result身份。原生链接固定actual AIBatchCallItemResultView、纯presentation/计费展示依赖及Masonry，不注册业务SDK，recordingHandler/展开回调nil；Flutter actual BatchReceiptItemCard同纯合成SUCCESS/联系人/合成结果/业务结果确认参加/事项字段，无transcript/callId/计费/录音操作。宿主308宽（共同目标）、top200+原生外层12间距，Flutter实际owner既有margin12；tool script/Host/Flutter入口三文件微批，source hashes覆盖参与源。两实际编译和稳定图逐张核对状态pill、header、字段、边框/内距、缺失或重复；仅纯UI局部参考不称正式整页/SDK验收，analyze/脚本语法/OpenSpec，不重复正式双端或全量，差异另开小批修复。

### 批量单项回执展示范围 H30

V1O044/045实际同payload确认Flutter显示额外purpose行；固定Android BatchPlusCallResultItem与iOS actual item均heading=name fallbackphone、summary=headline/detail/status，businessResult仅状态pill，不另列phone/detail或通用receiptFields。仅BatchReceiptItemCard去上述额外行，保留原始domain/facts/普通单路/textformatter；foreground边框保持10点实际内距（Container现隐式11）。共同Android紧凑右侧pill保留，iOS实际pill布局差异已记录不复制两套样式。独立专项正常/两倍字双主题验证不存在重复电话/详情/原始字段表、summary/phone fallback及business状态仍可见、实际10内距，受影响回执/录音/独立展开/业务状态/跨页定向+analyze/OpenSpec，重建Flutterresult稳定046对照044；不动HTTP/结算/播放，不重复全量/普通双端包，原生整页仍待验。

### Android实际批量单项回执对照 V1P

在既有隔离reference新增scene=batch-result，直接调用固定原生internal BatchPlusCallResultItem同模块组件，不复制body；合成与V1O相同SUCCESS/联系人/摘要/businessResult+purpose，无callId/transcript/billing，recording route准入为null不创建业务端口。Flutter同场景直接生产BatchReceiptItemCard，共同308/18side/top200，背景仅宿主不用于整页验收。nativefixture/Activity/Flutterfixture三文件微批，随后Flutter入口单文件接线；新tool默认<500。原生现有JDK11/固定Gradle显式init、纯Application/隔离id/配置String清空/8业务权限移除，Flutter固定3.32/已验JDK21独立id；保留-r不动普通dev，正常/两倍字稳定实际截图，最后font1/普通首页和首次安装时间核验。只局部native与Flutter证明pill/字段，重用H30定向、analyze/OpenSpec/两reference编译，不重复全量/普通正式构建，不称业务SDK或原生正式流程验收。

### 批量结果大字状态宽度 H31

V1P431/432实际两倍字发现Flutter“确认参加”两行、原生单行。共享header固定2:1权重且Align占满右区使状态提前换行。改为左侧Expanded取得剩余空间、右状态按内容自然宽且上限可用宽度一半；长状态仍自然换行、不压字体或截断，右边界8不变。header/独立专项两源微批，正常/两倍字双主题308宽验证四字状态单行、长状态自然增高无overflow，再邻接结果/展开/字段定向、analyze/OpenSpec及同Android隔离重建运行；不改业务/普通包/平台依赖、不重复全量。

### 批量通话记录共同布局 H32

两原生批量transcript均顶部5/底部6、行间11、说话人固定60宽与正文8间隔；说话人11heavy/16行高/0877D1或218242，正文13/21/263142。Flutter复用普通ReceiptTranscript的13说话人/19正文、无固定列、逐行top10，实际批量层级不同。提取专用NativeBatchTranscript，仅批量owner接线，普通单路保留；三源码/测试微批验证实际列边界/行间/正常两倍字两主题展开收起与更新重置，不改domain解析或录音。随后隔离参考新增同纯合成两句transcript运行展开/收起、不含callId不会播放，明确SDK不验。

### 批量转写实际运行参考 V1Q

在V1P独立scene基础新增batch-result-transcript分支，两fixture额外同纯合成AI:合成询问/对方:合成答复；无callId和业务端口。nativefixture/Activity/Flutterfixture三tool微批，Flutter入口单独接线；实际原生自主remember展开与Flutter生产owner分别操作正常/两倍字展开收起，核对说话人列/正文/间距及状态文字，最后恢复font1/普通首页/安装时间。不复制原生body、不改原生仓库，不把合成记录当真实录音。

### 批量记录实际字行 H33

V1Q同条件实际记录行框普通49/58px、两倍99/115px（原生/Flutter），导致第二句纵向偏移。先核对固定3.32 SelectableText/EditableText默认strut与首末行leading；仅batch transcript去编辑器默认strut及首末额外leading进行隔离运行测量，不降低字号、不强设行容器高，长多行正文保持21行间与自然增高/可选择。专项和正常两倍实际重建对照后才判修正有效；不改普通单路、domain、录音，不重复原生编译或全量。

### iOS批量记录实际展开对照 V1R

扩展既有--result为可选--transcript（仅result合法），独立native-result-transcript/flutter-result-transcript身份和产物，纯合成assistant/callee两句，无callId/SDK/播放handler。原生ReferenceHost持有local expanded与item/row，用actual item的transcriptExpandHandler重建actual card；只宿主承担原生调用方同生命周期，不复制body。Flutter直接生产item同fixture；script/Host/Flutter入口三tool微批，metadata覆盖新transcript源码hash。两隔离编译+实际按钮初始/展开/收起稳定原图和AX，不声称原生正式整页或真实录音。

### 批量确认与结果阶段回归 V4Y

H28–H33跨批量联系人统计/recipient/toggle、结果header字段及自然宽、独立transcript owner/实际首末leading传播，触发一次阶段全量，冻结生产5019b7e，不在执行期间改生产。上轮3210冻结5e70752不含H27–H33。本轮全量、最新Android普通纯合成preview保留-r安装及iOS纯完整shell编译/连续批量流程，reference不能代替普通App。iOS formal SDK真机构建与真实媒体仍独立，未改插件平台依赖不重复device正式包。每项结果独立记录，未完成不勾。

### 批量回执与文档原位更新归尾 H34

固定iOS AIPureVoiceThreadRenderPolicy第133行将displayPayload纳入contentSignature；Flutter ConversationContentRevision未包含batchReceipt/document，NativeConversationTimeline只在revision变化归尾，同id/text空的批量回执或文档更新遗漏。添加独立纯presentation值投影，仅batchReceipt实际显示的汇总、单项name/summary/outcome/businessResult、结算展示行、转写及录音准入身份，以及document文件名/metadata；不取整份payload/隐藏参数，不重置本地展开。回执隐藏purpose/attempt/非展示detail与文档batch身份变化保持revision相同；同消息可见变更触发既有归尾。新helper/revision/专项三文件微批，专项先复现同id更新未变，再验证可见/隐藏、顺序/独立对象值相等及不可变快照，既有tail/确认/回执定向加analyze/OpenSpec。不改状态/domain/平台，无需重复全量或双端包。普通单路revision另外盘点，不将本批说成全部回执覆盖。

### 单路回执原位更新归尾 H35

H34邻接盘点显示单路receipt同样未进入会话revision。继续独立纯展示投影：使用实际CallReceiptStatus outcome/label而非全量metadata；联系人/电话、仅实际显示的headline/detail、字段label/value、解析转写role/text、recordingCallId及billingRows展示。隐藏callId/attempt/field key/无展示metadata或结算session/state变更不归尾，metadata若改变实际状态标签则归尾。single helper/已有receipt helper/专项三文件微批，不修改单路卡片业务和录音owner；先复现再验证两平台实际timeline历史位置/可见状态归尾、业务语义优先与隐藏元数据稳定，定向tail/回执/状态+analyze/OpenSpec，不重复全量/平台包。实际纯壳任务恢复运行另记范围，不冒充此变更运行态。

### 会话结果状态点完成色 H36

普通批量恢复310/060实际结果阶段仍蓝点。固定Android PureVoiceStageContent的showCallResult会令PureVoiceLiveIndicator completed=true，StageVisuals完成点34C759；UIKitStageIndicator done亦绿色。Flutterheader始终2196F3。仅header按既有presentation progress=result取共同34C759，其余阶段保留蓝，不把完成色当业务成功/外呼许可，不改状态事实。header/专项两文件微批，双平台普通两倍字检查四阶段点色、状态文字仍蓝且语义无装饰点、返回非结果色恢复。未完成点900ms呼吸另立后续动效批，不能把颜色修正称完整动效一致；本批定向header/progress/会话冒烟、analyze/OpenSpec，无需每批重打双端。

### 批量回执隐藏展示分支归尾 H37

H34投影复查发现执行中批量headline实际不显示、没有展示行的billing section实际shrink，投影仍包含headline/billing数量，可能干扰历史浏览。仅共用helper与既有专项两源码微批：headline仅积分拒绝或终态纳入；结算投影只纳入有展示行的section及实际标题（标题仍受原始attempt数量/index影响），不丢显示序号变化。新增执行中摘要/无展示结算保持revision的反例与显示标题变化正例，修改前复现、修后专项/tail/结果邻接和analyze/OpenSpec，不改事实、UI或SDK，不重复全量/平台包。落实既有“隐藏业务参数变化不得打断历史”requirement，不新增产品规则。

### iOS上传资料卡实际原生对照 V1S

从批量流程扩展到P08成功历史资料卡：隔离reference --document（与batch/result/shell/short/dynamic互斥），两端同308宽/top200，两份纯合成docx/xlsx文件与字数/截断状态；原生直接编译AILargeTaskDocumentCardView+AIUserDocumentPolicy，Flutter直接NativeDocumentCard，无选择器/文件读取/上传/SDK。script/Host/Flutter入口三tool微批，独立native-document/flutter-document身份和产物，metadata加document owner。两隔离编译/原图实际核对标题、数量、分割线、34icon、14内距、filename/metadata/换行；参考卡不可代替完整文件业务。现有磁盘2.3Gi，编译顺序执行、只清理已核验ignored可重建app副本，保留截图/hash/已安装App数据；不重复全量或正式平台包。

### 上传资料卡边框实际内距 H38

V1S063/065同条件真实图显示Flutter标题/icon左多1点，卡内底比原生多4点；两原生border仅绘制不增加layout，FlutterContainer Border.all隐式增加1点各边。只NativeDocumentCard border改foregroundDecoration，保留308宽/16圆角/14横12竖/34icon/10gap/3行间/两份同fixture和既有font14/19共同Android目标，不缩字体或硬改总高。独立四平台字号专项先复现真实14内距与divider全宽，长文件/metadata自然换行无overflow、解析标题切换及语义；source/test两文件微批，受影响附件/会话doc/revision定向+analyze/OpenSpec，重建同iOSdocument并原图/实际像素对063核验。余下iOS自然标题lineheight与共同19差异分开记录，不称全像素或真实上传验收，不重复全量/普通双端包。

### 上传资料卡大字号数量右对齐 H39

H38大字号检查续查：header Wrap(spaceBetween)在两倍字把数量独占下一行并左对齐；两原生标题/数量是同一Row且数量尾对齐。采用共同自适应Row：标题Expanded在剩余宽自然换行，数量按内容自然宽、上限header宽一半、右对齐，间隔8；不复制UIKit截断标题、保持字体缩放/无overflow。source/既有几何专项两文件微批，正常两倍双平台测数量真实尾距14与解析标题切换后仍右对齐、信息完整，修改前复现后定向附件/doc/revision+analyze/OpenSpec，同iOSdocument正常重建复核；实际iOS大字号/Androidreference独立记录，不把Widget当运行验收，不重复全量或正式双端包。

### Android上传资料卡实际原生对照 V1T

接V1S/H38/H39，在既有隔离reference新增document scene，原生直接actual LargeTaskDocumentCard/Models、Flutter直接生产NativeDocumentCard，同308上限/18边距/top200、两份同合成file metadata，无文件IO/上传/SDK。native fixture/Activity/Flutter fixture三tool微批，Flutter入口单文件接线；两host在卡外用同具名“切换上传状态示例”按钮只改变local parsing，采集正常/两倍字已上传/正在上传两个状态，两端各4原图。现有隔离id/24配置String清空/8业务权限移除，固定原生JDK11与Flutter JDK21，保留-r不动普通dev；最后font1/普通首页及首次安装时间核验。普通大字不同自然分配如实记录，不把原生布局缺陷复制进共同目标；reference不能代替真实上传。先脚本/OpenSpec/analyze后两参考编译运行，不重复全量/普通正式包。磁盘1.9Gi，仅有需要时清理核验ignored可重建副本，不删已安装数据/截图/hash。

### 资料卡显式共同字间距 H40

V1T正常文件名原生277/Flutter273px、两倍562/539px，metadata换行差异。核对固定原生Theme.kt未替换Typography，Compose material1.4.3本地classes的Typography body1默认0.5sp，actual Text继承body1；固定Flutter3.32 Material3 bodyMedium默认0.25且tracking不随TextScaler自动增长。采用共同Android资料卡目标0.5、按各字号TextScaler倍率显式缩放，标题/数量/icon/文件/metadata全部隔离环境主题tracking影响，两平台共享同样规则，不新建双套样式。不变字号/行高/内容/header宽度策略，不改UIKit仓库。source/独立tracking专项两文件微批，先用夸张环境letterSpacing复现漂移，再验证两平台1/2倍率实际RichText值、主题变更布局稳定与长文件/metadata无overflow；定向几何/文档revision/import加analyze/OpenSpec。Android复用native449–454，Flutter新构建同状态四图实际核对；iOS同document参考复核正常字号，保留系统字体造成的固有差异，不以测试替代完整文件流程。

### 餐厅候选共同展示 H41

核对固定Android PureVoiceAgentOptionsCard/RestaurantOptionPresentation/AdaptiveContent/DetailsText及iOS AIAgentInteractiveCardView/AIRestaurantOptionPresentation，现有Flutter ConversationMessages.options仅label和detail/phone/address，丢餐厅评分、人均、菜系、商圈/距离、营业状态/时间，且通用detail分隔不一致。新增纯Dart餐厅展示值投影，category/tags或原生advanced字段识别，不改变后端fact/动作参数；共同284候选卡采用原生紧凑布局：13/18名称、12蓝粗评分、11/16价菜系/位置营业，26编号/9间隔；长文/大字自然换行保留信息，不照搬原生ellipsis。通用候选继续原有构造和行为，详情trim/去重、补距离、共同“ | ”分隔。编号选择仍现有第N个，接受成功才本地选中，忙态/旧轮次不可提交，不增加餐厅拨号入口。推荐菜仅原生iOS详情支持、共同内嵌目标不新增该行，但原始fact保留。微批A新projection/现有messages/纯domain专项≤3文件；微批B新餐厅展示widget/现有OptionsCard/widget专项≤3；微批C revision/专项≤3确保新可见值归尾及同值稳定。每步定向测试/analyze/OpenSpec；实际隔离native/Flutter候选新scene另规划，未完成运行不得声称视觉验收。

### Android餐厅候选实际对照 V1U

延续H41增加纯options scene，同标题/两份合成餐厅（4.7分/¥88/粤菜/商圈1.3km/OPEN10–22与未知评分CLOSED），原生直接PureVoiceAgentOptionsCard实际渲染及本地remember选中，Flutter直接生产OptionsCard，经服务端相同map投影。点击只回调local selected，卡外显示合成已选编号/具名reset用key重建，不调用Agent/外呼/餐厅API。native fixture/Activity/Flutter fixture三tool微批，入口单文件接线；固定双JDK顺序两隔离编译/核验身份权限/install-r，正常/两倍字初始→第一项选中→第二项不能重复→reset四状态分别新dump/原图。不复制原生body，不碰普通dev数据；font1恢复/普通包安装时间核验。实际差异如实转后续修正，不能将H41Widget通过当V。iOS同候选reference另记，既有实际iOSSDK正式壳限制不妨碍纯组件编译。

### 候选编号大字与评分行高 H42

V1U两端固定26编号圆都在两倍字裁切；Flutter评分span font12继承body font11的16/11倍height，实际17.45行高而非共同16，导致额外行高。content/test两文件微批：通用/餐厅编号保持正常26、随缩放文字行高+6增长为圆，明确rank16/12height，不缩字；餐厅评分span明确16/12以维持12字/16行，餐厅tracking保持H41，不将资料卡普通Text的tracking直接套到富文本；原生AnnotatedString与Flutter富文本有效字宽须另核对（普通候选正文风格保持）。双平台正常/两倍/通用与餐厅编号实际文本框在圆内，ratingspan字号/行高与parent核验，再既有32定向/analyze/OpenSpec；Android复用原生465–472，新Flutter正常/大字实际初始与选中复核。整体标题行高/阴影另盘点，不把本批称全像素一致。原生裁切不复制为共同目标；不改业务、第N个、domain/平台SDK，不重复全量/普通正式包。V1U文档fixture行数87为记录误写，实际Flutter fixture71，入口174，原生40。

V1V补齐iOS餐厅候选纯组件实际参考，复用同合成数据与生产组件；不改变外部业务或测试授权，实际差异继续台账跟踪。


### 历史原生字体回退诊断

正常同数据历史图仍有标题/正文宽度及阴影差异，先在纯history-content宿主遍历实际UILabel并记录UIFont名称/字号/字重、CoreText各字形run实际回退字体和排版宽度，输出仅合成文本及数值到独立参考App临时目录；不读用户/账户/SDK，不改变展示字节或生产排版。helper/host/buildscript三tool文件微批，metadata包含helper；Python语法、既有历史fixture定向/analyze/OpenSpec和纯原生编译后读取诊断，再按证据制定修正，不以猜测字号/字距或不可选择的图片替代SelectableText。

原生实际CoreText标题回退.PingFangUIDisplaySC-Bold，正文.PingFangUITextSC-Regular；继续只在Flutter纯fixture对默认/CupertinoSystemText/CupertinoSystemDisplay别名作TextPainter合成宽度诊断，正常字号不改生产样式，不把别名度量等同已确认实际回退字体。


### 历史气泡共同平面外观

同条件实际图蓝气泡下沿795–815采样，原生均背景244/247/251，Flutter最低232/235/239并延伸至825前；固定UIKit layer.mask裁掉原shadow，不能只照抄shadowRadius参数宣称效果一致。Android原Surface elevation2为不同有效参照。共同普通Flutter目标选实际UIKit平面气泡，去历史独有BoxShadow，不按平台分两套；保留颜色/82%宽/22与6圆角/16×14内距/正文行高、选择与业务。单生产文件微批，不写仅镜像BoxShadow配置的测试，复用排版/长按语义/关闭/历史完整Shell定向+analyze/OpenSpec，重编同纯iOS参考核验原始图相同外部背景；Android2dp差异显式记录，不称Android原生像素一致。


### 历史两倍字实际参考

扩展已有history-content为Flutter --large-text，独立.historycontent.large，原生history-content仍拒绝large（固定UILabel不随TextScaler变化，不假造原生大字）；其他互斥规则保持。纯fixture MaterialApp builder局部TextScaler2且默认正常，生产页不改；同正常合成内容，标题允许既有ellipsis，电话/字幕自然换行，关闭保持可操作。fixture/buildscript/既有fixture专项三tool/test微批；两个字号真实widget进入/关闭及既有排版/长按定向/analyze/OpenSpec，原生large和混language两个非法组合设备动作前拒绝；iOS实际大字图/具名关闭返回记录。系统设置及普通App不改，不把工具TextScaler称系统动态字体或固定UIKit大字配对，平台滚动仍需实际证据。


### 历史字幕空态原生配对

在既有history-content增加--history-empty仅该场景合法、独立.empty身份（Flutter可组合已有large）；只逐字提取固定renderDetail空字幕UIView/UILabel配置与约束范围，生成纯emptySubtitleView方法供参考builder调用，不编译原controller/服务。增加范围字节SHA，原生宿主按参数只组空组件，Flutter正式历史页同header和空rows/no recording；不修改生产行为。微批A extractor/nativehost/buildscript三工具，B Flutterfixture/既有专项两文件；默认/空×正常/大字fixture进入返回及原历史/字幕语义定向/analyze/OpenSpec，非法非history组合在设备动作前拒绝。两纯参考编译运行正常空态实际图与关闭，对实际差异另开小批，不假造原生大字或空历史无业务事实。


### 历史空字幕行高继承隔离

正常空态实际glyph框native651–688/Flutter656–693，空Text14未显式height/letterSpacing继承Material20行，与UIKit14自然17不一致。仅该空Text明确17/14行高及0字距，两平台同目标，28内距/中心对齐/文案/数据/录音/返回不改。生产page+既有fixture专项两文件微批，空场景1/2字号实际行框17/34与返回先RED，再原历史/header/typography/长按语义/完整Shell定向/analyze/OpenSpec；同pureFlutterempty重建原图对照，字形宽度固有差异仍不称已解决。


### 历史首次加载与失败共同展示

固定两原生首次Loading只有顶部28“正在加载记录”及top18/right20关闭，Error为居中6E6E73提示+间12重试；无合成标题、电话、时间或录音。Flutter content null仍显示“翻译通话记录”标题/LinearProgressIndicator，error为标题下合并TextButton。新增单职责TranslationHistoryLoadState widget，仅content null接线：共同14/17灰提示、加载顶部28、失败中心提示+12间隔蓝重试4圆角，按钮沿项目48热区而非UIKit36明确适配；同48关闭复用既有Semantics/current门禁。生产page提取已有close构造私有helper供两分支复用，不改动作。content非null保留现有刷新进度/失败重试、字幕、录音及后端事实，不把首次无内容修改扩散到旧内容刷新策略。生产widget/page+新状态专项三文件微批，先复现两主题正常/2x初次load/error无假标题、位置和仅重试/关闭动作，再验证load/error/content切换及原详情/录音失败分离/完整Shell定向/analyze/OpenSpec；纯参考场景实际初次load/error/恢复另微批，未完成不称原生整页V。

加载文案为两倍字号预留关闭控件所需横向空间（对称margin至少28、字号32缩放+37（含1点字距/像素舍入余量）），正常文案仍居中top28，大字可自然多行，避免与放大后的关闭图形重叠；不削减文字或字号。

共享关闭图形本页显式零字距，字号/行高/字重和48热区不改，初始状态专项使用夸张主题字距9/行高3，验证加载与关闭仍不重叠。


### 历史首次加载/失败原生纯展示运行参考

history-content扩展--history-initial none/loading/error（非none只该场景且与empty互斥），独立.initialloading/initialerror；Flutter可组合large，原生large仍拒绝。固定buildBaseLayout/showLoadingState/showErrorStateWithMessage三个纯展示方法逐字抽取并记录SHA，生成仅message/retry/stateStack属性的UIViewController，不编译原controller；removeRenderedContent仅首次无已有内容空实现，loadDetail/closeTapped回调仅参考宿主，不注册业务Service/音频。宿主合成retry once→原展示loading→2秒后本地内容reference，关闭设置finished抑制晚到；Flutter直接正式历史页同local状态和晚到门禁，不冒称repository/后端或原controller完整生命周期。工具A extractor/nativehost/buildscript≤3，B Flutterfixture/专项≤3；8范围字节核验、非法组合先拒绝、状态进入/返回/重试/等待中关闭定向/analyze/OpenSpec。两侧正常loading/error原图和实际重试/关闭顺序核验，UIKit全屏center与Flutter可用SafeArea center及36/48按钮差异明确，不能以数值替换原生字节凑图。


### 联系人与历史跨模块阶段回归

上次全量3598/1冻结5ad5552，后续已改联系人Skill返回/账号代际、共用记录日期（任务/历史两调用方）、语种占位、历史头部/字体行高/初次状态和纯运行参考；触发一次跨模块阶段全量。冻结生产2b0c43f9841e8868446397fbd273d443953aaf48，执行中不改lib/生产端口/平台/依赖；只允许整理文档，保留外部pubspec.lock28条host-only差异，不恢复/提交。全量--no-pub与日志实际输出计数/跳过/错误及复核freeze哈希，标准opt-in文档跳过若出现按实际范围另执行显式开关专项；无平台/插件/构建链新改，不重复普通业务双端构建/安装，也不启动SDK。结果逐项记录，实际运行和后端/签名门禁未因此关闭。


### P20评分弹层一次性返回与保存期门禁（阶段全量后执行）

静态核对TaskRatingRoute发现评分close直接Navigator.pop且捕获build时state.saving，成功onSubmit/反馈onDismiss也直接pop。沿联系人已确认的一次性返回规则，先专项复现：同帧两次close、旧close在提交等待时触发、成功关闭/旧submit回调、反馈重复dismiss只能退自己的弹层，不能误退结果/会话。待当前冻结全量结束再改源码；预计route+新专项两文件微批，弹层与成功反馈各有独立finished及mounted/current-route检查，close读当前provider saving而非旧snapshot；submit在await前/后检查自身当前弹层，成功才一次pop。保留资格/owner/幂等键/草稿/后端积分与保存禁退、失败重试，Controller/domain/backend不改；两主题RED/修后专项、原评分/回执完整Shell定向/analyze/OpenSpec；实际纯iOS回执/评分正常关闭/重试/只读恢复另验证，不把单次UI点击当竞态证明。

P20补充：成功反馈显示时，来源评分入口的旧onOpen也必须检查mounted、controller生命周期和来源路由isCurrent，禁止在反馈上叠加只读评分；新增Android/iOS双主题RED专项后实施，保留正常重新查看。

### 身份性别选择语义补验
纯iOS完整Shell实际选择男后蓝色选中变化而AX三个按钮均无selected；原Semantics(selected)与OutlinedButton的独立节点未合并。先增加双主题专项要求同一具名按钮节点同时有button、selected、enabled与tap，选择更新后唯一选中、忙态禁用无tap；RED后最小合并语义，保持既有视觉、输入、保存和认证业务。生产editor+新专项两文件微批，受影响身份UI定向/analyze/OpenSpec，隔离iOS重建实际复验取消与保存回流，无真实认证/用户资料。

### 完整Shell未登录与两步初始化独立参考
现有iOS shell固定UI_START_SIGNED_IN=true，不能用已登录首页证明登录到初始化。新增仅Flutter --shell允许的--shell-login，独立.shell.login身份/metadata，编译使用既有signedIn=false，沿AuthScenario无API/无真实短信/无持久凭据，初始化身份为空。非法非shell/native组合须在任何设备或原生读取前拒绝；测试工具以mock run/read确认零副作用，既有两步初始化与Shell登录定向验证。实际iOS只输入合成号码/验证码1234，协议UI仅合成本地状态、不打开或接受真实服务条款，检查错误验证码/正常登录→身份跳过或资料→模型返回→完成首页；IME失败有限恢复并保留未验，不改变系统键盘或以测试替代实际输入。工具脚本+工具专项两文件微批，无生产行为/SDK改变。

### 登录协议和初始化选择项语义闭环
独立未登录iOS实际发现协议两个同值switch（一个无名）、初始化性别无selected、模型名称按钮与无名radio分离。采用组件内显式具名语义边界、checked/selected/enabled及唯一onTap，exclude子重复节点，保留Checkbox/OutlinedButton/ListTile/Radio的可视样式与物理点击。协议只提供一个具名checked节点，链接独立保留；初始化性别唯一选中，模型一项对应一具名button含描述/推荐，busy/disabled无tap。先双主题专项RED，2生产+1专项微批，登录/初始化与两步Shell定向及analyze/OpenSpec，独立iOS登录身份/模型同流程复验，不修改认证、条款、网络、计费或保存逻辑。

### 初始化固定UIKit纯展示参考
读取固定bb9ff349 AIInitializationViewController确认真实UI方法与账户/服务/原三步动作同文件。新增独立build_initialization_reference工具，不扩大已有404行多场景脚本；提取enum/gradientAction/buildLayout/heading/identity/input/fieldGroup/gender/provider/card/badge/radio/error等纯展示原始字节并记录范围SHA，禁止Account/IdentityService/NSURLSession/SDK/通知/原rebuild/保存动作进入生成源码。原provider options用合成展示对象（Qwen/Seeduplex/V3同Flutter样例），host仅本地两步跳过/返回/选择/完成，符合当前用户两步决策，不复制原第三步或声称原controller业务跑通。工具extractor/host/builder三文件微批，合成方法边界/禁止依赖测试另微批，原始SHA核验与仅独立模拟器编译/实际图和动作；新参数拒绝非法设备身份，不改普通App/SDK/真实账户。源UI44字段/42性别/36返回与Flutter48热区等差异分别记录，正常布局配对与业务验收分开，中文IME/原生系统键盘不在本场景自动冒称通过。

### 初始化模型卡共同紧凑布局
新固定UIKit与Flutter同三项合成目录实际选中边span206/263px，差19点；固定Android V61ProviderCard也明确16横/15纵、名称16粗/描述12、5间隔、整卡点击且Radio onClick=null，与UIKit20视觉单选相符。共同Flutter目标采用16×15内距、名称16/19与描述12/14/5间隔、20圈/10实心/1.5边、1边/16圆角/12卡距、可见推荐11/13与2×6内距；正常短两行卡68高（整体已大于48热区），不让Radio或ListTile默认48/72布局强加19高。长文本/2倍字自然增高，不裁剪；单一整卡点击和上批语义/忙态/disabled/选择规则保留，disabled不能显示选中。按职责将InitializationModelCards从fields独立文件并export保持调用方，2生产+新geometry/interaction专项≤3源码微批；先四主题倍率RED卡高/圆圈/显式tracking、点击一次/禁用与长字，定向原初始化/登录Shell/analyze。真实iOS同.shell.login重建到模型采图与固定原生蓝边对照，头部/输入边框另微批，未处理模型capability缺行：当前domain无该字段，不能擅造后台能力事实，将另按固定policy装配核对。

模型卡参考证据补充：现有Flutter metadata git diff不包含新未跟踪文件，独立工具微批增加Shell初始化page/fields/model_cards三个实际源码SHA，重建前覆盖新拆分文件；不将hash清单当全部编译文件清单。


### 初始化顶部布局校准
固定UIKit顶部44高，Flutter现有18×2额外留白且左右44/60不对称。共同目标顶部最小48高（原生44与按钮36明确做可访问适配），标题在全页面中心，左右各保留76避让区；大字按标题实际行框增长，返回按钮48完整热区，跳过至少48。去掉顶部额外留白，将原22横边距移到内容及底部动作，不改变两步/草稿/忙态/保存业务。页面、新header、布局专项三个源码微批；定向初始化及Shell/analyze，独立iOS实际对照另验，不称自动测试为像素验收。


### 初始化身份字段共同样式
固定Android有效V61DemoIdentityInputField/GenderField与UIKit均有浅边框，现Flutter默认主题覆盖为深灰。共同明确输入各状态边框0x213C3C43（focus蓝0A84FF），姓名/电话15/18，Android占位13/16及0x5C3C3C43/medium作为统一目标；标签12/14及4B5563，gender13/16bold、选中0A84FF及1A/52透明底/边、未选F9FAFB/1F3C3C43。busy输入F3F4F6/6E6E73，不造可操作态；全部tracking0，字段/按钮≥48且大字增高，保留数字/11位/姓名128过滤与唯一选择语义。不改Controller或数据。fields+专项两个源码微批，定向初始化/Shell/analyze，纯隔离实际样式另验证。


### 初始化模型能力说明
固定Android V61CallProviderOptions及UIKit AIInitializationCallProviderOptions共有QWEN_OMNI_PLUS“支持系统音色和声音克隆”、DOUBAO“仅支持系统音色”。将此初始化纯展示策略作为InitializationModel getter，无网络/权限/可用性推断；已有QWEN_OMNI_FLASH规范化别名沿同已知provider，V3/GPT/unknown为空。卡在描述后4间距12/14自然增高并纳入同一具名语义；若描述已等于能力说明只显示一次，保持合成旧夹具不重复。两行卡68规范只适用于无新增说明，三行86。domain/card/专项三个源码微批，先RED能力文案与语义、未知不造说明、大字增长/禁用，定向初始化/调用方/analyze；实际纯参考能力目录下一工具微批，不将标签解释为已获克隆授权或真实声音验收。

能力配对工具微批：原纯UIKit宿主两已知项capability从空改固定策略同文案，V3仍空；builder将固定AIInitializationPolicy.m只读Git对象计算SHA证据但不导出或参与编译，不接服务。Flutter source metadata加入domain getter SHA。三个tool文件微批，既有5抽取/拒绝专项与1Shell参数专项、两隔离构建；同合成目录选中模型与说明实际图核验，旧两行几何证据仍保持对应旧场景。


### 联系人备注旧入口与旧弹层操作保护
正常纯Shell取消/保存/重入已运行，静态_ContactDetailRoute._edit无当前route或重复入口门禁，beginEdit可能重置草稿；旧ContactRemarkEditor直接controller action可影响后开的editor。只给详情编辑入口context mounted/current及editing门禁；编辑器改ConsumerStatefulWidget，以自身mounted/current和最新saving限定edit/cancel/save操作，生命周期结束的旧action不触碰新草稿，既有ref.listen服务端匹配关闭规则保留。详情仍单职责308行允许小增，不机械拆分；route/editor/新竞态专项三个源码微批，先重复编辑/旧取消保存输入RED，定向联系人remark/delete/notice/主Shell与analyze/OpenSpec，不新增网络或备注规则，不把正常实际点击当竞态验收。

### 普通拨号旧路由动作保护
普通拨号现有country/close/config及号码动作捕获旧页面回调，覆盖页或销毁后可能误pop或修改持久草稿。仅在宿主mounted、当前route且捕获controller仍为provider当前实例时允许操作；country返回再核验同一条件，旧owner结果丢弃。保留普通拨号与翻译拨号两层返回及关闭后草稿，不改号码/国家规则或权限。route与新竞态测试两个源码微批，双平台旧入口重复/覆盖页旧关闭输入/销毁旧动作RED后定向拨号及Shell验证，analyze/OpenSpec；翻译route另微批按职责评估487行。

### 翻译拨号旧路由与异步返回保护
翻译拨号本地controller在页面销毁即释放，现有旧digit/delete/clear/close/country/call缺当前route保护。增加mounted/current及setup provider identity检查；国家返回、预设/联网准入/会话准备返回再次检查，不在失效route推进通话，已准备的controller失效时dispose。独立国家导航helper承载push及定位返回，保持主route≤500；route/helper/竞态专项三源码微批，双平台旧覆盖动作/重复入口/销毁动作及合法返回定向，无真实外呼。弹层内部既有enable操作仍可在弹层打开时执行，不错误用父route current限制合法配置。

### 翻译预设弹层旧动作保护
已发现弹层finish未先检查mounted，options的enabled/prompt/language直接旧回调；关闭后重开可修改当前设置或访问失效context。以自身mounted/finished/current及controller mounted/ready限定弹层动作，语言导航入口与返回同样检查原context/current和controller存活；合法弹层配置仍可操作，覆盖语言页期间旧动作无效，关闭不拨号。presets与独立竞态专项两个源码微批，双平台旧关闭/开关/语言重复入口及正常语言返回RED/定向与analyze/OpenSpec，无真实外呼或配置契约变更。

### 翻译语言页销毁后回调保护
语言页现有_finish仅检查current，销毁后的旧InkWell/语义/返回会访问失效context。先检查context.mounted再访问ModalRoute，保持已选择与取消结果、七语种和具名语义；现有双平台大字语义专项追加销毁后重入旧选择/旧返回，两个源码微批RED后定向选择/预设/拨号及analyze/OpenSpec，不改布局或业务。

### 翻译模型弹层旧选择和刷新保护
模型弹层现有_close已mounted/current，但onSelect直接pop、refresh/retry直接setState或invalidate；旧回调覆盖其他页可误关页，销毁后可访问State/ref。统一_current检查选择/刷新/倍率重试，真实选择重新检查地区准入，刷新读取最新loading与access防过期回调；show入口/返回检查context/current/controller存活。既有model sheet专项追加双平台旧选择与刷新覆盖/销毁RED，两个源码微批；定向质量/选择/拨号及analyze/OpenSpec，不执行真实探测或改变计费配置。

### 海外翻译设置旧页面动作保护
设置页模型/区域和返回仍直接controller或pop，旧回调可能修改新配置或关闭覆盖页。共享页面增加mounted/current及controller存活ready、可选即时canEdit策略；正式route传入最新showOverseasSettings，受限页返回同样检查context/current。三个源码微批（selection/route/专项），先双平台覆盖旧back/model/region和销毁重入RED，追加地区变化未重绘拒绝，定向正式翻译与选择/analyze/OpenSpec；目录重试另微批，不新增服务/权限。

### 翻译服务目录旧重试保护
目录重试直接invalidate旧WidgetRef，销毁后可能报错，覆盖时或区域换代后可重试错误目标。保持ConsumerWidget，只在context mounted/current、该element当前widget区域仍等于捕获区域且最新目录是非loading error时invalidate。catalog_status/既有widget专项两个源码微批，双平台覆盖/销毁旧retry及同帧重复和旧区域回调验证，原区域迟到/空目录仍保留；定向目录/设置/翻译及analyze/OpenSpec，全部fake repository无真实服务请求。

### 预设海外设置入口按弹层归属拆分
拨号route的_extraOptions提前构造TextButton捕获父context，合法入口在预设弹层内，父route current门禁会误拒正常打开，现无门禁又允许旧entry重复push或弹层关闭后继续打开。将设置导航提取为独立TranslationOverseasSettingsEntry，父通过RouteProviderScope保留同container；entry使用自身modal context/current、当前setup identity及地区/ready/busy门禁，保留preview本地页与正式route。route/helper/新入口竞态专项三个源码微批，先重复入口与弹层关闭旧入口双平台RED、正常设置返回保留；定向预设/拨号/设置及analyze/OpenSpec，主route从500回落，避免继续堆职责，无服务查询/电话。

### 共同设置选择按钮唯一具名选中语义
iOS实际海外设置选GPT蓝框及返回摘要已确认，但AX具名button未显示selected；NativeSettingChoice只在匿名外Semantics设置selected，OutlinedButton内部具名节点未合并。改外层唯一container/button/label/enabled/selected/onTap并exclude子语义，保持视觉和OutlinedButton输入、48热区、大字。禁用仍可表示已有selected但无tap，不把当前选择当可编辑。共同组件/新双平台正常两倍字专项两个源码微批，先具名selected RED、视觉tap与语义tap各仅一次/disabled拒绝，定向翻译、开发者各直接调用方与正式Shell/analyze/OpenSpec；作用范围已由五调用方界定，不无理由重复全量，实际iOS重建确认selected另验。


2026-10-09 用户在分支对话批准移除正常实时翻译拨号页的“进入翻译通话演练（MOCK）”。演练仅保留独立迁移验收目录，不关闭全局开关，不改变真实拨号/模型/语言/返回及平台行为。
