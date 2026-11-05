## 实施
- [x] 1 参考UI/业务核对及差异矩阵、规格校验。
- [x] 2 Android恢复原SDK组件，移除强制启停并验证重启/退出规则。
- [x] 3 iOS原生首次说明和SDK导航，保持参考UI及交互。
- [x] 4 启动匿名崩溃摘要安全导入、定向验证。
- [x] 5 定向/JVM/analyze/OpenSpec/双端构建/APK检查，中文提交推送。
- [ ] 6 真机同条件重启/开关/系统权限/返回及崩溃证据验收，未完成不归档。

验证：202定向、61 JVM、analyze、Android Debug/iOS无签名Debug、APK类定义及原SDK manifest守卫通过；真实任务6待验，详见docs/engineering/TRUSTED_SERVICE_REFERENCE_LIFECYCLE_20261010.md。
