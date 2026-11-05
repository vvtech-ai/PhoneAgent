# 任务

- [x] 阅读规则、需求、现有历史/语种回退规格，核对当前工作区。
- [x] 创建本次规格并通过 openspec validate --all。
- [x] 微批一：控制器和页面传递并恢复有效历史对方语言，保持其他配置与 UI。
- [x] 微批二：补齐控制器优先级/持久化及双端页面接线回归。
- [x] 运行 analyze、定向测试、OpenSpec和diff检查，更新根任务及问题记录。
- [ ] 用户验收，验收前不归档。

## 验证进度
- 首次4文件定向53通过、3失败；历史恢复与双端页面新增用例均通过。失败为既有离线硬编码语种预期（2条）及服务器默认语种被补入语言列表后的旧无效值断言（1条），核对当前实现后修正测试，不改变国家切换业务规则。
- 扩展拨号/直接调用方定向264通过、2失败；失败为持久化用例同类缺少目录预置及摘要用例仍断言原始en而非现行本地化“英文”。仅校正测试夹具/展示预期，业务源码未扩大。flutter analyze 已无问题。
- 最终定向266项全部通过（拨号模块及历史/配置/持久化/目录摘要/页面返回/账号归属直接调用方），包含Android/iOS主题、普通/翻译模式历史选择及无自动拨号。
- Flutter3.32.0 analyze：No issues found；OpenSpec207项通过；Dart格式化及git diff --check通过。修改源码均小于500行，不需要文件例外。
- 用户已授权提交并推送codex/dev，保留最新远端更新，不强推；无构建、安装、真实认证/外呼。真机与用户验收待完成，未归档。

## 最终验证命令
```sh
flutter analyze
flutter test test/features/dialer test/features/translation/translation_history_language_test.dart test/features/translation/translation_setup_test.dart test/features/translation/translation_preferences_persistence_test.dart test/features/translation/translation_dial_summary_directory_test.dart test/features/translation/translation_dialer_return_guard_test.dart test/features/translation/unified_dialer_ownership_test.dart --reporter compact
openspec validate --all
git diff --check
```

- 提交前基于远端a4b22618重放本次提交，仅两份追加记录冲突，已保留双方记录；集成后历史/双端页面44项复验通过，analyze无问题，OpenSpec208项通过。
- 2026-10-19 20:08 +08：首次push因远端新增22859e94被拒绝（fetch first），随后fetch超过两分钟无完成输出；核对进程及干净工作区后仅终止本次fetch，带低速超时重试成功。已重放到22859e94，保留可信被叫提醒修改，无业务代码冲突；未强推或丢弃远端内容。
