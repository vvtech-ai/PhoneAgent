# 共享页面双端阶段验证（2026-09-20）

后续状态：安全驱动及页面扩大检查见[最新21截图扩展报告](EXTENDED_DEVICE_STAGE_20260920.md)。下文保留首次事故与当时11截图事实；“尚待实机证明”是该批当时状态，不覆盖新报告，也不表示当前真实登录已恢复。

## 结论与重要异常

基点6583d29加本批测试入口，Android/iOS同一连续MOCK流程通过，各11张截图已逐张查看。页面可运行不等于整迁移完成，也不等于真实接口/音频或设计高保真通过。

**本轮有验证工具事故，不能称为“无损阶段验收通过”**：首次直接运行flutter drive未带保留参数。Flutter3.32在测试结束调用DriverService.stop，停止并卸载App，导致Android Dev本机登录数据丢失。普通APK已恢复，但登录页需要重新登录；已向用户说明并在手机请求一次验证码，待输入。原安卓正式App未操作。iOS此前没有登录，本轮普通调试包已恢复并重新连上VM服务。

防重发措施不是备份APK：APK不包含账号数据。新增`tool/run_shared_stage.dart`只允许连接已运行测试App，并固定`--use-existing-app`和`--keep-app-running`。不让drive取得应用安装包或执行卸载清理；4条定向命令保护测试通过。此新入口尚未再做一次实机保留数据验证，不能把静态命令测试当真机证明。

## Preconditions

- 固定Flutter3.32/Dart3.8，两个平台测试同一`integration_test/shared_stage_test.dart`。
- Android明确选择OCE-AN10真机，不选同时在线的模拟器；仅com.vvtech.aiassistant.dev。
- iOS16.7.16真机，Xcode15.2，com.chaken.phoneagent.test；Mac通过原主机密钥校验及主机名连接，在已解锁screen操作。禁止重置钥匙串、重新登录AppleID或改全局Xcode配置来绕过问题。
- ShellPreviewPage直接复用PhoneAgentApp、正式路由/控制器，账号/历史/任务/模型/原音/录音外部端口为内存MOCK。appConfig无API地址。测试断言SMS请求和登录提交均为0；测试本身不读取真实凭据或设备音频。
- 顶部黄色MOCK/返回目录属于验收宿主，缩小业务可用高度；本图不能作为普通App全屏精确像素基线。

## Build / Install

| 平台 | 本次实际执行证据 | 恢复情况 |
|---|---|---|
| Android | Gradle20.0秒；安装7.6秒；主测试22秒通过（框架另计tearDownAll） | 普通APK install-r Success；随后冷启动为登录页，firstInstallTime重新变为16:56:07，登录丢失不能写“保留成功” |
| iOS | Xcode83.6秒；安装启动49.6秒；主测试约21秒通过 | 复用预先ditto备份的普通Runner.app，flutter run --use-application-binary安装启动46.4秒并出现VM Service；无额外重新编译 |

测试入口及driver的Windows/Mac SHA-256一致；正式lib本批无改动。原声页仍有“媒体尚未接入”旧迁移提示，属于后续文案清理项，不据这句话否认已经落地的媒体工厂。

### 后续安全执行方式

1. 构建测试入口，并检查包名、证书及设备ID。Android用明确`adb -s <id> install -r <apk>`；安装失败即停止，不卸载重试。不得把普通Dev包/数据当一次性测试产物。
2. 在显式保留数据安装之后启动测试App并获取本机VM Service地址。测试可使用独立测试包；若使用Dev，必须记录前后firstInstallTime及普通包恢复结果。
3. 在同一主机运行：

```text
dart run tool/run_shared_stage.dart android <device-id> <local-vm-service-url> <flutter-command>
dart run tool/run_shared_stage.dart ios <device-id> <local-vm-service-url> <flutter-command>
```

4. 新入口只附加，不构建、不安装、不卸载；URL仅使用127.0.0.1，不将调试认证路径写入文档。显式保持App运行；结束后保留数据覆盖普通包并冷启动检查。
5. 禁止直接复制旧`flutter drive --target ...`命令，不论测试通过还是失败都必须关注其清理行为。不要用`flutter install`安装失败自动卸载回退来处理证书问题。

## User Actions / 自动路径

| 截图编号 | 来源与操作 | 自动断言 |
|---|---|---|
| 01 / 02 | 目录→完整App→首页模型sheet→Seeduplex | 首页存在；选中DOUBAO写入合成模型仓库 |
| 03 / 04 | 订餐厅→默认语音→切文字→发送“帮我订餐厅” | 默认切文字入口存在；候选甲/乙渲染；仅1条Agent命令 |
| 05 / 06 | 关闭→任务列表→新会话→选甲 | sessionId对应新任务；恢复不重发；选择发送“第1个”，共2条命令 |
| 07 / 08 | 关闭→第一翻译历史→保存→取消 | 对应营业时间字幕；明确MOCK弹层；取消后不显示已保存 |
| 09 | 返回→第二翻译历史 | 酒店入住字幕，不包含第一条回复；显式关闭返回列表 |
| 10 / 11 | 设置→原音→打开→返回→重开 | 内存设置仍开启；返回设置再回目录可操作 |

输入使用WidgetTester，虽然设备日志观察到IME打开/关闭，不代表已验证不同系统键盘、联想候选和遮挡。音频按钮只检查UI，没有按住录音；本轮历史播放按钮未点击（Web已有播放/暂停验证），不将录音卡存在当播放成功。

## Expected Logs / Forbidden Logs

- 实际观察：两端`All tests passed`；result.json `completed=true`、`agentCommands=2`、12项completedSteps（11截图+返回目录）。Android驱动退出0；iOS返回原screen提示符。
- 安装确认脚本：本次未出现安装确认页，安装自动完成，因此没有调用。
- Android随后读取crash buffer无输出；测试输出无Flutter异常。不是完整日志归档或所有历史崩溃扫描。
- iOS恢复普通包有`fopen failed`/`Invalidating cache`/restoration marker警告，随后正常启动及VM连接；不冒充日志无警告。
- 失败条件：`FATAL EXCEPTION`、`ANR in`、`Lost connection to device`、布局异常、任务上下文串用、恢复重发、firstInstallTime变化、恢复后登录丢失。**本轮最后两项确实发生，须单独处理。**

## 截图与高信号检查

原图和机器结果在本地`.local/shared-stage/android/`与`.local/shared-stage/ios/`，不提交图片或凭据。Android图1080×2256（Flutter表面，不含完整系统导航），iOS图750×1334。打开对照：

- 文字候选：[Android](../../.local/shared-stage/android/04-text-options.png) / [iOS](../../.local/shared-stage/ios/04-text-options.png)
- 恢复选择：[Android](../../.local/shared-stage/android/06-restored-choice.png) / [iOS](../../.local/shared-stage/ios/06-restored-choice.png)
- 任务列表：[Android](../../.local/shared-stage/android/05-tasks.png) / [iOS](../../.local/shared-stage/ios/05-tasks.png)
- 翻译详情：[Android](../../.local/shared-stage/android/07-history-first.png) / [iOS](../../.local/shared-stage/ios/07-history-first.png)
- 保存弹层：[Android](../../.local/shared-stage/android/08-save-dialog.png) / [iOS](../../.local/shared-stage/ios/08-save-dialog.png)
- 设置：[Android](../../.local/shared-stage/android/10-settings.png) / [iOS](../../.local/shared-stage/ios/10-settings.png)

逐张检查11类状态：无黑白屏、横向溢出或主要控件文字裁断；标题、阶段条、语音/文字输入dock、蓝白字幕、录音栏及取消按钮可读。两端系统字号/字重、蓝色呈现、返回箭头和折行不同，属于后续统一视觉校准范围。iOS设置无OTA行、Android有，符合平台边界。

Web8122当前第一翻译详情实际截图与两端的标题/两条蓝白字幕/底部录音栏结构一致；Web视口高度不同，不据此作尺寸或像素一致声明。主页/任务列表的浮动底栏覆盖当前滚动区域末端，需滚动访问下方项目；本轮未完整检查所有末项点击，不把部分截图当全列表通过。

`VISUAL_CONTRACT_COMPONENT_COVERAGE_MISSING`：本轮没有重新采集完整设计运行态逐组件契约。按用户批准视觉后置；不评分为高保真通过。设计目录历史状态图中的voice/audio-deferred等只作源追溯，以当前正式代码及批准基线为准。

## Pass Criteria / Failure Follow-up

- 已通过：本表连续共享交互、上下文隔离、显式返回/取消、内存偏好保持；关键截图检查。
- 未通过：Android Dev登录保留，等待一次验证码恢复；不能勾选无损阶段验收。
- 未验：全部22目录/正式页面状态、系统返回/侧滑、所有键盘、真实ASR/TTS/翻译/外呼/身份SDK、后端持久化、正式OTA升级；仍按MIGRATION_CURRENT_STATUS和各专项人工清单推进。
- 不为此重新跑几千条全量测试；本批新增1条双端连续测试和4条命令安全测试、analyze/OpenSpec。
