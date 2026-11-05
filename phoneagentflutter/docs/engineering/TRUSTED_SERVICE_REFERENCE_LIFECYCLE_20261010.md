# 可信通信服务生命周期及UI对齐（2026-10-10）

## 参考及范围
用户批准严格遵循指定两端的业务/UI/交互。固定Android `0f8879e4baf1d56fe6d7f8f356101fdf61d602ed`、iOS `bb9ff34966f40a3c2794a9a8b8e935669a9faa12`；本轮使用的Application/AuthRuntime/SettingsHome/iOS Settings文件已与固定提交逐文件SHA比对一致。不修改参考工程。

## 行为对照
| 环节 | 参考 | Flutter本轮处理 |
|---|---|---|
| 设置入口 | 两端同标题/副标题及箭头 | 保持原设置卡片，不增中间route |
| Android初始化 | Application调用SDK.init | 保留幂等init，移除组件禁用/角色接管 |
| Android首次/后续 | openIncallUi / SettingActivity fallback | 沿用既有原SDK入口，权限、开关、子页由相同SDK承载 |
| Android组件 | AAR声明原接收器和原筛选服务 | 恢复合并声明、READ_PRECISE_PHONE_STATE声明，移除自建guarded adapters |
| Android重启 | SDK/系统保留开关与角色 | 不再启动disable/refresh固定关闭；restoring和restoreFailed不发送null清理 |
| iOS首次 | 全屏UINavigationController说明→push SDK→整体dismiss | 新TrustedCallerNativeIntroduction复用参考UIKit约束和三张同源PNG |
| iOS说明交互 | 2秒轮播/0.25淡入、开始/边缘60pt退出 | 同原生实现，开始时才创建SDK，不叠modal；SDK返回说明可再次开始 |
| iOS后续 | 原生KX设置全屏navigation | 保持NO intro/mobileNumber/jiguangRid空及delegate整体返回 |
| 退出/换账户 | 参考账号归属及旧页面失效 | surface代次和自有SIM journal清理保留，不写SDK全局开关/撤销系统权限 |

SDK开关真实读法由SettingActivity.updateUI字节码确认：READ_PHONE_STATE && canDrawOverlays && CALL_SCREENING roleHeld，并受core_function_on控制；先前“PreciseCallReceiver导致开关关闭”只是嫌疑，不是已证实的唯一原因。旧Flutter禁用筛选服务可能导致角色丢失，不能由新包静默重新授权，需SDK原权限UI让用户重新选择。恢复DEFAULT只处理旧Flutter曾写入的PreciseCallReceiver DISABLED一次；SDK AAR/runtime未发现PackageManager组件写入，不强制ENABLED、不写core_function_on。

## 崩溃证据与诊断
用户diagnostics-5共799条：12次open、7次正常结束、5次未结束；未结束不等于异常。13:29后prepare成功，未见原生崩溃事件。用户日志不纳入Git。只读检查当前连接手机：目标.dev未安装，crash缓冲为空；另有.test进程退出记录为SwipeUpClean/历史低内存，不能归到本次Flutter事件。未安装、启动或修改现有App/权限/登录。

NativeCrashRecorder在Flutter账号bind前将固定摘要写到unassigned，原read(scope)不会导入，故补readStartup/acknowledgeStartup，原账号分区read不改变；摘要仅UUID/时间/mainThread/固定kind，无账户/异常文本。新JVM测试确认可恢复、错误ID不删除、其他账号隔离。信号崩溃或具体异常栈仍需Android系统日志，源码修正不等于现场闪退根因已确认。

## 实际验证
- Flutter相关定向202项通过（可信/日志/设置Shell返回），非全量；新增恢复延迟/恢复失败不清理、确认退出清理。
- Android JVM61项、0失败/错误；旧接管策略3项随已废弃实现删除，新增启动摘要测试。
- 最终flutter analyze无问题，9.9秒；首次curly braces提示修正复验。
- Android Debug最终构建6秒通过；此前阶段构建19.7/16.3秒用于原生及接线验证，不重复计数。
- APK守卫确认运行时哈希、无重复类、四类各有定义、SDK组件启用及原服务角色permission、无旧adapter；临时篡改筛选服务disabled能被守卫拒绝。
- iOS Debug无签名最终12.4秒通过；首次及直接重试均缺新增类链接，检查Pods项目确认未收录后pod install --no-repo-update更新local spec，再构建成功。Podfile.lock仅local spec checksum变化。PNG和Pods编译/资源条目已核查。
- OpenSpec及diff交付前复核。未改工具链、密钥，保留外部pubspec.lock及并行提交。职责微批、资源复制/Pods机械批次独立；新原生说明187行、surface239行、runtime70行，无新增超500例外。

## 真实验收清单（待验）
在指定账户/设备环境与相同权限下对照原生与Flutter：首次/后续入口；开关开后重启/关后重启；SDK角色申请/拒绝/返回；后台进程恢复；SIM变化；退出/换账户；iOS轮播、开始push、SDK返回及边缘取消。Android旧包角色若已撤销，先通过SDK权限UI重新选择，不静默授权。需要复现时记录精确时间和系统异常堆栈。没有真实SDK认证、来电或外呼，本change未归档。
