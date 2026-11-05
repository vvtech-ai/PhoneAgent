## 1. 规格与修复
- [x] 1.1 核对截图入口、Debug默认开关、正式创建及tool独立入口。
- [x] 1.2 OpenSpec校验与移除正常页演练跳转。
- [x] 1.3 双平台/大字回归验证无MOCK，保留真实创建和试听流程。
## 2. 验证交付
- [ ] 2.1 analyze、定向测试、显式演练开关仍无入口。
- [x] 2.2 更新根任务/问题日志、限定本次提交推送。
- [ ] 2.3 新包设备显示与用户验收，未验收不归档。

## 本批验证
- 新8项默认Debug回归先RED（均找到MOCK），移除后默认及邻接34项通过；显式ENABLE_MIGRATION_PREVIEWS=true专项8项再通过，不累计为42个不同用例。
- 全仓flutter analyze --no-pub返回10条info（5处重复展示），均是进行中的trusted_caller模块curly_braces_in_flow_control_structures，涉及account_providers/account_synchronizer/settings_entry。本次不修改其他任务；当前全仓分析未通过，2.1暂保留待验。
- 定向flutter analyze --no-pub lib/features/call_models test/features/call_models/voice_sheet_production_entry_test.dart无问题。OpenSpec65项通过，diff无空白错误。
- 本次仅1源码+1测试微批，无平台/插件/依赖修改，不重打或安装普通双端包；现场手机需更新包含修复的新包后验收，未操作登录数据。
- 独立tool/previews/workbench_catalog.dart的克隆演练入口保留，不以简单改文案冒充真实流程。当前其他可信来电变更/pubspec.lock保留。

实现fcbdafe5已推送origin/codex/dev_zys，仅本次8文件；全仓分析和新包验收继续按上方边界保留待验。
