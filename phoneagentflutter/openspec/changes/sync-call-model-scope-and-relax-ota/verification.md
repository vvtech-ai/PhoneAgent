# OTA、模型选择与拨打反馈验证

基线：Flutter codex/dev `38cfc6cc52d3c357a4e54ef7d977ce6d1aed880f`；Java feature/test_v1.7.0 `7989731a65cc60b63656ed6c8bb0dc909c49d0be`。

## 修改与职责

- OTA客户端及原生取消版本大小和后台/APK版本一致性限制，保留身份/签名/完整性/归属/权限。恢复清理依赖真实安装时间及同APK摘要回执，系统安装规则不变。
- CallModelController管理刷新代次与保存排队：新请求胜出、刷新与失败不授权旧目录，旧model对象不能绕过新available。统一刷新Provider接首页/任务/设置/模型面板、前台恢复/子页返回及可信会员履约。
- Java GET/PUT纠正并保存失效默认到后端排序首个可用项；有效选择保留，无可用不选。锁后当前读/重新计算available、READ_COMMITTED及MyBatis缓存清理防旧响应改库覆盖新手选。
- 任务标签、倍率、面板radio及监控标题使用同一任务模型；Agent只改任务，手动面板选择全局保存成功后更新任务；有效历史选择保持，失权时重新确认克隆。模型名称按任务ID解析。
- 独立ConversationCallFeedback投影现有1500ms准备期与用户确认，复用提交commandId，权威ledger替换本地回显。主动重试属于新发言，每次各一条。拨后整理状态按当前命令思考/结果接替，原权威结果和TTS去重保持。
- 新外呼准入在异步读后和真正submit前检查当前目录，撤权/加载中/无模型停止下发且允许重试；不动真实activeRequest通话。音色设置也拒绝刷新中的旧模型写入。
- Shell浮层样式独立到ShellModelSheet，主文件499行；请求排序在controller，权限在后端与业务门禁，任务局部模型由原任务binding负责，不向Shell堆网络或持久化。

## 已确认的验证

- 模型刷新/声音/三入口/会员履约直接调用方：186项通过。RED覆盖旧请求、旧对象、无权限active、保存时刷新；额外stale voice先失败后通过。`.local/model-refresh-final.log`。
- commerce与首页/设置导航：642项通过。`.local/model-commerce-shell-final.log`。
- Flutter全项目analyze：No issues found。`.local/model-scope-analyze-final.log`。
- OpenSpec全仓：167通过、0失败。`.local/model-scope-openspec.log`。
- Java主线程重新执行Maven目标模块/依赖编译及51项回归，0失败/错误；细目见后端独立change verification。已推送 `a0eb9b53e70eb97f7c18e4fffee1ddf9e518e7ac` 至 feature/test_v1.7.0并用ls-remote核对。
- OTA模块145项与原生JUnit6项、4个原生文件Android SDK35编译通过，详见ota-verification.md；最终Release整包另行记录。
- 新道歉任务模型26项/确认与拨后反馈105项定向通过，见apology-model-verification.md、call-confirmation-feedback.md；会话/通话/评价/模型/OTA集成回归在主线程最终记录追加。
- 独立复核关闭Java旧available快照覆盖与新外呼等待期模型门禁两项Important，无未关闭Critical/Important/Minor。
- UTF-8与中文读回、git diff --check、变动lib文件500行约束通过；未提交原始诊断日志、账号资料或构建私密输入。
- 实际product/AOT配置探针接受独立test三服务并拒绝16种非法配置；SDK/Agent只读签名请求：正确签名AC0002（缺账号认证）、错误签名AC0009，证明当前测试凭据/网关签名匹配，不代表已执行用户登录/外呼/支付。

## 交付与运行边界

用户最新要求测试Release原登记签名包，包名com.vvtech.aiassistant.test、1.0.52 (45)，文件名仅更新时间戳。源码验证/中文提交推送后冻结打包；具体APK、SHA256与成包核验回执随后追加。旧交付文件保留。

未部署后端、安装或操作真实账号/外呼/交易，真实MySQL并发、模型发布/购买后的跨端联调及设备系统安装/外呼/TTS仍待环境验收。Java全仓OpenSpec有1项既有只读审计缺delta失败（75通过/1失败），本次独立change严格通过，未改无关规格。

## 最终集成复验

- 五模块会话/通话/评价/OTA/模型集成首轮1705通过、1条旧断言失败。失败是conversation_submission_gate_test仍只期待原需求1条用户消息；新确认回显使其正确地变为需求+确认2条。改为精确校验这两条且被拦截的修改输入不存在，未修改业务行为。
- 该门禁与确认反馈14项复验通过；随后完整calls模块206项全部通过，原失败已消除；其他四模块没有失败且未再改动。日志.local/model-scope-runtime-final.log、.local/call-feedback-gate-final.log、.local/model-scope-calls-final.log。
- 最终42个变动Dart文件格式检查0修改，全项目analyze无问题；独立change严格规格、全仓167项及UTF8/diff通过。
- 本轮没有尚未修复的自动回归失败；Java既有只读审计规格缺delta仍按上节保留运行边界记录。

## 测试Release签包交付

- APK：`Phone_Agent_TEST_1.0.52_45_test_20261016_152116.apk`，78974560字节。
- SHA256：`fbdce04c3925e5ace18f8754c200a68a78f53d943b951b440f5fb925e4e79b9a`。
- APK冻结源码：Flutter `50e9d8e2e6a2a93aaa344fd300f87d5334564e24`，已推送codex/dev；Java `a0eb9b53e70eb97f7c18e4fffee1ddf9e518e7ac`已推送feature/test_v1.7.0。
- 测试环境/Release/ARM64/AOT，实际包名com.vvtech.aiassistant.test、1.0.52 (45)，签名MD5 ebd4c931de412bf5d9c3716815389097，三服务地址/邀请入口/11项保护库字节一致性/无debuggable或kernel/无私钥或defines文件均核验通过。
- 按登记入口验证参数并Release config-only --pub生成；沿用同版本engine校验后的离线Gradle回退，assembleRelease成功（2m45s），包含本次OTA Kotlin的实际生产编译。构建期间未改源码或运行Flutter测试。
- 完整回执在工作区`D:/work/04phoneAgent/deliveries/model-scope-20261016-45/`，含README.md、SHA256SUMS.txt、build-receipt.json、test-release-verification.json及不含凭据的配置/签名探针结果。旧包未覆盖。
- 本次后续提交只记录交付文档，APK业务源码仍为上述冻结提交。未安装、部署、真实账号操作、外呼或支付。
