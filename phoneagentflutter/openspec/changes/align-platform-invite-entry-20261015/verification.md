# 分平台邀请入口验证（2026-10-15）

## 实现范围
当前codex/dev_zys，保留主线程3份原未提交文档；不切分支/提交/推送，不改参考项目或后端。分批：①纯Dart平台策略/provider/SDK resolve；②Pending入口序号/欢迎provider/路由；③Android独立路由/策略/receipt；④Manifest/Gradle/MainActivity；⑤channel/entry去重装配；⑥Android激活页优先与回归。每业务微批≤3文件，文档与格式化单独批次。手写新增文件均小于500行，无新例外。

- Android dev/test/prod入口与当前原生默认配置一致；独立无UI Activity使用NEW_TASK/CLEAR_TOP/SINGLE_TOP，将邀请转入App任务。MainActivity记录新Intent，接收层消费后清理，历史标志和持久UUID拒绝重放。只保存UUID，无URL/邀请码或账号凭据。
- iOS既有Universal Links、entitlements、Info.plist、Xcode配置与InviteChannel.swift和HEAD逐字节一致；仅共用Dart策略允许对应可信cloud-dev/test API下的既有iOS入口。
- resolve优先SDK且不带Bearer；旧未配置SDK配置仍兼容同源，不将分享地址迁移到SDK前缀。
- 新入口按(code, entryId)隔离欢迎响应；内存入口ID不写入存储，不因历史邀请码自动进入欢迎。提交保护、请求ID重试、来源归因、奖励去重与账号恢复沿用既有流程。
- Android保留激活页优先、错误继续需重试；iOS保持业务错误白名单。所有展示widgets未改，示意图不落地改版。

## 自动验证
- 首批环境/公开解析14项通过。
- 中途邀请/auth定向190项通过；补充入口/路由/架构8项通过（与前者重叠，不累计）。
- 最终邀请全模块 + auth_controller/auth_invite_draft_persistence/auth_session_widget + architecture：197项通过（11秒），含完整冷启动欢迎→登录challenge→激活页热邀请替换→REFERRAL提交→奖励→会话恢复；非全仓回归。
- flutter analyze最终无问题（9.1秒）。
- Gradle :app:testDebugUnitTest --tests com.vvtech.phone_agent.InviteAppLinkPolicyTest：2项通过，无失败（10秒）；该测试仅证明链接策略，不等于Activity/系统投递验收。
- Android debug构建在配置修正后通过（21.3秒）；对最终Dart路由补充后的增量构建与最终OpenSpec/diff结果见下方追加。
- APK manifest解包确认dev host=chakenai-dev.vvtech.tech、scheme=phoneagent-dev、独立InviteLinkActivity/noHistory、MainActivity无空taskAffinity。未安装设备。

## 工具恢复
- 开始时flutter/dart/openspec不在PATH；使用既有固定3.32 SDK和缓存OpenSpec CLI，未安装/升级工具链。
- 10:41附近首次Android构建失败：audioplayers_android profile复制自定义BuildConfig字段而未启用功能。已核对日志和当前源码，改为应用Manifest元数据读取，不改插件；有限重试构建通过。
- APK分析器有integer expression expected启动脚本警告，仍完整返回manifest及退出0，实际解析结果已读取；不以该警告替代验证。

## 待验边界
双端真实浏览器/系统冷热唤起、最近任务/历史恢复、服务器AASA/assetlinks部署与签名关联、真实短信注册和奖励到账尚未验证。iOS未改原生，未重新构建/安装；iOS规则已通过合成测试但不等于设备验收。本次Android为编译验证包，无真实环境凭据，不作登录/生产交付包；未构建登记test签名包。不卸载/清数据，不发短信/外呼/收费，未归档。

## 最终回执
最终Android Debug增量构建8.1秒通过，包含激活页优先和全部最终Dart改动；OpenSpec148通过0失败，git diff --check通过。保持当前codex/dev_zys及其他工作区内容；未提交推送，未安装设备，待验事项仍开放。

## 2026-10-15 iOS打开无提示修复
- 用户给定诊断1860条截至UTC03:13:57，仅有accountRequest/commerce/trustedCaller/translation/audio等，没有邀请入口或Flutter异常事件。因此不能从此日志证明Universal Links未投递或服务解析失败；不输出/保存原日志和真实邀请码fixtures。
- 当前1503打包记录确认已包含上一轮邀请修改，不能再按旧包未含修复解释。本批不修改服务器链接、iOS配置、登录数据或待注册归因。
- RED：新增真实MaterialApp.builder外层InviteEntryHost回归，iOS/Android各冷队列和热入口4项全部复现No Overlay widget found；失败后旧通知dismiss还会因未插入Overlay再次异常。
- 修复：showNativeNotice支持可选显式OverlayState并在创建通知前解析hostOverlay；InviteEntryHost通过生产router navigatorKey取得根Overlay，不再从自身祖先查找。保留原共用提示UI和所有原调用方默认行为。三份生产文件为单微批。
- GREEN：4项根宿主回归通过，提示可见、无邀请绑定且页面能继续导航。真实PhoneAgentApp连续登录/奖励/恢复后追加热入口提示断言通过。
- 组合首轮214通过1失败，失败为完整应用树异步事件+postframe+Overlay渲染前就断言；读取失败日志后改用项目既有有限UI settle辅助，单项恢复通过。首轮analyze提示新增测试if缺花括号，已修正。最终组合215项通过（13秒，含邀请全模块、native_notice/keyboard、登录协议/会话、联系人提示、评价成功、shell/workbench调用方和架构），非全仓；最终analyze无问题（4.8秒）。
- 本批纯Dart接线与测试，不改平台/依赖/构建链，不重复双端构建或安装。215项证明客户端合成场景，不证明用户真实链接已在手机上验证成功；修复后设备包尚未生成安装。真实系统投递/登录状态/同码再入仍待设备复验，4.3不勾选。

## 2026-10-15 iOS 1504原生回调修复
用户明确diagnostics.jsonl 22是iOS日志；435条截至UTC04:11:53，无invite入口operation。1504回执确认Overlay修复已构建安装，因此旧包假设不成立。本次未输出/保存真实日志、邀请码和凭据fixtures。

### 实际原生根因与RED/GREEN
固定Flutter3.32缓存FlutterPlugin.h的可选生命周期协议导入为launchOptions:[AnyHashable: Any]及restorationHandler:([Any])->Void。InviteChannel错误使用UIKit UIApplicationDelegate签名（可选typed launchOptions、可选UIUserActivityRestoring数组），Swift只报nearly matches optional requirement，构建仍成功，但没有将两个Swift方法导出为ObjC实现。
- tool/verify_ios_invite_callbacks.py实际编译InviteChannel到LLVM IR，检查类实例方法表（不能只全文搜索，因为协议元数据也含selector）。修复前cold=false、scheme=true、universal=false、nearMatchWarning=true，脚本失败，证据/tmp/invite-native-red.log。
- 修正两处签名及启动URL索引类型后cold/scheme/universal全部true，nearMatchWarning=false，脚本成功，证据/tmp/invite-native-green.log。
- 1504没有本次原生修复。先前Dart模拟只覆盖入口之后的流程，无法代替selector注册；上一轮验证有遗漏，本回归专门覆盖该缺口。

### 脱敏诊断
共用入口增加固定枚举阶段inviteReceived/inviteRejected/inviteQueued/inviteExistingAccount/inviteRegistrationDispatched/inviteSaveFailed/inviteStreamFailed，经现有journal账号/环境隔离落盘。仅operation/result/time/statusCode/elapsedMs，不带任意文本、码、URL/query、手机号、token或账号。ref.read在事件时选择journal，切号不重建入口。诊断observer异常不得阻断邀请。
新增两项测试验证真实provider阶段、账号隔离、JSON往返与字段白名单、等待会话/拒绝/流错误/诊断异常隔离。首轮测试缺少AuthGateway的LoginOutcome import导致编译失败，读取状态后补import一次重试通过，无产品逻辑绕过。

### 最终验证与边界
- flutter analyze：无问题（16.1秒）。
- 定向邀请全模块、app_logs导出/归档/脱敏、auth_diagnostics/auth_session、共用native_notice/keyboard及架构：289项通过（19秒，非全仓）。
- 原生callback编译检查再次通过，三个selector都存在。
- xcodebuild Runner/Profile/iphoneos、独立.local/invite-native-build派生目录、CODE_SIGNING_ALLOWED=NO：BUILD SUCCEEDED；仅编译不签名安装。日志有Profile本地网络说明键读取提示，但总构建成功，不作为运行验收。完整日志不输出，以免构建环境字段泄漏。
- Info.plist、entitlements、Xcode工程文件与HEAD完全一致；现有Universal Links和UI不变，Android原生不改。主线程已有修改及当前codex/dev_zys保留。
- 未提交推送、未安装/卸载/清数据、未真实短信注册/外呼/收费。实际手机仍需新包及同一链接冷/热验收，5.4保留待办；不能将构建/IR等同设备通过。

## 2026-10-15 未登录欢迎页不可用：公开成功码兼容
- 用户diagnostics23共240条，有已登录inviteReceived/inviteExistingAccount；PublicInviteResolver独立匿名Dio不走accountRequest，不能将日志里的通用HTTP500认定为该公开接口失败。
- 当前只读匿名GET验证dev SDK与Agent公开resolve均HTTP200、业务code为字符串000000，返回ACTIVITY_RETIRED且无activity。仅读取状态摘要，不复制响应、真实码或下载上下文，不注册/领取/记录visit事件。
- 本地InviteCodeService表明ACTIVITY_RETIRED涵盖码所属期与当前不匹配、当前无published或活动已不live；单凭公共响应不能进一步确认哪个分支。后台只读，不修改活动/真实码/数据库。
- Flutter PublicInviteResolver仅接受数字0，导致提前UNAVAILABLE，掩盖既有INVITE_ACTIVITY_RETIRED文案。本轮采用与已有AccountApi/AuthGateway相同的0或000000成功契约，非成功码不宽泛转换；成功后仍核对邀请码和业务状态。
- 合成RED：新增双成功码/生命周期及非成功码共14项（原3+新增11），其中字符串000000的ACTIVE/ACTIVITY_RETIRED/EXPIRED/EXHAUSTED四项失败，其余通过。
- GREEN：增加实际resolver→iOS welcome controller断言，活动退休显示“本期邀请活动已结束”、积分未知、不虚构奖励且维持iOS原继续规则；公开resolver/欢迎规则/生命周期/连续注册流程/邀请API合计40项通过（4秒，非全仓）。
- 仅改PublicInviteResolver业务成功判断及合成测试；UI、链接和平台原生未改，不重复双端构建/安装，不提交推送。未让真实已退休的邀请码恢复有效，客户端错误分类修正和后台活动可用性是两件事。设备新包6.3待验。

## 2026-10-15 codex/dev_zys双原生欢迎错误对齐
用户批准后明确在codex/dev_zys修改。开始工作区codex/dev，两个本地分支同a9312dfb；安全switch并核对原4份未提交文档SHA256一致。两份其他change/tasks保留未触碰，根tasks/issue仅追加本轮。无commit/push。

### 实现与小批
1. 纯Dart欢迎失败策略+controller+原断言：业务原因使用已核对双原生完整文案，返回/继续白名单从controller移至纯策略。只改变欢迎页文案，不改全局InviteFailure.message、页面布局、共用按钮/Toast、平台入口。
2. 固定resolve诊断类型+DiagnosticEvent序列化+data诊断适配：started/active及退休/过期/耗尽/配置/网络/未知响应等枚举，成功码只保留类别；HTTP与耗时沿用event字段。无邀请码/URL/query/原文/手机号/token。诊断lookup/sink失败均隔离。
3. PublicInviteResolver+provider：保留SDK优先、0/000000、匿名不带Bearer和不跟重定向；HTTP错误仅暴露白名单业务码，ACTIVE缺activity按CONFIG_NOT_PUBLISHED，坏积分/结构/未知状态按INVALID_RESPONSE，Dio网络按NETWORK。请求开始捕获journal，不watch移动账号诊断，不因切号重建resolver。没有后台写操作。
4. 新增18项公开分类/诊断/隔离回归和双平台18个小屏2倍字错误页面+2个网络恢复用例；扩展现有provider测试确认账号切换resolver身份不变。所有修改文件<500行，无新例外。

### 验证
- 第一批既有公开解析/欢迎/生命周期29项通过。
- 新增分类/诊断/双平台策略38项通过；含详细活动结束文案、配置未发布、网络、未知响应、错误时不显示奖励、继续/重试/返回及错误恢复。
- 组合邀请全模块、app_logs导出/归档/脱敏、auth_controller/auth_invite_draft_persistence/auth_diagnostics/auth_session、native_notice/keyboard与架构：354项通过（20秒，非全仓）。
- 最后provider身份断言与诊断定向20项通过，与354重叠不累计。
- 首轮analyze四项info（if花括号和测试私有类型API）已修正；最终flutter analyze无问题（4.9秒）。无运行失败重试或产品行为绕过。
- 纯Dart业务/测试/规格修改，Android/iOS平台、插件、依赖及构建链无改动，不重复双端包或设备安装。
- OpenSpec/diff最终结果追加于本节末；未验收不归档。

### 后台与设备边界
已核对后台InviteCodeService只读代码：ACTIVITY_RETIRED可由当前无发布活动、所属期不匹配或活动不live产生。此前dev/test公开GET均返回此状态，但不包含期次详情；本轮没有管理端只读授权数据，具体哪项仍待后台核对，不把自然到期当确定结论。没有调整活动/邀请码/数据库、真实注册/奖励/外呼/收费。此次本地分类修复不会恢复失效活动，真实状态需新包与后台活动数据独立验收，7.5保持待办。

本节最终回执：OpenSpec151通过0失败，git diff --check通过，当前分支codex/dev_zys。平台目录无新增diff，源码与既有文档保持本地未提交。
