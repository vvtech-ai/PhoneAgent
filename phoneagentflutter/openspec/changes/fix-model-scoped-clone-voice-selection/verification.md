# 修复与验证记录（2026-10-13）

## 已实施
- 音色读取使用 `GET api/account/settings/realtime-call-voice/models/{modelId}`，保持公开modelId，数字ID不替换为内部cloneModelId。
- 已有克隆选择使用 `POST api/account/settings/voice-clone/activate?modelId=...`，成功后重读同模型并确认CLONE；旧全局CLONE PUT已移除。
- 系统音色切换先读取目标模型。处于CLONE时同模型deactivate，重读后按需PUT；停用失败仅status只读确认，更新失败仅重读确认，不自动重复业务写入。
- Controller使用操作目标模型，保留busy/generation/账号隔离。结果不明提示“音色设置尚未同步，请刷新状态后再操作”，阻止重复写入直到手动刷新，不声称原选择必然保留。
- 候选确认独立，创建/删除及页面布局未修改。

## 修改文件
业务源码仅3文件：`api_call_model_repository.dart`、`api_clone_voice_repository.dart`、`call_model_controller.dart`（均在lib/features/call_models下，分别153/101/314行）。测试修改call_model_api_test、clone_voice_api_test、clone_voice_controller_test，新增model_scoped_voice_contract_test。主线程其他未提交改动保留，不提交推送。

## 验证
固定Flutter3.32.0/Dart3.8.0：
- `flutter test test/features/call_models --reporter expanded`：167项通过。
- `flutter test test/features/call_models/model_scoped_voice_contract_test.dart test/features/voice_clone test/shell_clone_workbench_test.dart test/shell_developer_workbench_test.dart test/extended_device_stage_test.dart --reporter expanded`：456项通过，与前项有重叠，不累计。
- `flutter analyze`：无问题。
- `openspec validate --all`：111通过、0失败。
- `git diff --check`：通过。

新协议测试实际经过AccountApi/Dio离线adapter，覆盖当前A/目标B选择与重开、数字ID、双向切换、激活未生效、停用结果不明、停用后读取失败、系统更新丢失回包的只读核对及账号切换；现有Controller/UI/入口回归覆盖busy、候选确认、旧响应及试听停止。
首轮协议19通过4失败：测试读取Dio queryParameters属性，而AccountApi实际将参数编码在URI；核对请求后修正为uri.queryParameters。首次analyze发现2条新测试lint，机械修正后通过。未重复任何真实业务请求。

## 待验
- [ ] Android/iOS真机：克隆选中、系统切回、关闭重开和失败提示。
- [ ] 授权测试账号的实际SDK activate/deactivate及模型级音色联调。
本轮未执行真实认证、生成、收费或外呼，未构建安装；仅修改明确范围Dart业务，按增量规则无需重打平台包。自动测试通过不代表现场问题已在真机验收；change保留active，不归档。
