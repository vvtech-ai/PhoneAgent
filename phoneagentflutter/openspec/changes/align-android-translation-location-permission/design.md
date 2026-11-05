# Design
原生依据：DialerLocationPermissionGate.kt 的 entryAction、dialogKind、onConfirm；DialCountryLocationState.kt 的 requestLocation 与 settingsLauncher。

Android locationStatus 与 locate 对历史 translation_location_permission/requested 及 phone_agent_permission_requests 的位置项读取一致：任一粗/精度授权视为已授权；已申请且两项都不能再申请才blocked，其余denied。只改位置判断，其他权限继续原逻辑。

拨号controller增加显式Android策略，默认false保留iOS和独立调用方。Android首次进入只在未展示时弹REQUEST，后续不自动重复；主动开关按真实状态选择REQUEST/BLOCKED。确认前关闭Flutter业务框；settings阶段保留内部等待而不再显示额外弹窗，resumed只读复查后刷新位置/翻译开关。

位置controller通过App注入的只读权限回调获得Android策略，iOS无回调沿旧实现。位置卡片操作先检查权限，blocked直接打开设置；未授权可申请走现有locate系统申请；设置返回只读检查，已授权才自动定位，不重弹系统授权。App生命周期observer绑定卡片，代次/取消/退出隔离迟到结果。

保留NativeBusinessDialog及所有尺寸/颜色/字体；原生标题正文按钮已一致，只有Android settings额外文案消失。不改iOS文件、普通通话/联系人/麦克风/通话记录逻辑。

微批每次最多3个手写文件，需求/任务记录同步。验证：Kotlin策略JUnit、Flutter controller/port/UI/定位/provider/拨号返回及iOS回归，analyze、OpenSpec、Android Debug编译（在Flutter测试完成后串行进行，JDK17，固定工具链）。不安装或外呼；真机系统界面待验。
