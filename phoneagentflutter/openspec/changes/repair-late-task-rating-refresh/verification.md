# 验证记录（2026-10-20）

## 基线与来源

- Flutter `codex/dev@8445d06f21f04d3511498b73aa16d7d32bc39867`；其他任务工作内容保留，不切分支、不提交、不推送。
- 只读核对 v66 `a0bedb12` 的 Android TaskRatingViewModel：claim 只取得 owner，load 无请求代次。
- 只读核对原生 `feature/test_v1.6.0@8f235920`：再次 claim 触发 load，generation 过滤旧响应。相关原生回归为 `reentering result card retries eligibility that arrived before sdk projection`、`older eligibility response cannot replace the reentered card`、`duplicate routes for the same task share exactly one rating card owner`、`submitted rating ignores edits and cannot be submitted again`、`retry after an uncertain failure reuses the same idempotency key`。
- Flutter 原有控制器、草稿、API 幂等回归已有覆盖；缺少真实页面连续结果补全、owner 交接重查及跨结果代次交错。本次补齐相关自动回放。

## RED → GREEN

使用固定 `D:/tools/flutter-3.32.0/bin/flutter.bat`。

1. `test --no-pub test/features/feedback/task_rating_result_refresh_test.dart`：生产修改前两条详情连续回放均 RED，结果补全后找不到 NativeTaskRatingEntry；结果说明仍显示，排除页面未挂载。接线后转 GREEN。
2. 新增测试最终共 **12 条唯一用例**：共享实时反馈 call/batch 补全；详情首次 false/异常恢复；旧结果响应；重复 revision 合并；owner 交接与单卡；账号切换；目标切换；编辑期间延迟刷新并保留草稿；提交只读；运行批次不因一路结束生成整批评分。
3. `test --no-pub test/features/feedback/task_rating_result_refresh_test.dart test/features/feedback/task_rating_controller_test.dart test/features/feedback/task_rating_draft_recovery_test.dart test/features/tasks/task_detail_route_test.dart test/features/tasks/task_detail_controller_test.dart`：**29/29 PASS**。
4. `analyze --no-pub` 指定本次六个生产文件、rating 回归及独立 fixture 文件：**No issues found**。`git diff --check` 指定本次生产路径通过；中文 fixture、OpenSpec 读回正常。

扩查 `test --no-pub --reporter json test/features/feedback test/features/tasks`：评分 owner 旧单测曾因自动刷新在途被原 loading guard 吞掉显式 load 而失败，保留原断言后通过代次替换修复；复跑只剩以下两条非评分路径失败，未删除或修改测试：

- `task_detail_supplement_artifact_test.dart` 的 `terminal detail projects supplementary Q/A and explicit artifact save without replay`，Android / iOS 两个 variant。
- 独立运行该文件仍在第 133 行缺少“查看文件”；该 fixture 直接装配 TaskDetailPage，不使用本次修改的详情 route 或反馈 builder。没有在未复跑基线的情况下称为“基线已证实”。交由整体集成核查。

全套测试由父级代码冻结后统一执行，当前不声称全套通过。

## 证据边界

已证实客户端机制与合成端口下的 RATING-01/02/03 连续回放。共享实时反馈测试使用正式 forReceipt/provider/controller；详情测试使用正式 TaskDetailRoute 与可控历史输入，不代替真实 SSE、后端及设备证据。

仅结果有效内容改变、owner 交接或已有显式 load 驱动重查。若最后一次结果后后端独自更新评分资格而没有任何新客户端事实，现有信号无法自动发现；本次不引入计时轮询，不保证该边界自动恢复。查询返回明确 false 仍隐藏；查询失败可由后续有效信号恢复；没有伪造资格或奖励。

未执行真实后端资格/积分、真实外呼、构建、Android/iOS 真机画面或音频；本 change 不归档。

## 独立审查补充：批量结构字段 revision

2026-10-20 追加 RATING-01/02 合同防护。代码核对确认 batch revision 未纳入 item.fields/recalled/abnormal 与整批 totalHint；这属于可复现机制缺口，不宣称已取得线上缺陷或同会话设备证据。

生产仅在 `receipt_feedback_target.dart` 的既有值 revision 增加4行，将上述业务结果值纳入。未修改刷新 controller、provider、route、home 或账本，不引入新查询端口、事实或轮询，也未纳入目标显示名、电话号码等无关显示更新。

专用 `batch_task_rating_result_revision_test.dart` 使用真实 `CallEvaluationRoute.forReceipt` 与原 provider/controller，仅通过现有受控资格仓库替代外部服务。四条回放分别只改变 receiptFields、recalled、abnormal、totalCount，固定原 batch/item/attempt/call 身份、headline/detail/status；从初次无资格到结果补全后原区域出现“去评分”。每条同时验证仅一次重新查询、同值新对象不重查、仅 targetName 改变不重查、原 batch target 与结果→评分→Agent说明顺序。

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' test --no-pub test/features/feedback/batch_task_rating_result_revision_test.dart --reporter expanded
```

修改生产前4条均 RED：找不到“去评分”；加入4行 revision 值后4 passed，退出码0。格式化只应用于新测试文件。

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' test --no-pub test/features/feedback/batch_task_rating_result_revision_test.dart test/features/feedback/task_rating_result_refresh_test.dart test/features/feedback/task_rating_controller_test.dart test/features/feedback/task_rating_draft_recovery_test.dart test/features/tasks/task_detail_route_test.dart test/features/tasks/task_detail_controller_test.dart --reporter expanded
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' analyze --no-pub lib/features/feedback/domain/receipt_feedback_target.dart test/features/feedback/batch_task_rating_result_revision_test.dart
openspec validate repair-late-task-rating-refresh --strict
git diff --check -- lib/features/feedback/domain/receipt_feedback_target.dart
```

最终6文件33 passed，退出码0；静态2项 No issues；OpenSpec valid；diff无空白错误；中文文案UTF-8读回正常。未复跑之前记录的整套feedback/tasks扩查，原两项文件查看失败记录继续保留，不把本次聚焦通过扩展为全套通过。
