## 方案
使用已注册FlutterPlugin的application:didFinishLaunchingWithOptions:启动回调调用注册协调器，无需新增AppDelegate公开桥接接口。启动入口主线程、进程内防重；调用UNUserNotificationCenter requestAuthorization(alert|badge|sound)，完成后主线程重新读settings，不以回调布尔值替代系统事实。前台与账号同步仍只读权限，不重复主动申请。
授权允许时，环境配置与SDK构建环境一致即可注册APNs，无需owner或SDK链接；token仅内存。实际SDK初始化和服务端绑定仍由既有driver按owner、权限、token控制。退出/切账号/迟到成功补偿规则不变。
## 验证
原生绑定状态和driver定向覆盖token先到、登录先到、退出迟到token、切账号补解绑；Flutter可信模块定向与analyze，iOS无签名Debug编译。真实首次授权弹窗、拒绝后重启、设置返回、APNs及服务端绑定需设备验收，本轮不自动操作用户设备。
## 微批
第一批3源码文件：注册协调器.h/.m及插件.m；第二批原生测试；文档单独批次。无依赖/平台签名配置变化，Android不重建。
