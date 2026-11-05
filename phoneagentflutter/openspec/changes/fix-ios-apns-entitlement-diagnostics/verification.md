# 验证记录

## 范围与证据
- 基于 codex/dev@7beb059d，保留原有未提交修改。只修复 iOS 权限声明与安全诊断；DEVICE-01 的设备证据待验，未改任务编排或共享规则。
- 日志有授权成功及注册失败，无 token 收到/绑定成功；Debug/Profile 缺少 aps-environment、本地旧签名也缺失。不能据此认定手机安装包完全相同。
- 本机测试身份开发 profile 含 development APNs，至2027-09-20有效，无需更新 profile。

## RED / GREEN
- Python 首轮 Debug/Profile 两个子场景均因缺少 aps-environment 失败；补声明后通过，Release 保持 production。
- 原生新增失败诊断测试先编译失败（原实现无接收 NSError 接口）；补实现后白名单域、负错误码、超界拒绝、原文清理、消费代次和有界缓存通过。
- Flutter 新增4项中3项因错误域/码丢失失败；修复桥接/序列化后4项全部通过，覆盖非失败/其他stage过滤、伪造域/非法类型和导出恢复。

## 自动验证
- Flutter 可信来电模块 + core/diagnostics：148项通过；首轮直接调用方17项通过，不重复相加。
- Foundation incoming_diagnostics、push_binding_state、push_binding_driver 三个可执行回归通过，无真实 SDK/APNs 请求。
- Python APNs entitlement / SDK环境2项通过（内部覆盖三配置及四种宏条件）。
- iOS arm64/iOS16.1 真机SDK clang syntax-only：Plugin与IncomingDiagnostics通过。
- flutter analyze --no-pub 无问题；当前OpenSpec严格校验通过。

## 签名验证
- 用户指定1.0.52（45）；隔离构建Debug/test/arm64，最终IPA通过签名完整性、Bundle ID、版本、邀请域名与环境、无私有输入文件混入检查。
- 最终签名与embedded profile均为 aps-environment=development，与Info.plist一致。证明本次成包修复权限缺失；不等于设备已收到token。
- 三次准备失败分别为APP_ENV重复、Pod默认dev与Dart test不匹配、直接Xcode构建资源bundle未取得团队配置。逐项核对后使用config-only及显式PHONEAGENT_IOS_ENV=test / 既有DEVELOPMENT_TEAM进行最终成功构建；未修改源工程默认或私有配置。三个失败隔离目录按规范保留；成功目录在完整验证和导出SHA一致后清理。

## 设备安装核验
- 用户追加授权后，1.0.52（45）覆盖安装到数据线连接的iPhone 15。Debug包启动后在AudioplayersDarwinPlugin.register阶段崩溃；仅确认崩溃位置，未修改插件或认定唯一根因。
- 同版本改用Profile/AOT测试包，签名与profile均含development APNs；覆盖安装后回读Bundle ID/版本，并验证启动十秒后进程仍运行。未卸载、未清数据，原有诊断目录仍存在；界面、登录态及完整数据一致性未签收。
- 安装验证未触发源码修改；不把Profile启动成功表述为Debug崩溃已修复。

## 待验
- 实际APNs token与SDK绑定未读取到新日志，真实后端/画面/音频/外呼均未验收，不能报告token或SDK绑定成功。change不归档。
