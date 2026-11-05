# 任务

- [x] 读取当前规则与相关规范，对照原生回填和国家语言规则。
- [x] 创建规范并通过 openspec validate --all。
- [x] 微批一：新增控制器和页面回归，更新旧 peer 断言，复现旧实现差异（最多三个测试文件）。
- [x] 微批二：控制器复用默认语言规则，历史回填原子更新，保持其余配置。
- [x] 执行相关定向测试、flutter analyze、OpenSpec 和 diff 校验，更新根任务及问题记录。
- [ ] 用户验收；验收前不归档。

## 验证进度
- 规范先行：openspec validate --all，183项通过。
- 微批一共3个测试文件；旧实现定向24项中13通过、11失败，均为 peer 仍保留 fr 而非国家默认语言，包含Android/iOS页面接线。预期回归失败，不涉及设备或外呼。
- 微批二仅修改 TranslationSetupController：country/restoreHistory 共用默认语言函数，历史配置一次 _change 保存；无UI、接口或平台源码改动，控制器211行无需拆分。
- flutter analyze：No issues found；dart format --output=none --set-exit-if-changed（4个源码/测试文件）无变化。
- 修复后定向263项全部通过，包含Android/iOS主题页面、历史有效/缺失/失效我方语言、国家目录优先、同国家重选、持久化、配置保持和无自动拨号；不是全量回归。
- 测试命令：
```sh
flutter test test/features/dialer test/features/translation/translation_history_language_test.dart test/features/translation/translation_setup_test.dart test/features/translation/translation_preferences_persistence_test.dart test/features/translation/translation_dial_summary_directory_test.dart test/features/translation/translation_dialer_return_guard_test.dart test/features/translation/translation_presets_return_guard_test.dart test/features/translation/translation_settings_return_guard_test.dart test/features/translation/unified_dialer_ownership_test.dart test/features/translation/translation_preset_auto_prompt_test.dart test/features/translation/native_translation_presets_test.dart --reporter expanded
```
- Git diff空白校验通过；不修改平台/依赖/构建链，未打包、安装或真机验收，未触发真实认证和通话。用户随后授权本项提交推送codex/dev；真机验收前不归档。
