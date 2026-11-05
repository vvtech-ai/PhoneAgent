# iOS 异常恢复小阶段（2026-09-21）

源码基点6bfd6c0，加本批共享阶段脚本。正式lib/原生本批不改。只验证本组，不是整体迁移完成报告。

## Preconditions

- 固定Flutter3.32.0、Xcode15.2、iPhone8/iOS16.7.16；使用已保留screen和主机名SSH，不重新登录或索取验证码。
- 安卓只读安装时间仍2026-09-20 22:27:05；未恢复普通Dev包的新证据，不绕过旧安装拒绝。
- 仅选工作台task-error-recovery场景；禁止真实安全存储及系统拨号通道，AuthScenario发码/提交必须为0。

## Build / Install

只构建integration_test/network_recovery_stage_test.dart并显式启动；已保留普通二进制备份，结束构建恢复普通lib/main.dart。驱动STAGE_GROUP=network-recovery，固定use-existing-app/keep-app-running，不让driver安装或卸载。结果写.local/shared-stage/network-recovery/ios，不覆盖其他阶段。

## User Actions / 自动路径

无需用户配合本组。真实OS网络只读取单次状态、首次订阅、取消后重订阅；不打开设置、不切换Wi-Fi、不申请权限、不探测URL。此项不能证明实际断网/重连或后台可达。

| 截图 | 共享控件操作与通过条件 |
| --- | --- |
| 39 | 首页订餐厅→MOCK断网→文字发送；错误可见，用户命令仅1条 |
| 40 | 关闭→任务列表；pending保留，任务执行异常 |
| 41 | MOCK恢复网络只补发一次状态→恢复同一任务→文字补充；有效回复后recovered，命令共2条 |
| 42 | 正常关闭→再次恢复/关闭；任务进行中，不新增异常同步 |

## Expected Logs / Forbidden Logs

预期reportData.completed=true、forbiddenNativeCalls=0、四个completedSteps，nativeNetwork记录read/first/resubscribed。出现All tests passed仍须核对JSON和截图。模拟网络错误日志conversation_failure reason=network为预期，不是设备崩溃。

禁止：未处理Flutter异常/布局溢出、Lost connection to device（测试未完成时）、命令/状态请求超出断言、SMS或系统存储/拨号调用、MissingPluginException或nativeNetwork unknown。安装失败不卸载重试。

## Pass Criteria / Failure Follow-up

两尺寸×双平台样式4条预检、5条attach保护已通过；analyze无问题（4.6秒）。iOS实际本组通过；普通入口恢复另见下方结果。

需要分别证明：测试完成、4张截图可读可操作、真实通道注册可调用、普通包恢复与VM响应。任何一项失败保持该项未通过，先查对应日志，不重跑旧38图或全量测试。

视觉按用户决定后置，VISUAL_CONTRACT_COMPONENT_COVERAGE_MISSING；截图为Flutter表面，tester.enterText并隐藏输入法不能证明真实系统键盘。真实服务/持久存储/杀进程/旧pending升级仍按集中清单人工验证；不把MOCK成功扩大为整体验收。

## 实际设备结果

2026-09-21 04:48 CST收集：测试构建37.0秒（编译链接签名9.5秒），严格签名校验通过，安装启动46.8秒；实际测试15秒，附加驱动返回All tests passed及Leaving the application running。没有重跑此前38图，没有默认driver安装/卸载。

机器报告[本次结果](../../.local/network-stage/ios/result.json)：completed=true，forbiddenNativeCalls=0，四张750×1334有效PNG；真实nativeNetwork.read/first/resubscribed均available。证明原生注册、一次读取和取消后重新订阅能够返回；不证明真实断网重连、后台可达或强杀落盘。短信与登录提交计数在同一真机脚本中断言为0。

- [39：对话网络错误](../../.local/network-stage/ios/39-conversation-network-error.png)：用户内容、网络错误、输入dock可读，无自动重发。
- [40：任务异常](../../.local/network-stage/ios/40-task-pending-error.png)：同一任务标题，执行异常，状态请求2。
- [41：恢复后回复](../../.local/network-stage/ios/41-restored-business-reply.png)：历史和新补充都在，仅2条用户命令；有效回复后状态请求4。
- [42：正常退出后任务](../../.local/network-stage/ios/42-task-recovered.png)：进行中，请求保持4，返回和再次打开/关闭均通过。

四图均已打开检查：无本组阻断性黑白屏、异常换行或主要控件裁切。布局与上轮Web同一页面/状态，字号、颜色及折行存在平台差异，未作逐像素结论。列表浮动导航覆盖视口下方部分列表，需滚动访问；本组只验证目标首项，未据此宣称全部末项可点击。黄色MOCK双工具栏是验收宿主，不是正式产品页面。

首个screen启动使用相对脚本路径未产生进程/日志，确认未运行后改用绝对路径启动；没有因等待超时重复构建。老版screen不支持-Q只读查询，改用实际构建日志与进程取证。测试正常通过，没有为取得通过删除断言。

## 普通入口恢复

恢复采用当前6bfd6c0正式lib/main.dart测试环境构建，不复用更老的MOCK或普通二进制。构建25.9秒、严格签名校验通过，安装启动45.7秒；04:51 CST实时getVM返回iOS、main、PID16405及error=null。USB原生截图[普通入口已恢复](../../.local/network-stage/normal-restored.png)已打开检查：正常登录页，无黄色MOCK栏；当前未登录，不把登录页冒充登录复用成功。未发送验证码。

保留会话仍为phoneagent-build，新普通运行窗口network-normal-run；后续可继续附加调试，不要求用户重新解锁或重登Apple ID。实际设备“无服务”但Wi-Fi已连接，与网络通道available并不矛盾；本批没有验证蜂窝网络或真实电话。
