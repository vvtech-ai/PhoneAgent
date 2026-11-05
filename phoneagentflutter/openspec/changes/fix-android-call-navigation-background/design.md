## 事实与边界
基线test_v1.8.0_fix@f285726b，起始存在主线程AI说明改动，修改前保存两页面源快照至本次/tmp目录以便核对。本机连接Android API34；尚无本轮修改的安装包，不将连接设备当作新代码实机验收。
当前NativeSystemChrome.dark已声明透明导航栏，工程无SystemUiMode调用。仅body内深色与白色宿主不能保证非edge-to-edge系统栏区域覆盖。两类页面共用Android展示包装，临时使用Flutter既有SystemChrome edgeToEdge API，无原生/插件/全局主题变化。
## 所有权
仅Android非Web生效。任务通话原为覆盖层，Android包装提供本地深色Scaffold；翻译页保留其独立Scaffold并仅Android设置底色。背景填充导航栏下，原SafeArea和20dp说明底距保持，不手写系统栏高度。
共享租约串行应用系统栏模式，晚到release不覆盖当前owner；PageRouteVisibilityObserver区分业务页面与PopupRoute，弹层不释放，覆盖业务页释放，返回重获。离开最后通话恢复既有所有系统栏可见模式；Android15+强制edge-to-edge仍服从系统策略。工程无其他mode调用，后续新增全局mode策略时须统一所有权，不隐式覆盖。
## 验证
先新增回归证明旧页底层未显式深色，再按至多3源码微批实现。覆盖Android/iOS、安全区0/24/48、短屏/大字、控制回调、弹层/其他页覆盖与返回、多owner快速交错，检查透明/图标样式及模式释放。analyze+两类页面/AI说明定向和连续导航冒烟；无新原生/插件配置，不额外打包安装。设备实测待同版本安装后的手势/三键验证。适用Superpowers技能目录未检索到systematic-debugging/verification-before-completion，不声称已加载，按本仓完整规则执行重现/定向回归。
