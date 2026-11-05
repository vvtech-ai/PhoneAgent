# 验证记录

## 基线与旧版证据
- Flutter 独占修改 `D:/work/04phoneAgent/_isolated/phoneagent-task-flow`，`codex/dev@921385e8`，开始 Git 干净。首次 `git fetch origin` 后 `origin/codex/dev` 同提交，无需快进；只发现其他远端分支更新。后续提交及远端再次前进的整合见末节。
- 外部必读导航属于 Chaken-OMS，已确认不将其配置/模块当作 App 事实。本仓 AGENTS、README、迁移基线及 active change 是本次依据。
- 只读 `aiassistant-app@8f235920`：`app/src/main/java/com/vvtech/aiassistant/features/assistant_calls/AssistantDialerPreferenceState.kt` 的 selectCountry 写国家默认 otherLanguage；`AssistantDialerStateHolder.kt` 的 prepareContactNumber/restoreHistoryTarget 共用选择；`DialTranslationLanguagePolicy.kt` 的 preferredDialLanguageCode 优先有效 selected，`AssistantCallsDialSheet.kt` 将同语种拨号校验独立处理。
- 只读旧单体 `a0bedb12`：`android/app/src/main/java/com/vvtech/aiassistant/features/assistant_calls/AssistantDialerPreferenceState.kt` 的 selectCountry 写 inferredLanguageForCountry；两个旧版各自的 `features/assistant/FinalOtaUpdateDialog.kt` 均仅展示非空白 releaseNotes、左排、14sp/20sp。只通过 git show/grep 阅读，未改旧检出或构建。

## 微批一 RED → GREEN
- 新增国内/海外有效模型下 US→CN 控制器回放，以及 Android/iOS 正式 route 连续国家选择→中国联系人→手选英语/目录刷新→历史中国号码→同语种拨号拦截。号码使用合成值，不复制用户联系人。
- 命令：`D:/tools/flutter-3.32.0/bin/flutter.bat test --no-pub test/features/translation/translation_language_alignment_test.dart test/features/translation/translation_dialer_parity_test.dart`。
- RED：22 通过 / 5 失败，两个模型分支 `Expected zh / Actual en`，双端正式页面无“中文 对方”，另一个既有空模型语言列表测试迁移 CN 预期后同样失败。
- 最小修复只删掉 `_normalize(resetPeer: ...)` 清空国家已选语种的路径，模型不支持时继续原有回退。GREEN：27 项全部通过。
- 兼容迁移：空模型支持列表代表无限制，CN 默认应保留 zh，修正原先自动避开 caller 的 en 断言；纯缺失/非法语种的避同语言 fallback 用例仍保留通过。

## 微批二 RED → GREEN
- 命令：`D:/tools/flutter-3.32.0/bin/flutter.bat test --no-pub test/features/app_update/native_update_notes_test.dart`。
- 双平台共四项 RED：正文实际 center（预期 left），空白说明未显示兜底。共享控件说明改为 left、14/20、trim 空白检测；非空正文保持原内容及换行，标题/版本/下载状态和按钮均未调整。GREEN：4 项通过。
- 回归检查真实 RenderParagraph 的对齐、字号、行高、多行内容以及独立下载状态；正式 offer/install/iOS 接线继续使用该同一控件。

## 扩大回归与直接相关旧断言
- 首次扩大集合 470 通过 / 5 失败。其中 1 个为命令误填不存在的 `translation_persistence_test.dart`，不是产品失败；纠正为实际文件后不再使用该路径。
- 校正命令去掉不存在路径后，以 `--reporter json` 对 dialer 全目录、语言/历史/返回守卫/所有权、联系人翻译入口、app_update 全目录、about_update 与 settings_update_entry 运行：470 通过 / 4 失败。
- 四项都在 `test/features/dialer/dial_recent_ui_test.dart:168`，组合为 Android/iOS × restrictPeer false/true、translation=true。恢复首条美国 `+12025550101` 系统历史，无显式保存 caller/peer 字段（见 PreviewDialRecentSource）。当前 caller=en，国家默认 peer=en；旧断言 peer=zh 来自本次删除的避同语言回退。根据相同旧版规则仅将该断言改为 en，保留零拨号、后续历史、开关及手选语种断言，不修改其他业务。
- 最终命令：`D:/tools/flutter-3.32.0/bin/flutter.bat test --no-pub test/features/dialer/dial_recent_ui_test.dart test/features/translation/translation_language_alignment_test.dart test/features/translation/translation_dialer_parity_test.dart test/features/translation/translation_history_language_test.dart test/features/translation/translation_setup_test.dart test/features/translation/translation_preferences_persistence_test.dart test/features/app_update/native_update_notes_test.dart`，7 文件 **89 项全通过**。该轮包含上述四项旧断言的复跑和真实偏好存储回归；未再次无故扩大整仓。

## 静态检查与边界
- `flutter analyze --no-pub`：No issues found。
- `openspec validate repair-country-peer-and-update-notes --strict`：valid。
- `git diff --check` 与改动文件 UTF-8/中文读回检查通过。
- 本轮未改 API releaseNotes 内容或字段语义，未改 pubspec/lock/平台/版本、任务编排共有规范、后端或其他任务文件。
- 自动回放不代表真实机型画面、音频、更新下载安装或外呼验收；无 APK 构建、安装、真实下载和业务请求，不归档 change。

## 完成本项后整合最新 App
- 主会话复核生产差异后授权本地中文提交与合并；本项 13 文件提交为 `91e3e8e1`（修复翻译国家语种联动并对齐更新说明左排）。
- 再次 fetch 确认 `origin/codex/dev` 已比初始基线前进 11 提交至 `e1016c15`。正常 merge 创建 `0bca444f`（合并最新开发分支并保留国家语种与更新说明修复），未 rebase/force；tasks 与问题日志由 ort 自动合并，无冲突，双方记录均保留。
- 已读取最新 AGENTS 新增统一基准；本轮遵循用户明确指定的 `codex/dev` 整合路径，不擅自切交付分支。共有规则块和远端功能无本项修改。
- 合并后使用上文相同最终七文件命令复跑，**89 项全部通过**；`flutter analyze --no-pub` 无问题（34.9 秒），当前 change strict 校验通过。
- `git merge-base --is-ancestor origin/codex/dev HEAD` 返回 0；相对该远端差异仅为本项 13 个白名单文件，AGENTS、批量结果诊断和系统试听增量保持远端内容。UTF-8/中文读回及 diff 检查通过；未推送，由主会话再次核对远端。
