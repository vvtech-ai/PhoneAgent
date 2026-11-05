# 实施与验证（2026-10-13）

## 参照与结果
Flutter起点c10ad11c，aiassistant_app参照47d1cee。用户确认执行普通实时翻译准备对齐，当前codex/dev_zys本地修改，未提交推送，参考仓库只读。

- 正式拨打冻结有效主叫国家（含开发者模拟），US/JP选择相应环境区域、其他DEFAULT、国内强制海外US。普通HTTP外呼与该通话语言目录使用同一环境节点，options仍验证精确模型、语言和国家能力，未切换V70。
- 语言按原生代码/原始值/名称逐行匹配；不再额外强制ko/fr/de/es转区域码。离线预览以服务器短代码展示这些合成语言，并验证真实返回码进入create。
- LiveKit媒体校验允许安全https/wss及query，与解析层一致；userinfo/fragment及不安全协议仍拒绝。双就绪、LiveKit失败转WebSocket、单次外呼及取消/挂断顺序保留。
- 创建响应realtimeProvider为空时使用原请求协议值；voiceProvider既有twilio回退保持。HTTP连接/读取超时对齐30秒。已有去capabilities一次兼容及固定mobile-app-user保持，账号/归档仍真实用户隔离。
- 语言不支持、创建HTTP错误、媒体失败及后端未发起被叫分别反馈；不透出原始服务消息或凭证。清理失败保留结束待确认。
- UI布局、颜色、字体、组件风格未改。仅必要错误文案及区域说明更正；下方区域选项继续用于公开目录检查，不声称覆盖正式按国家路由。

## 实际验证
固定Flutter3.32.0/Dart3.8，未升级工具链。
- `flutter test test/features/translation test/features/translation_history test/shell_translation_workbench_test.dart test/shell_translation_dial_boundary_test.dart --reporter expanded --concurrency=8`：885项通过，0失败。
- `flutter test test/extended_device_stage_test.dart test/migration_increment_device_stage_test.dart test/shell_developer_workbench_test.dart test/features/app_logs/diagnostic_journal_test.dart test/features/app_logs/log_zip_api_test.dart --reporter expanded --concurrency=8`：27项通过，0失败；属于离线widget/诊断测试，不是真机验收。
- `flutter analyze`：无问题。
- `openspec validate --all`：104通过，0失败。
- `git diff --check`：通过；修改的手写lib源码不超过500行。

首轮扩大测试872通过9失败，旧离线预览依赖Flutter额外语言转换；修正合成目录及两处返回码断言后上述885项完整通过。未改公共账户鉴权/依赖/平台链，按增量策略未执行全仓测试或重打双端包。

## 待验
- [ ] 新包Android/iOS模拟US/JP后的实际节点、语言目录及创建响应联调。
- [ ] LiveKit/WebSocket真实音频就绪、超时/回退及取消释放。
- [ ] 真机UI与错误提示视觉验收。
- [ ] 经单独授权的真实认证、外呼与计费流程。

本轮未获具体真实认证/外呼/收费测试授权，未安装或清理设备数据，不宣称已证明线上故障根因或真实通话打通。Android私有构建节点覆盖与Flutter构建参数实际值需部署验收核对。不修改登录失效统一提示或AI代办流程。未验收不归档。
