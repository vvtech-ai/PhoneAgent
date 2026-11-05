# iOS 系统键盘与对话布局小阶段

基点fc0e679，加本批keyboard测试分组。正式lib与原生代码未改；不是全部页面或输入法验收。

## Preconditions

- iPhone8/iOS16.7.16，Flutter3.32.0、Xcode15.2；复用已解锁screen和Mac电脑名称连接，不重登Apple ID。
- 安卓本轮截图仍为独立诊断存储探针，安装更新时间09-20 22:27:05；不能检查普通App登录。已集中请求用户手动保留数据覆盖普通Dev，不绕过安装拒绝、不先发短信。
- 业务使用同一完整App的隔离内存端口；系统键盘和viewInsets保持真实。禁止真实安全存储、系统拨号、短信和认证提交。

## Build / Install

仅构建integration_test/keyboard_stage_test.dart；原普通二进制已在Mac本地另存，安装阶段不卸载。STAGE_GROUP=keyboard通过既有use-existing-app及keep-app-running附加；分组结果不覆盖原42张页面报告。结束恢复当前fc0e679正式lib/main.dart测试环境包，再核对实时VM与普通页面。

## User Actions / 自动路径

| 检查点 | 操作与断言 |
|---|---|
| 43 | 首页→统一页→文字→点击输入；实际键盘inset大于100逻辑像素，输入和发送按钮位于可用屏幕内且可命中 |
| 44 | 注入合成文字，键盘仍显示；输入与发送按钮仍可见，随后真实点击发送 |
| 45 | 仅一次合成Agent提交，主动收起键盘后inset归零；回复页面可继续操作 |
| 46 | 关闭→任务列表→恢复，保留原文字，命令计数仍为1，不重复提交 |

系统键盘显示是真实平台行为，文字由测试工具注入；不证明拼音候选、组合输入、系统发送键、语音输入法或真实键盘逐键输入。系统返回隐藏键盘仍留人工验证，不能用TextInput.hide等价代替。

## Expected Logs / Forbidden Logs

预期completed=true、四个completedSteps、forbiddenNativeCalls=0，keyboardMetrics记录前两图实际inset大于100、后两图为0。驱动必须All tests passed及Leaving the application running。

禁止布局溢出/未处理Flutter异常、目标App崩溃、测试未结束时连接丢失、键盘未出现时降级为模拟、真实SMS/认证/存储/拨号、安装失败后卸载。普通包恢复与测试成功分别取证。

## Pass Criteria / Failure Follow-up

本机两尺寸375×667/393×820及两平台样式共4项预检通过；仅这些预检显式注入300px键盘inset，不当作Android/iOS真实键盘。5项安全驱动测试、analyze4.4秒通过；未跑全量。

设备阶段已通过，下方列实际范围。失败先检查键盘是否被硬件键盘/系统层影响及对应页面边界，再决定修正，不重复旧42图。高保真视觉仍后置，VISUAL_CONTRACT_COMPONENT_COVERAGE_MISSING，不作像素对齐声明。

## 实际设备结果

2026-09-21 05:55 CST收集：[结果JSON](../../.local/keyboard-stage/ios/result.json)为completed=true、forbiddenNativeCalls=0，四图750×1334，前两图系统viewInsets=260逻辑像素，后两图=0。测试12秒、驱动All tests passed并保留App，测试构建36.5秒、严格签名校验通过。仅本组4图，不重跑旧42图；没有业务API、发码、登录提交、设备存储或音频。

- [43：输入框聚焦](../../.local/keyboard-stage/ios/43-conversation-system-keyboard.png)、[44：输入后可发送](../../.local/keyboard-stage/ios/44-keyboard-send-reachable.png)：输入框、按钮在键盘上方，短文字不异常折行。
- [45：收起后回复](../../.local/keyboard-stage/ios/45-keyboard-dismissed-reply.png)、[46：任务恢复](../../.local/keyboard-stage/ios/46-keyboard-task-restored.png)：原消息和两候选保留，dock回到底部，恢复默认语音模式；关闭和后续列表操作通过。
- 四图已逐张打开。截图只捕获应用窗口，没有捕获系统键盘按键层，前两图下方空色是截图范围限制，不能据此说手机键盘白屏，也不能声称已截图核验按键外观。真实键盘证据为未注入的系统inset与实际布局/命中断言。黄色MOCK栏占用了高度，不等于正式页面完整视觉基线。
- 本阶段未发现需要修改正式产品代码的布局问题。中文组合输入、系统返回/发送键、Android真机对应阶段仍集中待验。

## 普通入口恢复

当前fc0e679普通测试环境包构建22.6秒、严格签名校验通过，安装启动44.7秒；实时VM返回ios/main。[USB整屏截图](../../.local/keyboard-stage/normal-restored.png)已查看：普通登录页，无MOCK栏，原本未登录，不声称本轮恢复了iOS登录。未发送验证码、未清数据。

初次直接调用SDK内idevicescreenshot缺少动态库搜索路径，截图命令失败但App未受影响；改用Flutter自带screenshot命令注入正确运行环境后成功，无需安装或修改系统库。保留会话新普通窗口为keyboard-normal-run，后续可复用。
