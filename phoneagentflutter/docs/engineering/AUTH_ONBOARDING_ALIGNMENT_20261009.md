# 登录、邀请与初始化参照对齐

2026-10-09用户逐项批注、澄清并确认修改计划执行。专项为[auth-onboarding-reference-alignment](../../openspec/changes/auth-onboarding-reference-alignment/proposal.md)，尚未用户验收，不归档。

## 结果与依据

- 品牌PhoneAgent保持；两端登录均强制同意协议，未同意用共用showNativeNotice提示。登录业务错误、验证码成功及协议打开失败复用共用Toast。
- 标准化手机号变化清验证码/challenge，同一号码不同输入格式不清；冷却绑定发送号码。iOS手机号Number、Android Phone，验证码Number、邀请码Text。
- 邀请码请求忙时按钮及系统返回均禁止；请求完成才可返回，旧会话结果仍有代际保护。
- 原生PendingInviteStore/AIPendingInviteStore把邀请码与注册requestKey/requestId持久化，短信/challenge不落盘。其目的为跨外链、短信和注册的自动带码、恢复和幂等；欢迎入口仅控制本次展示，返回/继续只消费入口，不清码。Flutter手工编辑排队持久化，保留未完成草稿；只有合法格式才提交REFERRAL，编辑变化清旧请求ID，同提交重试复用。存储失败阻止带未保存码注册；成功登录沿用EntryController清理。
- 欢迎页使用原生共同浅灰底、20边距、90×88品牌、26标题、34积分、32邀请码及46按钮。前台刷新；iOS原生14项业务错误白名单允许继续登录且不虚构奖励，网络/未知错误主按钮重新加载。按钮/系统返回均保留码。
- Android原生V61InitializationOverlay在调用onSelectCallProvider后立即step=3，不等待切换响应；Flutter仍按已确认两步，在完成时异步发模型切换并独立保存身份/跳过状态。身份保存失败留页重试；模型失败只Toast。账号级协调器承接离页后的反馈/真实模型刷新，切换账号时销毁旧协调器。

## 微批记录

1. AuthPage/AuthRoute/AuthController登录三源文件。
2. AuthController/PendingInviteController草稿状态及相关测试。
3. 欢迎Controller/Page/Content三源文件。
4. 初始化Controller/ModelSwitchController/providers三源文件。
5. AuthRoute/初始化演练接线；测试按最多三文件微批更新。
6. 独立integration target与共享attach-only命令/driver三文件；无平台工程/依赖源码修改，所有手写文件小于500行。

## 实际验证

- auth、invite、initialization及Shell初始化连续流程183项定向通过；之后手机号、生命周期、模型协调及共享驱动21项定向通过，有重叠不累加；邀请草稿快速编辑/存储失败另2项通过。未运行整App全量。
- flutter analyze无问题；openspec validate --all为53通过；git diff --check通过。
- Android独立com.vvtech.aiassistant.ui.authonboarding测试APK构建成功；仅emulator-5554安装-r，普通包/真机未操作，结束保留安装。
- iOS仅PhoneAgent-UI-20261006模拟器独立com.vvtech.phoneagent.ui.authonboarding宿主，固定3.32引擎+正式Flutter页面及integration_test截图插件，无业务SDK注册。
- 双端attach-only共享driver使用--use-existing-app和--keep-app-running，均exit0；各10张PNG。结果位于ignored的.local/shared-stage/auth-onboarding/{android,ios}/result.json，字段声明真实短信/认证/外呼均0。
- 实际运行：协议Toast→勾选→换号清验证码→邀请码输入/返回；过期邀请继续且保留ABCD；身份填写/返回/模型完成→首页；跳过/返回/模型完成→首页。查看了两端协议Toast、过期欢迎和模型截图。Android320×640短屏模型内容可滚动，选择后截图存在滚动位置，不能认定整页静态像素一致。

## 故障与恢复

工具PATH缺固定Flutter/OpenSpec，核实缓存后使用绝对路径；新增生命周期测试误await void以及未监听autoDispose控制器导致测试失败，修复夹具后通过。原有9项断言与新协议/禁止返回/异步模型/欢迎文案不符，更新并复验。iOS控制台未打印VM服务地址，重新读取实际进程、端口及simulator统一日志发现服务后attach成功，无卸载/清数据或业务重放。

## 待验边界

真实验证码/认证/服务端身份模型保存、真实外链系统唤起、双端真机键盘、原生与Flutter同条件整页视觉配对及用户验收仍待验。运行图含DEBUG或合成演练标识，不能当作生产包/真实业务验收。欢迎奖励正常态及加载/网络错误有定向组件验证，本次设备截图为过期欢迎态；未宣称所有状态设备验收。
