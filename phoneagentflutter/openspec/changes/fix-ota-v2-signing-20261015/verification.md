# 2026-10-15 OTA签名兼容验证

## 实现
- v2/HMAC-SHA256仅SDK api/ota/check生效；复用DeviceC1Credentials中的部署SDK凭据，不改配置/密钥。native SdkC1SigningInterceptor将同一appKey/appSecret转交v2签名器，证实凭据来源一致。
- 请求体只JSON序列化一次；实际Dio出站stream字节与SHA256和HMAC匹配，网关前缀、raw query、UTF8中文和HTTP方法大写处理有独立Python固定向量证据。
- OTA401为rejected，不触发Bearer/刷新或清会话；普通C1、SSE、下载、multipart及刷新保持原逻辑。
- otaRequest记录请求开始/结束、本地UUID、HTTP和耗时；otaCheck记录整体检查及格式/平台/状态失败类别。两阶段UUID各自配对，不发送到服务器；不宣称可用它直接检索网关日志。日志不保存账号、包名、URL、请求/响应原文或签名凭据。
- 不改UI、共用控件、Provider、安装与强制更新策略；iOS无OTA。AccountApi从474到490行，诊断及v2独立辅助职责，新增/修改手写文件均小于500行。
- 保留当前codex/dev_zys及全部既有邀请改动；DiagnosticEvent仅追加两个枚举，根文档仅追加本轮记录。不切分支、提交、推送或归档。

## 实际验证
固定/Users/Eason/.cache/phoneagent-flutter-3.32.0/flutter，Dart3.8。

1. `flutter test --no-pub --reporter expanded test/features/app_update test/features/settings/about_update_test.dart test/features/settings/about_route_test.dart test/features/settings/settings_update_entry_test.dart test/core/network test/core/diagnostics`：205项通过。含新签名10项、启动/手动共享去重、强制状态失败保留、离页/切号、关于完整App及网络刷新/SSE/download边界。不是全仓回归。
2. 最后加入缺凭据和诊断sink故障两项，并按实际HTTP规范归一化方法大写；`flutter test --no-pub --reporter expanded test/features/app_update/ota_signed_request_test.dart test/core/network/c1_transport_test.dart`：14项通过（OTA12+C1 2，包含前轮重复项）。全部使用合成凭据和响应，没有真实用户fixture或真实OTA请求。
3. `flutter analyze --no-pub`：最终无问题。首轮新增测试if缺花括号，按实际行核对修正后重验通过。
4. `flutter build apk --debug --no-pub`：首次21.9秒、最终源码8.6秒通过；仅默认Debug编译验证，没有注入部署凭据，不是可交付真实环境的OTA升级包，不安装或改签名配置。
5. `openspec validate --all`：初次152通过0失败；最终结果以同轮工具输出为准。`git diff --check`通过。

## 待验
用户日志四次401缺少路由与code，不能认定全部为OTA。新测试环境包真实点击、服务器接收签名/部署凭据注册、生产签名身份及保留数据升级尚未验证，需新包与服务/设备联验；当前修复完成源码及自动/编译验证，不声明线上故障已实测消失。
