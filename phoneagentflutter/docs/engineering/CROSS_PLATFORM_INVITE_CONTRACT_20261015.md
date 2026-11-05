# 双端邀请契约完善执行记录

2026-10-15 用户在侧会话确认计划后授权执行。工作树 PhoneAgent，分支 codex/dev_zys；初始无未提交修改。本轮本地实施，无分支切换、commit/push；参考仓库及后端只读。

## 实现

1. 共用 AuthController 在手工或外链邀请码注册时持久化稳定 registrationRequestId；普通登录不增加请求号，普通激活码仍不强制 REFERRAL。PendingInviteController 的身份键包含真实 MANUAL/REFERRAL 来源；同一提交重试/重启复用，手机号、码或来源变化更新。原 REFERRAL 键保持兼容，不持久化短信或 challenge。
2. me/code DTO 拒绝缺活动或缺失/空白周期，分类 INVITE_ACTIVITY_CHANGED；Controller 同样防止不完整 Repository 快照。完整新周期响应原子替换活动、个人信息及邀请码，不能回退到旧 activity 查询。
3. 刷新清空旧 overview/code；失败不恢复旧分享。loading/acting 期间的刷新合并为一次，完成后执行；设备操作事件绑定点击时 code 周期，统计异步失败不撤销复制/保存、不阻塞刷新。
4. 新增独立活动提示映射，按 AIAssistant1 InviteViewModel；注册 InviteFailure 按 InviteRegistrationBridge。补 ACTIVITY_DISABLED/ACTIVITY_UNAVAILABLE 白名单。欢迎页独立映射与 iOS 继续白名单保持。
5. 未修改 Flutter 页面布局、颜色或共用控件；保留记录账本到账判断、奖励事实校验/确认去重及既有双端链接配置。

## 自动验证

固定 Flutter 3.32.0 / Dart 3.8.0；无依赖/工具链升级。

- 最终 `flutter test --no-pub --reporter expanded test/features/invite test/features/auth test/architecture_test.dart`：398 项通过，0 失败，25 秒。日志 `/tmp/invite-contract-final-tests.log`。
- 包含注册重试/恢复、来源/手机号/码变化、普通激活兼容、缺快照/截断周期、跨期规则/个人信息/事件、加载与复制/保存期间合并刷新、取消/失败后刷新、统计挂起、旧 Controller 销毁晚到结果。
- 包含已有双平台入口、欢迎页、海报、记录、奖励/账号隔离回归；新增 Android/iOS 主题的 320 宽两倍字号错误→重试恢复页面测试。主题测试不等于真实系统验收。
- `flutter analyze --no-pub` 无问题（4.7秒）；`openspec validate --all` 153项通过、0失败；`git diff --check`、UTF-8及修改Dart文件500行上限检查通过。
- 所有修改手写 Dart 文件低于 500 行，新增职责分别为活动错误映射及测试；架构预算测试通过。

## 中间失败及恢复

初始 PATH 不含 Flutter/OpenSpec，通过 package_config 和缓存实际目录定位固定 SDK、Node 和 OpenSpec。一次测试 patch 上下文不匹配，读取当前文件后修正；无重复副作用。

新快照测试首次字段命名错误与 test.fail 名称冲突导致编译失败，按真实 InvitePersonal.successful 和 this.fail 修正；中间误写 count 也已纠正。模块首轮389通过/2失败均是环境链接测试缺活动快照，补合成夹具后最终398全通过。未通过放宽生产协议使旧夹具过关。

## 待验与后端边界

- 本地后端 SmsReferralRegistrationRouter 使用可信分类识别手工好友码，InviteRegistrationService 强制有效请求号；本次补齐此客户端字段。
- SmsReferralReplayStore 只对显式 REFERRAL 缓存提前重放结果。MANUAL 稳定请求号不意味着登录凭据已消费后的响应丢失可以直接重放；仍需核对实际部署和服务器认证/恢复契约。后端未修改，未将源码修复描述为完整服务验收。
- Android/iOS 真实冷/热链接、iOS Universal Link/Scheme、已登录提示、相册授权/取消/保存、真实注册及奖励到账仍待设备及必要的真实短信/注册授权。
- 本轮未改平台、插件、依赖或构建链，不重复打双端包；没有安装、卸载、清数据、真实服务写入或收费。既有 iOS selector/Overlay 修复保持，不宣称本批真机验收。
- OpenSpec 保持 active，3.3 不勾选、不归档。
