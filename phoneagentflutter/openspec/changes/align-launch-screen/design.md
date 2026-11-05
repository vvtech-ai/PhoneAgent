# 设计

参考AIAssistant/iOS的LaunchScreen.storyboard及launch_wave.imageset，使用其Contents.json指定的JPG三倍率。iOS复用原始Storyboard和图片组；Flutter注册同源多倍率资源，以全屏白底居中120显示；Android旧版居中密度图片，API31起设置白色windowSplashScreenBackground及无背景图标按比例留白的288基准画布中的120图案，避免系统裁剪。深色模式同样白底。系统栏透明、深色图标，Flutter以全屏中心布局衔接；系统动画及厂商行为保留。

不修改会话恢复逻辑、不请求额外接口、不添加计时器，不隐藏恢复失败重试。手写实现每批最多3文件；资源复制为机械批次。保留当前Mac分支，不提交推送、不安装设备。定向认证测试、analyze、双端构建和OpenSpec校验；设备视觉待验。

## Android尺寸跳变修正（2026-10-11）
用户确认后实施。AOSP SplashscreenContentDrawer将自定义图标以默认108dp预绘制、放大到无背景192dp；SplashscreenIconDrawableFactory对普通drawable再扩展前景1.5倍，等效288基准画布。旧LayerDrawable内部120dp绝对尺寸不随预绘制bounds缩小，随后被整体放大，这是本次尺寸跳变原因。改用InsetDrawable每边29.166667%比例留白，内部bitmap填满剩余5/12；等效288×5/12=120。保留Flutter120及旧Android原120布局，不更改会话、iOS或延时。系统整数像素取整可有约1–2像素误差，实际冷启动动画仍待视觉验收。
来源：https://github.com/aosp-mirror/platform_frameworks_base/blob/android-14.0.0_r1/libs/WindowManager/Shell/src/com/android/wm/shell/startingsurface/SplashscreenIconDrawableFactory.java 。连接设备API34，系统资源查询icon_size160dp/default108dp；不安装覆盖现有App，用shell临时资源渲染器验证生产APK drawable在系统预绘制及缩放下的图案边界，避免打断主线程运行。

本轮验证结果：Android Debug构建12.5秒通过；启动页3项定向通过；OpenSpec83项通过；API34设备shell运行tool/LaunchIconProbe.java，使用生产APK实际Resources/InsetDrawable/BitmapDrawable，复现AOSP默认108dp预绘制→1.5前景扩展→192dp输出。旧LayerDrawable配置在440dpi下彩色图案286×262px，120dp参考161×147px；修正后162×148px。160/320/440/480dpi四组边界误差0–2px，通过<=3px取整容差。旧结构回归断言确认尺寸差异明显；探针模拟旧图层配置，不声称旧APK真实冷启动视频验收。

探针复用：使用Android34 android.jar以javac编译tool/LaunchIconProbe.java，再以SDK build-tools d8转换为classes.dex；adb push dex及构建APK到/data/local/tmp，以CLASSPATH=<dex> app_process /system/bin LaunchIconProbe <apk>运行。仅读取资源，不安装、不启动业务App；运行后删除这两个临时文件。本轮已清理。探针只验证静态资源与AOSP缩放，厂商实际动画、旧Android、深色模式连续截图仍待验。当前原生修复1文件+独立验证工具1文件，均500行以内。保留既有pubspec.lock及其他本地工作，无提交推送。

## 用户最新决策：Android以系统为准
用户明确Android不遵循120×120，覆盖上方Android比例尺寸对齐方案。API31图标改为普通同源bitmap，由系统决定尺寸；Android首次会话恢复时通过Flutter deferFirstFrame保留原生启动画面，状态不再restoring后在目标页面布局完成时allowFirstFrame，直接进入首页/登录/错误重试。无固定延时；仅Android非Web，iOS和Web不延迟首帧；dispose平衡释放，不在后续登录/恢复时再次hold。不等待网络/首页内容。旧Android保留原生背景，直到实际目标首帧。
验证转为首帧生命周期测试：Android恢复期间不送帧，成功/失败释放，dispose释放，iOS不hold；删除已被新决策替代的尺寸探针，不覆盖设备App。用户最新授权覆盖旧设计的系统尺寸要求，不改变分支/提交边界。

最新方案验证：首帧宿主19项（6平台×3恢复结果及dispose释放）、启动页3项、认证到首页/任务连续流程2项，共24项定向通过；analyze4.8秒无问题；Android Debug构建7.1秒通过；不涉及iOS原生修改，不重打iOS。首次测试手动platformOverride仅在tearDown清理晚于Flutter不变量检查，核对日志后改为测试返回前清理；同时移除1个unused import，完整集合复验通过。没有业务逻辑失败。实际Android系统动画/深色模式/旧设备仍待验；未安装、未启动设备业务App，未提交推送。
