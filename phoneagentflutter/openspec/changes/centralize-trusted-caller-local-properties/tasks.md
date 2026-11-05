# 任务
- [x] 核对当前源码、既有规格和单文件迁移边界。
- [x] 创建并校验本次规格（OpenSpec全量200项通过）。
- [x] 增加根目录忽略、Properties解析及原生接线，安全迁移真实值。
- [x] 同步构建/准备入口、脱敏示例及定向回归，移除旧可信字段。
- [x] 完成Python/Flutter/原生、OpenSpec及必要构建验证和敏感信息核对。
- [x] 更新记录并确认本次提交范围；Git同步以实际提交和远端SHA核对结果为准。
- [ ] 用户及真实设备验收；生产配置、Windows运行独立待验，不归档。

## 当前验证
- 根目录文件600权限且Git忽略；六个字段按Java Properties转义后逐一解码核对一致，再移除三个JSON可信字段，其他业务配置保留。
- Python入口9项、准备工具7项、Properties解析7项、真实Gradle脚本8项通过；后者包含Java/Python特殊字符、Unicode、续行和重复键的实际解码对比，未跳过。
- JDK17/Flutter3.32 Debug编译通过（13.4秒），沿用批准版本1.0.52(45)，仅必要编译验证，不导出安装。原生/Flutter回归及最终差异核对进行中。

## 最终验证
- Python50项：Properties解析7、入口9、准备工具7、真实Gradle脚本8、私有写入直接调用方3、临时生命周期16，全部通过；Unicode空白及Java/Python解码一致性已覆盖，没有跳过Gradle用例。
- Flutter可信来电126项通过；analyze无问题。Android原生10套26项通过；首次命中缓存后用仅测试任务--rerun实际重跑通过。
- Debug构建通过；APK SDK/Glide19类、供应商清单、唯一读取器和无整份Properties/JSON资源检查通过。实际Gradle test/dev的BuildConfig值分别与根文件对应字段一致；pro仍因cloud业务APP_ENV=test被拒绝。
- 根文件600权限且忽略，六个字段无迁移值差异，其他JSON字段保留；android/local.properties与iOS私有文件摘要不变。本次不修改UI、iOS业务或SDK二进制。
- macOS无pwsh，Windows实际运行未验；生产有效业务配置、真实SDK及来电仍待验。不安装、不导出交付，保持active不归档。
- Git核对发现远端新增3387ac39克隆流程修复，配置改造将保留该更新接入最新codex/dev，普通推送，不改远端历史。
- 已无冲突接入3387ac39，原生/脚本/工程说明与整合前逐文件相同；整合后analyze无问题、OpenSpec201项通过，可信来电126项加远端新增克隆试听/重试10项共136项通过。最终提交差异仅本项28文件，无真实凭据或UI/iOS业务改动。
