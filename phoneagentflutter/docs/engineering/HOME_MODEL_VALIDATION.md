# 首页、模型与账号请求层（2026-09-16）

## 已实现范围

- 登录落点由工程页替换为正式首页布局；四 Tab 与中央拨号导航壳。联系人、任务、其他设置及拨号业务仍待后续接入，当前明确提示未迁移，不伪造成功。
- 首页 published 配置、严格解析、ETag/304、安全图片 URL、失败内置兜底、禁用隐藏/即将提供/最低版本门禁；首页会话内标语只选一次。
- 模型读取/选择、普通音色读取/选择、下一次通话生效提示；保存失败保留旧选择；旧音色响应隔离。普通音色沿 v65 使用 active-provider 接口，per-model 接口属于克隆退出协调，未提前接入。
- 账号请求保留 base 前缀，仅固定受保护路径附带 Bearer；并发 401 共享刷新、最多重放一次、账号代际隔离；刷新 401 退出，网络/服务错误不丢登录状态。
- UI 采用固定 HTML 设计资源和测量值；主图原 SVG 的 CSS/filter 不受 Flutter SVG 引擎支持，使用 Chromium 将原图转换为 PNG，未重画、未使用整页截图。

## 验证与证据

| 检查 | 结果 |
| --- | --- |
| OpenSpec | 9/9 通过 |
| analyze | 通过 |
| 单元/控件 | 90 项通过；含并发刷新、请求头和普通音色路径、失败回退、卡片门禁、保存失败、过期响应、小竖屏 |
| Android 配置测试环境构建 | 通过；普通入口覆盖安装和启动通过 |
| 模拟器离线流程 | 首页、模型弹层、模型页、音色页、四 Tab、返回、失败重试；合成模型/音色保存，不修改真实账号 |
| 设计中间产物 | 13 项 schema 校验通过；190 节点、18 个原始资源及主图 PNG 派生资源 |
| 公开首页在线接口 | GET 测试环境成功，published 20260915.23；8 卡片中 6 enabled、2 disabled |
| 真实账号模型/音色读取 | **未通过在线验收**：普通入口启动时模拟器已回登录页，无可用登录态；不自动重发短信、不猜测账号或注入真实凭据 |
| iOS 本批 | 未验证；不借 B0/Android 结果宣称通过 |

本地截图与离线结果位于 `.local/home-model-validation/`；固定 HTML 预览位于 `.local/design-home/previews/`。不提交含账号内容的截图。首次主图转换用 librsvg 失败，已改 Chromium 并重新验证；新增资源需刷新 pub 资源清单后再构建，失败轮不作为验收通过。

原登录态未恢复的确切原因尚未确认。设备包信息显示 firstInstallTime 已更新，应避免把 `flutter drive` 安装循环当成“保证保留真实登录态”的升级验证。后续离线测试固定使用专用模拟器/合成账号，真实账号测试留独立设备或集中验证；正式 OTA 仍为独立门禁。

## 剩余边界

统一页、任务恢复/结果、联系人、拨号、身份引导、积分、完整设置继续下一批；声音克隆录放/音色试听、真实外呼、平台音频后置。模型延迟指标与克隆音色目录尚未接入，不能据此声明完整模型模块已验收。当前版本仍 1.0.0-foundation，最低版本门禁不假装客户端为 v65。

设计与行为冲突时保持 v65；无充值按钮，不引入原型未来模型/记忆功能。OpenSpec 保持 active，用户验收后再归档。依赖固定 [flutter_svg 2.0.17](https://pub.dev/packages/flutter_svg/versions/2.0.17)，未升级 Flutter/Dart。

## 复跑

```powershell
flutter analyze
flutter test
flutter drive --driver=test_driver/home_model_driver.dart --target=integration_test/home_model_flow_test.dart -d emulator-5554
flutter build apk --debug --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=https://agent.vvtech.tech/aiassistant-api/
```

集成测试后重新安装最后的普通入口 APK；真实账号业务未验证项不得由合成成功替代。
