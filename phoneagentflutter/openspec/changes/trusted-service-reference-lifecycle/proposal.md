## Why
用户批准严格按Android/iOS参考同步可信服务业务、UI和交互，反馈开启后重启退出且开关关闭。diagnostics-5无原生异常栈，不认定崩溃根因。当前Flutter主动禁用SDK组件并使用自建筛选服务，与参考有实质差异。
## What Changes
- Android恢复原SDK组件和系统角色归属，移除Flutter启停覆盖；保留平台桥账户/号码隔离。
- iOS首次说明由原生全屏导航承载并push SDK，保持参考布局/轮播/边缘退出/整体dismiss。
- 冷启动匿名崩溃摘要纳入后续导入，仍只固定类别，不读取身份/异常文本。
- 按源码/测试/设备分层记录，真实SDK授权和来电不自动执行。
## Impact
Android SDK组件、iOS设置流程、诊断存储，替代旧incoming-call-native-parity的组件接管策略；固定工具链及配置。codex/dev_zys中文提交推送，外部pubspec.lock保留。
