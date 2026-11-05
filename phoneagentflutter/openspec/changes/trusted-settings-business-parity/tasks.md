## 实施与验收
- [x] 1 固定参考复核、双端行为矩阵及OpenSpec校验。
- [x] 2 串行账户同步和入口确认，失败/旧结果/退出定向。
- [x] 3 Android应用初始化、首次记录及SIM非阻塞/清理保护，JVM专项。
- [x] 4 iOS账号说明记录、开始到SDK及整体退出，覆盖/取消/账号切换。
- [x] 5 白名单阶段诊断、错误码保留/文案/导出和定向。
- [x] 6 定向/analyze/OpenSpec/双端构建，更新报告和中文提交推送。
- [ ] 7 双端真实SDK配对验收（设备/账号/环境/次数明确后），未验收不归档。

验证记录：204定向通过，流程21复验，analyze无问题，OpenSpec65通过；Android JVM/Debug APK及iOS Debug无签名构建通过。中文提交推送在交付前核验；真实设备任务7待验。

- [x] 8 复制并接入参考运行时、初始化错误分类及APK防回归。
- [x] 9 Android构建/JVM/定向/analyze/OpenSpec并中文提交推送。

运行时修复：旧APK检查RED，新APK四类定义/哈希/无重复GREEN；134定向/analyze/Android JVM/Debug APK通过。设备复测任务7待验。
