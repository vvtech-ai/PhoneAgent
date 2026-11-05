# 原生功能对齐差异台账

2026-10-05，步骤一台账及后续邀请实施更新。原始静态审查固定来源保留；NF01/NF22/NF28–NF31已按用户后续确认实施，新增证据见[邀请验证](INVITE_PARITY_VALIDATION.md)。其余条目的历史范围保持，不以页面数量计算完成率。

2026-10-06用户确认的六类高风险能力核查/修复见[专项验收矩阵](HIGH_RISK_CAPABILITY_VALIDATION_20261006.md)：覆盖NF06/NF14/NF16/NF17/NF19–NF22的相关已接线链路，补录音停止/失败重试和国外翻译终态钱包只读同步。自动证据更新不改变这些条目“真实能力待验”的状态，不代表完整W05或其他新增原生功能完成。

## 2026-10-09 初始化固定原生配对与共同布局增量

| 范围 | 实现与验证 | 仍待完善 |
|---|---|---|
| 模型卡 | ba22d94共同紧凑整卡及具名选中；3507880同步固定原生Qwen/Seeduplex能力说明，未知/V3不推断、重复描述只显示一次；最新初始化及两步Shell45项5秒、analyze4.9秒 | 真实目录、音色/克隆与服务端保存；展示标签不等于克隆许可 |
| 顶部与字段 | 0355f85标题居中/完整48热区及大字，c152e7f浅边框/蓝选中焦点/统一占位；实际合成12位电话截11位，返回草稿姓名/女/电话保留 | 中文IME、真实读屏及Android完整运行；48热区相对UIKit36/42/44为明确适配 |
| 固定UIKit对照 | e7d4490四范围原始字节SHA及独立无服务宿主；最新同合成目录两端能力说明与选择实际PNG、domain/policy SHA吻合 | 三行卡span261/257物理像素约1.3点高差及约2点位置差、系统字形；未标整页V通过 |

原始图位于ignored的`.local/ui-reference/ios-initialization-reference`，明细见[活动任务](../../openspec/changes/native-ui-interaction-parity/tasks.md)。只运行独立纯UI身份，无SDK/真实认证/短信/外呼，当前增量不能用历史冻结3658/1宣称新的全量。

## 2026-10-09 联系人备注及拨号完整流程增量

- `8bae721`修复备注重复编辑入口及旧编辑器取消/保存/输入污染：8项问题先复现，备注/删除/提示邻接39项通过，保存忙态及正式联系人Shell最终13项通过（范围重叠，分别计数）；analyze3.7秒。实际iOS取消→重开→合成输入→保存回详情已复验。
- `2062317`实际备注取消不保存、保存后列表重入保留、删除确认取消不改内容；`2eb2fcf`实际拨号123→国家搜索65→新加坡选中/重入→删除一位12→对方日语→提示返回→关闭翻译拨号回普通拨号→关闭回联系人→重开保留12/+65。
- 原始图在ignored的`.local/ui-reference/ios-contact-remark`与`ios-dialer-country`；只独立纯UI内存端口，未删除备注、读取真实通讯录、拨打电话或初始化SDK。真实服务/全国家语种目录/跨进程偏好、双端原生整页配对仍待验，不以正常点击替代旧回调竞态测试。

## 2026-10-09 登录初始化、身份及评分最新增量

以下增量已保存至`codex/dev_zys`；历史全量冻结2b0c43f的3658通过/1跳过不包含这些修改，各批定向分别计数，不合并成新的全量结论。

| 共用业务 | 已实现及实际iOS正常流程 | 尚需完善/验收 |
|---|---|---|
| 登录与两步初始化 | e25f8bb独立未登录演练；错误验证码留登录、合成登录、身份跳过与填写、模型返回保留草稿、完成首页；a6133f8协议唯一具名勾选、性别/模型具名选中与忙态禁用，42项定向/分析通过 | 真实短信/账号、服务端保存、双端系统键盘与读屏、固定原生整页配对；合成协议动作不接受真实服务条款 |
| 模型与系统音色 | 9129fd9实际Qwen音色Andre→Ethan、关闭回传；Seeduplex选择、音色取消、设置摘要×2.0及重入保持 | 真实目录/音频/偏好持久化；演练单voice与非活动卡默认摘要不证明每模型持久保留 |
| 身份编辑 | 4f388ca性别单节点selected/enabled/tap，27项定向/分析通过；实际选中→取消恢复→保存回设置→重入回显；初始化姓名Synthetic UI/女回显 | 真实认证/SDK/克隆音色清理与文件/账户联调，完整原生视觉 |
| 评分与回执 | 9701aae弹层/成功独立一次性返回，最新saving门禁、旧入口禁止叠加成功反馈；34项定向/分析通过；实际草稿关闭重开、失败重试、完成回来源、只读查看再关闭 | 真实评分/奖励/音频及跨进程恢复；旧回调竞态由专项测试证明，不能用单次平台点击冒称实际竞态验收 |

原始运行图分别保存在ignored的`.local/ui-reference/ios-shell-login`、`ios-onboard-selection`、`ios-identity-gender`、`ios-rating-return`及`ios-model-selection`，执行细节和真实IO边界见[活动任务](../../openspec/changes/native-ui-interaction-parity/tasks.md)。全部使用独立纯UI身份，无普通App替换或可信SDK初始化；Android普通数据未动。SDK已复制入工程并从指定原生读取私有配置，安全模型短期配置及真实测试条件仍独立待补，详见[国内联调缺口](DOMESTIC_TRANSLATION_INTEGRATION_GAPS_20261008.md)。

## 2026-10-08 国内翻译与平台配置接续状态

以下为后续批准实施后的当前补充，后面的 F=75e0e2 静态表保留原审查时点；NF32 原“缺失”不能再当作当前源码事实。未按实现文件数量计算业务完成率。

| 能力 | 当前实现 | 验证及待完善 |
|---|---|---|
| NF32 国内模型与账号设置 | 可信CN入口、Qwen3.5/豆包服务端读取/确认切换、原音设置共享导航；用户已删除手动SIP账号入口和设备偏好依赖 | 定向页面/账户切换/拨号门禁通过；内部默认值仅准备占位，实际注册凭证以服务端租约为准，不读取或删除旧偏好 |
| NF32 正式拨号与双向翻译 | 国内/国际网络号码、模型/语种冻结计划、积分准入、租约、UDP SIP/G711/RTP、双模型WS、开场、字幕、静音/扬声器/手动DTMF及共享通话页接线 | 离线与真实本机loopback通过；安全模型配置来源尚未提供，默认在权限/积分/SIP前拒绝，不构成可用的线上实时通话交付 |
| NF32 积分与归档 | 原生五动作、幂等/续授权/终态权威；DOMESTIC_ANDROID独立归档、账户隔离私有录音、AAC上传、停止日志恢复 | 定向上传/崩溃窗口/账户门禁通过；真实后端结算、双端语音与字幕、DTMF和录音上传待明确测试条件 |
| NF32 双端录音 | 物理通话时间轴、两轨最终混音、完成标记及回执、真实AAC16k单声道编码；归档和pending删除持久确认后仅清理同call私有文件 | [实际模拟器合成编码](DOMESTIC_RECORDING_SYNTHETIC_VALIDATION_20261008.md)通过；真机听感/通话录音未验。pending删除后崩溃可留孤立文件，全局存储配额及有事实依据的孤立清理待完善 |
| NF35/C05 活动翻译后台 | Android已授权前台启动的microphone服务/通知/CPU锁/不重启；iOS audio后台声明和活动duplex；显式租约不扩展普通ASR/TTS | owner/PCM定向及双端Debug构建通过；真机锁屏、耳机/来电中断和后台双向听感仍待验，不把配置存在当实际验收 |
| C01/C02 构建与发布 | Flutter3.32/Dart3.8、已验证JBR21、普通debug身份保留；独立合成演练包与业务包分开 | 合成演练后恢复普通APK构建身份；生产签名/同签名OTA/旧数据升级及iOS正式分发仍独立待验，未交付正式升级产物 |
| UI参考来源 | iOS演练直接从固定bb9ff349导出所需纯UI git对象，原生HEAD前进不更换基线 | 固定36源/头文件的候选隔离编译启动和运行图已核验；完整页面/子页/错误态/两倍字/手势差异闭环仍按active UI tasks继续 |

从Flutter工程角度，国内通话采用 feature-first：纯Dart SIP/积分/模型/媒体生命周期在 domain；HTTP/WS/UDP、私有文件和设备通道在 data；共享页面通过 controller 合同展示，UI不直接发起网络或硬件。app层按账户装配通话与归档，SIP账号与地址以服务端租约为准，不再依赖手动SIP偏好，模型设置按账户生命周期维护；平台代码仅处理路由、PCM、后台与编码。两端共享业务/UI，必要差异落在系统权限、后台服务/audio模式及文件保护。当前关键未完项是安全配置与真实验收、UI运行对照、存储长期治理和正式升级，具体依赖见[国内联调缺口](DOMESTIC_TRANSLATION_INTEGRATION_GAPS_20261008.md)。

## 2026-10-09 可信来电与扩展当前工程事实

此节覆盖下方固定75e0e2审查表中NF33/NF34/C06的历史“缺失”；自动测试、编译、纯UI运行与真实SDK验收分别记录。

| 范围 | 已实现 | 尚需完善与验收 |
|---|---|---|
| SDK副本/私有配置 | Android工程AAR；iOS工程Vendor test/pro及资源，本地生成配置来自指定原生固定提交、ignored且不入Dart；51文件哈希及双端Debug编译 | 真实SDK许可与各包身份匹配；正式签名和授权服务结果 |
| 双端可信设置 | 完整account/phone/epoch/env及surface隔离；Android SDK首次/后续UI，iOS首次说明与SDK进入/取消/返回，授权仅接受明确事实 | Android公开SDK尚无可靠授权查询，仍仅readyToConfigure；SDK实际页面、拒绝权限与退出 |
| Android SIM | 既有权限按系统版本读取、固定单卡/多卡规则、写前journal与写后回读、账号切换等待旧SDK窗口实际销毁再清理、仅清App归属未改值 | 实际SIM/双卡、SDK保存/用户修改、引擎切换与窗口销毁时序；后台角色及receiver/service仍禁用 |
| iOS账号/来电 | 原生APNS内存token串行绑定、UN代理链/背景通知、精确payload及SDK验证、consumer/event隔离、唯一incoming UUID结束、首账号恢复前25秒单条内存通知 | 实际通知/APNS和SDK；注册Plugin之前通知、跨进程未确认绑定、CX时序和多来电；号码匹配与PSTN关联不能混同 |
| 凭据UI | 独立Flutter四状态凭据页及root owned route，原图资源；固定iOS纯宿主与Flutter同合成数据实际查看/返回、大字拖动及边框修正 | 两端普通SDK业务端到端和完整页面视觉，iOS说明物理滚动仍待验；页面源码/局部图不算完整功能验收 |
| LiveActivity | 独立WidgetKit target、原生锁屏/岛视图、共享属性、公开前台新鲜verified创建、4KB预算、到期/账号/来电清理及当前UUID深链展示版本 | 实际签名/锁屏；后台push-to-start需可信服务端验证契约，不采集或绑定未知token、不用私有回退 |

详细来源、边界和验证见[可信SDK契约](TRUSTED_CALLER_SDK_CONTRACT_20261008.md)与[执行任务](../../openspec/changes/trusted-caller-parity/tasks.md)。当前Android min26及Debug/Profile .dev、iOS App15.5/扩展16.1与测试/正式包前缀保持，iOS仅已有audio/remote-notification后台用途；Android生产任务仍受签名/OTA保护，不交付正式升级产物。SDK配置来源已经用户明确，不再列为待提供；模型短期凭证来源属于独立国内翻译缺口。

## 2026-10-09 共用业务连续交互补验与修复

本节为后续执行的当前补充。仅包含工程自带隔离端口的实际Web交互和相应源码修复，不新增线上可用结论，不关闭双端原生完整一致性验收。SDK配置已经从指定原生固定提交读取到工程私有配置，不能再列为待提供；国内模型安全短期配置与真实测试条件仍是独立缺口。

| 业务范围 | 实际连续交互与本轮实现 | 尚需完善/验收 |
|---|---|---|
| NF01–NF04 登录/初始化/模型音色 | 合成验证码校验与冷却、身份↔模型草稿保留、两步完成直达首页、快捷取消、非当前模型音色入口切换及回首页 | 真实短信/认证、服务端目录和持久化；双端键盘/完整UI |
| NF05/NF15 对话/批量确认 | 文字输入、候选回传、联系人展开/收起、确认前取消、任务未完成及同内存会话恢复取消状态 | 真实Agent、批量执行/重连/结算及跨进程恢复 |
| NF08/NF09 附件 | 合成docx/xlsx自动解析回传、bundled图片识别图文、同内存历史附件恢复；Agent请求Markdown、OK/USER_CANCELLED、取消后继续 | 真实系统选择/相册/解析服务/中文OCR及后台收件；工具文档专项不证明真实历史 |
| NF11/NF12 联系人/拨号 | 详情备注保存/编辑取消保留、Skill带入联系人、202号码匹配与只预填、不自动外呼 | OS通讯录/权限、备注API、姓名/T9全部情况与真正系统拨号 |
| NF13/NF16 翻译历史/录音 | 静态种子详情、模拟播放/保存取消；修复主次字幕独立语义，长按选择及更新保留 | 真实新通话归档、音频/系统导出、双端读屏 |
| NF16/NF17 回执/评价 | 单路草稿恢复、预设失败重试、合成成功及只读、批量赞踩/展开；修复字段/摘要/详情/转写空语义 | 真实评分奖励、音频、跨任务/账号及后台恢复；合成7积分不增钱包 |
| NF18/NF19 翻译电话 | 模型/语种/服务节点、号码拒绝、合成媒体就绪/接通/双语字幕、静音/音源/DTMF按钮、挂断、最近记录只预填 | 真实位置/权限/媒体声音/DTMF/路由回退/结算归档；按钮演练不等于电话成功 |
| NF22/NF23 原声/钱包 | 原声90%/混音40%调节与重入、900样例余额/流水；Slider.label保留系统10%语义动作 | 真机偏好消费/声音、实际账户余额/邀请奖励/跨进程对账 |
| NF20/NF21 身份/声音克隆 | 身份草稿放弃、保存自动返回与重入；姓名/手机输入具名；合成勾选→填写→假采集→候选→具名试听→模拟确认→返回，克隆姓名/身份证输入具名且保留门禁 | 真实身份采集/克隆服务/音频/收费/存储；双端读屏，合成“已认证”不构成真实认证 |
| NF26 开发者/外呼配置 | 本地拨号串拦截开启入口；内存号码保存自动返回/草稿放弃/重入；按固定两端共同样式校准表单、短屏大字换行标题；JP/Gemini/强制开关返回重入保持 | 真实号码API及拨号消费、平台权限/位置来源；开发者可见性不授予业务权限，海外节点不是用户真实地区 |
| NF29 邀请复制/海报 | 当前码独立可读且可长按选择，模拟复制反馈；生成海报后端口拒绝显示取消，无误报成功；返回900样例余额 | 真实系统剪贴板/相册、链接、注册和奖励；内存PNG不等于已保存到设备 |
| NF37 关于/手动日志 | 正式入口直接模拟上传；失败重试→已上传但清理失败→只重试清理→成功→返回，复用生产ZIP/controller | 真实诊断文件/上传服务及双端实际运行；本轮空上传回调，不证明日志送达 |
| NF33 可信来电 | Web设备前拒绝→打开禁用→刷新→返回；不可用提示不再推断配置缺失 | 普通双端SDK授权/SIM/APNS；不支持Web不反推工程配置失败 |

修复和证据提交：81f9d24（字幕）、53a1002（回执）、e56036e（滑块名称）、93ff81e（仅工具文档续聊分流）、6501f55（不可用提示）。相应定向分别17、12、8、9、30项通过，非一次全量；旧006ae55全量3575通过/1跳过保留为历史证据；本轮5ad5552冻结点全量3598通过/1跳过/0失败（5分25秒）覆盖上述后续实现。后续实现及范围：50c8675（身份输入14项）、c43def1（克隆试听21项）、802c1d2（克隆输入27项）、0374271（外呼样式20项及共用标题相邻22项）、5ad5552（邀请码10项）；各自定向通过，未将总数相加成全量。749e2c0和946ee1d为开发者配置/日志实际演练记录，没有新增生产行为。跨模块里程碑以5ad5552冻结点全量回归3598通过/1跳过/0失败（5分25秒），唯一跳过为UI_AGENT_DOCUMENT显式场景专项，本次未开启，该专项此前已有独立验证；不代替真实能力。实际Web原图保存在工程忽略目录`.local/ui-reference/web-shell-*`，详细场景、失败恢复、截图尺寸与限制见[执行记录](../../openspec/changes/native-ui-interaction-parity/tasks.md)。旧web-shell-flow为414×800；新标签早期未继承viewport的图为1280×720，后续显式设定的mobile图为414×800。部分语种字体缺字仍未关闭，所有P01–P29/P08a完整双端V保持待验。

## 2026-10-09 Flutter工程结构、逻辑和UI分析

当前主入口为[main.dart](../../lib/main.dart)：初始化Flutter、锁竖屏、读取APP_ENV/API_BASE_URL并校验配置，装配ProviderScope和诊断宿主。[PhoneAgentApp](../../lib/app/phone_agent_app.dart)以MaterialApp.router承载根鉴权页，GoRouter按loginEpoch重建；业务子页沿用Navigator。令牌刷新保留epoch，账户退出/切换则更换导航和业务归属；可信凭据与邀请入口挂在根宿主，避免落到过期子路由。Web的[MobilePreview](../../lib/app/mobile_preview.dart)将整个导航与弹层限制为最大430宽，Web演练不能代替系统键盘、读屏、后台和返回手势。

| 工程层 | 实际职责与代码方向 | 维护重点 |
|---|---|---|
| lib/app | Riverpod依赖装配、账户生命周期、路由及各能力Provider；正式端口与演练override在装配处隔离 | 避免把多种生命周期塞入同一controller；切号/退出、迟到异步和子路由必须共同验证 |
| lib/core | 环境/网络/安全存储/诊断及NativeDetailHeader、NativeGradientAction等共同设计组件 | 共用组件改动验证直接调用方；保持唯一具名语义、动态字号和触达范围 |
| lib/features | 24个职责目录，包含鉴权/初始化、模型/语音、对话/任务/附件、联系人/拨号/翻译、身份/克隆、积分/邀请/反馈、日志/更新/可信等 | 按feature-first组织presentation/pages/widgets/controller、domain、data；目录数量不代表业务完成率 |
| domain与data | domain定义纯Dart模型/规则/生命周期；data负责HTTP/WS/UDP、Repository/DTO、私有文件和平台端口 | UI经controller或Provider使用端口；后端事实优先，未配置/未知/不可用不能当零值或授权成功 |
| Android/iOS宿主 | 设备权限、系统来源、PCM/路由/后台/编码/SDK/通知等薄适配，业务状态仍由共享层编排 | 保持env/account/epoch/consumer归属；系统能力真实结果与共享UI互相校验 |
| test、tool、openspec及docs | 自动测试、明确MOCK演练/固定原生纯UI参考、变更规格和分级验收证据 | 真实参考读取固定git对象；不把合成端口、编译或静态图混成端到端验收 |

UI当前采用一个共同视觉体系，ThemeData为Material3，但正式关键页面显式使用原生共同的颜色、字重、卡片、渐变动作和返回标题，不能只靠主题默认控件宣布对齐。这轮外呼页由默认AppBar和下划线输入改为共同表单就是具体差异修复。对话采用生产可选文本与独立语义；候选/资料/回执按实际可见内容更新，控制器门禁决定可操作性。手写源码遵守500行与职责拆分、每微批不超过3源码文件；具体例外见[file_exceptions](file_exceptions.md)。实际仍需完成全部页面正常/空/错误/忙碌/大字/键盘/返回运行配对，已有29页及子页目录不是全部验收通过。

## 2026-10-09 双端工程配置分析

[依赖声明](../../pubspec.yaml)固定Flutter3.32/Dart3.8边界，Riverpod2.6.1、GoRouter15.1.2、Dio5.8.0+1、LiveKit2.4.6、secure storage、file/image picker、MLKit、音频/压缩/二维码等承担已有功能。这里只报告本仓库锁定版本，不建议自动升级；当前另有pubspec.lock托管URL差异未纳入本任务提交，未修改依赖版本。

| 项目 | 当前配置与必要平台差异 | 尚需完善 |
|---|---|---|
| Android构建 | [Gradle](../../android/app/build.gradle.kts)min26、compile/target沿固定Flutter模板、NDK27.0.12077973；Java/Kotlin源码目标11，实际构建使用已验证JBR21，二者不是同一概念 | 正式签名、版本号策略、同签名OTA和旧数据保留升级；Release仍有明确保护，不以foundation包交付升级 |
| Android身份/设备 | prod com.vvtech.aiassistant，Debug/Profile .dev；系统联系人/通话记录/位置/通知/录音按权限与系统版本隔离；活动翻译前台麦克风服务及CPU锁 | 真机权限拒绝、SIM/双卡、后台中断和系统拨号；call-screening角色/后台receiver当前不冒充可用 |
| iOS构建/身份 | 主App15.5、Swift5；Debug/Profile com.chaken.phoneagent.test，Release com.chaken.phoneagent；WidgetKit扩展16.1及对应包前缀 | 真实签名/provisioning/扩展安装、正式分发及锁屏/岛运行；无OTA，不照搬Android更新链 |
| iOS设备/通知 | [Info.plist](../../ios/Runner/Info.plist)仅竖屏、相机/麦克风/联系人/位置/相册用途说明、audio/remote-notification、LiveActivities；系统来电记录不开放给应用，使用App记录 | 真机音频会话、后台/耳机/来电中断、APNS服务与权限、跨进程绑定和真实SDK；声明存在不代表系统验收 |
| 可信SDK工程依赖 | Android libs/trusted_caller两个1.5 AAR；iOS TrustedCallerSDK/Vendor/test与pro KXSDK及Common框架/Resources，按有效环境选择，私有配置从参照项目读取并ignored | 包身份/许可/正式授权、APNS/SIM/LiveActivity实际链路。构建使用工程副本，不再依赖交付iOS_SDK路径，配置来源问题已解决 |
| 邀请与文件 | Android按版本用MediaStore/系统文件创建，iOSPhotoKit追加保存；Debug/生产链接环境分开，私有录音与资料归属按账号/任务隔离 | 正式域名关联/系统唤起/相册拒权、存储长期配额与孤立文件治理；纯Web图片取消不等于双端保存能力已验 |

## 1. 固定来源与读法

| 别名 | 本机仓库／路径前缀 | 固定提交 |
|---|---|---|
| A | 仓库 `/Users/Eason/Desktop/Git/AIAssistant1`；下文 `A:` 相对 `android/app/src/main/java/com/vvtech/aiassistant/` | `0f8879e4baf1d56fe6d7f8f356101fdf61d602ed`（test/v65.0.1） |
| I | 仓库 `/Users/Eason/Desktop/Git/AIAssistant`；下文 `I:` 相对 `iOS/PhoneAgent/PhoneAgent/` | `bb9ff34966f40a3c2794a9a8b8e935669a9faa12`（iOS/v1.0.46/dev） |
| F | 本 Flutter 仓库；源码链接相对本文 | `75e0e256b3b193129126f7d8df8ef28a78f36c63`（含 iOS Team 配置） |

重查外部证据：在对应仓库执行 `git show <固定提交>:<上述前缀><路径>`。路径不依赖分支今后是否移动。下面 R 编号描述正式入口到页面／服务的核查线索，不能把同一行内所有文件理解为直接相邻函数调用。

状态：**已接线**表示入口、共享逻辑和适配已存在，不等于真实业务验收；**部分**表示已有基础但缺少目标能力；**缺失**表示正式 Flutter 入口／能力未发现；**平台等价**表示效果按平台能力实现；**待核实**表示入口或业务语义证据不足。以下“待验”均不代表本轮测试失败。

历史证据分级：H1=[2026-09-22交接核对](MIGRATION_GOAL_AUDIT_20260922.md)，83项定向收尾及报告索引；H2=[Android真实登录和文字恢复](ANDROID_LOGIN_CONFIRMATION_STAGE_20260921.md)与[Web真实文字](WEB_REAL_TEXT_STAGE_20260921.md)，仅其报告场景；H3=[页面覆盖表](PAGE_FLOW_COVERAGE.md)中的专项自动化及双端隔离端口演练；H4=[集中人工清单](MIGRATION_HANDOFF.md)中的尚未验证项。H1/H3不是新版三端同提交端到端通过证明；iOS真实登录、真实媒体／SDK、Android暂缓27点仍按原记录待验。

## 2. 原生正式入口与调用链证据

| 证据 | Android | iOS |
|---|---|---|
| R01 登录／初始化 | `A:features/assistant/AssistantAuthGate.kt` → `A:features/assistant/SmsLoginSubmission.kt`；`A:features/assistant/V61InitializationOverlay.kt` 与 `A:features/assistant_initialization/AssistantInitializationPolicy.kt` | `I:App/AIRootViewController.m` → `I:Features/Auth/AILoginViewController.m`、`I:Features/Auth/AIInitializationViewController.m` |
| R02 首页／模型 | `A:features/assistant/AssistantPageHost.kt` → `A:features/assistant_home/AssistantHomeConfigRoute.kt` → `A:data/homeconfig/HomeConfigRepository.kt`；设置进入 `A:features/assistant_settings/AssistantRealtimeProviderPage.kt`、`A:features/assistant_settings/AssistantRealtimeCallVoiceSettingsPage.kt` | `I:App/AIMainTabBarController.m` configureTabs → `I:Features/Home/AIHomeViewController.m` → `I:Core/Services/AIHomeConfigService.m`；音色 `I:Features/Settings/AISettingsRealtimeCallVoiceViewController.m` |
| R03 统一对话／工具 | `A:features/assistant/AssistantConversationPageHost.kt` → `A:features/assistant_pure_voice/PureVoiceThreadList.kt`；流执行 `A:features/assistant_agent/AgentStreamTurnRunner.kt`、联系人工具 `A:features/assistant_agent/AgentStreamDeviceContactSelectionHandler.kt` | 主 Tab 打开 `I:Features/Assistant/AIAssistantViewController.m`；联系人选择 `I:Features/Assistant/AIAgentDeviceContactSelectionViewController.m` |
| R04 文档／OCR | `A:features/assistant_actions/AssistantAgentDocumentActionHandler.kt` → `A:features/assistant_shell/AssistantAgentDocumentPickerActions.kt`；`A:features/assistant_pure_voice/ocr/MlKitPureVoiceOcrProcessor.kt`、`A:data/repository/ocr/ConversationOcrAttachmentRepository.kt` | 对话进入 `I:Features/Assistant/AIAgentDocumentImportViewController.m`；`I:Core/Services/AIPureVoiceOcrService.m` |
| R05 联系人／拨号 | `A:features/assistant/AssistantContactPageHost.kt` → `A:features/assistant/FinalContactsPage.kt`；`A:features/assistant/AssistantSingleFlowPageHost.kt` | 主 Tab → `I:Features/Contacts/AIContactsViewController.m` → `I:Features/Contacts/AIContactDirectoryDetailViewController.m`；数据 `I:Core/Services/AIContactsService.m` |
| R06 任务／单路／批量回执 | `A:features/assistant/AssistantTaskSettingsPageHost.kt` → `A:viewmodel/TaskListViewModel.kt`；`A:features/assistant_tasks/TaskCallMonitorController.kt` → `A:features/assistant_audio/CallMonitorAudioSocketClient.kt`；对话 ThreadList 批量渲染 | 主 Tab → `I:Features/Tasks/AITaskListViewController.m`、`I:Features/Tasks/AITaskDetailViewController.m`；对话 → `I:Features/Voice/AIVoiceCallViewController.m`、`I:Features/Voice/AICallMonitorAudioSourceSheetViewController.m` |
| R07 翻译／历史 | `A:features/assistant/AssistantSingleFlowPageHost.kt` → `A:features/translation_call/ui/TranslationCallScreen.kt`；`A:features/translation_call/data/RegionAwareTranslationCallGateway.kt` 分流 | 主 Tab → `I:Features/Calls/AIRealtimeTranslationHistoryViewController.m`；`I:Features/Settings/AISettingsOverseasTranslationViewController.m`、`I:Features/Calls/AITranslationCallSettlementViewController.m` |
| R08 身份／克隆 | 设置 → `A:features/assistant/MyIdentityScreen.kt` → `A:data/repository/UserIdentityRepository.kt`；核验／模型 `A:data/remote/voiceclone/VoiceCloneVerificationApi.kt`、`A:data/remote/voiceclone/VoiceCloneModelApi.kt` | 设置 → `I:Features/Settings/AIVoiceCloneModelFlowViewController.m`；`I:Core/Services/AIUserIdentityService.m`、`I:Core/Services/AIVoiceCloneEnrollmentRepository.m`、`I:Core/Services/AIVoiceCloneVerificationService.m` |
| R09 钱包／邀请 | TaskSettingsPageHost 的 PointsWallet → `A:features/invite/WelfareCenterRoute.kt` → `A:features/invite/InviteHomeScreen.kt`、`A:features/invite/InviteScreen.kt` → `A:features/invite/InviteRepository.kt` → `A:features/invite/InviteApi.kt`；原积分 `A:data/repository/points/PointsWalletRepository.kt` | `I:Features/Points/AIPointsWalletViewController.m` 挂载 `I:Features/Invite/AIInviteActivityViewController.m` → `I:Core/Services/AIInviteActivityCoordinator.m` → `I:Core/Services/AIInviteService.m` |
| R10 海报／外部唤起／奖励 | `A:features/invite/InvitePosterScreen.kt` → `A:features/invite/InvitePosterAlbumWriter.kt`；`A:MainActivity.kt` onCreate/onNewIntent → `A:features/invite/InviteIntentReceiver.kt`、`A:features/invite/PendingInviteStore.kt`、`A:features/invite/InviteRegistrationBridge.kt`；`A:features/assistant/AssistantInviteRewardOverlay.kt` → `A:features/invite/reward/InviteRewardNoticeHost.kt` | `I:Features/Invite/AIInvitePosterViewController.m`；`I:SceneDelegate.m` URL/userActivity → `I:Core/Services/AIPendingInviteStore.m`，登录 REFERRAL/requestId；Root → `I:Features/Invite/AIInviteRewardPresentation.m`、`I:Core/Services/AIInviteRewardStore.m` |
| R11 SIP／可信来电 | TaskSettingsPageHost 的 SipAccountSettings → RegionAwareSipAccountSettingsHost；`A:callengine/AssistantSipRouting.kt` → `A:callengine/AndroidAssistantSipCallSession.kt`；设置 onOpenTrustedCallee → `A:features/assistant/TrustedCalleeSimNumberBridge.kt` | `I:Features/Settings/AISettingsViewController.m` 第3行 trustedCalleeCard → openTrustedCalleeSettings/KX SDK；通话 `I:Features/Voice/AINormalCallViewController.m` startClientSipCall → `I:Core/Domain/Voice/AIClientSipCallLifecycleCoordinator.m`，主Tab另有localCallCoordinator分支；具体准入及设备效果需专项验收 |
| R12 设置／日志／更新 | `A:features/assistant/FinalSettingsHomePage.kt` → `A:features/app_logs/AssistantLogUploadRuntimeController.kt`；版本更新 → `A:features/assistant/FinalOtaUpdateInstaller.kt` | Settings UITableView 当前挂载身份、模型、原音、可信、关于、开发者／账号；`I:Features/Settings/AIOtaUpdateCoordinator.m` automatic=NO，Settings 的 versionUpdateCard 未出现在该列表，不能仅据方法认定当前可达 |
| R13 产物 | PureVoiceThreadList 的 taskArtifact/batchResult.artifacts → `A:features/assistant_artifacts/PureVoiceArtifactCard.kt` → `A:features/assistant_artifacts/ArtifactDownloadBinding.kt`、`A:features/assistant_artifacts/ArtifactDownloadCoordinator.kt` → `A:domain/artifact/ArtifactDownloadUseCase.kt`、`A:data/repository/artifact/TaskArtifactRepository.kt` | AIAssistantViewController 的 assistant_artifact/task_artifact 与批量 artifacts → `I:Features/Assistant/AITaskArtifactCardView.m` → `I:Core/Services/AITaskArtifactDownloadService.m` |
| R14 关于／账号／候选入口 | FinalSettingsHomePage 当前未见与 iOS 对等的关于／注销入口，不能推断 Android 已实现注销服务 | Settings 第4行 → `I:Features/Settings/AIAboutPhoneAgentViewController.m` → 协议页；账号 → `I:Features/Settings/AIAccountViewController.m` 确认输入后 deleteAccount 实际仅 signOut；`I:Features/Home/AIHomeTextComposerView.m` 未找到当前 Home 创建引用，Coordinator 仅找到清理引用 |

## 3. 功能差异与后续工作

“证据”列的 H 是历史结果索引，源码接线由本轮检查；无历史证据写“静态”。W 编号对应第6节工作包。UI均按业务交互与平台结果对齐，旧独立页面不要求逐个复制。

| NF | 业务／旧页面编号 | 原生依据 | Flutter 正式入口或逻辑 | 实现、证据与具体缺口 | 后续 |
|---|---|---|---|---|---|
| NF01 | 登录、验证码、会话恢复 P01 | R01/R10 | [AuthRoute](../../lib/features/auth/presentation/pages/auth_route.dart) → [DioAuthGateway](../../lib/features/auth/data/dio_auth_gateway.dart) | 已接线；H1/H2。已增新版REFERRAL/requestId和结构化错误；普通登录/邀请注册/恢复定向已验，真实iOS登录另验 | W01/W02 |
| NF02 | 首次身份→模型→首页 P02 | R01 | [初始化控制器](../../lib/features/initialization/presentation/controller/initialization_controller.dart) | 已接线；H3。用户确认两步优先，不照搬原生旧三步；真实持久化待验 | W01 |
| NF03 | 动态首页、Skill、积分摘要 P03 | R02 | [HomePage](../../lib/features/home/presentation/pages/home_page.dart) → [仓库](../../lib/features/home/data/dio_home_repository.dart) | 已接线；H1/H3。有缓存/回退；需新版配置、失效入口及版本展示核对（首页仍有1.0.0字面量） | W01/W09 |
| NF04 | 模型、默认音色、试听 P04/P05 | R02/R08 | [模型页](../../lib/features/call_models/presentation/pages/call_models_page.dart)、[音色页](../../lib/features/call_models/presentation/pages/call_voices_page.dart) | 已接线；H3。真实目录、选项消费、音频与克隆资产待验 | W01/W05 |
| NF05 | 统一页文字、补问、候选、恢复 P06/P07/P16 | R03/R06 | [ConversationRoute](../../lib/features/conversation/presentation/pages/conversation_route.dart) → [控制器](../../lib/features/conversation/presentation/controller/conversation_controller.dart) | 已接线；H2真实两轮/恢复，不证明全部工具。保持VOICE channel、候选“第N个”、不加确认执行按钮 | W01 |
| NF06 | 按住说话、ASR/TTS、文字切换 P06 | R03 | [语音装配](../../lib/app/conversation_voice_providers.dart)、[语音服务装配](../../lib/app/conversation_speech_providers.dart) | 已接线；H3/H4。真实麦克风、声音、打断、锁屏及焦点待验，不列为从零开发 | W05 |
| NF07 | 权限、工具进度与结果回传 P07 | R03 | [ConversationRoute](../../lib/features/conversation/presentation/pages/conversation_route.dart) | 已接线；H3三类合成权限结果。真实系统授权、后台收件及重复结果待验 | W01/W05 |
| NF08 | 主动附件／Agent索要文档 P08/P08a | R04 | [附件装配](../../lib/app/attachment_providers.dart)、[ConversationRoute](../../lib/features/conversation/presentation/pages/conversation_route.dart) | 已接线；H3，iOS4点MOCK，Android阶段未执行；真实文件选择、解析上传及收件待验 | W05 |
| NF09 | 相册OCR、长文展开、上下文 P09 | R04 | [OCR装配](../../lib/app/ocr_providers.dart) | 已接线；H3合成闭环。真实图片、识别质量、权限和超长结果待验 | W05 |
| NF10 | Agent选联系人／姓名号码查询 P10 | R03/R05 | [联系人工具连续测试入口](../../test/shell_contact_tools_workbench_test.dart)、[ConversationRoute](../../lib/features/conversation/presentation/pages/conversation_route.dart) | 已接线；H3。真实通讯录与ASR姓名、返回后台上下文待验 | W05 |
| NF11 | 联系人、详情备注、发起Skill P11/P13 | R05 | [联系人连续链路](../../test/shell_contacts_workbench_test.dart)、[ShellRoute](../../lib/features/shell/presentation/pages/shell_route.dart) | 已接线；H3。系统来源、备注API、跨账号清理真实验证待补 | W05 |
| NF12 | 系统拨号、国家/T9、最近记录、权限 P12/P14/P15 | R05/R07 | [拨号装配](../../lib/app/dialer_providers.dart)、[权限装配](../../lib/app/dial_permission_providers.dart) | 已接线／平台等价；H3。Android系统CallLog，iOS仅App记录；真实系统交接和设置返回待验 | W05 |
| NF13 | 任务列表、会话/终态恢复、翻译历史 P16/P17 | R06/R07 | [任务页](../../lib/features/tasks/presentation/pages/tasks_page.dart)、[翻译历史](../../lib/features/translation_history/presentation/pages/translation_history_route.dart) | 已接线；H2/H3。终态可恢复，不以CLOSED禁输；新版历史样本、真实归档待验 | W01/W05 |
| NF14 | 单路监听、音源、挂断、返回 P18 | R06 | [通话页](../../lib/features/calls/presentation/pages/call_session_page.dart)、[会话仓库](../../lib/features/calls/data/api_call_session_repository.dart) | 已接线；H3 Web/iOS模拟。真实媒体、电话及回执待验；普通返回不能推断为挂断 | W05 |
| NF15 | 批量确认、逐项进度、回执 P19/P06 | R03/R06 | [ConversationRoute](../../lib/features/conversation/presentation/pages/conversation_route.dart)、[计费装配](../../lib/app/confirmation_billing_providers.dart) | 已接线；H3扩展联系人及历史计费。新版结果/产物另见NF36；真实批量结算待验 | W01/W03/W05 |
| NF16 | 录音播放、下载保存、翻译录音 P17/P20 | R06/R07 | [录音页](../../lib/features/translation_history/presentation/pages/recording_audio_route.dart)、[录音仓库](../../lib/features/translation_history/data/io_recording_repository.dart) | 已接线；H3。真实文件、导出目的地、过期URL、旧录音迁移待验 | W05/W07 |
| NF17 | 赞踩、eligible评分、草稿及奖励 P20 | R06 | [评价页](../../lib/features/feedback/presentation/pages/call_evaluation_route.dart)、[评分页](../../lib/features/feedback/presentation/pages/task_rating_route.dart) | 已接线；H3。只读/失败/草稿有合成证据，真实奖励与幂等回执待验 | W05/W07 |
| NF18 | 国外翻译配置、位置/语种/模型准入 P21 | R07 | [配置入口](../../lib/features/translation/presentation/pages/translation_dialer_route.dart)、[设置](../../lib/features/translation/presentation/pages/translation_settings_route.dart) | 已接线；H3。位置可信性及模型后端可用性待验；国内SIP另列 | W04/W05 |
| NF19 | 翻译通话、字幕、DTMF、结束归档 P22 | R07 | [会话协调器](../../lib/features/translation/domain/translation_session_coordinator.dart)、[双端媒体装配](../../lib/app/translation_device_media_providers.dart) | 已接线；H1/H3。已有LiveKit/AppAudio；真实 create→media ready→merchant-call、fallback、音源和计费待验 | W05 |
| NF20 | 身份查看、保存、删除及清理 P23 | R08 | [IdentityRoute](../../lib/features/identity/presentation/pages/identity_route.dart)、[API仓库](../../lib/features/identity/data/api_identity_repository.dart) | 已接线；H3。真实服务和删除后的设备缓存待验；不是账号注销 | W05 |
| NF21 | 克隆创建、核验SDK、录音候选/保存 P24 | R08 | [克隆入口](../../lib/features/voice_clone/presentation/pages/clone_creation_route.dart)、[设备采集端口](../../lib/features/voice_clone/data/device_identity_capture_port.dart) | 已接线；H3。真实SDK/PASS/释放、收费、录音可用性待验 | W05 |
| NF22 | 积分激活、钱包余额/流水 P25 | R09 | [钱包入口](../../lib/features/points/presentation/pages/points_wallet_route.dart)、[钱包仓库](../../lib/features/points/data/api_points_wallet_repository.dart) | 已接线；H3。已增加邀请入口，真实余额和跨进程恢复待验；不新增充值 | W02/W05 |
| NF23 | 设置、原音混合、退出登录 P26 | R12/R14 | [SettingsRoute](../../lib/features/settings/presentation/pages/settings_route.dart)、[会话控制器](../../lib/features/auth/presentation/controller/session_controller.dart) | 已接线；H3。当前正式设置与新版iOS信息架构不同；注销不能等同退出 | W01/W09 |
| NF24 | 日志准备、上传、失败重试、清理 P27 | R12 | [日志页](../../lib/features/app_logs/presentation/pages/log_report_page.dart)、[日志仓库](../../lib/features/app_logs/data/zip_log_repository.dart) | 已接线；H3 Web/iOS合成。真实收件与Android阶段待验；用户取消的匿名导出不恢复 | W05 |
| NF25 | Android检查、下载、安装与OTA P28 | R12 | [更新装配](../../lib/app/app_update_providers.dart)、[安装页](../../lib/features/app_update/presentation/pages/update_install_route.dart) | 部分；H3交互。正式签名和旧数据/降级门禁未完成；iOS APK OTA不适用，手动检查入口见NF38 | W07 |
| NF26 | 暗号开发者入口、网络/号码/位置/列表/权限 P29 | R11/R12 | [DeveloperToolsRoute](../../lib/features/settings/presentation/pages/developer_tools_route.dart) | 已接线；H3 iOS增量。SIP文案/演练不等于正式SIP；真实号码/系统来源和Android阶段待验 | W04/W05 |
| NF27 | Android旧登录/偏好/记录/录音/评分迁移 P01/P17/P20/P26/P28 | R01/R06/R07及旧基线 | [旧状态清单](LEGACY_STATE_INVENTORY.md)、[迁移会话存储](../../lib/features/auth/data/migrating_session_store.dart) | 部分；H3合成迁移。真实同签名升级待验；未绑定账号旧异常标记不导入、不重放；D03仍待决策 | W07 |
| NF28 | 福利中心、邀请码、活动（记录仅数据层） | R09 | [现有钱包](../../lib/features/points/presentation/pages/points_wallet_route.dart) | 已接线；新增invite API/模型/活动/邀请码及个人资格文案；2026-10-11移除原生没有的邀请记录入口/页面，保留Android记录协议，合成定向通过，真实接口待验 | W02 |
| NF29 | 邀请海报、二维码、保存/复制（新增） | R10 | [当前平台注册](../../ios/Runner/AppDelegate.swift)及钱包未发现对应功能 | 已接线；二维码海报/复制/保存及成功后事件，PNG已解码到原链接；Android/iOS保存端口编译通过，真实相册待验 | W02 |
| NF30 | 邀请链接冷/热启动、欢迎页、登录绑定（新增） | R01/R10 | [根路由](../../lib/app/phone_agent_app.dart)、[Android Manifest](../../android/app/src/main/AndroidManifest.xml) | 已接线；欢迎/冷热点接收、环境校验、待处理持久化及注册重试；完整App合成闭环通过。Android测试域assetlinks 404，系统唤起待验 | W02/W06 |
| NF31 | 邀请奖励弹层、事件回执、去重（新增） | R10 | [积分会话装配](../../lib/app/points_providers.dart)无邀请奖励消费者 | 已接线；grantEvents/referralResult交叉核对、账号/operationId持久去重，确认失败可重试；不本地发积分，真实到账待验 | W02 |
| NF32 | 国内App SIP、账号配置、准入/通话（范围扩展） | R11/R07 | [翻译协调器](../../lib/features/translation/domain/translation_session_coordinator.dart)仅既有国外路径 | 缺失目标能力；静态。进入新目标，需客户端SIP媒体/租约/区域准入专项；不能沿用国外媒体已接作为完成证据 | W04 |
| NF33 | 可信来电SDK、号码/授权/身份状态（范围扩展） | R11 | [SettingsPage](../../lib/features/settings/presentation/pages/settings_page.dart)、[共享授权owner](../../lib/features/trusted_caller/domain/trusted_caller.dart) | 当前共享入口/反馈/账号号码代际隔离已接线并离线验证；默认SDK未配置不可用，平台SDK/SIM/真实授权仍缺，不复制凭据；见[change](../../openspec/changes/trusted-caller-parity/tasks.md) | W04/W06 |
| NF34 | iOS可信来电Live Activity（平台专属） | R11；`I:Core/Services/AIKXSDKService.m` 解析有效来电 → `I:LiveActivity/AITrustedIdentityLiveActivityManager.swift` startOrUpdate；`I:AppDelegate.m` 观察token/退出清理；`I:LiveActivity/KXActivityAttributes.swift` | [Xcode工程](../../ios/Runner.xcodeproj/project.pbxproj)无对应扩展目标 | 缺失；静态。需扩展target、共享属性、签名和生命周期；Android无ActivityKit，另定义相应来电状态展示 | W06，依赖NF33 |
| NF35 | 后台、锁屏、媒体中断/恢复（跨功能） | R06/R07/R11及原生配置 | [Android生命周期](../../android/app/src/main/kotlin/com/vvtech/phone_agent/MainActivity.kt)、[iOS播放](../../ios/Runner/PcmOutputChannel.swift)、[采集](../../ios/Runner/PcmCaptureChannel.swift) | 部分；静态/H4。已有失焦/中断停止保护，不能承诺后台连续通话；需按语音/翻译/SIP/可信分别设计恢复 | W05/W06 |
| NF36 | 对话任务产物卡片、批量产物、下载（新增缺口） | R13 | [历史事件筛选](../../lib/features/conversation/domain/history/conversation_source_steps.dart)、[消息组件](../../lib/features/conversation/presentation/widgets/conversation_message_tile.dart) | 部分；静态。有artifact事件识别，未找到对应产物卡片/下载完整消费者；补模型、流/历史映射、UI、下载及账号隔离 | W03 |
| NF37 | iOS关于、协议、账号确认界面（新增差异） | R14 | [SettingsPage](../../lib/features/settings/presentation/pages/settings_page.dart)无关于/账号页 | 部分／缺失；静态。Flutter有退出；iOS“注销”实际仅signOut，不能宣称服务器删除。需协议链接、版本来源；删除语义由后端契约单独确认 | W09 |
| NF38 | 首页快捷输入／iOS手动版本检查（候选） | R14/R12 | [HomePage](../../lib/features/home/presentation/pages/home_page.dart)、[设置入口](../../lib/features/settings/presentation/pages/settings_route.dart) | 待核实；静态。未找到当前首页composer创建和设置列表版本卡挂载；不作为已证实缺失功能直接开发 | W08 |

## 4. 六类验收场景

下表全部为**后续验收预期，尚未按新版基线逐项执行**。每行以第3节的实现/历史证据为现状；“恢复”包括页面返回、重启、进程重建或中断后重入，不能默认重新执行副作用。测试数据必须合成；真实认证、短信、外呼另获测试授权。

| NF | 正常 | 失败 | 取消 | 离线 | 恢复 | 跨账号 |
|---|---|---|---|---|---|---|
| NF01 | 验证码登录/有效会话复用 | 码错/过期/服务错可重试 | 返回不遗留提交 | 不伪报成功 | 冷启动校验会话 | 旧回调不得写新账号 |
| NF02 | 身份可跳过→模型→首页 | 保存错保留输入 | 返回保留编辑 | 不误置完成 | 完成标记一致 | 初始化状态按账号 |
| NF03 | 配置入口/摘要正确 | 无效Skill明确不可用 | 退出加载不导航 | 缓存与回退可辨 | 回首页重载不重发任务 | 余额/配置不串号 |
| NF04 | 选模型/音色并被消费 | 失效项/试听错可辨 | 关浮层不误保存 | 不伪报服务可用 | 重新读取有效选择 | 克隆私有资产隔离 |
| NF05 | 文字/候选/补问同会话 | 流错误投影一致 | 普通退出停本地流 | 断流可重试不重执行 | 终态session仍可恢复 | 旧流不能写新会话 |
| NF06 | 按住采集/松开发送/TTS | 拒权/识别错释放租约 | 手势取消不提交 | ASR断开有反馈 | 中断后显式恢复 | 切号停旧音频 |
| NF07 | 请求→系统结果→回传 | DENIED/SETTINGS_REQUIRED可辨 | 取消返回约定结果 | 回传失败可追踪 | 设置返回重新查询 | pending工具按账号 |
| NF08 | 选文件解析并提交上下文 | 格式/大小/上传错误 | 回传取消而非空成功 | 不丢错误原因 | 重入不重复上传/提交 | 文件与任务归属校验 |
| NF09 | 图片OCR/展开/上下文 | 无字/解析失败可重选 | 取消选图不发消息 | 本地/网络依赖可辨 | 历史保留同一结果 | 临时图片按会话清理 |
| NF10 | 姓名/号码/候选正确回传 | 无匹配/拒权 | 取消不选默认联系人 | 设备查询与服务回传分开 | 恢复不重复选择 | 不泄露旧联系人结果 |
| NF11 | 详情备注保存/Skill接续 | 备注API错误保留编辑 | 放弃编辑不写入 | 缓存不得伪称已保存 | 返回列表/详情一致 | 备注/任务按账号隔离 |
| NF12 | 区号/号码/系统交接/记录 | 无拨号器/权限失败 | 系统返回不伪造接通 | 显示平台可用范围 | 设置返回重新检查 | App记录不串号 |
| NF13 | 列表分类/记录/恢复 | 分页或历史错可重试 | 返回不重启任务 | 旧快照标识明确 | 终态恢复不补发首轮 | 列表/快照按账号 |
| NF14 | 监听/音源/显式挂机 | WS/挂断API错误 | 普通返回不挂机 | 监听断开不谎报结束 | 查询服务端通话状态 | 旧监听释放/回执隔离 |
| NF15 | 每项进度/确认/结算 | 部分失败与总失败可辨 | 保持活动批量例外 | 重连不重复外呼 | 同一批次快照/费率 | 批量流代际隔离 |
| NF16 | 播放/保存到正确目的地 | 过期URL/空间不足 | 停止/取消不留假完成 | 缓存可播/无缓存提示 | 文件存在性重检 | 录音按账号/任务授权 |
| NF17 | eligible评分/独立赞踩 | 提交错可重试 | 草稿与放弃规则清楚 | 保留草稿不重复奖励 | 成功只读/草稿恢复 | 草稿不得串任务/账号 |
| NF18 | 位置准入/语种/模型 | 无准入/模型不可用 | 返回不发起通话 | 禁止伪造可信位置 | 设置重入选择一致 | 偏好和探测结果隔离 |
| NF19 | 媒体ready后外呼/字幕DTMF | 建会话/媒体/外呼分段失败 | 建立取消正确释放 | 断网/回退明确 | 中断后查询/归档不重复 | 媒体/结算回调隔离 |
| NF20 | 保存/删除本人身份 | 服务错不假删除 | 放弃编辑不覆盖 | 不谎报认证状态 | 删除后缓存确已清理 | 身份不能复用到他号 |
| NF21 | 核验PASS→候选→保存 | SDK/收费/服务失败可区分 | 关闭SDK释放资源 | 不把离线当核验成功 | 重入从服务端状态恢复 | 模型/录音归属隔离 |
| NF22 | 激活/余额/流水一致 | 激活/分页失败 | 返回不重复激活 | 缓存余额标识明确 | 重启重新对账 | 钱包缓存按账号 |
| NF23 | 原音保存/退出成功 | 保存/清理失败可见 | 取消退出维持会话 | 本地与远端状态可辨 | 偏好重读并被消费 | 退出清理旧代际 |
| NF24 | 打包→上传→清理 | 上传错/仅清理错可区分 | 关闭不误报成功 | 明确失败/保留重试 | 清理重试不重复上传 | 包/请求归属隔离 |
| NF25 | 合法升级包下载并安装 | 签名/校验/安装失败 | 取消保留明确任务态 | 续传策略需定义 | 旧下载/进程死亡核对 | 下载元信息不串用户 |
| NF26 | 暗号/开发者工具实际生效 | 号码/网络/权限错误可辨 | 取消编辑/退出门禁 | 不越过在线准入 | 返回复核系统来源 | 测试配置不泄露账号 |
| NF27 | 同签名升级导入可认归属项 | 损坏旧数据保留原文件 | 中止不破坏旧数据 | 本地迁移无需伪造服务端态 | 幂等迁移/降级按D03 | 无归属异常标记不重放 |
| NF28 | 活动/码真实显示；记录仅数据层 | 活动过期/无资格/API错 | 返回不重复生成邀请 | 不展示假奖励 | 刷新/重启重查 | 邀请码不串号 |
| NF29 | 有效二维码/复制/相册保存 | 权限/渲染/磁盘失败 | 关闭海报不触发保存 | 已有海报与过期链接区分 | 返回相册权限后可重试 | 旧账号海报失效/清理 |
| NF30 | 冷热链接→欢迎→绑定 | 伪造/失效/重复来源可辨 | 关闭/取消登录保留规则 | resolve失败可恢复 | 待处理邀请不重复绑定 | 已登录冲突按契约处理 |
| NF31 | 服务端奖励展示/确认 | 回执错不伪增余额 | 关弹层与已读分开 | 不重复展示已确认奖励 | 去重跨重启 | 他号奖励不弹出 |
| NF32 | 准入/租约/SIP/媒体完整 | 注册/呼叫/媒体分段错误 | 建连取消/挂机释放 | 断网租约/重连策略明确 | 进程/后台恢复防重复拨号 | 旧租约/号码/媒体清理 |
| NF33 | SDK授权/可信身份显示 | SDK失败/无SIM/无权限 | 取消授权不伪报完成 | 证书状态不得伪造在线 | 回前台重新核验 | 号码/身份解绑和隔离 |
| NF34 | 创建/更新/结束活动 | 系统不支持/拒绝有降级 | 结束可信流程关闭活动 | 展示可用的过期状态 | 扩展/主进程状态一致 | 退出及时结束旧活动 |
| NF35 | 支持的后台场景按规格运行 | 焦点/系统中断正确释放 | 用户停通话不自动恢复 | 媒体断网状态明确 | 前后台/锁屏恢复分业务 | 切号终止旧音频任务 |
| NF36 | 流/历史/批量产物卡可下载 | 无权/过期/校验失败 | 取消下载清理临时文件 | 失败与已缓存产物可辨 | 重入核对本地文件/任务 | 产物URL与文件严格隔离 |
| NF37 | 关于/协议/版本；账号语义准确 | 链接失败/接口失败明确 | 关闭确认不退出 | 协议不可达不显示假内容 | 返回位置/确认态正确 | 不把退出当删除账号 |
| NF38 | 先证明真实入口才定义动作 | 不可达记待核实 | 核实时不注入新入口 | 依赖确认后定义 | 查调用/开关/版本演进 | 后续需求仍须账号隔离 |

## 5. 平台工程配置与专属验收

| 配置 | 当前 Flutter 事实／证据 | 原生参考与应完善的事项 |
|---|---|---|
| C01 工具链与包身份 | [pubspec](../../pubspec.yaml)、[Android构建](../../android/app/build.gradle.kts)、[Xcode工程](../../ios/Runner.xcodeproj/project.pbxproj)：固定Flutter3.32/Dart3.8；Android min26、生产com.vvtech.aiassistant，Debug/Profile .dev；iOS15.5、Debug/Profile测试ID、Release生产ID且已有Team | 保持工具链；JVM源码target11不等于构建JDK11。后续发布核对版本递增、环境/后端和插件兼容；Team存在不证明证书/描述文件/分发可用 |
| C02 签名与发布 | Android release签名为空且有任务保护；iOS本轮仅读取配置 | Android同身份同签名、旧状态/OTA/降级D03是发布门禁；iOS单独验证分发签名与权限，不能因开发签名可用而称已发布 |
| C03 邀请链接 | [Android Manifest](../../android/app/src/main/AndroidManifest.xml)、[Info.plist](../../ios/Runner/Info.plist)及新增薄端口已装配邀请链接；系统投递仍待验 | Android参照仓库路径 `android/app/src/main/AndroidManifest.xml` 的 App Links/Intent；iOS参照 `I:PhoneAgent.entitlements` 与 SceneDelegate 的 Universal Links/URL；需域名关联文件、应用标识、冷/热/已登录/未登录四象限，外部服务器配置不能只改App文件完成 |
| C04 权限及设备端口 | [MainActivity](../../android/app/src/main/kotlin/com/vvtech/phone_agent/MainActivity.kt)、[AppDelegate](../../ios/Runner/AppDelegate.swift)已有通讯录、拨号、PCM、定位、录音等薄适配；iOS已有麦克风/相机/定位/相册/通讯录说明 | 海报已用Android29+ MediaStore、26–28系统创建文件与iOS PhotoKit追加权限；可信SDK/SIP仍需增量列最小权限与用途；逐项验拒绝/永久拒绝/设置返回。iOS系统CallLog不复制Android；仅App记录 |
| C05 后台与中断 | Android onPause标记PCM非前台；iOS播放后台停止、采集中断停止；Info.plist未声明原生参考的UIBackgroundModes | 原生 `I:Info.plist` 声明audio/processing/remote-notification不等于这些链路都有效。按NF35设计音频会话/前台服务或后台能力、锁屏/蓝牙/系统电话/杀进程矩阵；不盲拷全部声明 |
| C06 可信来电和扩展 | Flutter无可信SDK入口及Live Activity扩展target | 原生扩展仓库路径 `iOS/PhoneAgent/KXLiveActivityExtension/KXTrustedIdentityLiveActivity.swift`；需SDK版本/许可配置、扩展最低系统与降级、entitlements/签名匹配、活动结束清理。推送/通信授权按实际消费者判断是否需要，不凭参考声明全部启用 |
| C07 文件与数据 | [录音保存](../../lib/features/translation_history/data/device_recording_exporter.dart)、[旧数据清单](LEGACY_STATE_INVENTORY.md) | 产物/海报增加各平台保存目标、权限与空间失败；升级测试保留用户数据，不卸载回退；凭据、真实用户文件、签名材料不得进仓库 |
| C08 UI与可访问性 | [共享页面索引](PAGE_FLOW_COVERAGE.md)；竖屏配置存在，已有键盘及窄屏历史证据 | 邀请/产物/关于等补加载、空错、长文与取消态；双端系统返回、安全区、键盘、动态字体/读屏、暗色和锁屏需按真实设计验收，不把Web或静态图当双端视觉验收 |

## 6. 后续工作包、依赖与验收出口

P0=先定契约/阻塞架构或发布的决策；P1=主要功能补齐与验收；P2=有证据后再排。下表保留最初工作包划分及完成出口；当前进度以各active change/tasks和本文最新日期增量为准，不能把早期“建议新change”或依赖措辞解释为尚未实施。邀请、国内SIP、可信来电及平台接线已有实现和定向证据，真实能力与发布验收仍未关闭。每包先读并更新相应OpenSpec，手写微批不超过3文件。

| 工作包 | 优先级／NF | change归属与依赖 | 完成出口 |
|---|---|---|---|
| W01 既有共享功能增量核对 | P1；01–05、07、13、15、23 | 复用 `auth-api-session`、`login-presentation`、`home-model-shell`、`conversation-history-core`、`conversation-error-status-sync`、`settings-interactions`；以本台账固定版本为输入 | 新版真实响应脱敏样本/契约与共享实现逐项比对；只对实际差异写代码；受影响定向测试/关键连续链路通过 |
| W02 新版邀请闭环 | P1；01、22、28–31 | 建议新change `native-invite-parity`；先定 resolve/activity/code/records/events、REFERRAL/requestId、活动/奖励幂等及跨账号语义；依赖W06链接装配 | 钱包→邀请→海报→冷/热唤起→欢迎/登录→绑定→奖励闭环；六状态及真实后端对账；不以手填邀请码替代 |
| W03 任务产物 | P1；15、36 | 建议新change `task-artifact-parity`；依赖对话流/历史/批量结果契约和文件保存端口 | 单产物/批量/恢复一致，鉴权下载/取消/重试/过期/跨账号验证；不把OCR输入附件当输出产物 |
| W04 SIP与可信来电 | P0先契约、P1实现；18、26、32、33 | 建议分开 `domestic-sip-parity`、`trusted-caller-parity`；先定区域准入、SDK/服务端接口、号码、租约及资源所有权；依赖W06/W05 | 正式入口→平台适配→真实媒体/授权→停止清理；两能力独立验收。旧排除已进入新目标，未批准凭空复制实现细节 |
| W05 既有平台能力真实验收 | P1；04、06–22、24、26、35 | 复用 `voice-protocol-foundation`、`single-call-session`、`overseas-translation-ui`、`contacts-migration`、`identity-profile-core`、`task-result-details`、`wallet-feedback-core`；先核历史H3避免重写 | 按H4与六状态执行双端真实SDK/权限/媒体/文件/收件，缺陷才触发代码修改；真实短信/认证/外呼测试另需授权 |
| W06 平台新增能力 | P0配置设计、P1实现；30、33–35 | 建议 `native-platform-capability-parity`；链接可先做，Live Activity依赖NF33，后台依赖各媒体生命周期 | C03–C06配置及域名/签名/系统版本匹配，锁屏/中断/冷启/切号有设备证据；不能只有plist/manifest变更 |
| W07 生产升级与旧数据 | P0发布前；16、17、25、27 | 复用 `bootstrap-flutter-foundation`、`android-legacy-preferences`、`android-legacy-call-records`、`android-legacy-recording`、`android-legacy-rating-drafts`；依赖[剩余决策D03](MIGRATION_OPEN_DECISIONS.md)和生产签名 | 同签名保留数据升级、旧下载处置/降级、各数据归属与幂等；未通过继续保留Release保护，不交付Dev作升级包 |
| W08 入口不确定项 | P2；38 | 本change台账继续追踪，不先建空业务change；需当前导航/开关/运行版本进一步证据 | 证明可达后补差距与验收；证明废弃则记录排除理由。iOS版本检查若以后确认有效，单独设计外部更新，不做APK OTA |
| W09 关于/账号语义与展示 | P1；03、23、37 | 建议 `settings-account-information-parity`；依赖产品协议来源和服务端删除契约 | 版本来自包信息，协议可达；账号动作名称与实际效果一致。是否新增真正删除账号独立决策，不照抄“注销”文案+signOut |

建议顺序：W01契约差异核对与W02/W03规格准备 → 邀请/产物共享实现 → W04/W06平台补齐 → W05集中真实验收 → W07发布门禁。W07签名/D03以及W09账号语义应提前确认，不能等全部UI完成才发现阻塞。静态核查不足以给出可信工期，按每个change的契约、SDK和测试资源进一步估算。

## 7. 范围冲突与交付边界

- [原批准基线](../requirements/MIGRATION_BASELINE.md)保留既有行为：两步初始化、统一对话、普通退出不挂机、终态恢复、无匿名导出、无未归属异常重放。新原生文件不能反向覆盖这些用户决定。
- SIP/可信来电由原先排除变为新版目标的待实施能力；邀请/产物有有效入口证据。支付/记忆/废弃独立对话仍无本轮有效证据，不自动进入开发清单。
- iOS关于与账号页确实可达，但“注销账号”处理仅signOut，没有本轮证据证明服务器删除。iOS首页composer和手动版本检查仅有定义/残余引用，维持待核实。
- 本轮源码检查没有证明三端完全等价；未调用真实接口、安装设备、拨号、认证或迁移用户数据。六状态是验收计划；邀请新增自动化结果按邀请验证报告引用，其余历史结果仅按H编号引用。
- 本次[OpenSpec change](../../openspec/changes/native-feature-parity-audit/proposal.md)保持active。验收后才合并正式spec并归档，业务工作包各自推进，不把台账完成当业务完成。

可信来电当前平台契约和仍需完善项见[20261008 SDK核对](TRUSTED_CALLER_SDK_CONTRACT_20261008.md)；共享反馈页不等同原生SDK引导/证书/来电或Live Activity完成。


## 2026-10-09 外呼原生参考与iOS翻译实际增量

- NF26：`ff447d0`为独立iOS固定原生外呼四态参考，29源/头哈希不变、8独立运行状态与具名返回；`459ec39`修复聚焦/禁用边框及读取灰/失败红状态，共25项定向通过。四态UI采用最小合成DTO/service，没有真实配置读写或SDK；公共56点标题/48点返回与固定UIKit46点头的可访问差异保留，键盘待验。
- NF18/NF19：`97cd856`记录完整iOS合成Shell从首页→拨号提示→媒体预检→振铃→接通→双语字幕→静音/扬声器→按键失败→挂断→拨号页→首页实际流程。假media不支持DTMF，实际提示失败，不能记录为按键成功；无环境事实仍灰色检测中。
- NF18：`e4b6091`补语种32×32勾选占位，普通至少64点/大字自然增高，与固定Android/iOS共同规则相符；8项定向/analyze通过。iOS实际选择日语→重入选中→取消保留；模型弹层Gemini→GPT Live Translate→重入selected→关闭保留实际验证，刷新仍相同内存样本，无实际节点检测。
- 可信说明：iOS两倍字体实际返回通过；CUA竖向拖动/坐标滚动无确认位移，滚动可达保持待验，不点击离屏开始替代。

原始运行图位于忽略目录`.local/ui-reference/ios-outbound`及`ios-shell-translation`。全量3598通过/1跳过仍只对应冻结5ad5552，后续为各自定向范围，不改写为新全量通过；整个UI、国内安全模型配置及真实通话/SDK/后台/发布仍待验。


## 2026-10-09 联系人与翻译历史最新实施证据

| 业务 | 当前实现及实际范围 | 仍需完善／验收 |
|---|---|---|
| NF11 联系人备注/Skill | fd708c4输入独立名称，双主题语义编辑/忙态27定向；8c735e7五个完整具名动作及19定向；9df9db0防重复关闭与选择、来源route及账号epoch两await保护，26定向。iOS隔离Shell实际编辑取消、Skill带联系人开场、关闭回详情 | 平台真实键盘备注保存、OS通讯录/后端、原生完整页配对仍待；8专项竞态证明不等于设备双击已验 |
| NF18 翻译语种 | c154499固定bb9ff349 UIKit真实语种页/纯策略/Masonry29源与生产Flutter页，同模拟器正常字体中文→日语→返回→重入→取消保留；7定向，实际两侧配对 | 48与42返回热区形成6点正文差异明确保留；平台大字/系统字形及全部翻译页面仍待 |
| NF13/NF16 翻译历史/录音 | e8f15f8修第二条合成列表/详情10:30一致，7定向；d32501a添加仅tool编译期录音场景白名单及独立包，20定向。iOS完整正式历史入口实际加载/播放/保存失败→重读、取消/确认、关闭重入清旧成功；字幕保持 | 全部音频/保存端口为合成，无真实声音/磁盘/网络；合成processing已见加载中且保存/播放禁用→ready，但短暂过程未留PNG；Android同流程、后台与真实录音导出仍待 |
| NF33 可信来电 | 5046348完整iOS Shell未配置重读及返回，中性不可用/设置禁用，不误报授权；工程SDK副本及从参照项目读取安全配置已接线 | Shell明确Unconfigured端口，不能视为正式SDK初始化/授权/API/APNS/SIM/来电/Live Activity验收 |

实际原图分别在ignored `.local/ui-reference/ios-shell-contacts`、`ios-language`、`ios-shell-history`及`ios-shell-trusted`；各提交和测试文件为可追溯实现证据，未公开真实用户数据。SDK配置来源已解决；国内模型短期配置契约、真实测试条件及生产签名/升级资源仍独立待验。全量3598/1冻结5ad5552，未声称覆盖本表后续提交。


## 2026-10-09 翻译历史展示与状态最新证据

以下补充 NF13/NF16、P16/P17，只有标明的正常部件/状态范围完成实际对照，不将纯宿主替代原控制器、账户或音频。

| 范围 | 已实现及验证 | 仍需完善／验收 |
|---|---|---|
| 任务与历史记录时间 | 22b7b2e共用今天/昨天、七日内星期、同年月日/跨年年月日，本地日历比较避开DST；32定向及New York 23小时边界12专项。851157c两个正式页实际星期/跨年进入与返回 | 真实服务数据、两端原生完整页与时区设备设置场景仍待；没有修改设备时区 |
| 标题/电话/字幕位置 | af12cc6标题与号码同列；1a2f1fe明确phone18/time17及零字距。3f7352e固定UIKit展示字节及纯模型对照，第一蓝字幕原生与修后Flutter同561–794物理行 | 149f9ac已量化UIKit UI Display/Text回退与Flutter别名字宽差异，换Display不能同时解决中文/英文；不改全局字体或不可选择图片凑字形 |
| 气泡统一外观 | 88cd44d采用UIKit实际平面气泡，两平台共用；26定向8秒、实际外部背景采样相同，颜色/圆角/82%宽/选择保留 | Android原Surface2dp是明确不同参照，不宣称Android原生像素一致；整页字形仍有差异 |
| 两倍字和字幕空态 | 2f17988独立Flutter两倍字实际完整号码/双语自然多行、关闭；f24be67固定空态字节与两侧实际关闭；b906d2f空14/17行高，29定向8秒及实际复核 | 原生正常空字框651–688，Flutter653–690仍2物理像素系统基线差；工具TextScaler不是系统动态字体、原生大字未伪造 |
| 首次加载/失败/重试 | 8e6a0b0无内容只关闭及顶部加载/居中错误+独立重试，有内容刷新保留字幕录音；33邻接、关闭隔离后10直接调用方。2b0c43f固定原生3展示方法/8范围哈希、14参考定向，实际两侧失败→加载→内容/加载关闭、重试等待关闭后不复活，Flutter两倍字亦核验 | 宿主恢复为本地合成2秒，非原服务；UIKit全屏center/36按钮与Flutter可用安全区/48热区差异明确，不当真实网络重试/完整controller V |

原始证据在ignored `.local/ui-reference/ios-history-content`、`ios-record-time`及`ios-shell-history`；来源/动作/测试与恢复记录在[执行任务](../../openspec/changes/native-ui-interaction-parity/tasks.md)。SDK来源及工程副本已完成；模型短期配置、真实电话/录音/SDK/后台、Android OTA数据/签名和iOS发布仍独立待验。联系人/日期/历史跨模块全量冻结2b0c43f已完成3658通过/1跳过/0失败，7分10秒；唯一测试skip为UI_AGENT_DOCUMENT开关场景，另以文档开关+10000ms合成解析延时专项2通过（3秒）。范围分别记录，不把两项重复测试累加为默认全量数。旧5ad5552结果保留历史含义，后续P20修改需自身定向验证。

2026-10-09 初始化与联系人跨模块里程碑完成：冻结源码 `2eb2fcf896e07f9804fbdae8e7912bfe89256285`，全量 `flutter test --no-pub --reporter expanded` 退出0，3706项通过、1项按UI_AGENT_DOCUMENT开关跳过，耗时7分10秒；日志 `/tmp/phoneagent-onboarding-contact-milestone-tests.log`。跳过项先前已以UI_AGENT_DOCUMENT=true及UI_DOCUMENT_PARSE_DELAY_MS=10000单独验证2项通过，本轮未重复，不并入3706计数。此前同源码analyze无问题；全量期间仅文档及纯隔离UI记录，无lib/test/tool/ios/android差异。真实SDK、后台模型配置、外呼收费、正式签名/Android OTA与完整原生像素验收仍待验。用户指定SDK配置从参照项目读取已落实为工程内SDK副本及忽略的安全配置，不在日志或Git输出凭证。下一子任务继续拨号路由旧回调保护，不归档。

2026-10-09 拨号及预设增量：4c6c9a2普通拨号当前route/controller归属（23项8秒），4a75728翻译拨号异步迟到释放（43项9秒与追加10项6秒竞态），272e17e预设旧开关/语言/系统返回（32项10秒），计数存在重叠分别报告。最新analyze7.6秒无问题。纯隔离iOS实际国家返回123/+65、翻译关闭回普通123/+86及首页；预设日语返回、翻译关闭语言禁用、重入关闭和日语保留、再开启恢复可用，无呼叫。原始guarded-translation-country/guarded-presets-reentered-off已查看；SDK配置从参照工程读取及副本接线已完成，不再请求来源。3706/1全量仅覆盖2eb2fcf，真实SDK/模型服务/外呼/OTA/整页原生视觉仍待验。

2026-10-09 共同设置选择具名语义：core163/专项82两个源码微批，外层唯一container/button/label/enabled/selected/onTap及exclude内部OutlinedButton语义，视觉/48热区/大字保持。双平台1/2倍四有效RED具名节点hasSelectedState=false；修后语义/视觉各一次、disabled保留当前selected但无tap，翻译及全部五直接开发者调用方/正式Shell共39项14秒通过，analyze7.4秒无问题；影响已界定，不重复全量。另独立tool420单文件微批增加10个拨号/翻译/新helper/共同选择源码SHA，Shell login参数1项含3非法组合0.001秒通过，不称全部编译清单。纯.shell重建45333实际同传→预设→海外设置初Gemini具名button selected→选GPT仅GPT selected；原始setting-choice-selected实际查看，10SHA逐项对实际源匹配。无普通包/SDK/网络/电话/真实偏好，SDK条件及全像素仍待验。OpenSpec39/diff，pubspec.lock保持，中文提交推送后继续任务长列表已规划验证。

2026-10-09 H47L键盘分页实际补验：独立.tasksscroll构建安装启动48971，直接生产TasksPage/30条synthetic，无onOpen业务行为或网络。CUA点击首行后Next真实偏移0→536→1072→1608→1972且任务30可见；三次连续快速Next仅推进一页，逐次fresh AX后核验，不按按键次数臆测结果。Home无效一次，改Prior逐页返回1436→900→364→0。点击fixture两倍字范围3174，Next每页510.4，逐页到3174/任务30；Prior逐页回0，再恢复普通字号0/1972。四原始normal-bottom/large-bottom/large-top/normal-top在.local/ui-reference/ios-tasks-keyboard，均实际查看，顶部首卡阴影可见。未新增生产或tool源，工具TextScaler不是系统动态字号。此为真实外接键盘分页/回顶与布局证据，未称触摸拖动/滚轮已恢复，H47L触摸手势部分仍待验且不勾整体完成；此前两次失败未重放。无普通App/SDK/位置/电话/数据清理，不重复analyze/全量/普通双端构建，纯文档OpenSpec/diff。

2026-10-09 路由生命周期里程碑：生产源码冻结c14f983f8bf54fbee18788f0ba9584d0e898ea46，累计普通/翻译拨号、预设/语言/模型/海外设置/目录、共同选择语义及外呼/关于/开发者重置/原音触发一次全量回归；当前执行中未写通过计数。源码与工具/平台不再改动，只补纯隔离运行证据和文档，外部pubspec.lock保持。原音19项2秒/analyze2.5秒、外呼35项10秒及追加竞态4项、关于8项4秒、开发者重置9项5秒为各自定向范围，重叠不合计，不把此前2eb2fcf全量当覆盖本轮修改。

可信说明页独立两倍字补验：pure.trustedintro.large启动51237，键盘Next实际视口移至底部“开始”（AX文字未变，截图实证）；开始仅fixture结果“未调用可信SDK”→重新查看→直接AX返回element点击无效一次→刷新实际节点的公开Cancel动作返回“独立说明页已关闭”。large-bottom/large-return原始PNG在ios-trusted-intro-keyboard且实际查看。当前只有展示、键盘分页与公开取消动作运行证据；未声明触摸/边缘手势、真实SDK或完整原生V通过，工具TextScaler不同于系统动态字体。无普通App/真实授权/电话/网络。

2026-10-09 可信凭据独立两倍字补验：pure.trustedcredentials.large启动51714，synthetic长姓名/企业/编号与日期，无账户/SDK/通知端口；Next视口真实分页（AX整树文字不变，截图显示证书尾编号/颁发机构/说明及返回首页），点击可见返回回四状态菜单。再进入pending显示正在验证→返回、failed显示验签失败→返回、uncertified显示谨慎采信且无可信凭证→返回；每次实际AX核验，pending/failed未留PNG不称有截图。large-top/large-bottom/large-uncertified三原始PNG在ios-trusted-credentials-keyboard且均实际查看；首屏及长证书自然换行，未声称同原生整页像素V/触摸手势通过。公开verified只是合成输入，不当真实验签成功。全量仍执行中、c14f983生产/平台/工具无diff，只有文档；不新增SDK初始化或真实SIM/APNS/电话。

2026-10-09 路由生命周期跨模块里程碑完成：源码冻结c14f983f8bf54fbee18788f0ba9584d0e898ea46，全量flutter test --no-pub --reporter expanded退出0，3777通过/1跳过/0失败，7分38秒；日志/tmp/phoneagent-route-lifecycle-milestone-tests.log。唯一默认opt-in文档UI开关跳过保留（既有显式开关专项2通过不是本轮新执行，不并入3777）。期间lib/test/tool/ios/android无diff，仅文档与独立pure UI运行；source HEAD仍c14f983，analyze此前2.5秒无问题，外部pubspec.lock28条host-only差异不提交。新全量取代2eb2fcf的3706/1作为此冻结源码最新回归，不覆盖未来修改；OpenSpec39、四报告182相对文件目标存在及diff校验通过，本次未查锚点。SDK工程副本/安全配置来源已落实，真实SDK初始化/SIM/APNS/后台、模型短期配置、真实媒体/电话/结算/录音上传、Android同签名OTA/旧数据和iOS发布、三端全部状态像素与触摸手势仍待验，不归档。
