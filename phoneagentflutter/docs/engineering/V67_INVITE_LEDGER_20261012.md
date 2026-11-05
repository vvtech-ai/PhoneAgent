# v67邀请与积分记录迁移（2026-10-12）

用户追加授权全部邀请变更与积分记录UI迁移，覆盖此前只保留钱包邀请卡/无记录的历史约定。新change `migrate-v67-invite-records-ledger` 保持active；不提交或推送。固定来源旧项目 `origin/test/v67.0.0 5c0d737dc0a4c809cabafce2dfe9c8c0be4ba3a3`，只读git show；未改、checkout或build旧目录。v67树有Android源码，未发现iOS目录，不造双端原生同版本证据。

## 源码与实现对照

| v67实际源码（android/app/src/main/java/com/vvtech/aiassistant/features） | Flutter实现/保留 |
| --- | --- |
| assistant/FinalHomeCallModelActions.kt | HomeHero模型按钮旁36×36礼物，6间距、10圆角、F4F5F7底、FF4D5A图标，进入福利 |
| assistant/FinalSettingsHomePage.kt、invite/InviteEntryCoordinator.kt | 设置邀请好友；本人activity有效才显示，两入口共用资格文案；本人可赠且双方金额相等才双方各得。刷新/切号待查隐藏前数据，错误/无活动隐藏，不发码探测入口 |
| invite/InviteScreen.kt、InviteHomeScreen.kt、InviteQuotaProgress.kt | 独立福利/邀请好友来源页，规则Sheet、名额、实际资格/进度、邀请海报和记录；返回来源。旧钱包邀请混合内容移除 |
| invite/InviteRecordsScreen.kt、InviteRecordPresentation.kt、InviteRecordPagePolicy.kt | 22圆角白卡、19标题/12说明、总数/名额计数，14号码/时间、14绿色奖励、10到账状态；上海M/d HH:mm，加载/空/失败/翻页；刷新替换，翻页稳定去重，失败保留数据游标，切号销毁旧Controller |
| invite/InviteRepository.kt | 原me/records端口复用；inviterPoints+fullBonusPoints，各正奖励对应ledgerId非null才已到账。已脱敏号码保留、真实11位号码掩码，不生成demo记录 |
| invite/InvitePosterScreen.kt、InviteSingleLineText.kt | Phone Agent品牌、二维码白边、居中邀请码、实际双方奖励、保存图片/复制链接；关键人数/金额单行缩放不截断。没有新增复制邀请码UI |
| invite/reward/InviteRewardDialog.kt | 544×518奖励卡、最多400宽、绿色勾/星形、实际+amount、确定；独立Card/Artwork。服务端到账事实/账号隔离/一次确认持久化沿既有Controller，确认失败保留错误、忙时禁点、返回/遮罩不可取消 |
| invite/InviteWelcomeScreen.kt、InviteRulesSheet.kt、registration/reward相关领域代码 | 已有欢迎、按真实解析金额、活动规则段落/底Sheet、注册归因/一次奖励回执和平台海报保存接线复核保留；仅定位明确UI差异，不重做收费或发奖规则 |
| points/PointsWalletScreen.kt | 原积分流水标题、收支明细、说明、时间、操作后余额、17号收入绿色/支出红色、分页/错误/空态保留。补组件过滤零变化，与原controller一致；会员月积分/购买积分沿同视觉。用量自绘会员风格流水删除，直接接回PointsWalletRoute(ledger:true) |

v67实际客户端积分记录为纯列表，未定义筛选或详情动作，因此保留既有行为，不臆造筛选/详情接口。旧保存海报“目前仅支持安卓系统”不复制为当前双端错误营销；分享下载仍沿真实环境契约。未发送真实邀请消息、短信或二维码注册，不支付、不外呼、不克隆创建。

## 测试与视觉证据

`flutter test --no-pub test/features/invite test/features/points test/features/settings/native_settings_presentation_test.dart test/shell_workbench_test.dart test/extended_device_stage_test.dart --concurrency=4 --reporter expanded` 最终222通过，1分48秒；日志output/commerce1837/v67-final-targeted.log。首轮193通过/4失败均为旧钱包邀请入口的notice测试，改为真实新入口→海报→记录后5项复验通过，未删除反馈替换/覆盖页忽略/取消等原覆盖。

收尾入口切号、两来源返回、奖励卡及注册恢复12项通过（与222集合重叠不相加）；奖励确认文字颜色另红测6失败后修为v67白色，7项绿。积分零变化UI先观察错误行可见，修正后通过。若干手写括号、测试同名import、格式化glob路径及patch定位失败均按当前文件重读有限修复；没有重放真实业务操作。手写微批≤3文件，机械格式/curly lint修复单独执行。

analyze最终无问题，OpenSpec93通过，diff检查通过。商业化全量首轮另有Windows符号链接权限errno1314两失败，旧六导航已修复定向；未再次重复全量，不宣称全量全绿。

六页活动/海报/邀请记录/奖励卡/欢迎/原积分流水，375/390/430×1/2字号36项绘制通过，18 PNG在忽略output/commerce1837/v67-*.png。捕图使用微软雅黑和MaterialIcons；按钮保留Theme字体后中文正常，试用符号字库覆盖主字体导致方框的中间图已重绘；Windows字体中名额勾字符仍有字形差异，不作为原生像素一致证明。已逐张查看主要390图，关键号码、时间、金额、状态和文本可读。

Web代理在真实浏览器只读归档v67 `docs/product/prototypes/1850_welfare_center.html`，390×844参考截图位于Web树output/playwright/reference-welfare-390.png、reference-welfare-ledger-390.png、reference-welfare-poster-390.png。它是Demo HTML，其旧积分入口混邀请与v67最终Android独立入口不同；不当原生邀请记录截图，不以原型虚构奖励当真实到账。

## 测试产物与运行边界

沿原树忽略 `.local/cloud-test/device-defines.json`，APP_ENV=test/main.dart/关闭迁移预览，固定Flutter3.32/Dart3.8。初版2026101203构建19秒、同签名-r安装成功，首次安装时间保持2026-10-10 12:36:18。随后仅奖励确认颜色纠偏，最终2026101204增量构建17.4秒。最终安装、签名和只读截图结果另追加。

真实服务器会员/商品/订单仍需部署联调，缺配置不造可售。邀请活动/记录、原积分流水的真实显示以实际设备为准，不用组件mock替代；iOS本轮Mac DNS/SSH不可达未编译，保留既有screen/签名配置。新分支与所有商业化能力并存，未丢T07/T08，不改费用、克隆或后台发奖逻辑。

## 最新用户调整与邀请真实缺陷（22:53）

用户确认App只展示总积分，会员/永久来源内部区分即可。来源页、ApiWalletSources、WalletSources DTO及provider/预览请求已删除；总积分卡直接进入原积分流水，页头直达订单与发票，无用量中间页。原积分ledger收入/说明可继续承载真实月积分业务项，不额外分桶。

当前原生App只读实际branch feature/test_v1.6.0 / 1e67c2d：InviteRepository.code以返回URI本身host/rawPath检查HTTPS/443/no-userinfo/no-fragment/唯一code一致，InviteHomeScreen海报入口只要求已返回code且未加载。Flutter错把外部入站固定白名单用在可信发码响应，且额外按零名额/本地到期禁所有查看。发布响应新增独立data校验，入站InviteLinkPolicy源码不修改；保持无code、加载/操作中禁用，真实注册与奖励仍服务端判定。

RED：异发布host/path合法响应在Flutter抛INVALID_CODE；零名额/旧expiry真实code不可查看；积分卡保留用量跳转。修复后16项邀请API/状态及5项会员入口GREEN。组合商业化+邀请+v67ledger+shell+extended+AccountApi共219通过，1分30秒；日志latest-targeted.log（集合重叠不相加）。analyze诊断括号lint修正后无问题12.4秒，OpenSpec93通过。

1204既有安装firstInstall不变，实际邀请码错误/灰按钮重现。1205诊断安装未成功（INSTALL_FAILED_ABORTED，旧版本1204保留），调查中am start过早可能中断安装；并非确定人工撤销授权。1206完整修复包18.7秒构建，V2验证和原同证书SHA256；APK SHA256 247179C681185037F351452DFBA2F7406586B9EAD45251BCEAC595708E17B615。系统普通风险告知、本次勾选、允许本次安装后-r Success，version2026101206、firstInstallTime仍2026-10-10 12:36:18、lastUpdate22:46:06，冷启Statusok、登录与余额保留。未改安全设置/卸载/清数据/降级。

真实脱敏HTTP：POST /aiassistant-sdk-api/api/invite/me/code返回200/000000；code是String且四字合法，HTTPS host chakenai-test.vvtech.tech、path /aiassistant-api/invite/，codeKeyCount1、queryMatchesCode=true、incomingPolicyMatches=false。expiresAt存在/可解析/将来，confirmedUsed0/reservedCount0/available2。确认根因是客户端发布URL校验，不是SDK邀请码错误或空expiry。新版按钮正常可用、名额1/2未邀请。records GET200/000000，真实0/2空态；首页礼物→福利及设置→邀请好友/返回均真机验证，未打开/复制/保存真实海报或发送邀请。

真实商业化读取：GET /aiassistant-sdk-api/api/commerce/catalog、api/membership/current、api/commerce/orders均HTTP404（apiCode按安全白名单OTHER，无nestederrorCode）。这不是DTO解析/空目录成功。root尚未将商业化服务/库迁移发布到测试环境，Flutter显示真实失败，不填假FREE或订单。三个404映射明确服务暂不可用；500仍读取失败重试。积分包页原来忽略error显示暂无可售也已RED→GREEN补错误/重试。最终1207构建与安装结果继续记录。

真实截图（忽略output/commerce1837）android-1206-invite.png、invite-records.png、settings.png、home.png、welfare.png、membership.png、orders.png、ledger.png；与v67-*合成组件图区分。早先android-v67-invite-records.png是加载中，不当记录成功；android-v67-settings-invite.png为Launcher误取，不当App验收。总积分流水真机包含既有每日登录收入/任务通话消耗、时间/说明/余额/绿红金额；无新增收费。Mac本轮不可达未编译。

## 最终1207交付与只读验收（23:20）

最终完整构建18.4秒，APP_ENV=test / lib/main.dart / ENABLE_MIGRATION_PREVIEWS=false；显式ENABLE_INVITE_PROTOCOL_DIAGNOSTICS=true只在debug assert输出允许路径的安全元数据（默认false），不输出code/token/查询值/响应body。复用原树忽略device-defines私有文件，没有复制凭据。固定Flutter3.32.0/Dart3.8/JBR21。

1207最终APK SHA256 AEB9364A8ED40A0F016C39CBDAD9CFD7B02FD67E8C210972E29DE19D6B068676，V2通过，证书与现用包相同45655392a9295955d0d651eb7d1ff3f3edb1d15f8a62d74f201dfbc3789cdb4b。adb install --no-incremental -r Success；version2026101207、firstInstallTime仍2026-10-10 12:36:18、lastUpdateTime2026-10-12 23:14:12。安装Success前保持安装器，不修改系统安全设置。冷启Statusok，登录与8889总积分保留，结束首页。

只读复验：会员显示会员服务暂不可用且总积分直达原流水；积分包同样明确服务不可用、重试有效、确认支付enabled=false/clickable=false，没有暂无可售假成功；订单明确订单服务暂不可用，实际GET404。500/连接超时保持ApiFailure.rejected/network的定向5项通过。404+积分包+会员直达11项通过，analyze无问题16.3秒。与前219组合测试和历史全量均不相加。

邀请code/records实际200/000000，slots正常、按钮enabled=true；设置进入邀请好友、首页礼物进入福利，系统返回各自来源。records真实本期0/2空态，不能替代非空记录运行验收；非空/到账中/分页/账号隔离由真实行为单测与合成UI覆盖。积分流水真实纯列表的收入/消耗、时间、说明、余额颜色和直接返回路径正常。没有点击邀请发送/复制/保存，不付费、不外呼、不新建克隆。

最终真实PNG为output/commerce1837/android-1207-{home,settings,welfare,invite,invite-records,membership,points,orders,ledger}.png，已查看关键记录/流水/首页；业务图无真实手机号/邀请码/QR/token。安全协议日志android-1207-protocol-metadata.log确认catalog/current/orders404，invite activity/code/records200及合法响应与入站policy差异。持续logcat进程出现read unexpected EOF后改为短只读过滤抓取，无业务重放。原型HTML、v67组件合成图及真机图类别始终独立。

Mac本轮DNS/SSH不可达；不能确认Swift/StoreKit商品、支付或发票真实成功。Windows全量两个symlink errno1314保留，未修改无关测试。后端商业化部署/库迁移/渠道与税航配置未就绪，当前仍明确不可用，禁止宣称商品和订单加载恢复。本分支不commit/push，不归档OpenSpec。
## 2026-10-13最终1208接续
交叉消费契约3项修复与真实DTO/fixture证据见COMMERCE_1837_FLUTTER_20261012.md最新段；最新237全scope定向通过、analyze无问题/OpenSpec93。1208同签名-r Success、firstInstall不变，最终双邀请入口/records200空态、会员/包/订单真实404明确提示、总积分直达原流水复验通过，截图android-1208-*，结束登录首页。跨日总积分8989来自原每日登录+100（原流水确认），未手工操作。仍无真实消息/支付/外呼/克隆，不把发票literal/合成UI当真机开票成功；Mac本轮仍未编译。
