# Android旧积分不足提示状态兼容

日期：2026-09-21；Flutter基点f6ba78a加本批改动。对应迁移台账L03；实现及定向验证完成，真实同签名升级未验收。

## 来源与实现

固定Android v65 `4c781e3ccfcd148c1f205921534907ee0c5aa864`：AssistantPageHost把index9_native_screen交给SharedPreferencesTaskCallPointsAdmissionNoticeStore。旧key为task_call_points_notice_加SHA256(account+NUL+conversation+NUL+confirmationIdentity)，值为布尔。TaskCallConfirmationIdentityAliasPolicy与Flutter现有CallLaunchRequest的toolId/stableAlias保持相同编码。

- Flutter DeviceLegacyCallAdmissionSource计算旧哈希，仅将哈希列表传原生；核对版本、精确key集合和布尔类型。
- Android LegacyCallAdmissionChannel只允许同生产包、固定偏好文件及前缀；LegacyCallAdmissionKeys限制1–1024个唯一小写64位哈希。不枚举偏好、不传确认正文、不写旧文件。
- SecureCallAdmissionNoticeStore优先新安全存储；仅缺失项查询旧源，命中先写入新key的1再返回。新值存在、读取失败时不回退覆盖。独立alias单调写1，保留并发隔离。
- callAdmissionProvider仅在非Web Android、精确prod API启用旧源，并绑定登录代次及Provider生命周期。异步失效不向新账号发布结果。
- 复用CallAdmissionService原有“再次不足”判断与刷新，不修改余额、计费快照、提示接口或确认电话流程；存储失败沿原persistenceFailed语义处理。

这不是新增页面、积分扣款或呼叫功能。iOS/Web/Dev无旧Android来源；两端继续共享业务判断与新存储。

## 自动验证

本批43项相关Dart通过（其中12项新增，测试阶段约2秒），未跑全量：

```text
test/features/calls/legacy_call_admission_source_test.dart
test/features/calls/legacy_call_admission_store_test.dart
test/features/calls/legacy_call_admission_provider_test.dart
test/features/calls/call_admission_data_test.dart
test/features/calls/call_admission_test.dart
test/features/calls/conversation_restored_admission_test.dart
test/features/points/points_admission_provider_test.dart
```

覆盖旧哈希固定向量、分隔符、响应损坏/越界、新值优先、无匹配、读写失败重试、跨账号/会话、关闭与并发；正式Provider平台/环境门禁和正式Service再次不足分流，验证无新增通知提交。测试只用合成数据和替代HTTP端口。

原生 `:app:testDebugUnitTest --tests com.vvtech.phone_agent.LegacyCallAdmissionKeysTest` 通过；XML确认3项、0失败/错误/跳过，验证固定前缀、非法key和数量边界。不是原生偏好文件真机读取证明。

`flutter analyze` 无问题（42.1秒）；Android Debug构建通过（10.3秒，JBR，APP_ENV=dev、测试API）。仅编译产物，未安装设备；无iOS原生变更，未重建iOS。没有真实短信、电话、账号数据读取或上传。

## 集中人工升级验收

前提：专用测试账号和可控余额、固定v65同生产包、兼容签名及更高版本；不能用Dev包代替正式升级证据。按[集中主清单](MIGRATION_HANDOFF.md)的升级步骤执行，不卸载旧包、不清数据。

1. 在旧版本准备已产生首次积分不足提示的会话，记录对应会话/确认身份及提示次数。无需为了此验证实际拨通电话。
2. 保留数据覆盖升级，确认原登录可用；从任务列表恢复同一确认，余额仍不足时应走再次不足分流，不新增首次不足时间线提示、不发起电话。
3. 冷启动再次恢复同一确认，仍识别已提示；有旧记录但不匹配账号/会话/alias时不能串用。检查新的首次不足仍保持原流程。
4. 自动故障注入已验证读写失败不能假报保存；真实升级若出现存储错误，保留旧源和失败证据，不通过清数据绕过。

限制：不导入L04历史计费快照；不迁移未请求的所有哈希。旧文件只读保留，降级旧包不保证新状态反向同步。生产签名、其他旧状态和真实升级仍属独立未完成项。
