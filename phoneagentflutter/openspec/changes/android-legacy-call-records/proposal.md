## Why

Android OTA需保留原账号App内通话记录。固定v65使用index9_native_screen下final_call_records_<account>的JSON，Flutter现有安全仓库不能直接读到，升级后最近翻译记录会消失。旧Calls详情不属于本期迁移UI，不为导入恢复废弃页面。

## What Changes

- 同生产Android/精确正式API只读固定账号旧键，不接受任意路径/key，不清理旧源。
- 共享解析保留当前元数据消费者所需字段，沿v65时间、kind、fallback id与历史名称规则，不伪造后台任务或通话成功。
- 仅新key不存在时在既有同槽串行边界导入；先持久化再返回，空记录也写新信封防清理复活；失败明确可重试。
- 补合成迁移/账号/并发与正式provider测试、集中升级步骤。

## Capabilities

### New Capabilities
- `android-legacy-call-records`: 固定v65账号本机通话元数据只读导入。

### Modified Capabilities
无。

## Impact

Android薄读取通道/MainActivity、Dart来源/映射、SecureAppCallRecordRepository与正式provider；无新依赖、接口、权限、音频、真实外呼或后台状态变更。仅合成数据，定向测试/analyze/OpenSpec/Android Debug编译；同签名生产升级另验，不解除Release门禁。iOS/Web不读Android旧源。
