# 已实现接口合同（源码，未部署）

账号服务owner：aiassistant-sdk-api。沿用SDK C1签名、ApiResponse及普通账号Bearer鉴权。公开auth路径仍要求SDK签名；受限challenge和queryToken不能调用普通业务。

| 方法与路径 | 身份/输入 | 返回与语义 |
| --- | --- | --- |
| GET /api/account/cancellation/confirmation | 当前普通登录 | confirmationId、agreementVersion、agreementUrl、serverNow、estimatedEffectiveAt；不发短信、不受理 |
| POST /api/account/cancellation/sms/send | 同登录；confirmationId、operationId(UUID)、agreementVersion | challengeId、queryToken、maskedPhone、resendCooldownSeconds、expireSeconds；确认后才能调用 |
| POST /api/account/cancellation/sms/verify | 同登录；challengeId、queryToken、operationId、六位code | verificationToken、expiresAt及confirmation；只验证，不创建申请 |
| POST /api/account/cancellation/applications | 同登录；challengeId、queryToken、operationId、verificationToken | 最终确认后原子消费凭证并受理，返回applicationId、status、acceptedAt、effectiveAt、serverNow；同请求不延长期限 |
| POST /api/auth/account-cancellation/lookup | SDK签名；queryToken、原operationId | 原申请PENDING/FINALIZED/REVOKED，或明确NOT_SUBMITTED；查询失败不是未受理 |
| POST /api/auth/sms/login | 既有本人验证 | 普通登录/邀请保持；注销中追加cancellation对象(applicationId、effectiveAt、challenge)，不返回普通token、积分或奖励 |
| POST /api/auth/account-cancellation/revoke | SDK签名；challenge、applicationId、operationId | 截止前原子撤销，复用正常登录收尾返回LoginResponse；失败不能先进首页 |

## 与最初提案的收敛
- 用户确认先弹窗后短信，因此确认展示数据独立读取；发送短信前已冻结协议版本及confirmationId。
- 2026-10-27用户确认两个确认阶段：入口确认后发送验证码；sms/verify只验证本人并返回最终确认数据和10分钟verificationToken，最终点击注销才调用applications。旧版仅传code的申请请求不再受理，需客户端与SDK匹配发布。
- verificationToken按账号、operationId、源短信challenge及协议版本绑定；复用现有challenge表的VERIFIED用途，秘密只存SHA-256摘要。短信验证响应丢失时，同请求可恢复同一未消费有效凭证；正式受理时在账号锁内校验、消费凭证并创建申请。
- 同一已受理操作即使验证凭证随后过期，持原查询信息与原验证凭证重放仍返回原申请；不能据此创建新申请。
- 查询使用POST只读操作，使queryToken不进入URL；queryToken在发短信响应就可取得，受理响应丢失仍可查证。
- Flutter在提交前加密保存原操作及查询信息，不保存验证码；重进优先恢复原结果。旧查询过期时，只有受鉴权的ACTIVE确认接口成功才清理旧本地恢复信息并允许重新确认，不靠本机时间授权。
- 撤销返回丢失时，同有效challenge及同operationId重放撤销结果；challenge过期需重新短信登录。不会重复撤销、延长截止或重复授予奖励。

## 持久化与时间
account_cancellation记录申请及协议版本；account_cancellation_challenge隔离CONFIRM/SMS/VERIFIED/LOGIN用途，验证秘密存摘要；唯一有效申请及同账号操作唯一约束。短信有效期、重发及尝试次数复用正式SmsLoginProperties，注销验证码固定六位，不接受登录用验证码或测试固定码。

acceptedAt起连续15×24小时，服务端Clock为准；显示北京时间到分钟。验证后的最终确认弹窗是预计完成时间，实际受理后截止固定。临时验证记录17天后有界回收；账号、业务及账务数据不硬删除。

## 发布要求
先审核/执行V202610260001增量（本次未执行），再部署匹配SDK/Agent及共享实体。配置app.account-cancellation.enabled=true，协议版本固定1.0无需配置；agreementUrl固定返回https://www.chaken.ai/agreements/Phone_Agent_account_cancellation.html，不再配置agreement-url或agreement-version。默认关闭新申请；关闭时既有查询、撤销和到期处理继续。先完成真实MySQL并发、短信、协议及双端联调再开放。

## 本批数据库影响
本批复用现有VARCHAR用途和挑战字段，无新增DDL；VERIFIED行的application_id字段在该用途下关联源SMS challenge_id，不是申请ID。源SMS行继续关联入口confirmationId。只有applications成功才写account_cancellation并推进账号状态/epoch。dev上午日志曾缺少account_cancellation；2026-10-27后续只读核对确认三张表、账号字段及相关索引均已具备，现无需执行本批迁移或回填，不重复运行原V202610260001的CREATE/ALTER。本批不执行迁移或部署。

## 2026-10-27 调用时机与拒绝投影修正
入口本地确认之前不调用本表任何接口，也不读取注销恢复存储。确认后先恢复原请求，未知结果阻止新流程，再GET confirmation及发送短信。服务端接口与数据库结构本批不变；客户端仅对已知拒绝作白名单映射。最终提交拒绝后仍需查询原操作，查询明确未受理时才展示拒绝原因和重新验证操作。

## 2026-10-27 鉴权与续期逐接口核对

| 路径 | 当前客户端鉴权方式 | 401行为 |
| --- | --- | --- |
| GET api/account/cancellation/confirmation | SDK C1 + 当前账号Bearer + X-Account-Id | 普通过期按既有机制一次续期、一次原请求重试 |
| POST api/account/cancellation/sms/send | SDK C1 + 当前账号Bearer + X-Account-Id | 同上，operationId与确认数据保持 |
| POST api/account/cancellation/sms/verify | SDK C1 + 当前账号Bearer + X-Account-Id | 同上，原验证码/操作保持，不提前受理 |
| POST api/account/cancellation/applications | SDK C1 + 当前账号Bearer + X-Account-Id + 验证凭证 | 同上，原operationId/queryToken/verificationToken保持 |
| POST api/auth/account-cancellation/lookup | SDK C1，签名token为空；body中的queryToken与operationId | 不调用普通续期 |
| POST api/auth/account-cancellation/revoke | SDK C1，签名token为空；body中的受限登录challenge/申请/操作 | 不调用普通续期，成功后才取得普通登录结果 |
| 原短信发送及短信登录 | 原SDK C1及短信身份验证 | 保持既有流程 |
| POST api/auth/voice-clone/refresh | SDK C1绑定待续期Bearer | 刷新自身不递归刷新 |

AccountTransportPolicy只增加精确边界前缀api/account/cancellation，未扩大到api/account或api/auth。相似前缀cancellation-other/cancellations不匹配。四个普通接口的C1签名token必须与Authorization相同；重试重新生成请求号与签名，内容不变。签名拒绝、续期失败、网络错误或账号切换不无限重试。正式申请响应丢失仍由注销controller查询原操作。

## 协议版本与配置交付
当前协议版本为字符串1.0；SDK固定1.0，dev待应用片段仅保留enabled。计划公开URL为https://www.chaken.ai/agreements/Phone_Agent_account_cancellation.html，2026-10-27核对尚为404。仅准备发布稿及配置，不代表已启用。现有普通@Value配置按启动绑定，后续Nacos合并需受控重启并验证confirmation实际返回；原申请版本不回填。详情见服务器deploy/host-220/account-cancellation-dev.md。

协议地址合同：agreementUrl响应字段保留兼容，值固定为https://www.chaken.ai/agreements/Phone_Agent_account_cancellation.html。客户端使用相同固定地址打开链接，响应不再决定打开目标。协议版本仍由服务端返回并参与确认、短信与验证凭证绑定。
