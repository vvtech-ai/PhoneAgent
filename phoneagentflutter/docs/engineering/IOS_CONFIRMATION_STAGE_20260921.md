# 确认卡与历史恢复独立设备阶段

代码基点`ec643d5`加本批confirmation测试分组；普通/扩展卡与计费的正式实现不变。仅本阶段相关检查，不重跑此前52个截图点，不代表全部迁移完成。

## 路径与边界

| 检查点 | 路径及断言 |
|---|---|
| 53 | 首页→文字“演练单路通话”→模拟通话页→挂断→普通确认卡，100/10费率可见 |
| 54 | 正式模型Controller切Seeduplex→关闭→任务恢复，历史仍100/10，无新确认命令；不代替模型选择器交互验收 |
| 55 | 独立新场景→扩展批量确认，联系人6/5/1统计及问题、默认四人 |
| 56 | 查看全部→第五人可见→收起，不重建任务 |
| 57 | 退出→任务恢复，原Pending身份及100/10保留，未重复提交 |
| 58 | 原输入框文字“确认”→原卡已确认→再次退出恢复；无第二张普通卡、无单路页面，命令仅两次 |

复用`PhoneAgentApp`正式页面/路由与工作台内存业务端口；显式MOCK、API地址为空。真实安全存储、旧计费源、系统拨号和PCM端口调用均禁止；短信与认证提交为0。文字由测试注入且主动收起键盘，不证明IME组合输入。内存快照仅证明同一场景历史恢复，不代替真实冷启动或生产旧数据迁移。

## 本机预检

`flutter test --no-pub test/confirmation_device_stage_test.dart test/shared_stage_command_test.dart`：9项通过，包含375×667/393×820的Android/iOS样式四项和5项安全附加驱动规则。首次小屏脚本未滚动至懒加载任务条目导致失败；增加有界`scrollUntilVisible`后四项均通过，没有放宽可命中/命令数/隔离断言。

`flutter analyze --no-pub`：4.6秒无问题；6个改动Dart文件格式无变动。OpenSpec30项通过。没有全量测试或新的Android构建/安装。

## 设备执行与通过条件

iPhone8/iOS16.7.16、Flutter3.32.0/Xcode15.2，复用已解锁screen。当前源码同步到既有非Git构建导出目录；不改变远端Git历史、不重新登录Apple ID。先保存原普通二进制，再显式构建/安装/启动测试目标；驱动只附加已有VM且强制保留App。独立`confirmation`目录保存53–58六图及result.json，不覆盖旧报告。

必须同时具备：构建及严格签名校验成功、驱动All tests passed/Leaving the application running、completed=true、六张有效图片逐张查看、禁止端口0调用。运行完成必须重新构建并安装当前普通`lib/main.dart`测试环境包，另查VM和普通页面。任一步失败不得宣称阶段完成，不使用卸载回退。

## 真机结果

2026-09-21 13:16 CST：签名构建66.4秒，安装启动45.7秒，设备阶段29秒通过；驱动输出`All tests passed`和`Leaving the application running`。[结果JSON](../../.local/confirmation-stage/ios/result.json)为completed=true、forbiddenNativeCalls=0；六图均750×1334，已逐张查看：

- [53普通卡](../../.local/confirmation-stage/ios/53-confirmation-single-billing.png)、[54换模型后恢复](../../.local/confirmation-stage/ios/54-confirmation-single-restored.png)：底部由Qwen切Seeduplex，历史确认仍100/10；恢复默认语音。
- [55联系人检查](../../.local/confirmation-stage/ios/55-confirmation-batch-audit.png)、[56展开第五人](../../.local/confirmation-stage/ios/56-confirmation-batch-expanded.png)：6/5/1统计、问题及第五人可见，收起入口可达。
- [57恢复待确认](../../.local/confirmation-stage/ios/57-confirmation-batch-restored.png)、[58确认后再恢复](../../.local/confirmation-stage/ios/58-confirmation-batch-confirmed.png)：状态从等待确认变已确认，费率与低余额提示保留，未出现重复卡或执行按钮。

长卡需要滚动，列表边缘内容的裁切是当前滚动位置，不代表整张卡可同时显示；底部模式/输入控件固定可达。黄色MOCK条占用高度，不作为正式视觉基准。共享流程通过不是像素校准或真实电话成功证明。

## 普通入口已恢复

同一ec643d5源码的普通`lib/main.dart`测试环境包已恢复：构建25.5秒、安装启动45.7秒，严格签名校验通过且新VM服务已发布；[USB整屏截图](../../.local/confirmation-stage/normal-restored.png)实际查看为普通登录页，无MOCK栏。iOS此前未登录，不称登录恢复或要求验证码。现有screen保留，普通窗口为`confirmation-normal-run`。

首次单独截图命令缺Flutter随附动态库路径而失败；仅为该命令补`DYLD_LIBRARY_PATH`后成功，不修改系统库、钥匙串或App。截图失败未导致重复构建/安装。

## 仍独立待验

- Android当前安装更新时间仍为2026-09-20 22:27:05，普通包手动恢复没有新确认；不绕过安装限制、不重发验证码。
- Android对应阶段、真实后台确认/计费、双端真实持久化和同签名升级仍待集中验收。
- 视觉精校后置；截图证明此设备上的内容/滚动/交互，不证明与设计逐像素相同。

实现和集中人工步骤见[确认卡专项](CONFIRMATION_BILLING_VALIDATION.md)、[主清单](MIGRATION_HANDOFF.md)。
