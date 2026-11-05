# 日常定向验证

`scripts/verify.ps1`不再默认跑全量或构建APK。没有选择测试范围会在启动工具前报错，避免误触几千条测试。

```powershell
# 日常：填写受影响测试，可传文件或test内子目录。
./scripts/verify.ps1 -TestPaths test/shell_workbench_test.dart,test/shell_conversation_ports_test.dart

# 先只看计划，不运行Flutter、OpenSpec、构建或网络工具。
./scripts/verify.ps1 -TestPaths test/features/translation -PlanOnly

# 只有里程碑/交付/无法界定公共影响时才全量，必须写理由。
./scripts/verify.ps1 -FullRegression -Reason '阶段交付前整合回归'

# 只有平台/插件/依赖/构建变化或阶段产物需要时附加。
./scripts/verify.ps1 -TestPaths test/features/translation -AndroidBuild
```

- 定向路径必须是test内实际存在的测试文件或含测试的子目录；test根目录、缺失路径、范围冲突均拒绝。
- 通用检查仍包含固定Flutter3.32、OpenSpec、无写入格式检查和analyze；测试只执行给出的路径，不自动扩大到全库。跨页改动请主动附加对应主流程测试。
- 默认不执行pub get；依赖变更需要`-RefreshDependencies`时仍使用`--enforce-lockfile`。新环境先准备依赖。
- 保留`-SkipAndroidBuild`兼容参数，但它不再决定是否构建；只有`-AndroidBuild`启用构建，两者不能同时传。旧历史文档无参数命令仅是当时证据，不应照搬为日常命令。
- 脚本Android构建不注入环境，需测试环境包时使用明确APP_ENV/API_BASE_URL的原阶段构建命令，不把无环境包安装给用户。
- 本批未修改`scripts/verify-ios.sh`、`scripts/web/verify.ps1`等历史整组脚本；日常不要因为名称带verify就无条件执行，iOS阶段直接按当前任务构建/安装。

## 验证

`scripts/verify-policy.test.ps1`的15项参数/计划检查通过，全部PlanOnly，不执行全量或平台构建。实际运行`verify.ps1 -TestPaths test/shell_conversation_ports_test.dart`：OpenSpec22项、980文件格式零变更、analyze和指定3条测试通过；命令输出无全量、pub get或APK构建。
