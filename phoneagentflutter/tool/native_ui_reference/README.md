# Android 原生组件运行参考

直接引用指定 Android 工程固定提交 `0f8879e4baf1d56fe6d7f8f356101fdf61d602ed` 的 Compose 组件，使用合成数据。它是组件对照工具，不是登录后原生业务流程的验收证明。场景为 `tasks`、`rules`、`translation`；没有业务仓库、认证、音频或电话操作。

`inject.gradle` 仅在显式命令中把本目录加入原生 debug sourceSet。原生源码和 Gradle 文件不修改；新增包为 `com.vvtech.aiassistant.ui.reference`，使用普通 Application 和默认 debug 签名，清空本地配置来源的自定义 String BuildConfig 字段，移除网络、电话、定位、相机、录音及联系人访问权限。两个业务 App 的安装和登录数据不受此工具影响。

原工程使用现有 JDK 11/Gradle 7.5.1；Flutter 继续使用已验证 JDK 和固定 Flutter 3.32.0，不采用这里的原生构建基线。

```sh
TASK_REFERENCE_SOURCE=/Users/Eason/Desktop/Git/PhoneAgent/tool/native_ui_reference
TASK_NATIVE_SOURCE=/Users/Eason/Desktop/Git/AIAssistant1/android
python3 "$TASK_REFERENCE_SOURCE/derive_contact_skills_reference.py"
python3 "$TASK_REFERENCE_SOURCE/derive_model_capsule_reference.py"
JAVA_HOME=/opt/homebrew/Cellar/openjdk@11/11.0.30/libexec/openjdk.jdk/Contents/Home \
ANDROID_HOME=/Users/Eason/Library/Android/sdk \
bash "$TASK_NATIVE_SOURCE/gradlew" -p "$TASK_NATIVE_SOURCE" \
  -I "$TASK_REFERENCE_SOURCE/inject.gradle" \
  -Dphoneagent.uiReferenceSource="$TASK_REFERENCE_SOURCE" \
  -Dphoneagent.uiReferenceDerivedSource="$PWD/.local/ui-reference/contacts-skill-source" \
  -Dorg.gradle.jvmargs=-Xmx6g -Pkotlin.compiler.execution.strategy=in-process \
  --max-workers=1 --offline :app:assembleDevDebug
```

安装前核对 APK application id、移除的权限和生成 String 配置字段确实为空，不输出配置值。仅安装到隔离模拟器：

```sh
python3 "$TASK_REFERENCE_SOURCE/verify_reference.py" "$TASK_NATIVE_SOURCE" \
  /Users/Eason/Library/Android/sdk/build-tools/36.1.0/aapt
# 使用上述验证报告的实际 APK 路径；原工程 APK 名称含版本和构建时间。
adb -s emulator-5554 install -r "<验证报告中的 APK 路径>"
adb -s emulator-5554 shell am start \
  -n com.vvtech.aiassistant.ui.reference/com.vvtech.aiassistant.uireference.UiReferenceActivity \
  --es scene tasks
```

切换场景前 force-stop 这个独立演练包，避免 Activity 复用旧 Intent。固定与 Flutter 相同 OS、分辨率、DPR 和系统字号，采集后分别记录原生组件参数和 Flutter 的已确认统一目标。组件入口使用简单容器；截图不能用于验收宿主页位置、弹层呈现、真实服务、原生登录后流程或 iOS。

## Flutter 配对组件

`flutter_component_reference.dart` 直接调用生产翻译页面和控件，没有演练提示头、会话或业务端口。`flutter-inject.gradle` 为显式 debug 构建分配 `com.vvtech.aiassistant.ui.flutterreference` 并移除业务权限；普通 `.dev` 包不替换。任务参数只允许 assembleDebug，Flutter 插件的 included build 不受根任务 guard 误阻止。

```sh
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
PUB_HOSTED_URL=https://pub.flutter-io.cn \
bash android/gradlew -p android -I "$TASK_REFERENCE_SOURCE/flutter-inject.gradle" \
  -Dphoneagent.uiReferenceSource="$TASK_REFERENCE_SOURCE" :app:assembleDebug \
  -Ptarget="$TASK_REFERENCE_SOURCE/flutter_component_reference.dart" \
  -Ptarget-platform=android-arm64 -Pdart-obfuscation=false \
  -Ptrack-widget-creation=true -Ptree-shake-icons=false
```

安装前读取 `build/app/outputs/apk/debug/output-metadata.json` 确认独立包及 APK 路径，并用 aapt 核对业务权限移除。仅安装隔离模拟器，Activity 为 `com.vvtech.phone_agent.MainActivity`。对照时保存相同分辨率、字号和状态，外层参考容器不作为原生完整业务验收；字体排版引擎造成的细微字形差异单独记录。后续普通构建不带 init 脚本，恢复正常 `.dev` 输出。

字幕对照：原生 `scene=translation-subtitles` 与 Flutter 当前入口均提供相同两条双语合成字幕；`translation` 原生场景保持空字幕。可核对少量字幕顶部对齐、说话人方向、透明白气泡和间距。入口动作仍为空回调，不作为控制会话流程验收。

拨号盘对照：Flutter当前fixture预设dialPad=true；原生字幕场景可点击拨号盘，原生局部显示状态会展开网格，业务动作仍空回调。没有发送真实DTMF；Flutter参考入口按键不驱动会话。

国际盘：原生 `scene=translation-international` 使用仅UI的合成BackendWebRtc plan，Flutter fixture声明能力可用；两者业务发送回调为空，本地按键历史/按住效果可对照。原生组件自身触感可在模拟器触发；Flutter纯组件无Controller/触感端口，平台触感仅在注入控制器的正式路径与mock channel专项验证，不把参考工具当真实媒体发送。

翻译场景调用正式 `AssistantSystemBarChromeEffect(FinalPage.TranslateCall)`，由Compose生命周期应用浅色图标/透明系统栏/关闭导航对比遮罩；Flutter调用生产页面局部AnnotatedRegion。可比较该组件系统栏，但不能据此推断其他页面或iOS运行已验收。

任务组件配对：构建追加 `-Pdart-defines=VUlfUkVGRVJFTkNFX1NDRU5FPXRhc2tz`（UI_REFERENCE_SCENE=tasks的base64）。场景直接使用生产任务卡/同步/错误/初载组件，状态与原生tasks一致，无Repository/账号/网络。参考MaterialApp外层系统栏样式使用生产PhoneAgentApp相同参数，局部翻译样式仍覆盖父层，避免任务场景继承上次翻译图标。

完整规则容器：原生scene=rules-modal使用正式ModalBottomSheetLayout配置并复用InviteRulesSheet，同合成两段规则；旧rules仅内容参考。Flutter追加 `-Pdart-defines=VUlfUkVGRVJFTkNFX1NDRU5FPXJ1bGVz`（UI_REFERENCE_SCENE=rules），首帧打开生产showInviteRules。两者白色纯背景，无邀请/积分端口；我知道了只关闭参考，不产生奖励。

积分组件：原生scene=wallet调用正式PointsWalletScreen/Light system chrome，Flutter追加 `-Pdart-defines=VUlfUkVGRVJFTkNFX1NDRU5FPXdhbGxldA==`（UI_REFERENCE_SCENE=wallet）；同900可用/100今日赠分，无钱包或邀请服务。Flutter仅在非零布局完成后输出UI_REFERENCE_METRIC合成组件几何；读取必须限定reference进程PID并过滤该前缀，不能输出VM地址或其他日志。首帧零宽读数无效。

流水组件：原生scene=ledger/ledger-empty/ledger-loading/ledger-error，Flutter同UI_REFERENCE_SCENE编译值；同两条合成正负流水/已加载空结果/尚未取得初载或错误，调用正式PointsLedgerScreen/PointsLedgerPage。原生输入含零变更并由正式页面过滤；Flutter夹具按正式PointsWalletController既有投影先过滤零变更，不能把绕过Controller的非法直接状态当生产缺陷。所有回调空，无账号或钱包IO；已加载与未知事实后续展示批独立实现。

设置参考：native `--es scene settings`，Flutter `UI_REFERENCE_SCENE=settings`，直接复用有效首页组件，合成摘要，所有业务回调为空。保留入口集合差异与原生大字左右列，不用删除可信卡伪造一致；此参考不含主Shell底部浮栏，末项系统区范围不等同普通包。

模型参考：native scene=models、Flutter UI_REFERENCE_SCENE=models。正式页面含有效克隆入口；同两条合成模型、倍率/推荐/选中、默认音色Andre与清朗男声。回调为空，不点击音色入口（原生页面拥有真实媒体生命周期），不执行克隆或模型服务。64/66原生与67/68Flutter记录当前差异；65最初缺入口/默认音色夹具不是同数据验收。

音色完整容器：native scene=voices；Flutter UI_REFERENCE_SCENE=voices，并必须同时设置ENABLE_MIGRATION_PREVIEWS=false，base64 CSV为 `VUlfUkVGRVJFTkNFX1NDRU5FPXZvaWNlcw==,RU5BQkxFX01JR1JBVElPTl9QUkVWSUVXUz1mYWxzZQ==`。三个合成系统音色和无克隆状态，正式Sheet/页面，Flutter无音频Host。原生内置播放器仅点击试听初始化，不得点击试听/选择/克隆，只截图及返回；所有业务回调为空。正常/两倍字78/81和82/83为有效配对，79/80含MOCK额外行不可使用。

原音页面：native scene=original-audio；Flutter UI_REFERENCE_SCENE=original-audio，追加两个base64 define `VUlfUkVGRVJFTkNFX1NDRU5FPW9yaWdpbmFsLWF1ZGlv,RU5BQkxFX01JR1JBVElPTl9QUkVWSUVXUz1mYWxzZQ==`。enabled true、volume100/gain50，正式页面；native remember/Flutter Store仅内存，同参考开关/滑块动作不访问设备偏好或播放/翻译，普通账号和设备偏好保持。89/90/94与91/92/93记录正常/大字/关闭状态，运行滑块禁用与源码刻度/自动测试证据分开。

身份对照：native scene=identity / identity-verified / identity-empty，Flutter UI_REFERENCE_SCENE取同值且ENABLE_MIGRATION_PREVIEWS=false。姓名演练用户（空态为空）、不透露、手机号空，只读合成profile；动作空实现，不作为保存、编辑、删除或认证验收。99–110保留正常/两倍字同状态配对，确认额外首行间距/图标/徽标差异；iOS只核对有效源，未运行。

编辑参考V1E：native在identity或identity-verified实际点击编辑；Flutter UI_REFERENCE_SCENE=identity-edit / identity-verified-edit。同profile/draft，仅静态正式编辑页面和空业务动作；113–120正常/大字对照，不保存或认证、不把空动作当取消导航验收。

身份状态V1H：scene/UI_REFERENCE_SCENE=identity-loading或identity-error；已填演练用户缓存和相同合成加载失败文字，native loading/error参数与Flutter loading/error state，无服务请求。123–130正常/两倍字同状态配对；仅展示，不证明加载重试或真实业务成功。

联系人Skill私有展示参考：先执行`python3 tool/native_ui_reference/derive_contact_skills_reference.py`，仅在固定Android HEAD且该源无tracked diff时机械提取private纯UI，不复制ViewModel route，不修改原生工程。所有native参考构建需追加`-Dphoneagent.uiReferenceDerivedSource="$PWD/.local/ui-reference/contacts-skill-source"`（本地生成文件不提交）。scene=contacts-skills/contacts-skills-empty/contacts-skills-loading及Flutter同scene固定合成联系人与两条同数据技能，回调空，无账号/配置刷新/任务创建。

会话模型胶囊参考：所有native参考先同时运行上述两个派生脚本。`derive_model_capsule_reference.py`固定HEAD/源diff核验，只提取private纯胶囊及shape常量，保留原package调用实际internal selector，不运行含附件/IME状态的完整dock。scene/UI_REFERENCE_SCENE=conversation-model；合成QwenOmniPlus/无倍率/空模型回调。Flutter直接复用实际ConversationComposer，原生只胶囊；比较胶囊自身可见几何，不把参考容器居中位置或空回调作为完整页与正式模型导航验收。conversation-wave为actual Standby/Flutter纯待机图对照，不启语音SDK。

识别等待参考：scene/UI_REFERENCE_SCENE=conversation-voice-finalizing，原生直接实际PureVoiceBottomControl(Finalizing)，Flutter实际VoiceHoldButton仅合成finalizing binding、空callbacks。两侧只显示/动画，不申请权限或调用识别；图像相位不锁定，不能以不同帧视为相位一致证明。保持两个派生脚本及隔离包/权限核验。

按压参考：scene/UI_REFERENCE_SCENE=conversation-voice-press，actual native Mic及PureVoicePttFeedbackOverlay与Flutter actual VoiceHoldButton空callbacks。隔离包必须移除八业务权限；只由参考局部pointer驱动光圈/提示，不含语音controller/采集/SDK。实际DOWN→上移160物理像素超过58逻辑阈值→UP比较普通及两倍字号，UP后立即截图已取消（1200ms，XMLdump可能使提示先过期）；finally补UP释放，字体恢复1。参考居中/状态文案不是整页业务布局，截图相位未锁定。普通ShellPreview未override voice factory且无API baseUrl，不按普通mic或称其可模拟识别。

输入模式图标：现derive_model_capsule_reference.py同时从固定PureVoiceInputDockControls.kt机械派生private纯键盘/图标控件到ignored NativeDockIcons.kt，保留原package与actual Canvas，不提取完整IME/附件dock。conversation-model参考增加actual Add/Mic/六点圆行，回调空；Flutteractual composer，同样只比较控件自身，原生参考28模型/72行与Flutter48透明热区及父padding造成位置差独立记录，不能冒称整页位置一致。

开场完整结构参考scene/UI_REFERENCE_SCENE=conversation-opening：native直接SingleFlowHeader+PureVoiceStage，正式16横/statusBars/top14、indicator2/thread2、OCR空状态及业务空回调；同合成文案以ClarificationStep助手/streaming=false呈现，不用liveAssistantTranscript制造流式省略号。同步正式LocalSingleFlowBackgroundGeometry，避免默认height1造成假背景色带。无RecordingPlaybackHost/Repository/SDK，不点击图片选择或启动系统能力；Flutteractual ConversationPage空state/无controller/空动作。两者包含真实波形/消息/模型/dock结构，可定位整体锚点差异；固定PhoneAgent及统一iOS290/360宽比、系统安全区取舍独立记录，不称双端全部状态验收。405–408旧native居中泡只能作局部证据，409–410早期live流式/默认geometry版本也不能作为最终非流式整页基线，新的修正图单独编号。

动态波形局部参考：scene/UI_REFERENCE_SCENE=conversation-wave-listening / conversation-wave-speaking，native actual PureVoiceAiStateVisual内部enum，Flutter actual NativeConversationWave三态。只合成活动状态/无采集或播报，检查蓝/绿、58外框及变化；父容器居中和header文字不是正式整页状态，不以截图相位未锁定当帧相同。业务自动测试显式reduceMotion避免装饰无限循环，动画关键帧/90延迟取消/销毁由独立wave专项验证。

## iOS 独立气泡参考

`ios/build_reference.py native|flutter --simulator <明确的已启动iOS UDID>`只构建并安装`com.vvtech.phoneagent.ui.iosnative`/`iosflutter`两个新参考身份。使用固定iOS HEAD实际AIPureVoiceBubbleView/Markdown与Masonry，Flutter使用固定3.32模拟器引擎、实际ConversationMessageTile；仅注册普通消息的纯UIKit排版通道，不注册业务SDK或其余插件、不接账号/音频/网络端口，不修改源仓库或卸载普通App。产物及源SHA在ignored `.local/ui-reference/ios-isolated/`。

本参考固定安全区后200点/左右18点和合成助手、用户文字，父容器只提供可重复比较条件，不能作为正式会话页纵向位置证据。源动态字体行为未注入修改。iOS正式SDK模拟器切片限制仍存在；独立控件运行不等于正式App、键盘、导航或SDK验收。runtime日志写入本地文件，早期排查仅读取`REFERENCE_TEXT_METRICS`、`REFERENCE_TEXT_WIDTH`、`REFERENCE_NATIVE_METRICS`和`REFERENCE_NATIVE_FONT`诊断字段，当前动态入口不再输出Flutter文字诊断，不输出调试VM服务地址或其他运行日志。

H18参考直接链接当前`ios/Runner/NativeParagraphChannel.swift`并注册其纯UI通道，仍无GeneratedPluginRegistrant或业务SDK。Flutter使用实际ConversationMessageTile/NativeMessageParagraph，源SHA同时记录。`--dynamic`仅在Flutter参考加入追加12次/恢复/关闭的合成UI操作，验证原生文本view更新和销毁，不发送业务消息。每次只清理本脚本生成的`.local/.../<kind>.app`构建目录，避免残留临时字体实验资源；不清理模拟器App数据。正常001/004局部字体/断行和用户几何已测量，005验证只读选择菜单不出键盘；完整iOS流程仍待验。

H19参考stack沿有效iOS会话10点间距，Flutter复用实际普通消息10外边距；012/013稳定图实际30像素/3倍即10点。010/011为启动过渡截图，明确弃用，不作为布局证据。完整会话位置仍不由本参考父容器证明。

H22增加`--short`纯点号场景：native直接实际气泡，Flutter实际普通消息；014/015/016稳定图记录44→修前33→修后44点。相同Flutter入口也可用于Android隔离APK（UI_REFERENCE_SHORT=true），427/428仅验证actual fallback正常/两倍字；它不是完整会话父容器/系统栏参考，原生Android没有44最小宽度的统一目标差异另记。

## iOS完整Flutter合成导航参考

`python3 tool/native_ui_reference/ios/build_reference.py flutter --shell --simulator <已启动iOS UDID>`使用实际`tool/ui_consistency_preview.dart`及既有ShellPreview内存端口，独立`com.vvtech.phoneagent.ui.iosflutter.shell`/`flutter-shell.app`身份，只注册纯正文UIKit通道。默认合成登录、formalClone/系统音色/文档演练，无API地址；关于版本读取当前host的app_info，未注册通道时隐藏版本（不再使用PreviewStartupSource），不访问普通App。禁止与native/short/dynamic组合，日志及源HEAD/diff hash/工具hash在ignored目录，不输出VM地址。

可操作合成联系人、技能、会话、模型sheet、系统键盘草稿和返回；不点击语音/短信/认证/外呼/收费/真实日志上传，不把此宿主当正式SDK或原生整页配对。所有业务页面仍调用生产组件；iOS模拟器实际Flutter导航证据与原生纯控件对照证据分别记录。

V1N的`--batch`与shell/short/dynamic互斥，两种kind均独立.batch身份；native直接链接实际批量确认控件及纯策略/Points/TaskReceiptContract/TaskStatusContract，Flutter复用生产card。同合成摘要/规则、无audit/billing/说明、共同308白面板宿主用于局部对照，原生实色摘要308与统一Android渐变280差异明确记录，不能当正式iOS308/360宽比或整页验收。028/029对照发现状态未贴右，H25另修。

2026-10-07 iOS单项批量回执实际参考：`ios/build_reference.py native|flutter --result --simulator <已启动UDID>`，与batch/shell/short/dynamic互斥。独立`.result`身份，实际原生AIBatchCallItemResultView与FlutterBatchReceiptItemCard同syntheticSUCCESS/联系人/摘要/businessResult及purpose字段，无转写/录音/结算/业务SDK。044/045用于定位额外字段与状态标签差异，仅局部参考不代表整页验收。

## Android不注册业务端口的纯UI宿主

显式增加`-Dphoneagent.uiReferenceNoBusinessHost=true`，使用普通Application和独立`com.vvtech.phone_agent.uireference.FlutterUiReferenceActivity`，不注册插件或业务MethodChannel；默认演练路径及普通App不变。APK不得保留任何`android.permission.*`，安装前运行：

```sh
python3 tool/native_ui_reference/verify_flutter_isolated_reference.py \
  /Users/Eason/Library/Android/sdk/build-tools/36.1.0/aapt
```

可信凭据纯组件目标为`-Ptarget=/Users/Eason/Desktop/Git/PhoneAgent/tool/native_ui_reference/flutter_trusted_credentials_reference.dart`，普通字体不额外定义参数；两倍字体追加`-Pdart-defines=VUlfUkVGRVJFTkNFX0NSRURFTlRJQUxTX0xBUkdFPXRydWU=`。Gradle的`-I`应使用脚本绝对路径（`-p android`会改变相对解析根）。同已有独立包只安装AVD，不安装普通`.dev`，不触发真实SDK/通知/电话。无插件宿主仅适合纯presentation，设备插件验证沿专门隔离测试入口。

2026-10-09已实际构建/验证/AVD启动并查看普通和两倍字长文本截图，普通包安装时间保持；Qemu窗口无法由当前CUA绑定，故未操作点击、滚动和返回，截图不当交互验收。Android/iOS均采用当前正式凭据组件，系统字形和不同viewport不当同条件像素对齐证明。产物、截图与校验report位于ignored `.local/ui-reference/android-trusted-credentials/`，最终普通APK重新构建恢复`.dev`输出身份。

## iOS 固定外呼号码隔离参考

`ios/build_reference.py native|flutter --simulator <已启动的明确UDID> --outbound --outbound-state saved|empty|loading|error`使用按种类/状态独立的参考包，不覆盖普通App。此选项与其他场景互斥，非法组合在读取设备和构建前拒绝。正常字体下比较四状态；不要把原生固定UIFont解释为两倍动态字体已验。

原生只从固定`bb9ff34966f40a3c2794a9a8b8e935669a9faa12`导出正式`AISettingsOutboundNumberViewController`、纯号码规则及Masonry。实际UI实现保持原样；`ios/outbound/`内最小同名DTO/账户服务是参考专用合成替身，真实账户服务、Model服务装配、凭据与SDK不导出、不编译。读取只返回合成号码/空/合成错误；loading保持未完成，保存/删除始终合成拒绝，不联网或改配置。Flutter入口直接生产`OutboundNumberPage`，对应静态状态与空写回调。两侧真实返回只到“合成外呼配置已返回”的独立根。

构建记录状态、固定源哈希及本地替身/生产组件哈希，原图位于忽略目录`.local/ui-reference/ios-outbound`。返回和聚焦可用CUA核验；模拟器软键盘未显示时只证明输入聚焦，不改变宿主键盘设置或宣称IME完整验收。四状态图保留实际差异，参考成功不等于真实账户接口/SDK通过。


## iOS 语种选择隔离参考

`ios/build_reference.py native|flutter --language --simulator <已启动的明确UDID>`。与其他场景互斥，非法组合在设备动作前拒绝；独立`.language`身份，不覆盖普通业务App。原生直接固定bb9ff349的实际语种选择Controller、纯策略及Masonry；Flutter直接生产TranslationLanguagePage。两侧宿主仅在内存保留语言code，选择返回独立根，重入带当前值，取消不改值；不读取账号偏好、不注册SDK、不联网。

2026-10-09正常字体实际初始中文→日语→根ja→重入勾选→取消仍ja，两侧原图位于ignored `.local/ui-reference/ios-language`，源哈希位于ios-isolated/*-language-sources.json。原生AX只暴露首行时可依据fresh截图操作可见行并核验返回结果；Flutter具名按钮和selected独立检查。行高共同64，Flutter返回48相对原生42保留6点可访问差异；此局部正常对照不代表系统大字、全部翻译页面或真实电话已验收。


## iOS完整Shell录音失败参考

`ios/build_reference.py flutter --shell --recording-scenario normal|processing|loadFailure|playFailure|saveFailure --simulator <明确已启动UDID>`。默认normal保持既有完整Shell身份；其他场景独立`.shell.recording.<小写场景>`包。非法场景/非Flutter Shell在设备动作前拒绝。编译期UI_RECORDING_SCENARIO仅tool读取，复用现有合成录音端口及正式历史页面，不读写文件或播放真实声音。metadata记录场景，避免混用状态。

2026-10-09实际iOS加载/播放/保存首次失败及重试、取消/确认、关闭重入无旧成功反馈；原图在ignored ios-shell-history。保存确认是明确MOCK内存操作，不代表系统文件导出。processing和系统大字/真实音频单列待验。


## iOS记录时间调用方参考

`ios/build_reference.py flutter --record-time --simulator <明确已启动UDID>`，仅Flutter且与其他场景互斥，独立`.recordtime`包。直接生产TasksPage与TranslationHistoryPage，同合成近期/跨年记录按正式卡入口进入和关闭；无账号Provider、网络、录音或文件端口，metadata记录两页和纯时间规则哈希。默认字体实际星期/跨年进入返回图在ignored ios-record-time。宿主默认主题背景仅参考，不当整App视觉一致或UIKit整页证据。


## iOS历史内容展示部件参考

`ios/build_reference.py native|flutter --history-content --simulator <明确已启动UDID>`，独立`.historycontent`身份，与其他场景互斥。原Controller有服务/音频副作用，不编译运行；从固定Git逐字抽取color/trim、header方法及字幕UIView，ignored generated标记/原文件及四字节范围SHA/产物SHA记录metadata，缺失/重复结构拒绝。只链接实际纯模型/策略/Masonry，不导出账号/服务/SDK。原生宿主按已核对header/scroll/stack几何装配，时间/时长明确固定标签；原日期逻辑未在本宿主运行。Flutter直接生产TranslationHistoryPage，两条相同双语，双方不装配录音。

2026-10-09两侧内容与关闭本地结果实际核验，原图在ignored ios-history-content。原生关闭仅工具替换视图，Flutter亦本地反馈，不当原controller导航验收。蓝字幕目前Flutter低6逻辑点，系统字形/阴影继续待对齐，不能将部件及装配对照当全部历史页或真实录音流程通过。


## 联系人专项隔离参考

`python3 tool/native_ui_reference/ios/build_contacts_reference.py native|flutter --simulator <明确已启动UDID>`，Flutter可追加`--large`（两倍字号）；原生固定UIFont不接受大字号选项，非法组合在设备动作前拒绝。独立身份`com.vvtech.phoneagent.ui.contacts.native`、`.flutter`、`.flutter.large`，不覆盖普通App。

原生从固定iOS提交bb9ff34966f40a3c2794a9a8b8e935669a9faa12抽取实际列表/行、详情/备注/Skill纯UI，记录提取范围与SHA；生成文件位于ignored目录。最小宿主动作只在内存保存合成备注，Modal无障碍兼容层仅参考；不编译通讯录、服务、账户、电话或Agent。Flutter直接ContactsRoute，明确合成设备/目录/技能/版本与设置端口，编译bundle无业务插件。

`python3 -m unittest discover -s tool/native_ui_reference/ios -p test_contacts_reference.py`核对真实UI提取、业务IO拒绝及非法大字号选项。Android原生init脚本只复制顶层Compose参考源至ignored快照，避免递归混入Flutter宿主；现有Flutter组件入口按contacts/contacts-detail/contacts-skills/contacts-remark场景构建，并在模拟器安装前执行零业务权限验证。

2026-10-09双端正常四页面运行对照、iOS正式Flutter联系人备注保存重入与两倍字号输入保存/技能已验证。截图在ignored `.local/ui-reference/contacts-evidence`，构建元数据在`.local/ui-reference/ios-contacts`。真实权限/账号备注/电话与完整软键盘大字未验；字形行盒、阴影及SafeArea差异详见[联系人报告](../../docs/engineering/CONTACTS_PARITY_20261009.md)，不当逐像素或真实业务验收。


## 联系人Tab权限入口专项
`ios/build_contacts_reference.py flutter --tab-entry --simulator <明确Booted UDID>`直接生产ContactTabEntryGate和ContactsRoute，合成权限/目录与设置返回，不注册插件。可加--large两倍字号，--android-style仅Flutter tab-entry；各变体独立身份。`native --permission-dialog consent|settings --simulator <UDID>`从固定bb9ff349导出实际权限Dialog/Policy，确认空回调；Common仅声明/最小模态兼容，绝不链接系统授权或设置。
Android原生scene contacts-permission/contacts-permission-settings直接正式Compose纯UI，确认空回调。Flutter target为flutter_contacts_tab_reference.dart；UI_CONTACTS_PLATFORM=android，UI_CONTACTS_DIALOG=consent|settings仅工具自动呈现弹窗，非Tab操作证明。纯宿主构建追加-Dphoneagent.uiReferenceNoBusinessHost=true和-Dphoneagent.uiReferenceContactsTab=true，独立com.vvtech.aiassistant.ui.contactstab；安装前verify_flutter_isolated_reference.py <aapt> --contacts-tab，仍拒绝任何Android权限/业务宿主。旧默认参考身份保持，安装降级失败不得卸载回退。
2026-10-09实际iOS取消/合成授权/拒绝/模拟设置返回及两倍字号操作通过；Android仅原生与Flutter弹窗截图，无CUA窗口可用。详细差异及真实系统待验见[入口报告](../../docs/engineering/CONTACTS_TAB_ENTRY_20261009.md)。工具安全4项覆盖非法组合在设备操作前拒绝，原图ignored不提交。
