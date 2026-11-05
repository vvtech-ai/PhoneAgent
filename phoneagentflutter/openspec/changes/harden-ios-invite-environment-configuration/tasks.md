## 1. 上下文与规格
- [x] 1.1 阅读规则、需求、既有邀请 change，确认修改边界。
- [x] 1.2 建立三环境配置及签名验证方案。
- [x] 1.3 运行 OpenSpec 校验（初验198项通过）。

## 2. 配置与接线
- [x] 2.1 三环境配置显式选择、开发权限及构建前检查。
- [x] 2.2 原生与 Dart 网页域名接收一致，保持严格邀请码规则。
- [x] 2.3 最终签名 App/IPA 与描述文件检查；run-test-build.py声明IPA必须传ios-environment，完整平台验证后自动检查再导出。

## 3. 验证与记录
- [x] 3.1 工具合成回归18项、既有生命周期16项通过；Xcode三模式×三环境展开值及preflight符合预期，另验证XCODE_XCCONFIG_FILE可覆盖test且不改Bundle ID。
- [x] 3.2 邀请模块278项通过、analyze无问题、原生三个回调LLVM方法表通过；联合邀请/auth/architecture为404通过/1失败，未声称全部通过，详见下文。
- [ ] 3.3 只读检查线上 AASA/下载配置及已有 IPA。
- [x] 3.4 更新根任务、问题记录及实际验证范围。
- [ ] 3.5 新签名包与真机冷/热唤起、邀请码传递及回退验收（本轮不打包安装）。

## 实际范围与问题

- 修改微批分别为配置/权限、xcconfig/Xcode接线、原生与Dart接线、签名工具、回归及导出入口，每批不超过3个手写文件；Dart格式化单独执行。新增手写文件均低于500行；pbxproj为既有Xcode工程机械配置，不拆散模板。
- `python3 -B -m unittest discover -s scripts -p test_ios_invite_configuration.py -v`：18通过；`... -p test_test_build_workspace.py -q`：16通过。
- `flutter test --no-pub test/features/invite test/features/auth test/architecture_test.dart`：404通过、1失败。独立重跑device_legacy_session_source_test.dart为5通过、1失败；第134行期待SecureSessionStore，实际为IosSessionStore。测试、auth_providers.dart及ios_session_store.dart与HEAD字节一致，现有Provider明确在iOS返回IosSessionStore，本次不修改登录存储或其测试。
- `flutter test --no-pub test/features/invite --reporter json`：278项通过。`flutter analyze --no-pub`：无问题。`python3 -B tool/verify_ios_invite_callbacks.py`：cold/openURL/continue全部注册且无near-match。
- `plutil -lint`：Info.plist、两个权限模板及pbxproj均通过；diff校验通过。
- 只读复核两份20261019_121906、135624的1.0.52(45) IPA：均由新门禁返回1，原因为关联域名缺失/重复。没有生成或重签新包，没有安装设备。
- 线上prod/dev下载配置与专用域名一致；test请求及重试连接失败，3.3保留待验。专用域名及www/agent域AASA同时授权正式/测试ID，网页域仅返回专用路径；详细边界见docs/engineering/IOS_INVITE_ENVIRONMENT_CONFIGURATION.md。未修改服务器，dev/test独立身份需另行批准。
- 工具恢复：Xcode26的codesign `--entitlements -`返回展示文本、profile关联授权为字符串`*`；读取实际输出后改为XML输出`:-`并兼容Apple通配格式，再以两份真实IPA验证正常拦截。生命周期合成工程缺少新增模块导致一次失败，补齐合成工程复制依赖后16项通过。一次错误过滤测试名未运行用例，已改为完整文件独立复核；未扩大业务修改范围。
- 最终OpenSpec全校验198通过、0失败；两个专用域名Apple CDN同样返回200且包含正式/测试两个ID。未执行完整iOS成包编译或修复包签名/真机验证，不能据配置展开或原生单文件编译宣称设备验收通过；change保持active。
