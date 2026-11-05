- [x] 核对固定双端有效入口/首次流程/授权来源，记录旧iOS源测试与实现冲突。
- [x] 纯domain所有权/授权报告/端口及独立controller，初始化/读取/重复打开/迟到/返回/跨账号定向测试。
- [x] 默认未配置端口、独立Provider及共享设置入口/反馈，保持未授权/不可用事实，页面与连续流程验证。
- [ ] Android已许可SDK/SIM桥及最小权限接线，首次与后续设置/账号清理运行。
- [ ] iOS已许可SDK与首次说明/设置/通知清理接线，独立扩展与LiveActivity配置。
- [ ] 明确授权条件后双端真实SDK/权限拒绝/来电身份/退出清理验收。
- [ ] 整体验收后归档；未配置和真实未验项保持pending。

首批domain/controller/竞态测试三文件：12项所有权/初始化/重入/重复打开/返回读取/账号及代际作废/释放专项、4项架构共16通过，analyze7.5秒无问题；SDK端口仍待实际data配置接线，不称真实授权完成。

共享入口批：默认port不做设备工作；独立账号/号码/登录代际Provider、返回/恢复读取路由与五类事实反馈页，21项页面/连续/既有设置及6项Provider/邻接通过。token刷新不重建surface，换账号/号码和迟到明确授权报告隔离；真实SDK/首次说明/平台权限仍未实施，不将状态反馈页当SDK界面一致性验收。

本批最终analyze6.3秒无问题/OpenSpec38通过；新增Provider测试1项花括号提示按实际行修复后复验，无功能改动。首批16项+本批21及6项范围分开记录，非全量；未改插件/平台/依赖，不重复双端构建。

- [x] 固定两端SDK公开接口及Android AAR声明只读核对，记录SHA/加固/授权结果和部署缺口，未提交SDK或凭据。
- [x] 当前共享设置入口iOS合成实际运行，正常及不可用/返回证据，SDK画面仍待接线。

- [x] 按用户明确指令复制iOS test/pro及Android固定SDK到工程内依赖目录，逐文件校验/版本/架构/依赖记录；不使用提供路径构建。

SDK机械复制完成：KX test/pro各9、ASN1有效16、原生SDK内置资源15、Android AAR2共51文件逐项SHA一致；未引入原始_CodeSignature/签名材料。提供iOS_SDK是用户输入，保持不提交；工程Vendor副本加入Git。两KX arm64/I0S静态库、min12/SDK26.2已对象核验，未当模拟器可用；本批未实际SDK初始化/链接验收。iOS独立shell新卡→不可用→重新读取→返回设置已实际完成，SDK UI仍待验。

- [x] 工程内SDK环境链接：本地pod及device条件，Debug/Profile test与Release pro，固定依赖/资源；SDK availability编译事实及双端构建，不进行初始化授权。


2026-10-08 工程内可信SDK链接批：本地PhoneAgentTrustedCaller pod固定依赖/资源，Runner与pod均Debug/Profile=test、Release=pro；仅iphoneos链接KX/ASN1，availability不初始化SDK。pod install成功，Android首轮48.5秒及保留加固库后20.7秒Debug通过、iOS真机Debug无签名29秒通过。首轮strip警告后核对发现SDK原生库被改写，增加6库keepDebugSymbols后APK内12个ABI库全部SHA与AAR一致。51项目副本校验通过，Profile/Release实际build settings分别test/pro，未读取提供路径。完整iOS模拟器仍被既有APBToygerFacade真机对象阻挡（50.6秒），不是可信SDK真机库误链；独立pod模拟器编译继续核验。CocoaPods既有Profile自定义配置提示保留记录，未改原工具链或签名、不安装普通App/不真实授权。OpenSpec39项通过，其中其他对话的remove-manual-sip-account-settings不纳入本批提交。

独立PhoneAgentTrustedCaller pod模拟器编译BUILD SUCCEEDED；完整App模拟器仍受既有身份SDK阻挡，未把局部成功当整包通过。

- [x] 每页surfaceToken及完整owner的Flutter/native端口、晚到/释放/畸形报告定向验证；未配置native不初始化SDK。

2026-10-08 Flutter/native端口首批：每DevicePort独立随机surfaceToken及冻结owner/环境，prepare/read/open完整回显匹配，未配置不读不打开、release先作废且一次、迟到与换账号拒绝、真实authorized必须枚举及明确bool证明。新通道7项+既有controller12项共19通过，analyze3.9秒无问题；首次测试冗余foundation import提示已修复复验。尚未注册两端native或替换默认门禁，不称SDKUI完成。首次SDK大文件push11分钟无终态，核对进程/远端仍bff16eb后终止旧父及残留子进程，按同分支一次带lowSpeedTime60重试，结果仍待确认；本地提交已保存不force。

2026-10-08 两端native通道及正式Provider接线：Android只Class.forName initialize=false核对UI类，iOS只availability类元数据；两端prepare均configured=false，不调用SDK初始化、SIM/权限/推送/外呼。owner/token/environment校验及固定安全错误，web/local无设备接入，缺插件返回不可用；Provider按owner及环境创建独立surface，token刷新保持。Android最终Debug7.4秒/iOS真机无签名9秒通过，29项可信模块测试及analyze5秒通过、51文件再次校验一致。iOS首轮新类不可见因本地pod未刷新，重新读取umbrella确认后pod install一次，修正构建9.8秒通过；后续去掉控制字符和独立debug包环境判断，最终双端复验通过。手写微批为Android2、iOS公开桥3及AppDelegate1、Dart2分别实施，生成lock单独机械。SDK真实部署配置再次仅询问文档位置不索密钥，SDKUI/授权/来电仍未完成。

推送恢复记录：限速超时重试session47764最终exit143，未确认终止来源；重新只读远端仍bff16eb。本地SDK与接线提交存在，不声称已推送，不盲目叠加更多push，网络上传问题保持待恢复。后续独立UI/资源工作继续。

- [x] iOS首次说明纯Flutter页面/三图/减少动画与短屏大字验证；正式流程等待配置后接线，不标记SDK引导运行验收。

2026-10-08 iOS首次说明纯UI批：三原图由固定bb9ff349对象导出工程assets并SHA记录，34标题/17徽章说明/蓝竖向渐变/56开始/2秒三图轮播按有效源码迁移，保留左边缘返回且无障碍custom返回，不添加原生没有的可见返回按钮。320×568字号1/2均可滚动触达开始，轮播后台暂停/恢复、减少动画/读屏稳定、忙态不开始与边缘退出5项通过；analyze10.6秒无问题/OpenSpec39通过。首轮缺少semantics显式import及if花括号已按实际SDK定义修复后有限复验，失败不计通过。轮播被路由覆盖暂停有实现，当前自动只实测后台暂停；正式SDK初始化后guideSeen及开始/取消接线仍pending，纯页不标记运行像素验收。调研误猜flutter_ios_reference.dart不存在，按rg实际ios/flutter_bubble_reference.dart与build脚本继续，未覆盖其他文件。当前pubspec.lock只有153个host URL差异非本批资产需要，不加入我方提交。

2026-10-08 iOS独立首次说明运行：新增唯一trustedintro及large包ID/产物，只正式pure Flutter说明页，无SDK/账号/网络端口，源码与图资源hash记录。普通字号实际三图轮播、开始显示“未调用SDK”、辅助技术返回显示“已关闭”通过；实际大字号页无溢出日志但需滚动到底，CUA一次Group scroll不改变位置，保持真实手势可达待验，不用点击离屏AX按钮冒充滚动。截图已查看并保存ignored normal/large-initial，未替换普通App。fixture analyze3.5秒无问题/Python compile通过，继续配置来源用户已答复“从参照项目读取”，只本地忽略配置不提交密钥。

- [x] 按用户授权读取固定参照双端凭据，仅ignored本地/generated，环境编译隔离、缺失门禁和构建；不提交或输出密钥。

2026-10-08 用户明确参照凭据授权后：固定对象提取iOS test/pro及Android dev/prod配置到ignored .local与原生generated，所有输出0600；4项混合Groovy单双引号/环境顺序/生成隔离/未忽略拒绝/符号链接父路径拒绝/缺失与换行验证通过（4个testcase）。首轮Android单引号AppSecret解析不符，安全诊断仅输出字段/引号形状，有限修正后提取成功，不输出值。iOS本地pod private头与Generated编译、Android私有反射读取完成，SDK初始化仍未接。Android Debug12.5秒/iOS无签名27.5秒通过；实际iOS pod及Runner.debug.dylib含测试配置且不含正式secret。首轮仅检查Runner stub误判test缺失，按实际Xcode debug dylib修正；宽泛AppKey字节扫描命中既有OCR/号码归属地二进制，不当作配置泄露，所有tracked文件AppSecret命中0。Android参照dev/prod实际同凭据，如实保留，不能声称服务端许可分离；各variant仍只生成其选定配置。未提交Generated/.local，未初始化SDK或真实授权。pubspec.lock host差异继续不纳本批。

- [x] Android已配置SDK初始化与首次/后续UI、surface Activity退出和旧owner释放隔离，纯规则/JVM及编译验证；真实SDK/账户解绑/授权查询另pending。

2026-10-08 Android SDK运行源码续批：私有配置→SDK init，只初始化返回后可配置；首开openIncallUi、后续SettingActivity及原SDK回退，引导摘要记忆不置authorized。完整surface owner与registry独立纯类，当前SDK Activity弱引用/host返回完成、旧token释放不关闭新窗口、账号切换回收旧surface，不清SDK未知存储、不绑定SIM或启用来电后台。Debug构建7.3秒通过，4项JVM owner/号码/epoch/environment/同账号新页/严格参数/无凭据报告测试BUILD SUCCESSFUL20秒。测试未运行SDK初始化或UI；Android真实授权API仍缺，read仅readyToConfigure，实际SDKUI/账户解绑/权限/SIM/来电仍待验，不将源码接线当平台业务完成。

- [x] iOS SDK初始化/严格授权/原生设置退出与Flutter首次说明guideSeen串接，Foundation及连续流程、真机包编译验证；真实SDK和APNS/来电另pending。

2026-10-08 iOS可信SDK生命周期与正式说明接续：App级私有初始化缓存/15秒有限超时，严格authStatus/isAuthorized/authorized解析，冲突/未知仅可配置；表面owner冻结完整token/账号/号码/epoch/env，取消/迟到/重入只完成一次，独立dismiss代理不关闭新页面。账号环境摘要guideSeen独立于授权。Flutter可信入口初始化就绪后只自动进入一次，首次说明开始→SDK、取消→设置首页，已看说明直接SDK，退出回读→首页。Foundation12授权案例及owner/request两组通过，无SDK运行；可信模块37项通过，新增双端连续4项通过，analyze无问题，iOS真机无签名9.2秒构建与51副本哈希通过。首轮Dart交叉接口提升和route导入/async mounted提示已修正；连续测试iOS转场帧不足，诊断确认guide=1/open=0/intro=1后按逐帧完成过渡复验4通过，不改变生产流程。微批按授权解析2、SDK client2、owner/request各2、surface2、插件2及AppDelegate1、Dartdomain/data/controller3与route1实施，生成pod lock机械。真实SDK/权限/账户解绑/APNS/扩展/来电仍未验，不归档；推送旧限速重试失败，未称远端完成。

- [x] iOS账户推送独立串行owner/token/通知门禁，迟到成功补解绑与未知结果阻止新绑定的Foundation规则及专项；实际App消费者后续接线。
- [x] iOS SDK bindRid/APNS/账户Provider消费者源码接线，串行driver及account/root定向和编译验证；未实际发送推送。
- [ ] iOS安全身份事件解析/展示/LiveActivity扩展及签名/真实推送验收；规则测试不能当来电完成。

2026-10-08 iOS账户推送串行规则续批：独立Foundation state冻结账号/号码/epoch/env/token，通知和64hex token及SDK就绪门禁、重复/旧请求拒绝、旧绑定迟到成功先解绑、解绑未知阻止新账号、显式重试先清理、签出清理规则通过合成测试。补同账号绑定失败也不能误判confirmed，先cleanup再重试。该类尚未连接真实SDK bindRid/APNS或账户Provider，不触发通知/SDK，不将规则测试标为推送完成。iOS无签名10.2秒编译通过；新增guide acknowledgement严格bool/迟到释放2项，DevicePort共9项通过。手写state h/m/test三文件微批，pod私有头1文件及lock机械。只读固定iOS路径首次漏PhoneAgent层，按ls-tree重定位一次；误猜app_shell只读不存在后用rg确认phone_agent_app，未产生产品副作用。整体来电/APNS/扩展/SIM仍pending。

2026-10-08 iOS账户/APNS消费者与SDK执行端续批：root仅同步账号/号码/epoch/env，不接触APNS token；native consumer代际防旧引擎detach/更新，App级Registration读取现有通知授权、不主动申请，换owner先暂停旧许可缓存并回读。native APNS token只内存；driver冻结当前owner，bootstrap/请求各自去重，旧成功先解绑、未知结果不重放，当前owner显式设置请求才可重试失败清理。固定bindRid四参数/解绑空格语义接线，未返回SDK请求无超时重发；同账号失败绑定也先清理，设置关闭不解绑账户。固定号码规范化5项、driver合成bootstrap/迟到/重复/未知/退出组通过；可信+架构50项、账户Provider追加3项及auth邻接共7项、root/widget/nested/chrome10项分别通过，analyze3.2秒无问题。最终iOS无签名6.8秒构建、plutil及51SDK哈希通过。Debug/Profile=test+APNS development，Release=pro+APNS production实际showBuildSettings核验，不代表签名profile能力通过。微批SDKclient2、state2、driver h/m/test3、Registration h/m/plugin3、Dartdomain/data/provider3、root1、号码 h/m/test3及client/surface/pod3、工程plist/entitlements/PBX3依赖执行，generated pod lock机械。未安装普通App、未真实SDK初始化/APNS注册/通知/来电；verified身份事件/展示/LiveActivity/Extension及真实签名仍pending。远端只读最新仍bff16eb，本地073b862等提交存在，前两次上传失败后不冒充已推送。

- [x] 原生来电payload精确字段/当前called号码/opaque token内存隔离及Activity新鲜窗，纯Foundation提取和合成专项。
- [x] SDK结果展示白名单/uncertified分支与来电独立owner/event代际、迟到/退出/重复纯Foundation专项；真实SDK事件消费另pending。

2026-10-08 来电身份Foundation续批：精确root token/phoneno/targetNumber/sequence、规范called当前账号、token冻结且不入预览；预览强制pending并丢授权/头像URL。SDK明确code1且有效字典才形成白名单verified；showType6为uncertified，失败不使用SDK/推送自称验证，caller/called/sequence冻结不可覆盖。IncomingDriver独立账号/epoch/env与事件代际，重复push/bootstrap/parse回调各去重，切账号/来电结束/新事件拒绝迟到成功，签出关闭显示；新鲜窗20分钟及未来60秒inclusive，非法时间不创建活动。payload/evidence/driver三组Foundation合成测试通过（未调用SDK），iOS无签名最终8.6秒构建通过，源类分别58/40/102行。三类各h/m/test三文件微批，pod private header1及lock生成机械。首evidence测试尾换行按原生trim规则被去除，读取实际Field后改内嵌控制字符复验；IncomingDriver首blocks不支持dot copy编译失败，重读实际行改[block copy]一次复验成功，不把首轮失败计通过。SDK parseIdentityToken执行、通知事件消费、PSTN结束关联、Flutter凭据展示及LiveActivity扩展仍未接，不将纯规则当来电完成。

- [x] iOS SDK身份解析执行/安全证据输出、独立EventChannel与后台通知完成源码接线，Session/Driver合成与真机目标编译；真实推送另验。
- [ ] UN前台/点击通知消费者、Flutter凭据Host/UI、PSTN结束关联和LiveActivity扩展接续。

2026-10-08 原生来电SDK执行/事件通道续批：SDK verifyIncomingPayload只收private冻结payload，初始化确认后调用固定parseIdentityToken；15秒只读解析有限失败，SDK回调先白名单映射，不把原始字典/token送Flutter，重复/迟到一次完成。IncomingSession持有事件流与后台完成请求，旧引擎listener/cancel/owner更新隔离，重启/账号/来电结束取消旧后台请求；pending不报告验证成功，明确结果或25秒有限完成，未知push返回未处理。Plugin注册独立EventChannel并接UIApplication后台通知；源码尚未接UN通知前台/点击与Flutter凭据Host，未真实SDK/APNS运行。Driver与Session两组Foundation通过，增加引擎替换后旧listener/callback专项通过；iOS无签名9秒编译通过，三个主要类117/171/91行。client/driver头及client实现3文件、driver实现/test2、Session h/m/test3、Plugin/podspec2依赖微批；pod lock生成机械。只读曾猜Pods/Flutter头不存在后按rg找到固定Flutter.xcframework官方头，确认FlutterPlugin后台通知方法BOOL返回，未尝试未知UI控件或SDK请求。下一项继续前台通知消费者与纯Flutter凭据展示；OS来电关联/LiveActivity与设备推送仍pending。

- [x] Flutter安全身份model/DTO与独立EventChannel，owner/环境/验证枚举/未知字段/旧流合成验证。
- [x] Flutter纯凭据页原图与四状态/短屏大字、独立root展示host及当前事件关闭；UI与连续导航验证。

2026-10-08 Flutter来电安全数据/状态续批：纯domain四验证状态/typed身份、DTO严格完整owner/env/事件UUID/布尔新鲜/当前called号码，忽略signStaus和推送authorized，type6不认证、未知/畸形清空。native incomingEventsAvailable只环境/链接元数据，缺插件先拒绝EventChannel激活。data共享App级broadcast native stream，显式Subscription/controller取消不等待下一事件，重叠owner旧取消不关闭新listener；Controller用户关闭的同事件不会因晚到verified重开，旧账号一经作废不得回活，跨owner/错误/流终止清旧证书。Provider独立于设置，token刷新同stream、切账号/签出释放旧流，local无Native订阅。最终DTO6/port5/controller4/provider2及architecture4共21项定向通过，analyze2.9秒无问题；native probe iOS无签名7.2秒通过。首fixture窄Map类型改为显式Object map并校正addAll；从未订阅的unicast close等待导致测试30秒超时，改broadcast fixture。新增真实channel双订阅暴露async* awaitfor取消等待，阶段诊断仅打印取消位置后改显式subscription、共享native流，5项复验通过；生产修复不靠额外emit结束取消。永久作废替换未匹配格式化单行，已按真实source apply_patch并追加恢复旧tuple仍拒绝测试复验4通过。微批domain/DTO/test3、data/nativeprobe/test3、controller/provider/test3、provider专项1及定向修复2执行，无真实SDK/APNS或普通App安装。root凭据Host/UI还未接；9原图另机械复制verified等待下一UI批，不纳本数据提交。

2026-10-08 可信身份纯凭据UI批：九张固定原图工程assets逐字节校验，深灰背景/黑色圆角panel、头像/身份状态及verified非type6凭据卡迁移，缺字段不编造证书；长文本与320×568两倍字号可滚动触达真实返回。四状态/双平台短屏/显示类型/时间规则7项定向通过，analyze10.3秒无问题。首轮semantics句柄addTearDown晚于框架检查，改测试内显式释放；编辑时运行中测试读到旧teardown发生双释放，确认进程结束后按最终文件复验7通过。未安装普通App或调用SDK，不称像素或推送验收。root Host、UN前台点击/PSTN/LiveActivity仍后续；pubspec.lock他方host差异不提交。

2026-10-08 凭据root Host续批：App独立订阅当前来电Provider，单一owned credentials路由原位更新pending/verified及新事件；事件结束/账号作废只移除本路由，覆盖其上的其他业务页不受影响。后台暂停新展示、前台恢复同步；系统返回冻结显示事件id，已pop旧路由不更新为新事件。root/嵌套导航/chrome/Provider/Host14项通过，新增关闭旧A同时到达B专项及Host3项复验通过，analyze5.4秒无问题。未真实SDK/推送/普通App安装，UN前台点击、PSTN与扩展仍pending。源码误猜Sources目录只读失败后rg确认Classes，未副作用。手写Host/app/test三文件微批，其他pubspec.lock不提交。

- [x] iOS UN前台/点击代理链与当前consumer路由、未知通知保留及completion一次，离线专项和编译验证。

2026-10-08 iOS UN前台/点击续批：App启动super结束后安装App级relay，保存原代理并转发未知通知、其他点击动作和通知设置；当前SDK Session接受的默认点击/前台通知接安全身份流，系统呈现回调立即一次完成，不把接受当verified。当前consumer替换/旧detach防护与同步异步重复completion、原options保留Foundation组合通过；iOS无签名25秒构建通过、51SDK哈希一致。core h/m/test3、relay h/m/plugin3、公开header/AppDelegate/podspec3依赖微批，pod lock机械。patch首轮podspec上下文不匹配未写入，重新读取三个文件确认后按真实行一次修正。无真实UN投递/SDK/普通App安装，不称推送验收；冷启动账号恢复前推送缓存及PSTN关联/LiveActivity待完善，未归档。当前pubspec.lock他方持续更新不提交。

- [x] iOS incoming UUID/current event结束关联、outgoing/旧通话/多通话隔离专项与CallKit源码接线；真实PSTN另验。

2026-10-09 iOS系统incoming结束续批：Foundation UUID/event关联只取唯一未占incoming、outgoing不影响、旧占用UUID不复用新事件/账号，多incoming歧义保持未关联；SystemCallObserver只观察现有CXCall不发起电话。Session冻结consumer+event再次校验结束，lifecycle与Flutter流同时清理，迟到SDK不能复活。关联组合和Session增加旧event/consumer拒绝、当前结束专项均通过，无SDK/实际电话。首轮iOS8.1秒链接缺新增类，实际Pods sources未刷新；pod install后确认新m纳入Sources，有限复验无签名8.2秒通过，51SDK哈希通过。旧header glob不存在只读诊断失败后实际PBX确认，不重复旧glob。关联h/m/test3、Session h/m/test3、Observer h/m/plugin3、podspec1微批；pod lock机械。CXCall不提供号码，源码为时序关联而非真实号码验证，实际PSTN、多来电、冷启动仍待验；LiveActivity下一批。

- [x] 独立LiveActivity extension/原图视图/共享属性、公开前台创建与当前身份生命周期清理、固定deep link、编码预算和编译验证；后台push-to-start服务端契约和真实锁屏另验。

2026-10-09 LiveActivity工程/安全生命周期批：独立WidgetKit extension按bb9ff349原生锁屏/灵动岛240行视图适配，13图资源副本SHA、共享属性/默认头像，native verified+fresh/current event才投影，当前时间再次核对20分钟窗，编码预算3500及实际attrs+state<=4096，iOS16.1+允许且前台才公开创建。无远程头像/私有size回退/日志token；账号/事件/PSTN结束清本类型活动，异步代际保护/20分钟到期/重启孤立清理。固定深链只唯一UUID且当前freshverified；显式presentationRevision可重新展示，旧页关闭与低版本不清/复活新展示。Projection纯Swift组合、Native URL白名单组、Session增加独立lifecycle/显式revision/旧event/过期未来拒绝通过；可信模块及root/导航/chrome88项通过，analyze3.4秒无问题。iOS最终无签名8.2秒、Android Debug12.8秒、extension独立模拟器BUILD SUCCEEDED；Debug/Profile com.chaken.phoneagent.test.TrustedIdentity、Release com.chaken.phoneagent.TrustedIdentity，1.0.0+1与App一致，extension16.1而App15.5，plist/PBX及51SDK哈希通过。首轮extension嵌入末尾造成Thin Binary cycle，按真实phase移到其前6.9秒构建通过；Foundationfixture callTime误用秒，固定payload契约ms后复验；showBuildSettings空值split错误，改partition后3配置核验；Ruby系统/GEM路径不符后按实际pod wrapper GEM_HOME恢复。首次delta路径猜错写入未发生，rg实际trusted-caller后写入。核心微批domain/DTO/controller3、Host/test/test3、Session h/m/test3、公开Plugin h/m2、projection/test2、attributes/manager/plist3、AppDelegate/Info2、Link h/m/test3与Plugin/pod2；原图/source适配及Xcode脚本/PBX作为机械接线记录。extension target-only输出ios/build已移ignored local，不提交缓存。未普通App安装/真实SDK/推送/锁屏或签名；公开API后台创建不可用，可信push-to-start服务端契约仍pending，不能称整体来电完成。

2026-10-09 凭据独立UI运行批：唯一Flutter trustedcredentials/large及固定bb9ff349原生ViewController+固定SnapKit纯宿主，普通App不替换、不注册SDK、无账号/推送/外呼/远程头像URL。原生固定视图源码未改，合成同姓名/企业/号码/日期/编号/issuer；两侧已实际查看verified整页与pending/uncertified，failed AX及四状态返回通过，原图卡片/panel/顶部/返回与状态流程接近，字体引擎微差及普通App业务全链路不能用此局部证据冒充通过。Flutter长文本两倍字实际拖动到Home并返回，通过；首次实际图发现元数据贴装饰边框，底部留白按字号放大、正常字号仍38，重建后实际图全部三行避开边框并返回。首修num无法传double，读取真实编译错误后改38.0/1.0一次复验，页面7项通过、analyze3.4秒无问题。纯fixture先analyze3.9秒无问题/Python compile，通过Native Swift+SnapKit实际编译启动。截图ignored native/Flutter verified及large scrolled/fixed20261009，sources/hash manifest保留；Native fixture dark trait明确设定，不能代替普通App全局主题验证。源码微批fixture/builder2、NativeHost/buildscript2、cert1；不生成SDK权限/签名或缓存提交。SDK真实UI/来电/签名/push-to-start、AndroidSIM仍pending，继续。

- [x] 凭据原生固定纯宿主/Flutter独立同数据四状态与返回实际演练，两倍字长文本物理拖动/底部边框留白复核；普通SDK业务运行另待验。

- [x] Android固定SIM纯规划与号码/单卡/多卡/fallback专项；设备权限读取、账号写入清理后续接线。

2026-10-09 SIM纯规则与说明手势续批：固定Android大陆号码/无登录无卡不写/单SIM实际优先/多SIM只secondary或最后slot fallback、slot去重与负slot过滤，5项JVM全通过（12秒）、Android Debug7秒通过，未读取硬件或执行SDK写入；设备权限/账号清理下批。javap首次误取core AAR无SPUtil/SIMUtil，读取两个AAR class索引后确认UI AAR公开SPUtil put/get(context)/SIMUtil接口，无反编译受保护Helper。JVM XML初猜android/app/build不存在后rg root build/app实际结果5/0/0。iOS说明两倍字两次CUA物理drag仍不移动，未继续盲目重试；新增持续touch中2秒轮播换图+fling到底点击专项通过，说明全部6项通过/analyze3.9秒无问题，证明widget触摸可用但不冒充模拟器实际滚动成功，待验保留。微批SIM planner/test2与gesturetest1，既有pubspec.lock不纳提交。

2026-10-09 Android SIM归属纯规则批：完整账号/号码/epoch/env冻结，表面token独立；storage key仅SHA256摘要。已知SIM键变更前持久journal，失败/未知写结果保留待清理并阻止新owner；仅清仍等于本App写值的键，SDK用户修改及预先相等未知值不认领/不清。旧consumer更新/关闭/同步隔离，签出和冷启动第一条nil账户清恢复journal；发现attach owner=nil时首nil可能跳清，追加receivedAccount与专项修复。SIM规划5+ownership6+owner3+accountState4共18项JVM通过，Debug5.1秒编译通过，设备Store/读取/账户平台桥尚未连接，不真实SDK写或读SIM。微批ownership/test2、owner/test2、accountState/test2；所有源码<500。推送恢复确认原Git进程已结束后新HTTP/1.1+postBuffer+有限lowSpeed transport尝试成功，remote b531ae8→76b5531；此前SDK/接线/UI/扩展本地提交均已上传，不force。READ_PHONE_NUMBERS固定原生已声明，当前merged仅READ_PHONE_STATE；后续按现代Android号码独立权限门禁补声明，不自动申请。说明6项触摸通过仍不冒充设备滚动，pubspec.lock他方差异不提交。

- [x] Android已知SIM归属journal/完整owner与consumer、未知清理阻止新写/用户改值保留/冷启动nil账户纯JVM规则；设备适配后续。

- [x] Android设备SIM权限分版本读取/私有journal SDK已知键适配、App级完整账户consumer与设置前后接线、旧SDK窗口销毁门禁、定向和构建；真实设备另验。

2026-10-09 Android SIM设备接线批：existing READ_PHONE_STATE决定slot读取；API30+号码独立READ_PHONE_NUMBERS，低版本State/Numbers门禁，SDK公共SIM工具及Subscription API均有限失败；无SIM/无State不写，未知号码只使用固定规划的登录fallback，不作为真实SIM或授权。工程私有JSON journal与SPUtil context已知SIM键适配，App singleton完整账户consumer接root updateAccount，设置前/实际SDK窗口销毁返回后同步。账号变化先关闭owned SDK窗口，App级等待真实onActivityDestroyed后才清旧写入/新owner，跨引擎旧consumer关闭不覆盖新请求；失败固定安全码不输出号码/密钥。surface拒绝负epoch及全部控制字符。最终可信JVM25项通过（2秒，规则和权限合成）、账户/同步/配置连续Flutter11项通过、analyze4.4秒无问题、Android Debug18.7秒通过；未读取真实SIM、SDK初始化/授权/窗口/电话/普通包安装，Activity生命周期保护仅源码/编译，不当设备验收。微批policy/test2、Store/Reader/Bridge3、Dartport/test/Manifest3、Channel/Runtime2、Surface/test2；App级销毁门禁Bridge/Runtime2复核，所有源码<500。pubspec.lock其他任务差异不提交。

- [x] iOS首次账户恢复前单条白名单内存通知缓存/25秒到期/首nil或号码不符丢弃/旧consumer隔离，Foundation专项与编译；实际冷启动推送仍待验。

2026-10-09 iOS首账户恢复通知续批：IncomingSession仅第一条账户状态前保存最多一条严格白名单新鲜通知，opaque token只native内存，25秒timer代际过期；系统callback立即NO且不bootstrap。首owner先取走缓存，再重新核验当前号码/新鲜时间及25秒收取窗，nil/错号码/旧consumer/引擎替换/结束丢弃；同号码重入owner变更与结束的generation也阻止迟到消费。7组Foundation recovery加畸形结构/过期通知/首次nil关闭窗口通过，既有Session背景completion/迟到/深链revision专项通过；iOS Debug无签名构建与51副本哈希通过，无真实SDK或推送。首编译仅forward class缺完整payload import，重读当前两个source后补import一次复验通过。header/Session/test三文件微批，source181行；未覆盖Plugin注册之前通知、系统终止/真实冷启动APNS及跨进程绑定账本，不把内存合成当实际后台验收。

- [x] SDK退出时精确移除设置owned route，覆盖凭据/其他业务不关闭，定向连续与分析；修正版本设置旧断言和窄屏lazy列表测试，不删除已批准可信入口。

2026-10-09 SDK持久写确认增量：SPUtil.put公开返回void，设备Store写后通过同context公开get核对目标值，未确认抛固定异常交ownership保留journal/阻止新owner；不把void返回当已保存。Android Debug定向编译通过，未实际执行SDK读写；既有纯ownership写失败/未知状态规则25项已验。本改动仅Store1文件；本轮Flutter全量冻结7a0b656进行中，未编辑其Dart/tests。

2026-10-09 当前功能台账收敛：NF32上方当前摘要同步用户已删除手动SIP偏好入口，原始75e0e2静态审查保留；新增NF33/NF34工程/SDK私有配置/Android SIM/iOS通知与扩展事实表，源码/自动/纯UI/真实验收分开。原remove-manual-sip提交b531ae8已验证为origin/codex/dev_zys祖先，推送任务补勾，先前失败追溯保留。Info实际background audio+remote-notification及LiveActivities=true核对；发布/签名/实际SDK/电话/安全模型接口仍pending。OpenSpec39通过/diff检查，文档微批3文件，无业务变更。不重新请求SDK配置来源；仅异步请求独立国内模型短期配置契约。只读猜测Registry独立文件/额外Release entitlement/domestic旧任务或页面路径未找到，均用rg实际清单恢复，未产生副作用、不扩展权限。

2026-10-09 全量与SDK覆盖route修复：冻结7a0b656全量5分04秒3568通过/1跳过/3失败，两项设置版本专项旧断言要求可信入口不存在，另窄屏Shell直接查lazy未创建about卡。按当前可信批准范围只修测试为入口存在、先真实滚动创建目标；未删业务入口。SDK正常退出回读后精确关闭owned设置route，上层其他业务保留；失败保留设置错误页面，不误pop上层。新增双平台成功/失败覆盖route4项，相关flow/Host/设置/三尺寸Shell合计16项通过、analyze无问题。源码route/test两文件微批，旧断言与滚动test两文件另批。未改平台/依赖不重复双端构建；该定向不当全量green，冻结修复后将进行一次里程碑复验。iOS纯说明当前CUA scroll坐标与返回AX/坐标均无效果，刷新AX截图后有限重试无变化，App仍为独立UI说明/普通包未动；不重复同路输入、不宣称物理滚动或返回成功。既有widget6项仍只是自动证据。

- [x] Android SDK未确认launch与迟到Activity创建隔离、App级旧窗口回收和25秒固定反馈，纯JVM与编译；实际SDK时序另验。

2026-10-09 Android SDK迟到窗口续批：纯SdkLaunchGate冻结完整surface/consumer，一条未确认launch阻止下一打开，旧surface释放不作废新launch，当前/退役/换账号号码epoch环境/换引擎分别核对。App级observer在SDK Activity真正创建时消费launch，退役窗口先finish并等待销毁后处理最新账户；旧Runtime关闭注销observer也不丢全局保护。25秒未观察到窗口只返回SDK_LAUNCH_UNCONFIRMED，未确认请求仍保留，不自动重发或猜测取消成功。新增4项规则与既有可信合计29项JVM全部通过（11秒），Android Debug15.6秒通过；未运行真实SDK/窗口/权限，真实SDK多级窗口/异步启动效果仍待验。gate/test2文件微批、Bridge/Runtime2文件微批，分别25/47/97/179行，无文件例外。Flutter全量修复复验仍冻结006ae55进行中，未在其运行时编辑Dart/test。

2026-10-09 可信/root/导航里程碑全量复验：冻结006ae55，flutter test --no-pub expanded4分36秒3575项通过/1跳过/0失败。此前7a0b656的三项旧设置断言/lazy目标失败已经16项定向修复后全量消除，当前真实电话/SDK/签名/完整UI仍pending，不能用green替代验收。Dart/test冻结期间后续仅Native延迟launch保护改动，另29项JVM及Android Debug15.6秒通过，iOS最新无签名9.6秒构建。既有pubspec.lock28行host URL他方差异保留，未提交/恢复。继续尚未完成子任务，不归档。

- [x] Android未确认SDK launch等待仅宿主连续前台计时，系统授权pause/resume和旧timer隔离，JVM专项及构建；真实权限流程另验。

- [x] iOS冷启动结构候选沿用既有字符串/非布尔数字target提取，恢复后当前owner再核验，数字/布尔/错号码专项及编译。

2026-10-09 Android SDK前台等待边界续批：未确认launch的25秒只算宿主连续foreground；系统授权/角色Activity使host pause即作废代际，resume重新计时，实际SDK Activity创建结束此等待。纯gate加入旧timer/旧surface暂停不能改新surface、pause/resume/已到窗口/retire组合，可信JVM31项5秒通过；Android Debug5.3秒通过。仅Handler装配+纯规则，不运行SDK或系统权限，真实角色流程仍待验。微批gate/test2、Bridge/Runtime2；未改Dart，不重复3575项全量。

2026-10-09 iOS冷通知数字target续批：新增仅结构candidate factory，复用既有Text的字符串/非布尔NSNumber规则，不把candidate当当前owner或认证。缓存消费仍按真实owner重新提取和时间门禁；修复cold路径仅字符串接受而正常路径支持数字的不一致。冷通知7组及畸形/过期/nil窗口、新增数字target延迟至owner再bootstrap/parse一次、布尔target拒绝通过；已有payload字段/token冻结/号码/新鲜边界与Session后台completion/consumer/深链revision三组Foundation通过，无真实SDK。iOS无签名Debug9.8秒及51SDK哈希通过；payload h/m/Session3文件微批、专项test1文件另批。共享Dart未改，全量3575通过/1跳过证据保留，不重复全量；真实APNS/SDK/签名及Android授权查询仍待验。

- [x] Android固定10个SDK Activity宿主portrait声明、SDK/iOS方向校验与APK合并/构建，真实SDK方向另验。

2026-10-09 可信SDK竖屏配置批：宿主Manifest明确覆盖工程AAR公开清单的10个SDK Activity为portrait，Vendor文件未改；校验器新增Android清单完整性及iOS iPhone/iPad portrait检查，51份SDK哈希与Python语法通过。Android Debug3.6秒构建通过，aapt合并APK确认10/10为portrait；首只读解析误用E/A格式未匹配，读取实际E:/A:格式后有限修正一次成功。iOS既有UIRequiresFullScreen=true且双设备方向均portrait，无需重复修改或构建。源码Manifest/校验器2文件微批；未安装普通包、初始化SDK或执行页面旋转，真实SDK页面方向及系统角色流程仍待验；既有3575通过/1跳过全量证据保留。

- [x] iOS原生设置surface当前账户及engine门禁、账户变更立即作废和非负epoch，纯规则与构建；真实窗口切换另验。

2026-10-09 iOS原生设置账户门禁批：root同步完整账户时surface立即冻结账号字段；签出/号码/epoch/环境变化关闭旧窗口并结束旧请求，prepare/ready/初始化迟到均核对当前账户。旧engine除释放自身外不准更新账户或执行SDK；push消费者代际共用当前判定。owner拒绝负epoch，与Android一致；Foundation原有owner/可变输入/回显白名单加完整账户/签出/四字段变化/布尔和负代际通过，iOS无签名Debug7.6秒通过，无真实SDK。owner h/m/test3文件微批、surface h/m2文件微批、registration h/m/plugin3文件微批，最大199行，无例外。首design补丁因末句文本不符未写入，读取实际尾部后追加恢复；此前任务搜索glob不匹配未执行，rg实际domestic-sip-parity恢复，不修改该change。Android未受影响不重建；Flutter未改不重复3575项全量。真实账号切换窗口/SDK授权与推送仍待验，不归档。

- [x] 共享Dart完整账户非负代际及C0/C1控制字符门禁，双端无MethodChannel副作用专项及邻接验证。

2026-10-09 共享可信账户准入批：Dart valid补非负loginEpoch及C0/C1全部65个控制字符，与原生边界一致；双端账号端口逐个覆盖账号/号码控制字符且零MethodChannel，双端设置prepare本地固定SDK_SURFACE_INVALID且零通道，合法中文/合成号和零代际保留。可信feature全目录及架构90项6秒通过，analyze最终3.5秒无问题；未改平台不重复双端包/全量。首专项错误期待prepare false，但既有契约为固定异常，读取实现后修专项而不改错误语义；架构路径初猜不存在，经rg实际test/architecture_test.dart后有限复验，首85通过/2失败不当通过，最终90全通过。domain/test/test3文件微批，格式化独立机械；此前只读账号sync路径初猜不存在，rg实际lib/app/trusted_caller_account_providers.dart恢复，无写入。SDK51哈希、OpenSpec39及diff检查通过；真实SDK与完整UI仍pending。

- [x] iOS SDK环境宏缺失/非法时拒绝装配，测试/正式显式映射，编译矩阵及设备目标构建。

2026-10-09 iOS SDK环境显式装配批：Availability只在宏1/0返回test/pro，宏缺失/非法返回unavailable；Configuration对应门禁不读取Generated私有凭据，避免else默认正式。新的Apple clang矩阵全部在临时目录复制公开源并生成合成凭据，缺失/2/1/0四编译与执行通过（5.785秒），前两种credential read计数0，合法两种2；不读取或输出真实AppKey/Secret、不链接或初始化KX。iOS无签名Debug9秒构建通过，51SDK哈希保持。availability/configuration/test3文件微批，测试74行；Python语法、OpenSpec39、diff与凭据字节检查通过。固定Pod Debug/Profile test及Release pro映射未改，真实许可/签名/推送仍待验；此前只读Android配置文件名误猜，rg实际TrustedCallerConfiguration.kt恢复，无执行SDK/写入。共享Flutter本批未改，不重复90项定向/3575项里程碑全量。

- [x] SDK契约顶端同步2026-10-09最新接线/自动/隔离UI/真实待验矩阵，历史pending仅追溯；文档链接、diff及OpenSpec39通过，未归档。

- [x] iOS账户请求必须显式owner/null与三键账号、当前环境匹配，结构失败不改变业务状态；Foundation及构建。

2026-10-09 iOS账户请求结构批：纯Foundation解析要求owner字段存在，显式null才签出；账号仅accountId/phone/loginEpoch三键且环境为当前test/pro，冻结输出不带surfaceToken。Plugin在结构错误/旧consumer时于任何surface/push/incoming更新前固定安全拒绝，消除遗漏owner误签出。owner专项新增缺失/错误类型/空字典/多字段/错环境/未配置/null和合法冻结通过，既有取消/迟到/重入request专项通过；iOS无签名Debug7.6秒、51SDK哈希通过，无实际SDK或解绑。首专项NSCAssert内字典逗号被宏拆分，读取实际编译错误后括号修复；随后合法wire fixture误带environment第四键触发严格schema断言，核对生产Dart三键协议后修fixture移除该键，新证据有限复验通过，不放宽生产解析。owner h/m/test3文件微批、plugin1文件接线；源码最大150行，平台已验不重复共享90项/全量。真实设备验收仍pending。

- [x] prepare=false使用中性不可用提示，现有控制器/页面/设备拒绝专项及实际Web复验。


2026-10-09 可信来电不可用提示与Web完整入口补验：DeviceTrustedCallerPort.prepare在Web/不支持平台/无有效环境或SDK unavailable均可能false，共享旧提示“尚未配置”推断原因不成立。仅controller一句改“当前环境的可信来电服务暂不可用”，不新增支持/授权/初始化事实，不改bool端口、owner门禁或原生通道。控制器、页面、DevicePort含Web拒绝/非法owner/迟到/签出/禁按钮等30项通过2秒，analyze3.8秒无问题；23.3秒纯ShellWeb重建新8116且明确414×800，设置正式入口实际不可用、打开禁用→重新读取仍不可用且无授权→返回设置成功；原JPEG图unavailable-mobile.jpg位于.local/ui-reference/web-shell-trusted-unavailable。不可用状态正确不展示iOS有效SDK首次说明，不能虚构本次全Shell说明流程通过；既有独立说明页正常/大字/返回证据保持原范围。SDK配置读取工程内源已解决，此Web结果不能反推其缺失，更不能代替iOS/Android真实授权/APNS/SIM。生产1文件文字微批，不增镜像断言测试、不重复双端包/全量；OpenSpec39/diff及进度更新，正式设备读屏/SDK仍待验。
