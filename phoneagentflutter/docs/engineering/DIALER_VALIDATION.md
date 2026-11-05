# 普通拨号页面与平台交接验证

## 范围与基线

2026-09-17，继续 contacts-migration 2.4 的普通拨号子项。Android v65 `4c781e3` 为行为基线；iOS `ddb996a` 的 tel 系统交接仅作平台参考。用户已允许静态 HTML/CSS/组件先行，视觉差异后续统一校准，见 `design/dialer/interaction-contract.md`。

本批不是完整拨号/实时翻译模块：历史、T9 提示、地区持久偏好、定位、翻译开关及跨境提示尚未完成；界面明确说明未接入能力，不显示伪造通话记录。后续设置批次已接通开发者串进程内解锁，实际子工具仍是隔离MOCK，见 SETTINGS_VALIDATION.md。

## 实现边界

| 能力 | 实现位置 | 行为 |
| --- | --- | --- |
| 四地区/搜索/号码/分机/显示 | `lib/features/dialer/domain/` | CN/JP/SG/US；联系人原始号码校验和国际区号解析；v65 加拿大限制；分机不自动 DTMF |
| 输入/删除/清空/地区/单飞/返回状态 | `presentation/controller/dialer_controller.dart`、`lib/app/dialer_providers.dart` | 数字最多14位；姓名随编辑清除；本登录会话保留输入；账号变化重置 |
| 拨号页/地区页/来源返回 | `presentation/pages/` | Flutter 共用；底栏与联系人同一路由；小屏可滚动；系统返回与关闭均 pop |
| 平台端口 | `data/system_dialer_channel.dart` | 原生仅接收 canonical number；Web unsupported，无 tel 跳转 |
| Android | `SystemDialerChannel.kt`、MainActivity 注册/清理 | ACTION_DIAL；不申请 CALL_PHONE、不直接呼叫 |
| iOS | `SystemDialerChannel.swift`、AppDelegate 注册 | canOpenURL + tel 系统交接；保留系统确认，不打印号码 |
| Web MOCK | 显式 debug 演练 ProviderScope | 内存端口；持续标识；合成联系人入口继续保持 MOCK；无 API/短信/真实电话 |

通道 `com.vvtech.phone_agent/system_dialer` 的 `open({number})` 返回 `opened/unsupported/invalid/failed`。`opened` 只代表操作系统接受交接，不表示接听、完成或计费。无 Agent/任务/通话 ID，因为普通系统拨号不创建 App 内 Agent 通话。日志不得写号码，当前通过返回码和 UI 定位交接错误。

## 自动验证

- 新增 34 项号码、Controller、通道、页面测试；全量 **414 项通过**，`flutter analyze` 无问题。
- 页面测试：320×568、390×844、430×932 的预填/姓名、地区拼音搜索/无结果/选择返回、键盘、删除、长按清空、MOCK 结果与关闭；普通不支持流程返回后输入保留。
- 浏览器主入口：保留现有登录，从首页打开拨号；普通 Web 明确不支持；独立 MOCK 地区搜索 xjp→新加坡→输入→模拟交接。实际截图确认三项 SVG 加载、矩形键盘/底部按钮可见。仅交互和渲染验证，不是视觉对齐验收。
- Web Debug 构建、测试 API Android Debug 构建通过。
- Mac 独立临时构建目录完成锁版本依赖解析与 `flutter build ios --debug --no-codesign --no-pub`，Xcode 构建通过。旧目录/dirty Pods/已解锁 screen 未动；未签名、未安装，不声称真机通过。
- 既有 Android 普通包覆盖安装限制未绕过，本批没有新真机安装或真实拨号。
- Web 验证脚本已纳入 dialer 测试，307 项共享回归、2 项 Chrome 流式网络测试、1 项 Node 代理测试全部通过。

## 集中人工验收（待执行）

前提：专用测试号码、测试环境 Flutter 包，先确认版本含本批变更；不要拨打真实业务联系人或紧急号码。

1. Android 底栏输入测试号码→拨号：打开系统电话并预填规范号码，不出现 CALL_PHONE 权限请求、不直接外呼；取消系统界面回 App，原输入保留。
2. iOS 同一路径：系统 tel 交接/确认正常；取消不显示“已接通/已完成”。没有电话能力的模拟器应提示无法打开，而不是模拟成功。
3. 从联系人分别使用中国手机、带前导零的座机、+1 美国、+65、+81：进入相同拨号页且地区/姓名/号码正确；更改数字清除姓名。加拿大/未支持区号明确拒绝，不保留上一个号码。
4. 连点拨号或交接期间删号：不重复提交；系统返回后可继续编辑。关闭→重开保留本次输入；切换账号后不能出现旧账号号码。
5. 拒绝/无法打开电话 App：显示错误并可重试，不写任务成功或通话记录。检查通道结果与时间，不在日志输出真实号码。
6. 后续统一视觉校准：国旗、国家按钮、间距/字体/阴影、短屏和系统安全区与设计校对；历史/翻译入口必须接入其实际状态后再验收完整拨号模块。
