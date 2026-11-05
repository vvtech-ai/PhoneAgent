# Android v65 本机通话记录导入

2026-09-20：实现和合成自动验证完成，真实同签名升级未验收。没有访问实际通话记录/字幕、清理账号或设备数据、发短信、安装新包或打电话。

## 代码来源与边界

固定Android `4c781e3ccfcd148c1f205921534907ee0c5aa864`：`AssistantRootRuntimeGraph`的`FinalPrefsName=index9_native_screen`，`AssistantCallRecordState`的`final_call_records_<account>`，`FinalCallRecordStorage`的JSON编码；`DialRecentCallPolicy`和`LegacyDialHistoryContactSnapshotPolicy`决定历史元数据回填。不是系统CallLog，也不是后台任务。

| 实现 | 职责 |
|---|---|
| [LegacyCallRecordsChannel](../../android/app/src/main/kotlin/com/vvtech/phone_agent/LegacyCallRecordsChannel.kt) | 生产包名门禁、固定SharedPreferences/账号键，只读；不接受路径/key、不读guest、不申请权限 |
| [DeviceLegacyCallRecords](../../lib/features/dialer/data/device_legacy_call_records.dart) | Android非Web+精确prod API门禁，校验version/accountId/records信封，错误脱敏 |
| [LegacyAppCallRecordCodec](../../lib/features/dialer/data/legacy_app_call_record_codec.dart) | 共享旧格式→当前元数据映射，不保存全文转写、结果或其他旧详情 |
| [SecureAppCallRecordRepository](../../lib/features/dialer/data/secure_app_call_record_repository.dart) | 在现有同槽跨实例串行边界中一次导入、落盘、通知；新信封存在即权威 |
| [app_call_record_providers](../../lib/app/app_call_record_providers.dart) | 当前登录归属和生产门禁；系统日志来源/iOS不变 |

## 映射及状态规则

- 有效旧行必须有非空title/status/meta；无效行沿v65跳过。未知kind仍为AGENT，不臆造翻译记录。
- 保留phoneNumber、callId、contactDisplayName、occurredAtMillis、country和双方语言。缺少/非正时间为0，缺ID为`phone:time:KIND`，不解析显示文案猜时间或号码。
- 显式姓名优先；否则仅按旧“普通通话 / 实时翻译 / 翻译通话”标题前缀取快照，纯号码标题不当姓名。不自动读取通讯录补充。
- 新仓库存所有有效元数据；现有最近消费者仍只展示App翻译子集，与Android系统记录合并。普通/Agent不新增旧详情入口；选择历史只回填，不拨号。
- 新key不存在才读旧源，写新安全信封成功才返回；空源也写空信封防止反复导入。新key已有数据或空列表，均不合并/覆盖旧源。
- clear/append/load共用原队列，清空后重启不能复活；追加前首次导入保留旧行，按现有id+kind避免追加重复。账号变化或close后旧读取不继续写；已进入底层写操作不能撤回，但仍只写原账号槽位。
- 旧读取、损坏JSON、新写失败明确报错，可重试；不以空成功盖住错误。新数据损坏/未知schema不回退旧源。
- 技术读取上限16MiB UTF8（包括空白数据），超限失败，不截断。这不是v65原有容量声明，需在升级测试检查大历史样本。
- 旧源不改不删，包含旧全文的源也不再复制到新存储。清理新列表不是物理擦除旧源；旧版不认识新清理状态，不承诺安全降级。

## 自动证据

- 新增27条，迁移/映射/MethodChannel/正式provider28条，加最近记录/三宽UI/翻译结束直接调用方49条，共**77条定向通过**。未运行全量。
- 覆盖首次导入→持久恢复、已有新值/空信封优先、清理不复活、跨实例并发、写失败重试、账号切换/销毁晚到、当前provider及迁移通知不会无限刷新。
- `flutter analyze --no-pub`无问题；OpenSpec26项通过。Android Debug最终9.4秒构建通过（JBR、测试环境配置），没有安装。无新依赖，无iOS改动，不重复iOS构建。
- 测试使用合成JSON/安全存储替身/模拟MethodChannel，不证明真实SharedPreferences读取、生产签名、UID兼容、设备锁屏或系统IO。Release门禁仍在。
- 没有UI代码变化，不把旧Web截图说成本批新验收；最近列表320/390/430宽的原有Widget调用方回归已运行。

## 集中人工验证（以后统一执行）

前提：获准专用测试账号和设备、旧v65正式包及合法同签名/同包名更高versionCode产物。当前`.dev`包不能代替正式升级包。

1. 旧版账号A准备少量可识别的翻译和普通记录，包含显式姓名/旧标题姓名、不同国家与语言；不导出真实字幕或号码到日志。
2. 保留数据升级并登录A，打开普通/翻译拨号最近列表；App翻译可见，系统日志独立，顺序/号码/名称对应。选择只回填，不自动拨号。
3. 重启再打开，无重复；在专用流程产生获准的新本机记录后，旧记录仍在且新记录不被覆盖。无需为验证导入打真实电话，可用获准测试数据。
4. 经授权执行开发者清空本机列表，重启应保持空；后台任务与Android系统通话记录不被删除。
5. 切换账号B，不得读A的旧key或新槽；回到A仍遵守A的保存/清理状态。
6. 专用测试构建模拟旧JSON损坏、临时安全存储失败、账号在读取途中变化；预期失败可重试、不误报空成功、不跨账号写入。超过16MiB应失败而非部分导入。

以上未验前不归档`android-legacy-call-records`。生产OTA签名/versionCode、其他旧状态盘点及降级策略仍需独立收尾，不能由本批构建抵扣。
