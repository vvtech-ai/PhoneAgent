# 任务
- [x] 核对上下文及参考资源，用户确认计划
- [x] 原生资源及双端启动配置（机械资源批次、配置微批）
- [x] Flutter恢复画面及资源注册（3文件微批）
- [x] 定向测试、分析、OpenSpec及双端构建
- [ ] 双端设备冷启动、深色模式及错误重试视觉验收

验证：认证模块95项定向通过（含启动白底/居中/资源解码及恢复失败切换、既有双端登录恢复到首页/任务）；analyze无问题；Android Debug26.8秒、iOS Debug无签名Xcode38.1秒构建通过；三倍率资源字节与源一致，XML/diff检查通过；OpenSpec83项通过。未安装设备，未做全仓回归。

## Android尺寸修正续批
- [x] 核对AOSP缩放及设备API34系统图标尺寸
- [x] 将API31启动图标绝对尺寸改为比例留白
- [x] 构建APK、定向测试、设备资源渲染及OpenSpec校验
- [ ] 实际冷启动连续画面、深色模式和旧Android视觉验收

本轮验证结果：Android Debug构建12.5秒通过；启动页3项定向通过；OpenSpec83项通过；API34设备shell运行tool/LaunchIconProbe.java，使用生产APK实际Resources/InsetDrawable/BitmapDrawable，复现AOSP默认108dp预绘制→1.5前景扩展→192dp输出。旧LayerDrawable配置在440dpi下彩色图案286×262px，120dp参考161×147px；修正后162×148px。160/320/440/480dpi四组边界误差0–2px，通过<=3px取整容差。旧结构回归断言确认尺寸差异明显；探针模拟旧图层配置，不声称旧APK真实冷启动视频验收。

探针复用：使用Android34 android.jar以javac编译tool/LaunchIconProbe.java，再以SDK build-tools d8转换为classes.dex；adb push dex及构建APK到/data/local/tmp，以CLASSPATH=<dex> app_process /system/bin LaunchIconProbe <apk>运行。仅读取资源，不安装、不启动业务App；运行后删除这两个临时文件。本轮已清理。探针只验证静态资源与AOSP缩放，厂商实际动画、旧Android、深色模式连续截图仍待验。当前原生修复1文件+独立验证工具1文件，均500行以内。保留既有pubspec.lock及其他本地工作，无提交推送。

## 用户最新Android系统尺寸方案
- [x] 更新规格，覆盖Android120及比例留白方案
- [x] 系统图标及Android首帧生命周期宿主
- [x] 首帧生命周期测试、analyze、Android构建、OpenSpec检查
- [ ] 实际Android冷启动连续画面验收（不覆盖当前设备业务App）

最新方案验证：首帧宿主19项（6平台×3恢复结果及dispose释放）、启动页3项、认证到首页/任务连续流程2项，共24项定向通过；analyze4.8秒无问题；Android Debug构建7.1秒通过；不涉及iOS原生修改，不重打iOS。首次测试手动platformOverride仅在tearDown清理晚于Flutter不变量检查，核对日志后改为测试返回前清理；同时移除1个unused import，完整集合复验通过。没有业务逻辑失败。实际Android系统动画/深色模式/旧设备仍待验；未安装、未启动设备业务App，未提交推送。
