# 任务

- [x] 只读核对 dev/test 的 lzy URL、WAV 内容及 App 旧名单门禁。
- [x] 增加已有 URL 的非本地音色按钮回归，旧实现下 Android/iOS 均因按钮禁用失败，修正后通过。
- [x] 五个直接相关测试文件共 16 项通过；flutter analyze 无问题；本 change 严格校验通过。全仓 OpenSpec 为 150 通过、3 个既有 change 失败（incremental-validation-policy、login-presentation、native-feature-parity-audit 均因 MODIFIED 遗漏基线场景），未修改无关规格。
- [ ] 更新安装包并在真机验收按钮与播放；本次源码验证不代替设备验收。
- [x] 2026-10-16智能合并保留远端动态试听扩展：有URL直接下载，无URL但有效ID也允许试听；修正两端旧测试门禁，4项音色UI回归通过。合并总体验证见align-native-orchestration-presentation。
