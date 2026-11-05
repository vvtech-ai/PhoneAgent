# 设计
根层新增无业务权限的展示host，按当前账号及登录代次协调强制失效的加载。businessBlocked且带invalidationReason表示强制退出；清理运行中覆盖公共不透明背景和NativeLoadingOverlay，signedOut后等待登录首帧才撤去。失败停止加载、展示原重试；换账号清除旧过渡。主动注销原独立owner保持不变，普通退出不新增遮罩。

UI执行D01-D06适用范围和C01/C16：复用公共浅色背景与既有加载组件，无新增标题/按钮/卡片参数，不改共享默认值，TooltipVisibility保持。展示层不访问网络/存储，不保留旧widget/验证码/凭证。SessionNavigationHost继续真实卸载并帧确认，调用方只增加不透明占位。

验证：生产PhoneAgentApp/GoRouter双平台逐帧慢存储、慢草稿、失败重试、重复失效及账号切换；回归主动注销和普通退出。无平台变更不重打包；真实Android/iOS画面单列。关联ENTRY-03/08、DEVICE-01，保留原任务/音频/权限隔离。

## 2026-11-02 当前页面画面补充（用户批准）
强制失效前在根RepaintBoundary取得当前Flutter画面，仅内存保留一张，按最多200万像素限制尺寸；采集不等待权限/存储/页面释放。监听SessionController状态时在旧导航重建前发起采集。过渡期间用RawImage静态画面加既有loading，实际旧业务页照常卸载。采集失败/未绘制/平台视图或Texture无法保证捕获时保留不透明安全底层。超时250ms放弃采集结果，不延迟退出；晚到图像立即dispose。清理失败、登录首帧、新账号或host销毁释放画面。主动注销独立验证码页过渡保持不变。
