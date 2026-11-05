# 登录协议反馈与通用Toast（2026-10-09）

## 实现

参照iOS `AILoginViewController.m` 的 `requireLoginAgreement` / `updateLoginAgreementAppearance`：未勾选点击获取验证码或登录时阻止请求，原有协议普通文字及未选框边变为E5484D，链接保留蓝色；整个协议区按0/-3/3/0横向移动，240ms，可重复触发。勾选后恢复普通样式；减少动态效果时不抖动。没有增加额外行内错误文案。

共用 `showNativeNotice` 在Overlay中使用 `max(viewInsets.bottom, viewPadding.bottom)`，再保留28逻辑像素间距。键盘高度变化/收起时跟随；1800ms消失、替换、点击穿透和清理保持原行为，所有调用方共用。

## 验证

- 44项定向测试通过：协议双端样式/动画/恢复/减少动态效果、Toast双端键盘变化/安全区/时限、登录及直接调用方。
- flutter analyze无问题；OpenSpec 59项通过；diff检查通过。未跑全量回归，未改依赖/平台工程。
- iOS独立模拟器fixture运行通过，3张Flutter表面截图保存于 `.local/shared-stage/agreement-feedback/ios/`。真实键盘高度大于零、Toast位于键盘上方由运行断言验证；Flutter表面截图不包含系统键盘。首轮末尾语义句柄清理断言失败，状态核对后重启独立fixture重试通过，未屏蔽断言。
- Android独立AVD及独立applicationId构建安装完成；两轮均在真实键盘高度断言失败（viewInsets.bottom=0），未到Toast断言；日志在 `.local/agreement-feedback/android-driver{,-retry}.log`，Android实际键盘场景未验收。
- 全部业务回调为内存计数器；没有短信、认证或真实服务请求，没有触及普通App或真机数据。

## 工具恢复

Android avdmanager首次JDK11被拒，核对后改用已有Android Studio JBR。构建输出曾被同时工作的主线程覆盖，安装前applicationId守卫阻止误装；改用忽略目录独立构建输出。启动Activity首次名称不符，查询系统实际解析组件后启动成功。Android首轮软键盘高度为零，检查输入法/窗口后仅重启自身fixture重试。

用户视觉及双端真机验收仍待进行；OpenSpec保持active，不归档。

## 共用Toast原生样式追加执行

用户确认后对齐UIViewController+AICommon.m的ai_bottomToast：白色98%、灰度0.82边框1、圆角10、黑色12%阴影/半径8/偏移(0,3)，深色15/Semibold/居中文字、上下10左右18，左右屏幕至少32。无键盘底部距安全区96，有键盘按max(safeBottom+96, keyboardBottom+16)定位，替代前述28规则。180ms淡入后停留，再180ms淡出；默认停留1.8秒，登录协议2秒。仅两业务源文件修改；原协议文字和抖动保持。

最终45项定向通过（包括样式与淡入/停留/淡出时序），analyze无问题。旧测试的即时消失断言更新为包含动画阶段；180ms浮点边界使用181ms观察完成。截图发现Overlay文字继承调试下划线，设置独立TextStyle后重跑定向及运行验证。

双端隔离driver均exit0，各保存3图于.local/shared-stage/agreement-feedback/{ios,android}/，截图已检查。Android先前键盘缺口已通过输入框聚焦完成后再请求软键盘解决；实测viewInsets>0及Toast高于keyboardTop-16，业务请求计数为0。启动时进程尚未出现，核对pidof后增加有限等待，未清数据/卸载。iOS/Android测试均仅操作专项独立App与模拟器，不触及真机账号。

未进行同条件原生整页像素比对和真机验收；平台字体/阴影渲染差异仍需用户视觉验收。没有依赖或平台工程变更，未执行全量回归。
