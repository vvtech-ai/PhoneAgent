## 原生证据与共同取舍

AndroidTranslationCallPreflightDialog仅定义未调用，正式OverlayHost使用TranslationCallScreen；iOSRuntime固定ai_buildLayout包含号码/phase/计时/字幕/controls，国内onPreflightAccepted才push且resumeAfterPresentation才创建session。两端Flutter统一国内页面时机，保留正在检测通话环境/挂断等原生文案。

## 实施

微批1：page/route/独立widget专项最多3文件；不隐藏身份或控制，短屏和大字将控制区域可滚动，原生没有白卡和取消通话准备入口。微批2：coordinator纯Dart增加幂等prepare冻结配置与积分；start消费prepare后才启动模型/租约/SIP，close/账号切换拒绝迟到，错误仍清理。微批3：factory通过已有OS网络端口检查可用，unknown限时复读（最多10秒）且失败使用原生网络超时提示；实例网络source可注入，controller在预检期间由factory持有并清理，不产生通话归档。微批4：拨号页失效创建即时释放、失败使用原生文案，并修正直接调用方自动断言。

## 验证

双平台320×480普通/2倍字号无白卡、状态/号码/00:00与底部挂断可达；国内prepare不启动模型/租约/电话、重复start不重复积分、拒绝/取消/迟到清理、正式route正常结束与海外顺序；analyze和翻译/直接Shell定向。隔离UI截图验证可用宿主，不安装普通App或真实调用服务。未完成实际证据保持待验，不归档。


## 准备阶段控制

原生预检仍可选择静音/扬声器/拨号盘。国内已完成积分准入后保留desired控制，媒体启动前应用；海外在media未就绪时只记录desired设置，媒体就绪后应用成功才拨打对方。按键盘可展示，DTMF仍需真实能力及媒体准入，不因显示就发送。最多16次代际同步后仍变化则准备失败，不无限循环；不新增服务请求。三个生产源码微批及独立专项。

隔离截图通过可选UI_PREFLIGHT_CAPTURE与显式本机字体生成，默认自动测试不依赖本机字体、不写截图。截图无设备安全区/状态栏，不替代双端真机或固定原生截图配对；为避免干扰主任务未切换其模拟器和Shell宿主。
