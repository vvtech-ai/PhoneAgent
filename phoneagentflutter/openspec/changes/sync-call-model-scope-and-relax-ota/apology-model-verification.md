# 道歉任务模型作用域验证

## 实现范围

- `CallModelSheet` 接受任务模型ID，`CallModelsPage` 仅在该模型仍可用时覆盖全局选中项；不可用则显示当前可用默认。打开、前台恢复、手动刷新均重新加载模型目录。
- `ConversationRoute` 的底部名称、倍率、面板选中项及通话监控名称使用同一任务模型；显式手动选择仍先保存全局设置，成功返回后才更新当前任务并查询克隆音色。
- `bindApologyModelChanges` 只在成功目录证明任务模型不再可用时校正。有效任务模型不受其他全局变化影响；历史恢复晚于目录返回时也执行同样检查。
- 无可用模型时取消旧音色查询代次并清除可执行选择，阻止提交；后续目录恢复可用后重新检查音色。任务模型的缺音色提示使用任务名称，不误用全局名称。
- 无新增接口字段、持久化格式或全局音色激活；原有候选音色确认、暂停确认倒计时和账号归属门禁继续使用。

## 回归证据

定向6文件共 **26项通过**（`.local/apology-model-final.log`）：

```text
flutter test test/features/conversation/apology_task_model_scope_test.dart test/features/conversation/apology_voice_flow_test.dart test/features/conversation/apology_provider_initialization_test.dart test/features/conversation/apology_precheck_lifecycle_test.dart test/features/call_models/apology_task_model_sheet_test.dart test/features/call_models/conversation_model_sheet_test.dart --reporter expanded
```

10个修改文件 `flutter analyze --no-pub <paths>`：**No issues found**（`.local/apology-model-analyze.log`）；对应文件 `git diff --check` 无差异错误。工具链为固定Flutter3.32.0 / Dart3.8。

关键新增场景先复现再修复：

1. 全局变化错误地把有效任务模型2改为1：`.local/apology-model-scope-red.log`。
2. 历史任务模型2的标签正确、面板却选全局1（Android/iOS主题）：`.local/apology-model-sheet-red.log`。
3. 无可用模型后恢复原任务模型仍保持阻塞：`.local/apology-model-permission-red.log`。
4. 任务模型2缺音色却显示全局模型1名称：`.local/apology-model-name-red.log`。
5. 新目录先返回、再恢复历史任务时漏校验：`.local/apology-model-history-red.log`。
6. 面板打开后任务模型失权，列表无可用默认选中：`.local/apology-model-unavailable-radio-red.log`。

正式Route组件测试从合成历史detail的 `taskCallModelId=2` 恢复，证明任务标签/列表一致、关闭不写全局、手动切3同时写全局与任务且音色检查完成。原有Agent选项测试保持全局写次数0；候选资产确认/暂停拨号回归保持通过。

原有两处fixture随新语义修正：面板错误重试fixture明确让初始读和打开后的强制读均失败；历史预检查fixture使用其模型目录真实存在的 `QWEN_OMNI_PLUS`，避免把非法合成ID当作合法历史选择。

## 边界

Android/iOS主题的组件测试为共享UI证据，不代替双端设备运行。未执行真实登录、数据库调用、外呼或音色供应商请求。最终提交、签名测试包及成包核验由主任务执行。
