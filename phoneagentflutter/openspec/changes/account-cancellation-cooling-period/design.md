# 实施设计与职责

2026-10-28用户要求移除本地恢复保存机制，下文RecoveryStore和跨页面恢复描述由[移除注销本地恢复](../remove-cancellation-local-recovery/design.md)覆盖；当前页面内按原操作查询结果及服务端事实保持。

## 批次范围
Flutter与PhoneAgent_server当前feature/test_v1.8.0_zys检出。账号生命周期、API、短信、到期及逻辑删除owner为aiassistant-sdk-api；Agent读取同一账号事实校验凭证及新会话入口。Flutter只负责流程及渲染，UI不直连网络/存储。

## 已实施
- 入口确认后验证码，验证只签发10分钟一次性凭证；最终确认后独立原子受理；替换AccountRoute原仅signOut临时功能。
- 最终AccountConfirmation复用NativeBusinessDialog，验证码复用AuthInputGroup/AuthPrimaryButton和新共用AuthCodeInput；中央提示扩展NativeNotice，原底部展示默认不变。
- 独立CancellationController/Gateway/加密RecoveryStore按账号及环境隔离，当前登录代次检查、旧响应失效、超时按原操作查证。
- SessionController业务屏障立即禁止请求；identityEpoch在本地清理期间保持展示账号身份，避免旧组件提前重建；退出失败根认证页只提供重试清理。
- 冷静期身份不进入SessionController.accept；保持/返回不撤销，只有明确继续登录并成功撤销才进入普通登录收尾。
- user_account复用deleted逻辑删除字段，新增cancellation_state和auth_epoch。PENDING与既有enabled封禁独立；账号行保留，最终deleted=1，原权益由account_entitlement_termination记录终止，不制造消费流水。
- 受理/撤销推进凭证代次；SDK及Agent兼容v1正常账号、签发含epoch的v2凭证，防止撤销后旧token复活。已有录音播放授权也检查账号及申请时间。
- 受理与购买/使用会话共享钱包锁后复验账号；检查真实进行中的账务/支付/通话/任务。Agent会话创建在账号锁内校验生命周期。
- worker按截止扫描并在账号锁内重验；失败5分钟后恢复，10次后标记人工复核，等于截止时不可撤销。故障留待下轮有界扫描，账号不恢复；验证临时表有界回收。

## 保留规则与范围
保留普通退出、登录协议、邀请、原登录奖励幂等、退款及合法交易处理；不暂停会员、不补偿时长，不通过清空余额冒充注销，不改任务编排共享规则。回放DEL-01～05，直接调用方登录/session/邀请、提示组件和账号网络层回归。

## 未部署/未验收
未执行数据库写入、真实短信、发布协议、部署或真机操作。MySQL锁与DDL、真实多设备/媒体边界、账务迟到回调及双端邮箱跳转仍需授权环境证据。单元mock不代表已联调。详细文件和接口见implementation-plan.md及api-contract-proposal.md。

## 2026-10-27 两阶段确认调整
用户确认：入口恢复“确认注销账号？”提示；验证码成功后仍按网页展示最终确认及协议，最终点击“注销”才受理。入口恢复历史弹窗UI及文字输入，最终确认复用NativeBusinessDialog，无勾选框或文字输入；不恢复旧临时signOut逻辑。SDK新增sms/verify，复用验证记录表的VERIFIED用途，不增加DDL。凭证绑定账号、operationId、源短信及协议版本；秘密只存摘要、10分钟有效、受理原子消费，同操作重放截止不变。保留DEL-03～05、账号隔离、频控、恢复查询及逻辑删除。dev结构已于2026-10-27只读核对齐备，本批无需新增DDL或回填，不执行共享库写入、部署或推送。

## 2026-10-27 入口网络前置遗漏修正

基线Flutter feature/test_v1.8.0_zys@9ffda574，工作区初始干净。账号管理入口由AccountRoute持有；CancellationCoordinator持有原操作恢复及准备，CancellationController持有短信/验证/受理状态；SDK仍为账号状态owner。影响DEL-01/02/05及ENTRY-03/08账号隔离，不改任务编排共享规则。

发现10be39a9虽增加本地入口弹窗，仍先调用prepare，导致远端失败时无法显示弹窗。本批将入口确认放到恢复读取及所有注销请求之前，取消/关闭/返回均零读存储、零请求。prepare在每次异步返回后核对入口和账号代次；原申请查询未知时保留记录，停止新确认与短信。损坏或过期本地记录仍只允许在服务端ACTIVE确认成功后清理。

网关对现有SDK已知业务拒绝做逐字白名单映射；400/AC0001业务与鉴权签名错误通过既有AccountApi exposedMessage入口隔离，未知响应、5xx和认证错误不泄露原文。VERIFY只负责本人验证；最终明确注销才提交。提交业务拒绝仍先查原操作，只有明确NOT_SUBMITTED才显示拒绝原因并清除旧验证状态，查询未知只允许查结果。验证有效性仍由服务端裁定，不依赖客户端改时钟授予权限。短信重发重置旧凭证。

不修改数据库、SDK接口、运行配置或部署。原UI/共用控件、协议与mailto、成功中央提示、冷静期显式撤销、逻辑删除和权益规则保持。新增回归验证入口零请求、服务失败及慢响应、账号切换与离页、恢复未知、白名单错误及过期恢复。

## 2026-10-27 入口恢复历史UI
用户进一步明确“这个弹窗的内容跟以前的不一样，需要使用以前的UI”。入口按bb587487父版本的account_confirmation_dialog.dart原源码恢复，独立为account_entry_confirmation_dialog.dart；仅分离函数/类名和按钮key并做格式化。保留原文案、30圆角、322最大宽度、原边距/阴影/颜色、脱敏账号、输入“确认注销”及IME组合门禁、按压状态、关闭动画和小屏滚动。不恢复旧临时signOut业务。最终确认仍使用NativeBusinessDialog及内联协议，不增加输入或勾选；本次用户指令覆盖此前入口不含文字输入的描述。

## 2026-10-27 普通注销接口漏Bearer修正

只读核对发现AccountTransportPolicy原未列api/account/cancellation，导致四个普通注销接口在AccountApi._send中签名token为空、没有Authorization，且不会执行普通401续期。SDK的VoiceCloneAuthenticationFilter已要求该前缀账号鉴权，服务归属也已正确指向SDK。此前dev访问日志14:43:21至14:52:24的confirmation多次401与该缺陷相符；不能把这类错误仅解释为用户会话变化。

本批仅新增精确鉴权前缀，复用现有账号标识、Bearer/C1和一次续期重试，不放宽后端鉴权、不修改数据库或接口语义。lookup/revoke继续走DioAuthGateway的受限身份，不携带普通Bearer或进入普通续期。新增真实请求层离线测试覆盖头部、签名重算、SDK路由、刷新及身份切换；原UI、入口零请求、两阶段确认、恢复查询、逻辑删除及权益处理保留。

## 2026-10-27 协议1.0及配置缩减方案
用户明确无注销分支切换会同步还原数据库，本批不实现回退保护、最低兼容基线、能力标识或发布拦截。沿用已有协议托管方式，目标www.chaken.ai/agreements/Phone_Agent_account_cancellation.html；本次只准备1.0 HTML、dev SDK配置片段及操作清单，真实发布和运行配置待用户确认。原始Markdown保留，历史申请版本不回填。
SDK协议版本固定为1.0，enabled仍默认false；协议URL按最新用户决策固定，不再读取agreement-url。保留现有普通@Value启动绑定，不引入新的热更新生命周期；配置合并后需受控重启并以授权测试会话确认实际返回版本/地址。仅改dev SDK服务配置，不能覆盖整份Data ID或公共配置。公开URL未200前不启用。

## 2026-10-27 注销协议固定地址
用户指定https://www.chaken.ai/agreements/Phone_Agent_account_cancellation.html。Flutter领域提供统一地址常量，AccountRoute点击内联协议直接使用该常量，通过现有openPublishedAgreement通道打开，无原生改动。Gateway不再依赖响应agreementUrl，保留confirmationId、agreementVersion、预计完成时间的解析与验证。SDK用固定常量返回兼容字段，移除agreement-url绑定和URL配置校验，开关仍默认false，版本及凭证绑定规则保持。dev片段仅保留开关，未发布协议、改线上配置或重启。回归DEL-02-02/08和DEL-CONFIG-03。

协议版本按用户最新要求固定1.0：CancellationService使用源码常量，不读取agreement-version。confirmation、SMS、VERIFIED及申请仍记录并核验该版本，旧版本凭证拒绝，历史申请不回填。版本不再作为运维配置，enabled仍默认false。

## 2026-10-27 验证页自动验证
基线feature/test_v1.8.0_zys@f8a33683。现状：CancellationVerificationPage通过AuthPrimaryButton手动触发，notice直接展示正文；AccountRoute负责验证/确认/提交，CancellationController持有挑战及申请事实。目标：验证码完整事件由AccountRoute统一门禁触发，页面仍纯展示，AuthCodeInput只扩展可选焦点/自动聚焦。沿用AuthTokens、AuthInputGroup及NativeNotice；Toast由路由按状态通知转移投影并归属本页，倒计时不重播同事件、相同错误的新操作不被全局去重。
正常页无提交按钮；未知申请查询与受理后退出恢复保留。失败与最终确认取消清输入，Controller仅在未受理且结果明确时丢弃本地验证凭证，不改服务端申请；重输后重新验证。账号/路由/忙碌/组词/完整6位门禁共同限制自动请求，旧响应不得弹框或提示。影响DEL-01/02/05、DEL-UI-01～03；保留入口零请求、历史UI、Bearer/C1、协议、15天及逻辑删除规则。验证覆盖路由连续交互、异常恢复、双平台/小屏键盘大字体、相关调用方；不改SDK、数据库或原生。

## 验证码格背景与重发闪字修复
延续本批未提交修改。状态owner仍为AccountRoute/CancellationController；本次仅共用AuthCodeInput渲染及AuthTokens验证码专用色。现状六格背景F5F7FA与页面底色接近且非焦点边框透明；真实TextField仍有labelText，即使输入文字透明也不能隐藏InputDecorator的标签。目标：验证码专用浅灰底及常显边界，普通AuthInputGroup默认样式不变；底层输入只负责输入与语义，停止全部绘制并移除装饰，视觉只来自六格。影响DEL-UI-01/04及重发，不改接口、验证码代次或业务规则。验证实际渲染格间像素在清空/禁用/聚焦转移时无文字，另回归输入、语义、填充及重发。

## 2026-10-28 注销门禁补充

本文件历史设计中的任务、支付和账务完成门禁已被用户明确撤销；当前按 [注销通话提示收敛](../cancellation-physical-call-admission/design.md) 实现。其余本人验证、双确认、协议1.0、15天、主动撤销及逻辑删除合同保留。

## 2026-10-28 最终确认文案调整

基线feature/test_v1.8.0@b6b87141598a6f43d4bd999da88cb787b1533519，初始工作区干净。presentation/account_confirmation_dialog.dart负责最终确认展示，确认数据仍由原账号/操作流程持有。现状自行扩写“预计于”、冷静期说明和不可恢复说明；目标为用户批准的需求原文及动态完成时间，协议名按原文保留PhoneAgent后的空格及句末标点。

保持NativeBusinessDialog及原样式、原服务端时间格式化函数、协议固定地址和取消/提交回调；入口历史确认不改。冷静期按秒读取/校验、单位格式化和服务端准入仍保留，但最终正文不追加时长句子。影响DEL-02-01～04，直接调用方覆盖两阶段确认、自动验证、账号隔离、恢复和设置完整流程；本次不读取实际安装构建或签收真机。

## 2026-10-28 登录注销中提示文案与颜色

当前feature/test_v1.8.0@b6b87141598a6f43d4bd999da88cb787b1533519，保留前一批最终确认文案的11个未提交文件。状态owner仍为AuthController持有的当前受限申请；CancellationLoginHost只展示其effectiveAt并触发原回调。本批不修改账号/后端/数据库。

现状末句为自行改写文案，按钮使用共用secondary灰字/primary蓝色渐变。目标逐字需求文案及正常态灰底红字/黑底白字。NativeGradientAction增加可选背景/文字颜色，NativeBusinessDialog分别向两按钮传递；null沿用原渐变，禁用仍走原灰色样式。登录提示指定原有灰F2F4F7/红E14D46与黑111111/白FFFFFF，其余布局/字体/圆角不改。回放DEL-03-01～04及共用默认/危险/禁用动作兼容、小屏大字体。
