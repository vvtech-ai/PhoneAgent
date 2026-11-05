# 实施与验证（2026-10-13）

## 实施
- 新增纯Dart跨境策略，trim/uppercase后比较有效主叫与所选被叫；翻译关闭或国家缺失/相同不提示。
- 使用Flutter既有NativeConfirmationDialog，aiassistant_app标题/正文/按钮完全一致；返回/遮罩/取消均拒绝本次拨打。
- _call单入口在位置/模型等检查后、国内/海外binding.create之前确认，覆盖拨号和预设确认；_opening防重复。
- 确认快照包含登录epoch、号码、被叫国家、翻译偏好、有效主叫国家/forced及选中模型ID；页面退出、账号或快照变化则拒绝，权限继续检查。
- 两处重复预设确认收敛同方法；拨号页497行，其余新增源码小于500行。共用弹窗样式及页面布局不变，无持久化免提示。
- 当前Flutter没有号码格式警告弹窗，本轮保留严格号码校验，不新增此独立功能。开发者模拟国家按既有有效位置参与判断，国内SIP和海外HTTP准备顺序保留。

## 验证
- 规则与双端弹窗专项20项通过：国家归一/空值/普通电话、文案、共用组件、继续/取消/返回/遮罩、快照及页面有效性。
- 拨号接线专项最终10项通过：Android/iOS拨号和预设入口、取消零create、确认一次、普通/同国、模拟国家、偏好变化、登录epoch变化、页面移除。
- 首轮扩大913通过1失败；旧CN主叫/US被叫无配置场景必须先确认，已补确认后仍保留无配置不得创建断言，最终完整复验已通过。
- 页面连续流程冒烟10项通过：extended_device_stage、migration_increment_device_stage、shell_developer_workbench，均离线widget预检。
- flutter analyze无问题；OpenSpec105项通过；diff检查通过。
- 最终扩大定向：`flutter test test/features/translation test/features/translation_history test/shell_translation_workbench_test.dart test/shell_translation_dial_boundary_test.dart --reporter expanded --concurrency=8`：915项通过、0失败（1分08秒）。专项与此范围重叠，不累加。

## 待验及边界
- [ ] Android/iOS真实页面短屏/大字视觉与系统返回验收。
- [ ] 授权后的真实跨境通话确认/取消及音频计费联调。

未改依赖、插件或平台链，按增量策略未重打包/安装、未跑全仓测试。真实外呼/收费无具体测试授权，未执行，不把离线测试视为设备验收。保留前轮align-native-translation-preparation未提交改动，本轮仅增加三个产品源码文件（策略、弹窗、拨号接线），测试及文档另批。不切分支、不提交推送，未验收不归档。
