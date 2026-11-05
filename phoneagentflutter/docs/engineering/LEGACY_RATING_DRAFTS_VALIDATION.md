# Android v65 条件评分草稿迁移

2026-09-21；实现及合成验证完成，真实同生产签名升级待集中验收。不是整体OTA完成声明。

## 来源与有效性

固定Android `4c781e3ccfcd148c1f205921534907ee0c5aa864`：`data/local/taskrating/TaskRatingDraftStore.kt`、`data/repository/taskrating/TaskRatingRepository.kt`及`features/assistant_task_rating/TaskRatingViewModel.kt`。用户Q13确认保留条件入口，因此这不是废弃评分功能。

旧文件`task_rating_drafts`，键为`task_rating_draft_`加SHA256(UTF8(accountId + NUL + taskType + NUL + taskId))。使用服务端资格返回的taskType/taskId，不把callId/回执锚点直接当任务ID。旧VM每次编辑保存草稿并清空submissionKey，提交前保存重试key；成功清除。

## 实现分工

| 位置 | 职责 |
|---|---|
| [LegacyRatingDraftChannel](../../android/app/src/main/kotlin/com/vvtech/phone_agent/LegacyRatingDraftChannel.kt) / [Key](../../android/app/src/main/kotlin/com/vvtech/phone_agent/LegacyRatingDraftKey.kt) | 固定文件、当前账号/任务哈希键，只读单条；实际生产包门禁，原JSON最多64KiB，不枚举或写删旧数据 |
| [DeviceLegacyRatingDraft](../../lib/features/feedback/data/device_legacy_rating_draft.dart) | Android非Web、prod且精确chaken.ai API门禁；校验版本和完整作用域信封，固定脱敏错误 |
| [LegacyRatingDraftCodec](../../lib/features/feedback/data/legacy_rating_draft_codec.dart) | 纯Dart转换原分数/克隆跳过/建议/submissionKey，无页面或平台依赖 |
| [SecureTaskRatingDraftStore](../../lib/features/feedback/data/secure_task_rating_draft_store.dart) | 新key优先、导入落盘、清除标记、同作用域跨实例串行及关闭保护 |
| [正式Provider](../../lib/app/task_rating_providers.dart) | 当前账号、登录代次及生命周期装配；原生通道由MainActivity注册/清理 |

## 保留与状态边界

- 未填写分数保持null，分值需1–5；不自动补齐、不自动提交。suggestion原样保留空格、换行、未提交的超300字内容，现有表单继续显示长度约束。submissionKey原样保留，使失败后的显式重试仍是原操作。
- baseSubmissionVersion不转化为本地已提交状态：现有Controller先查后台资格，已有currentSubmission直接显示服务端只读结果并清新槽，不导入旧草稿；无资格仍隐藏。不增加评分入口或改赞踩、奖励逻辑。
- 只有新key不存在才读旧源；新值、损坏数据、未知schema均不回退旧源。导入先写新信封再返回；无源记录和clear均写同槽`schema=1, cleared=true`，防止重启复活；不另外持有竞争标记。
- 旧读/解析/新写失败不写空成功，可显式重试。2026-09-21后续修复：共享Controller与正式弹层在读取中/失败时阻止编辑、保存及提交，显示错误和重新读取；关闭重开不隐藏错误。重试成功才恢复原分数/建议/key，不自动提交。当前安全槽损坏/未知schema/非法字段也抛固定脱敏错误，不当无草稿或回退旧源；仅不存在/合法清除标记返回空。
- 同scope在当前Dart isolate跨实例串行，后发保存/清除在先发导入之后执行；不是多进程锁。Provider销毁关闭旧store，未开始操作及旧读后晚到写入被拒绝；已交给存储的写无法撤回，但仍仅写原账号槽位。
- 新clear抹除当前槽中的建议和提交key、留下最小标记；旧SharedPreferences不改不删，**不承诺降级到旧App后不再显示旧草稿**。
- 64KiB和标识长度256是保护上限，不是v65业务承诺；超限报错不截断。诊断不输出原JSON、建议、重试key、账号凭据。不访问真实设备私有数据。

## 本批验证

- 新增20条Dart（4转换、4通道、10存储/Controller、2正式Provider），评分模块加回执连续调用方共45条定向通过，测试阶段15秒；未运行全量。
- 原生3条JVM通过：独立.NET SHA256合成固定向量与v65 NUL分隔算法一致，账号/任务边界及UTF8上限拒绝。报告3 tests/0 failures/0 errors，不将JVM当SharedPreferences真机读取。
- `flutter analyze --no-pub`无问题（4.3秒）；初轮仅测试重复import提示已移除。OpenSpec28项通过，diff检查通过。
- JBR下Android Debug构建10.5秒，`:app:testDebugUnitTest --tests com.vvtech.phone_agent.LegacyRatingDraftKeyTest`9秒通过。无新依赖，无iOS原生变化，无新Web页面，不重复构建双端或做截图。
- 没有设备安装、短信、真实评分提交/积分操作、生产签名调整。iOS仍运行上一阶段普通入口，不能称其已安装此提交。原生产Release构建保护保持。

## 集中人工验证（未执行）

### 读取失败保护增量（2026-09-21，自动验证已执行）

- 代码审计发现Controller吞掉草稿读异常、存储层吞掉解析异常两个同源覆盖风险；均先补失败用例复现，再修复。不是来自真机用户数据丢失报告。
- 新增8项：Controller读失败编辑/POST保护、原建议/key重试、重复点击/加载中编辑、无草稿、服务端只读、销毁晚到、双平台主题正式路由关闭重开/重试，以及实际SecureTaskRatingDraftStore与Controller的损坏→恢复组合；既有损坏/未知schema/非法字段断言同步为保留原槽并报错。
- `flutter test --no-pub test/features/feedback test/shell_receipt_workbench_test.dart`：53项通过，15秒；含320/430宽正式回执连续调用方。`flutter analyze --no-pub`通过（4.4秒），OpenSpec30项通过。未全量、未新双端构建/安装或真实评分；widget平台主题测试不是设备验收。
- 读取失败没有自动丢弃入口；永久损坏或未知新版本需定位/恢复数据，反复点重试不能修复原始内容。本批保留其安全边界，不增加清空用户数据操作。

### 真机与升级步骤

前提：受控测试账号/设备、固定旧v65生产身份安装，以及已验证相同生产证书且更高versionCode的新包；当前Dev不能验证跨旧生产数据。

1. 旧版有eligible任务，打开条件评分填部分分数与合成建议，退出再进确认草稿。另准备一个失败提交保留重试key的受控任务；不为本项真实扣费或创造未经授权的电话。
2. 保留数据升级，打开同任务：分数、跳过克隆、原建议一致，无自动提交。重启仍一致；另一任务/账号没有串入内容。
3. 对失败提交任务，在受控后台核对重试使用相同幂等key，不重复产生评价或奖励；不要将key贴到公开日志。
4. 显式修改Flutter草稿后重启，应是新值；授权提交成功后再打开为服务端只读，重启不恢复旧草稿。无资格任务不显示评分。
5. 使用测试夹具注入源损坏/超64KiB/目标写失败或新槽损坏：必须显示读取失败和重试，评分/建议不可编辑、提交不可用，关闭重开仍有错误，原槽不能被覆盖。恢复故障后点击重新读取，原分数/建议/key恢复且无自动提交；重复点击加载只发一次读取。读取中退出账号不得晚到写另一个账号。
6. iOS/dev与首次新安装不调用旧通道；其他登录、偏好、认证录音、App通话记录和完整旧状态仍按各专项验收。旧App降级行为与发布条件另有门禁，不由本批通过抵扣。
