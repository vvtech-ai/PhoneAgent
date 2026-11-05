# 拨号权限顺序与开发者重置

## 范围与依据

基于 Android v65 固定提交 `4c781e3ccfcd148c1f205921534907ee0c5aa864` 的 `DialerLocationPermissionGate.kt`、`DialerCallLogPermissionGate.kt`、`DialerPermissionSequencePolicy.kt`、`AssistantDialerPreferenceState.kt` 与 `AssistantRootHostArgsShell.kt`。不引入历史独立 Calls 页面。iOS 不读取/申请系统通话记录；旧 iOS 开发者重置只有提示，不把空实现迁入。

开发者“重置所有权限”的有效行为是重置 App 的位置提示/申请标记并打开已选翻译的拨号页，**不是撤销 OS 授权，也不清位置缓存或通话历史**。旧麦克风/联系人/存储/电话模拟布尔值不作为 Flutter 系统事实；Flutter 使用已有真实权限端口，文件选择器不需要伪造存储授权。位置和 CallLog 提示标记为进程/登录内存，不增加永久提示抑制。

## 共用实现与平台边界

| 层 | 实现位置 | 行为 |
| --- | --- | --- |
| Domain | `dialer/domain/dial_permission.dart` | 权限事实、提示标记、阶段与端口 |
| Controller | `dialer/presentation/controller/dial_permission_controller.dart` | 进入/切换、解释/请求/设置返回、拒绝降级、顺序和晚到隔离 |
| 页面 | `dial_permission_host.dart`、`dial_permission_dialog.dart` | 普通/翻译两入口共用；Navigator 弹窗覆盖拨号配置，离页只移除自己的弹窗 |
| 开发者 | `settings/presentation/widgets/developer_permission_reset.dart` | 配置就绪后重置位置提示、打开正式翻译页；失败不假报成功 |
| Dart 平台适配 | `dialer/data/device_dial_permission_port.dart` | 调用已有权限通道；Web 不调用原生端口 |
| Android | `PermissionChannel.kt` | 只读位置状态；申请 coarse/fine 与 READ_CALL_LOG，复用原生单飞请求 |
| iOS | `PermissionChannel.swift` | CoreLocation 授权事实；无系统 CallLog 请求 |

顺序：进入拨号 → 检查位置 → 必要时说明/授权 → 位置决策结束 → Android 检查/必要时申请 CallLog → 可继续操作。已授权则异步刷新可信地区；缓存加载中的刷新会等待，不丢失。用户拒绝/取消位置后关闭翻译但允许普通拨号；再次打开翻译可重新申请，永久拒绝则引导系统设置，恢复前重查 OS。不得因设置返回自动拨号。

权限状态读取有 3 秒边界，系统申请有 90 秒边界；超时/失败显式可重试或取消。CallLog 失败不阻断普通拨号。界面存在期间只维持相关 provider 生命周期；控制器销毁或提示世代变更后，不应用旧授权结果。

## Web 隔离演练

运行 `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8107 -t tool/previews/dial_permission_preview.dart`，或开发者页“打开拨号权限演练（MOCK）”。

- 复用正式 Host、Controller、权限说明弹窗与拨号前配置组件，仅系统权限、位置、最近记录来源换为合成内存端口。
- 三种场景：Android 拒绝后设置开启、Android 直接授权、iOS 直接授权。
- 模拟设置按钮仅更改内存事实；不存在 OS 设置跳转、真实定位、通话、权限授予或账号 API。
- Web 普通业务页不运行手机系统权限引导；该页面专门验证共用权限流程，不冒充 Web 已验证 Android/iOS 系统弹窗。
- 翻译准入演练使用独立“已处理位置说明”的合成标记，避免新增权限端口落到真实设备；准入与权限流程分别覆盖。

## 自动验证

新增25项控制器、平台通道、页面、正式重置和缓存等待回归。覆盖重复操作、拒绝/取消、设置返回、失败重试意图、iOS 无 CallLog、账号/重置世代、320/390/430 宽嵌套弹层、旧页面移除不误关新页、位置缓存加载竞争。

- `flutter analyze`：无问题；`flutter test`：1732项全量通过。
- `dart format --output=none --set-exit-if-changed lib test tool`：798文件无修改；OpenSpec19项通过。
- Web dev构建、Android Debug构建、Mac scratch目录iOS Debug无签名构建通过。构建不是安装/真机授权证据。
- 8107浏览器：Android拒绝后普通模式，配置上方出现设置引导，模拟设置返回后翻译打开；重置不撤销合成授权/重复请求CallLog。iOS授权后trace只有location:check/request，没有CallLog。
- Web构建有既有Cupertino字体候选未配置提示；未影响构建，本批不作像素级验收或宣布视觉差异清零。

## 集中人工验收（尚未执行）

1. Android 新进入普通/翻译拨号：首次先出现位置说明，拒绝后才允许 CallLog 系统提示；普通输入/选择历史继续可用，不自动打电话。
2. 允许位置后检查系统取样与地区更新；慢缓存加载不能吞掉刷新。许可不等于定位服务可用，失败应沿地区组件显示，不能伪造国家。
3. 拒绝后开启翻译、永久拒绝后设置跳转；切后台/回来、授权或仍拒绝，分别检查开关和页面。拨号配置弹层必须位于权限说明下面。
4. 开发者重置：系统已授权时不伪造再次授权；未授权时恢复位置说明；不再次清除 CallLog 申请标记、不清联系人/历史/缓存。
5. iOS 允许/拒绝/设置返回同样验证，但绝不出现系统通话记录授权；仅展示 App 内记录。
6. 系统弹窗期间退出页面/账号切换，晚到回调不更改新页；超时后显式重试，不自动重放拨号。

本批没有重新安装、真实授权或位置采集；Android/iOS 编译和 Web MOCK 不能替代以上真机结果。整体迁移、真实翻译媒体、OTA 同签名旧数据升级及统一视觉校准仍未完成。
