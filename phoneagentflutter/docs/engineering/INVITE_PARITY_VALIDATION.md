# 邀请功能实施与验证

2026-10-05；用户确认四阶段计划后实施，关联NF01/NF22/NF28–NF31以及C03/C04邀请部分。参考版本为台账固定Android 0f8879e4、iOS bb9ff349；新增Flutter实现随本分支提交，不属于原始比较基点75e0e25。

## 已接入的行为

- 钱包→邀请活动→邀请码/有效期/名额→复制邀请码或链接→二维码海报→平台保存；活动规则；2026-10-11复核原生后移除Flutter独有邀请记录入口与页面。
- 活动名义奖励与个人奖励资格分开；个人资格缺失不显示假奖励，已领取/无赠分与满邀奖励按服务端字段展示。
- 公开resolve不携带账户凭据；activity、code、events及保留在数据层的records走账号绑定的AccountApi及Bearer刷新。仅向既有API发送请求，不跟随外部分享URL携带凭据。
- 外部链接→欢迎→普通短信验证→邀请码挑战→REFERRAL/registrationRequestId→服务端成功→保存会话→奖励确认→首页。保留普通登录、旧激活码和两步初始化。
- 账号已登录时收到链接只提示奖励限新用户；恢复中暂存，环境/host/path/scheme/码严格验证。重复冷/热投递去重，较新热链接优先于晚到的启动链接。
- 待处理邀请按环境/API隔离；注册ID在请求前持久化，同一手机号/码/来源重试复用，取消旧回调失效。存储读取失败不生成新的重试ID，恢复后重用原ID。不保存短信验证码或challenge。
- 奖励要求唯一REFERRAL_INVITEE_GRANT与referralResult金额一致；按账号和operationId持久去重，通知先保存再接纳新会话，确认失败保留重试。事件接口仅记录COPY_CODE/COPY_LINK/SAVE_POSTER，不作为奖励确认或积分记账。
- Android29+使用MediaStore，相册写入失败清理未完成条目；26–28使用系统创建文件并支持取消，不增加广泛存储权限。iOS使用PhotoKit addOnly及对应用途说明。

主要入口：[共享邀请页面](../../lib/features/invite/presentation/pages/invite_page.dart)、[活动控制器](../../lib/features/invite/presentation/controller/invite_controller.dart)、[注册状态](../../lib/features/invite/presentation/controller/pending_invite_controller.dart)、[平台注册](../../android/app/src/main/kotlin/com/vvtech/phone_agent/InviteChannel.kt)、[iOS适配](../../ios/Runner/InviteChannel.swift)。

## 实际验证

固定Flutter3.32.0/Dart3.8.0。仅新增qr3.0.2，原有依赖锁定版本/镜像未升级。手写编辑按最多3文件微批；格式化/lint修复独立机械批次，新增及修改手写源码均未超过500行。

| 检查 | 结果及范围 |
|---|---|
| OpenSpec | `openspec validate --all` 32项通过 |
| 静态检查 | `flutter analyze --no-pub` 无问题 |
| 定向回归 | 下方命令203项通过，约13秒；不是项目全量测试 |
| Android | `flutter build apk --debug --no-pub` 最终6.8秒通过；Android Studio内置JDK21，Dev包；存在上游x86弃用提示，不修改发布保护 |
| iOS | `flutter build ios --debug --no-codesign --no-pub` 通过；真机架构但未签名/未安装，不是分发验收 |
| 配置 | Info.plist、Runner.entitlements、project.pbxproj均通过plutil语法校验 |
| 海报 | 合成PNG实际生成，macOS Vision识别二维码，内容严格等于`https://example.test/invite/?code=ABCD`；测试引擎使用占位字体，该图只证明编码/二维码，不是正式字体视觉验收 |

```sh
flutter test --no-pub test/features/invite test/features/auth \
  test/core/network/account_api_test.dart test/features/points \
  test/features/home/shell_navigation_test.dart test/shell_workbench_test.dart \
  --reporter expanded
```

包含协议/鉴权/游标/错误码、邀请ID恢复与取消、存储失败、账号隔离、奖励去重、过期拒绝分享、事件失败不撤销复制、320/430宽页面流程，以及完整App冷邀请→欢迎→挑战→奖励→首页→恢复。没有发送真实短信、注册、外呼、奖励写入或操作手机相册。

回归中发现并修正：窄屏SnackBar遮挡底部分页，增加底部留白；旧auth-only演练进入完整Shell时缺失初始化/任务作用域，其宿主改为正式AuthRoute/Controller到认证边界并用内存邀请存储，11项复验通过。完整Shell兼容由独立首页/共享主流程及新增完整App邀请测试验证，未在正式代码添加绕过门禁。

## 外部配置与待验条件

2026-10-05只读检查公开关联文件：

- `https://agent.vvtech.tech/.well-known/assetlinks.json` 返回HTTP404。Android测试域的HTTPS App Links尚不能判定已验证；部署文件需包含Dev应用ID及实际安装证书SHA256，正式发布另配生产ID/签名。客户端scheme接收已实现，仍需真机验证浏览器回退与冷热启动。未修改服务器。
- `https://phoneagent-ioslink.vvtech.tech/.well-known/apple-app-site-association` 返回配置，含`425F285BQA.com.chaken.phoneagent.test`及生产ID，路径`/phoneagent/ios/*`覆盖邀请。仅证明公开配置匹配，未验证系统缓存、签名授权或实际投递。
- Debug/Profile使用测试域与phoneagent-test scheme，Release使用生产域与phoneagent；运行时还按APP_ENV/API_BASE_URL验证当前环境，不接受跨环境链接。Android HTTPS路径固定`/aiassistant-api/invite/`，后端自定义前缀需同步Manifest配置；iOS独立域路径`/phoneagent/ios/invite/`。
- 原生工程/部署应提供正确的签名授权和域名文件；本次未上传证书、不改生产发布保护。

待验：双端真实系统链接投递、重装/杀进程/重复点击、相册拒权与设置返回、真实个人资格/记录/统计收件、短信注册幂等及奖励到账、系统字体和视觉精校。按用户规则，真实短信/注册需明确测试授权；本次未进行设备安装，不触碰现有登录数据。上述条件未满足前保持change active，不声称邀请业务已完成生产验收。

## 2026-10-11 邀请记录范围修正

Android 0f8879e4b与iOS bf2b65245均没有邀请记录入口/页面；Android仅保留记录接口和模型。Flutter删除独有页面、入口、控制器分页状态和刷新记录请求，保留数据协议及其测试。上文203项等为历史验证；本次实际验证见根tasks.md及问题记录，设备视觉待验。
