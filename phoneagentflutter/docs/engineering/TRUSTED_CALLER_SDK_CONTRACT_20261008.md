# 可信来电SDK契约与待完善项（2026-10-08）

固定Android 0f8879e4、iOS bb9ff349。本文保留各阶段追溯，下方“当前验收状态”是2026-10-09最新结论；历史未接线描述不作为当前实现判断。源码、自动检查、隔离UI与真实设备验收分别记录。

## 当前验收状态（2026-10-09）

用户已明确从参照项目读取SDK配置，工程副本与ignored私有配置均已接线；不再等待配置来源。原交付目录仅追溯，构建使用工程Vendor/AAR副本，51文件哈希一致；私有值不进Dart、Git或日志。Debug/Profile选择测试，Release选择正式；iOS缺失/非法环境宏拒绝读取凭据。

| 范围 | 已实现与验证 | 尚需完善或验收 |
|---|---|---|
| 共享入口与账户 | 设置直接进入首次说明/SDK，错误反馈，精确移除自身route而保留覆盖页；完整账户、非负代际和控制字符门禁，迟到结果隔离；可信feature及架构90项通过 | 真实账号切换、SDK正常/异常退出及覆盖页面连续流程 |
| Android SDK | 工程AAR链接、首次/后续UI，Application消费者、SIM现有权限读取和已知写入journal清理；迟到Activity与系统授权前台等待；31项JVM、Debug构建；10个SDK Activity合并portrait | 明确SDK真实授权查询；真实SIM/双卡/权限拒绝/角色资格；后台3个receiver与screening service仍禁用，不据guide或权限伪造授权 |
| iOS SDK与账户 | KX/ASN1真机静态链接，首次Flutter说明、设置授权Evidence，当前账号/引擎窗口门禁；APNS与bindRid串行、未知结果阻止后续绑定；无签名Debug构建 | SDK包身份许可、真实授权、APNS与签名；跨进程未确认解绑账本/后端契约 |
| iOS身份事件 | SDK解析安全投影、后台/前台/点击消费者、25秒首账号恢复前单条内存缓存、Flutter四状态凭据；PSTN UUID关联及事件结束清理；Foundation和UI专项 | 注册Plugin之前通知、系统终止与真实冷启动APNS、多来电关联；CXCall不提供号码，时间关联不等于号码验证 |
| iOS LiveActivity | 独立扩展与共享属性、固定图资源、公开前台创建、4KB预算、账号/事件/到期清理及当前事件深链；扩展模拟器编译 | 真机签名、锁屏/灵动岛与真实推送；后台push-to-start需可信验证服务端专门契约 |
| 纯UI参考 | 独立原生/Flutter凭据正常及大字部分实际对照；Android纯宿主无业务插件与Android权限，普通包数据未替换 | iOS两倍字说明键盘分页/本地开始及公开Cancel返回已补验；iOS凭据长文键盘分页/返回和合成四状态已补验；触摸/边缘手势及Android实际滚动/返回待验，Qemu无法绑定，自动widget测试不替代实际交互 |

最新共享里程碑为冻结c14f983的3777通过/1跳过/0失败（7分38秒），包含此前普通/翻译拨号、选择弹层及外呼/关于/开发者重置/原音生命周期修改；共享账户规则此前90项定向通过，原生改动有对应编译或纯规则验证。真实SDK初始化、授权、SIM读取、推送或电话没有执行。完整项目业务/工程配置见[原生功能台账](NATIVE_FEATURE_PARITY_MATRIX.md)，实时翻译真实联调缺口见[国内翻译待联调](DOMESTIC_TRANSLATION_INTEGRATION_GAPS_20261008.md)。

2026-10-09 最新用户配置答复复核：6份工程本地私有输入0600、Git ignored且untracked、非symlink，与两端固定参照配置内存比较一致；没有输出或提交凭据。工程副本51份SHA及10个Android Activity/iOS竖屏检查通过，配置工具4项合成测试0.221秒通过。此为配置/静态验证，不代表实际SDK初始化、包许可、授权或来电完成。其后共享原音排版/父回调及平台返回已有27项定向8秒/analyze3.7秒，不把c14f983全量覆盖范围扩展至后续提交。

## Android实际SDK

初轮固定仓库两个1.5 AAR导出至ignored `.local/trusted-sdk-audit`核对；用户后续明确复制工程依赖，当前已复制android/app/libs/trusted_caller，尚未安装或运行SDK：

| 文件 | SHA256 | 字节 |
|---|---|---:|
| chaken-incall-1.5.aar | abac6c3439000be449b9367698c469a2cdd4eb22d840f98a0ddfd158d7089d5a | 4240394 |
| chaken-incall-ui-1.5.aar | 42943593f1b0e3648a9a77bc0e08bd8e55316f5fd246c5ba5bde89c6d1545dee | 1052922 |

UI AAR公开ChakenIncallSdk：init(Application,String,String)、openIncallUi(Context)、setPhoneNums、isPhoneNumsSet、grantPermissions及主题/BaseConfig；未发现明确授权结果查询。StatusUtils仅系统栏，PermissionUtil公开权限检查和permissionUpload，不作为证书/授权事实。core classes.jar只含加固Helper，未解包加固载荷或绕过保护。Android原生点击就置authorized是本地guide逻辑，不作为新Flutter真实授权事实。

AAR manifest声明网络、旧存储、READ_PRECISE_PHONE_STATE、通知、通话记录/通讯录/电话状态、悬浮窗及screening相关权限。只列静态声明；不代表每项实际必要或普通App能获得。下一平台接线需结合目标SDK、角色/系统授权和实际消费者逐项筛选，不直接合并全部权限。

## iOS实际SDK

固定ChakenSdk公开setAppKey:AppSecret:callback:、bindRid及sdkAuthLogCallback、parseIdentityToken。AIKXSDKService用sdkAuthLogCallback(code,data)读取状态：code非1不可用；缺少明确authorized/isAuthorized/authStatus字段仅readyToConfigure，不能当authorized。当前账号/规范号码/generation均检查后才落状态，初始化和表面token防重。

固定AISettingsViewController首次实际是内嵌Introduction：可信通信组件/来电归属地升级版/开始，之后KX设置；旧入口源文本烟测却要求没有Introduction，不能反向覆盖此固定实现。iOS无Android默认拨号器/悬浮窗。推送绑定、证书验证、来电展示、LiveActivity和退出解绑是账户/来电生命周期，不能塞进设置surface controller或仅关闭设置页就解绑整个账户。

## 仍需明确与完成

1. 已许可SDK分发及Flutter各包身份对应的安全部署配置来源，不将原生AppKey/AppSecret复制进Dart、仓库或日志。
2. Android真实授权状态查询/回调契约，不能用isPhoneNumsSet、权限成功或本地guide flag代替。
3. 两端平台端口/初次及后续SDKUI、SIM实际号码最小权限、取消和登录切换解绑，真实测试条件另需明确。
4. iOS通知消费者/APNS环境、授权状态回读、验证后身份及扩展target/共享属性/最低系统/签名和活动清理。
5. Android正式角色/后台/来电拒绝分支与生产OTA/旧数据兼容；当前debug不是正式升级产物。

未发起SDK初始化、读取真实SIM、发送通知、来电或真实授权。SDK配置/Android结果契约已异步询问信息，等待期间继续独立UI/其他已授权子任务。

## 用户提供SDK及当前工程副本

用户2026-10-08指定并要求复制，不使用提供路径构建：iOS两份SDK均1.8.0/build18，工程目录为ios/TrustedCallerSDK/Vendor/test与pro；二进制SHA分别68a07f6634ad0c7a6abd560ee846c03dea3d0a42bb0b822862955ec54d1343c6与50a2eed71dcc554c3bdb19124875c29479f421fafc687b0079d60a7b89254562。两个均arm64 IOS静态archive，对象LC_BUILD_VERSION平台IOS、min12.0/SDK26.2。不能拿arm64名称当iOS Simulator支持证明。

ASN1有效文件16项及SDK内置图片/GIF/归属地库15项来自固定iOS对象，已复制工程Common/Resources，不含_CodeSignature或签名私密材料。Android两AAR和iOS依赖/资源共51逐项SHA验证，见[工程manifest](../../ios/TrustedCallerSDK/SDK_MANIFEST.json)。`.gitattributes`禁止SDK载荷文本转换。用户提供iOS_SDK目录只读且不加入我方提交。工程内本地pod/AAR已接线：Debug/Profile测试、Release正式；Android Debug与iOS真机Debug无签名构建通过，可信pod单独模拟器编译通过（完整App仍受身份真机库阻挡）。Android加固so保留字节，12个ABI库与AAR哈希一致。SDK部署配置/授权查询/原生SDKUI仍待后续接线和验证。

## 用户授权的本地部署配置

2026-10-08用户明确“从参照项目中读取”。工具`tool/prepare_trusted_caller_credentials.py`以固定提交读取原生配置，只生成ignored .local和原生私有配置源码，权限0600，不输出值；运行该工具后pod install刷新新增generated。iOS Debug/Profile测试、Release正式仅编译所选分支；Android debug/profile测试、release正式源集独立。固定Android dev/prod实际共用同一组SDK凭据，不能把build variant当服务端许可分离证明。4项synthetic工具测试及双端Debug编译通过，真实SDK初始化/授权仍未验。原上方“配置来源缺失”是授权前阶段状态，已由本节覆盖；许可证/包身份匹配仍需实际SDK结果验证。

## 当前源码接线范围补充

两端SDK初始化、首次/后续设置surface已实现并通过编译；iOS首次说明guideSeen与进入/取消/SDK退出连续4项测试通过。iOS授权Evidence 12项及owner/request纯Foundation通过，DevicePort guide严格回显与释放迟到共9项通过。Android无明确授权查询仍仅可配置。源码与mock不是SDK真实设备运行验收。

iOS账户级PushBindingState已实现纯Foundation串行规则，SDK/通知/token门禁、跨账号迟到绑定先解绑、失败阻止新绑定。尚未接SDK bindRid执行、APNS消费者和账户Provider，来电身份解析/展示与LiveActivity仍pending。SDK关闭surface不解除整个账户绑定。真实SDK/推送/许可匹配未验证，不能用本地配置存在当服务端许可通过。

## 账户/APNS执行端当前范围

App root账户同步与native App级APNS消费者、SDK bindRid执行已接线；SDK bootstrap/绑定串行driver用合成依赖验证，不真实初始化或发送。只读取现有通知授权，owner变更先暂停缓存许可并重新回读；consumer代际防旧引擎更新或退出，token不入Dart/日志，SDK未回请求不重放，失败只当前owner显式设置请求重试清理。Debug/Profile APS development、Release production工程声明已核对；签名profile、真机注册/接收仍未验证。号码边界按固定原生去非数字和13位86前缀处理，不修改Flutter冻结owner。

来电payload解析/SDK身份验证/去重/凭据展示与LiveActivity扩展尚未实现；App级SDK状态非持久远端绑定账本，进程结束或卸载前未确认的解绑仍需要后端可验证契约/设备验收，不宣称跨进程清理完成。Android真实授权查询/SIM和后台仍pending。

## 2026-10-09 身份事件与扩展源码现状（覆盖上方历史pending）

SDK parseIdentityToken执行、safe native EventChannel、后台/UN前台/默认点击通知、当前owner/event的Flutter凭据Host与四状态页、CX incoming UUID时序结束关联已经源码接线并离线/编译验证。旧事件或账号不能清新页，任意通知字段/URL不得自称verified。CXCallObserver不提供号码，实际电话时序和多来电仍需设备验证。

独立TrustedIdentityLiveActivity extension与共享属性已嵌入，iOS16.1+公开前台创建当前新鲜已验证身份、原生锁屏/灵动岛视图、默认工程头像、4KB总预算、代际/账号/PSTN/到期清理、固定当前event深链显式再次展示已实现。App最低15.5保留；Debug/Profile扩展测试包前缀，Release正式包前缀，构建版本共享。扩展独立模拟器编译、App无签名真机目标与Android Debug通过；真实签名/锁屏/push未验。

[Apple公开request](https://developer.apple.com/documentation/activitykit/activity/request(attributes:content:pushtype:))限制App前台创建；普通远程通知不是后台创建Activity的许可。后台push-to-start需可信验证服务端专门APNS契约，当前不收集或绑定该token，不复制固定原生私有fallback或打印token。冷启动账号恢复前通知缓存、跨进程未确认解绑、Android授权查询/SIM/角色与后台、真实端到端仍待完成，不能以本批编译称已验收。

## 2026-10-09 Android SIM工程现状

Android App级账号同步、existing权限分版本SIM读取、私有持久化ownership journal和SDK公共SPUtil context键已接线。设置打开前与SDK所有窗口实际销毁返回后同步，换账户先销毁旧窗口后清已知归属写入；预存在相等号码和SDK用户修改值不认领、不清除。无法确认journal或写入时阻止新同步，保留明确错误。READ_PHONE_NUMBERS仅声明、不主动申请，号码fallback按固定原生规划，不作为实际号码或证书授权。25项JVM及11项Flutter定向、analyze与Debug构建通过，未在设备运行SDK/读SIM/写SIM。Android真实授权查询、角色资格与后台receiver/service仍待明确契约及设备验收，当前仍只报告readyToConfigure。

2026-10-09 本地接线复核：verify_trusted_sdk再次验证51文件及10 Android SDK Activity/iOS竖屏；配置生成4项synthetic测试0.278秒通过。固定参照配置与ignored JSON仅在内存比对一致，六个私有输入均0600、非symlink、ignored/untracked，不输出值、不重新生成、不初始化SDK。四当前报告182相对文件目标存在，锚点未检查。

2026-10-09 路由生命周期里程碑：生产源码冻结c14f983f8bf54fbee18788f0ba9584d0e898ea46，累计普通/翻译拨号、预设/语言/模型/海外设置/目录、共同选择语义及外呼/关于/开发者重置/原音触发一次全量回归；当前执行中未写通过计数。源码与工具/平台不再改动，只补纯隔离运行证据和文档，外部pubspec.lock保持。原音19项2秒/analyze2.5秒、外呼35项10秒及追加竞态4项、关于8项4秒、开发者重置9项5秒为各自定向范围，重叠不合计，不把此前2eb2fcf全量当覆盖本轮修改。

可信说明页独立两倍字补验：pure.trustedintro.large启动51237，键盘Next实际视口移至底部“开始”（AX文字未变，截图实证）；开始仅fixture结果“未调用可信SDK”→重新查看→直接AX返回element点击无效一次→刷新实际节点的公开Cancel动作返回“独立说明页已关闭”。large-bottom/large-return原始PNG在ios-trusted-intro-keyboard且实际查看。当前只有展示、键盘分页与公开取消动作运行证据；未声明触摸/边缘手势、真实SDK或完整原生V通过，工具TextScaler不同于系统动态字体。无普通App/真实授权/电话/网络。

2026-10-09 可信凭据独立两倍字补验：pure.trustedcredentials.large启动51714，synthetic长姓名/企业/编号与日期，无账户/SDK/通知端口；Next视口真实分页（AX整树文字不变，截图显示证书尾编号/颁发机构/说明及返回首页），点击可见返回回四状态菜单。再进入pending显示正在验证→返回、failed显示验签失败→返回、uncertified显示谨慎采信且无可信凭证→返回；每次实际AX核验，pending/failed未留PNG不称有截图。large-top/large-bottom/large-uncertified三原始PNG在ios-trusted-credentials-keyboard且均实际查看；首屏及长证书自然换行，未声称同原生整页像素V/触摸手势通过。公开verified只是合成输入，不当真实验签成功。全量仍执行中、c14f983生产/平台/工具无diff，只有文档；不新增SDK初始化或真实SIM/APNS/电话。

2026-10-09 路由生命周期跨模块里程碑完成：源码冻结c14f983f8bf54fbee18788f0ba9584d0e898ea46，全量flutter test --no-pub --reporter expanded退出0，3777通过/1跳过/0失败，7分38秒；日志/tmp/phoneagent-route-lifecycle-milestone-tests.log。唯一默认opt-in文档UI开关跳过保留（既有显式开关专项2通过不是本轮新执行，不并入3777）。期间lib/test/tool/ios/android无diff，仅文档与独立pure UI运行；source HEAD仍c14f983，analyze此前2.5秒无问题，外部pubspec.lock28条host-only差异不提交。新全量取代2eb2fcf的3706/1作为此冻结源码最新回归，不覆盖未来修改；OpenSpec39、四报告182相对文件目标存在及diff校验通过，本次未查锚点。SDK工程副本/安全配置来源已落实，真实SDK初始化/SIM/APNS/后台、模型短期配置、真实媒体/电话/结算/录音上传、Android同签名OTA/旧数据和iOS发布、三端全部状态像素与触摸手势仍待验，不归档。

## 2026-10-09 来电完善专项最新状态

本节覆盖上方“Android后台组件仍禁用”和旧扩展后缀的历史描述。专项为 `incoming-call-native-parity`，固定参考提交不变。

| 范围 | 当前实现 | 验证边界与待完善 |
|---|---|---|
| 共享凭据 | 待验证、验签失败、已验证、未认证四状态；仅已验证证书；连续事件更新、覆盖页/旧关闭回调/重复关闭隔离 | 可信feature88项通过；iOS隔离宿主普通字号与固定原生配对，大字长内容滑动及四状态返回实测；Android真实SDK叠层视觉待验 |
| Android来电 | Application级SDK初始化；当前账户、SIM同步、现有电话权限、悬浮窗或screening角色准入；自有Receiver/Service包装并调用SDK公开入口；首次进程默认关闭，换账号和释放禁用，异常screening放行普通电话 | 34项可信JVM通过，Debug APK构建通过；未申请真实权限或读取设备SIM。SDK无真实授权查询接口，不能把角色/权限当认证成功；真实双卡、重启、锁屏、退出及拒绝权限待验 |
| iOS通知 | 前台保留来电声音、通知点击与冷启动候选进入现有账号/事件校验；NSE通信通知外观与头像装饰；HTTPS/2MB/5秒限制，一次回调，失效回原通知 | Foundation7组和路由、Swift纯规则/并发完成专项通过；NSE不执行SDK验签、不保存token、不以通知字段宣称已认证；真实APNS与冷启动待验 |
| iOS扩展配置 | Debug/Profile分别为com.chaken.phoneagent.test.KXLiveActivityExtension及.KXPushServiceExtension；Release分别为com.chaken.phoneagent.KXLiveActivityExtension及.KXPushServiceExtension；同App Team，版本共享，单次嵌入 | 三配置工程检查、NSE模拟器、两个扩展Release无签名及完整App Debug无签名构建通过；签名profile/通信通知entitlement与服务端mutable-content推送需真实环境确认 |
| Live Activity | 已验证的新鲜当前事件，公开API前台创建、更新/结束和当前事件深链；保留iOS15.5低版本页面回退 | 用户指定ID已修正；锁屏/灵动岛/结束时序待真机；未引入私有API，后台push-to-start仍需服务端专门契约 |
| SDK与私有配置 | 工程内Vendor/AAR副本51文件哈希一致，10个Android SDK Activity竖屏；两端test/pro私有配置与固定参考在内存比对一致 | 不从交付路径链接，不输出或提交密钥；真实包名SDK许可与授权仍需运行确认 |

此次未安装或启动普通业务App，未发送短信、外呼、APNS或真实SDK认证。模拟器使用独立PhoneAgent-Incoming-20261009及合成隔离宿主，没有改动其他任务模拟器。真实端到端条件已向用户询问；不能将编译和合成流程写成真实来电验收。专项保持active，验收后再归档。

来电最终源码复核：头像HTTP错误/重定向拒绝/下载超限或空响应改为原通知一次回退，Swift真机SDK typecheck无诊断、完整iOS Debug无签名25.0秒通过；Android最终17.8秒APK及合并manifest默认disabled/SCREENING绑定权限核对通过。52e6b1f0已成功推送origin/codex/dev_zys。其他模块失败定向复现：identity_widget、translation_model_sheet、translation_overseas_entry_guard、native_translation_model_panel四文件18通过15失败；涉及反馈计时/入口与关闭定位，不修改这些生产行为。已修联系人/旧close11项通过与全量启动时的6失败对应，不相加为全量结果。

## 来电专项最终回归记录（2026-10-09）

全量运行6分18秒：4047通过、37失败、1跳过，exit1，不能称全量通过。启动时旧联系人/关闭定位6失败已另以11项8秒补验修复，未重跑全量；其余31失败保留原始结果，不通过减法伪造新全量计数。四个身份/翻译文件另定向18通过15失败，已复现。

- test/shell_contacts_workbench_test.dart：2失败
- test/core/native_sheet_close_route_test.dart：4失败
- test/features/identity/identity_widget_test.dart：1失败
- test/features/translation/translation_model_sheet_test.dart：2失败
- test/features/translation/translation_overseas_entry_guard_test.dart：4失败
- test/features/translation/native_translation_model_panel_test.dart：8失败
- test/widget_test.dart：3失败
- test/extended_device_stage_test.dart：4失败
- test/migration_increment_device_stage_test.dart：2失败
- test/shell_receipt_workbench_test.dart：2失败
- test/shell_translation_workbench_test.dart：3失败
- test/shell_developer_workbench_test.dart：2失败

可信feature88项、Android可信34项、Foundation7组与通知路由、Swift通知有界/一次完成专项通过；SDK51SHA、私有配置固定参考内存比对、扩展三配置/合并AndroidManifest通过。最终analyze无问题/OpenSpec62通过；Android Debug17.8秒、iOS Debug无签名25.0秒构建通过，扩展Release无签名及NSE模拟器构建通过。固定原生和Flutter隔离凭据四状态已运行，2x长内容滚动返回已验证，截图保存在.local/ui-reference/incoming-call-20261009。

未完成验收：Android原生SDK页面与叠层运行对照、真实首次/后续授权反馈、双卡/后台进程恢复/锁屏/账号切换、真实APNS/冷启动/Live Activity、签名及服务端mutable-content配置；测试设备/账号/环境/次数问题尚无回复。不触发真实短信、SDK认证或呼叫，不以无签名构建交付为正式升级包。需要真实条件的任务保持未勾选，change不归档。160b53f4及之前实现已推送codex/dev_zys，中文日志。

## 2026-10-10 设置入口当前行为（覆盖历史中间route描述）

设置项不再push Flutter状态页/加载页。附着原设置页的Entry只在点击时持有Controller：prepareEntry→iOS本地首次说明或SDK/Android原生入口→返回后独立refresh。prepare/readAuthorization不串为打开前置；iOS prepare增加本地needsIntroduction字段，缺失/非法不能偷偷跳过说明；Android首次/后续由SDK适配原分支管理。初始化/SIM仍归平台服务，UI只协调，不读设备/存储。等待保持原页、重复点击单次、失败原页提示可再点；旧账号/覆盖/销毁后结果无权打开，SDK返回不pop设置或覆盖页。状态查询失败不误报打开失败。

最终114项定向10秒/analyze5.2秒/iOS Debug无签名7.5秒通过。未重跑全量，历史全量失败结论不由本次定向覆盖。Android原生未改故不重打包；未安装普通App、触发SDK认证、读真实SIM或来电。本批实现不等于双端真实SDK视觉验收，待用户设备复测，不归档。
