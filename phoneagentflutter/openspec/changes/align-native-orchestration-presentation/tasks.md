## 1. 对照与规划

2026-10-16 后续提交授权：用户要求提交全部剩余改动并排除 IndexTTS。本次合并工作区定向 990 项全部通过（2分44秒），analyze 无问题，5个相关change严格校验通过；全仓173通过/3项既有规格失败。Flutter 的 ASR、编排、单呼、录音/权限及配套测试文档统一本地提交，Java IndexTTS 整组和安装包排除；设备待验项继续保留。证据位于 D:/Caches/bug-23737-23739-23748-23731/remaining-flutter-commit-*。
- [x] 核对原生和 Flutter 入口、已提交/未提交边界及当前规则。
- [x] 记录修复范围、身份/轮次规则与验证范围。
- [x] OpenSpec 全仓校验已执行：149 通过、3 项既有 delta 缺场景失败；本 change 通过。

## 2. 展示修复
- [x] 新增消失、重复、乱序定向回归并记录失败：首批 6 项失败；连续交互追加 2 项失败。
- [x] 修正实时替换与文件定位。
- [x] 统一实时和历史恢复的展示归一化。
- [x] 复现并修正文档批次重复、跨确认命令的通用拨号轨迹重复；修复同次通话结果说明遮挡真实字幕导致录音入口消失。

## 3. 验证与交付
- [x] 受影响定向测试、静态分析、diff/UTF-8 读回及工作区保护检查。
- [x] 更新根 tasks 和问题日志；记录实际证据及未验收项。
- [ ] Android/iOS 同输入真机展示验收（本轮未执行）。

## 4. 用户追加规则策略复核及修复（2026-10-16）

2026-10-16用户已明确“继续修复”，以下三项进入实施，历史复核证据保留。

- [x] 对照当前原生的最终 projector、identity policy、TaskConfirmationPresentationPolicy 和 PureVoiceThreadList；区分已提交规则与未提交 askUser 修改。
- [x] 补充6个隔离重放场景，确认3项通过、3项失败；上一轮13项回归本轮复跑仍全部通过。合并命令实际结果16通过/3失败，退出码1；不能据此前505通过声称全部策略一致。
- [x] 同用户轮次候选语义去重：补充同轮候选标签/通用标题和联系人尾号归一；保留不同明确工具身份。修复前重放得到两条，修复后一条；同名不同号码、后续用户重新查询保留独立候选。
- [x] 缺少工具ID的确认卡去重：补充同轮CallSpec内容比较和timeline fallback；真实不同ID不合并，比较排除传输元数据并保留scene/协商/边界/人数差异。修复前同spec显示两张，修复后一张。
- [x] 跨用户轮次的确认历史保留：账本构建与最终展示都保护旧快照；后轮重复确认只移除重复结构卡，独立正文保留并使用独立展示key。同轮相同ID的原位更新回归继续通过。

原生源码依据（只读，HEAD 5e0c362676cae077449b192f2f316231cf1f3298；下列差异规则也已用git show HEAD核对稳定分支）：
- `D:/phone-refactor/aiassistant-app/app/src/main/java/com/vvtech/aiassistant/features/assistant_pure_voice/PureVoiceConversationStepProjector.kt`：68–79跨轮确认、243起候选语义归一。
- `D:/phone-refactor/aiassistant-app/app/src/main/java/com/vvtech/aiassistant/features/assistant_conversation/policy/CallConfirmationIdentityPolicy.kt`：7–21无ID/spec fallback。
- `D:/phone-refactor/aiassistant-app/app/src/main/java/com/vvtech/aiassistant/features/assistant_pure_voice/PureVoiceThreadList.kt`：333回执、381正文。此前仅按ReceiptOrderTest名称推断“正文先于回执”不成立；最终渲染两端均为回执后正文，已排除此疑点。

重放脚本（Git ignored）：`.dart_tool/native_policy_alignment_review_test.dart`；完整输出`D:/Caches/flutter-native-policy-review-20261016.log`。

```powershell
& 'D:\Tools\flutter-3.32.0\bin\flutter.bat' test --no-pub .dart_tool/native_policy_alignment_review_test.dart test/features/conversation/native_presentation_parity_test.dart --reporter expanded
```

上轮复核仅增加隔离重放脚本与更新记录，当时三项未修复；本轮用户批准继续修复后已转为正式回归并实施。上述历史重放证据不代表用户设备现场；真机验收继续单列。

## 5. 继续修复验证（2026-10-16）

- [x] 将隔离6场景转为正式`test/features/conversation/native_policy_alignment_review_test.dart`，先复现3失败，再修正。
- [x] 追加跨轮/异ID/不同spec/contact尾号/独立正文等边界；额外复现实时重复确认吞正文和传输元数据干扰spec比较，各自修复。
- [x] 验证历史卡激活同时匹配工具ID和确认内容，不为不同内容的当前请求上报已呈现；含calls/正式shell接线的43项通过。
- [x] 最终定向/扩展回归、静态分析、OpenSpec及UTF-8/diff检查，并同步交付记录。

本次证据：
- 最终当前代码相关集合560项全部通过，退出码0，耗时1分25秒；完整日志`D:/Caches/flutter-policy-fix-delivery-20261016.log`。集合为原相关对话/calls及shell集合，追加匹配`ConversationMessagePresentation|ConversationOption`的直接调用方，并包含`test/shell_call_workbench_test.dart`。核心三项失败已关闭，Android/iOS同输入真机验收仍未执行。
- 继续修复前正式复现3项失败；新增边界又复现实时去重吞独立正文、传输元数据干扰无ID确认匹配，各自修复。
- 正式`native_policy_alignment_review_test.dart`共15项，含原6项、跨轮/异ID/联系人号码/独立正文和8字段CallSpec内容比较及历史卡激活。
- 首次相关扩展回归554项通过；补齐CallSpec比较后定向62项通过；最后增加历史卡激活校验与正式页面接线后43项通过。没有把不同阶段的数量相加为一次执行结果。
- 最后`flutter analyze --no-pub`无问题，退出码0；曾有一条花括号lint，修正后重新分析通过。
- 本change严格校验通过；全仓OpenSpec150通过/3失败，仍为此前三个MODIFIED遗漏场景的change；本轮未扩大修改这些历史问题。
- `git diff --check`通过，改动源码/测试UTF-8读回无替换字符，均小于500行。当前工作区其他通话/思考卡/语音/音色等任务修改保留；未提交推送，不修改原生/后端/数据库，不打包安装、不触发真实外呼。

## 6. 远端智能合并（2026-10-16）

- [x] 保存本地tracked恢复点及untracked清单，快进至b67ddb0f，解决16个冲突；恢复点继续保留。
- [x] 核对远端返回/确认/权限/音色/思考模型修复，保留本地编排去重和历史保护，适配远端typed thinking与批量文件投影。
- [x] 首轮相关集合1621通过/4失败，定位三类差异，不将拉取前560通过当作合并版证据。
- [x] 修正权限弹窗播报、字幕即时跟随及音色测试预期；首轮失败对应6个文件15项全部通过，最终相邻流程集合748项全部通过（2分6秒，退出码0）。
- [x] flutter analyze --no-pub无问题；本change及同步的音色/语音change严格校验通过；全仓OpenSpec173通过/3项既有失败。diff/UTF-8和Git状态检查完成，根记录已同步。
- [ ] Android/iOS实际权限、字幕、音频及同输入卡片验收（本轮未执行）。

最终相邻集合包含全部calls/call_models、对话voice、权限/思考/批量产物、两份本地编排策略回归、语音连续性，以及call/conversation/batch的正式shell接线。日志`D:/Caches/flutter-pull-merge-final-20261016.log`；首轮1621通过/4失败日志`D:/Caches/flutter-pull-integration-20261016.log`保留，不把两次数量相加。最终仅复跑变化影响的集合，未宣称全仓测试或设备验收通过。

快进57提交至b67ddb0f后HEAD与已fetch的origin/codex/dev一致，无未解决冲突和暂存改动。原35个untracked全部保留，另保留本地Cupertino返回回归；stash@{0}与refs/codex/backups/pre-pull-20261016-orchestration继续保留。未提交/推送/打包/安装，不修改原生参考与后端。工作区已有其他音频诊断任务修改继续保留，不纳入本轮修复结论。

## 拉取前历史验证证据（2026-10-16）

- 固定工具链 `D:/Tools/flutter-3.32.0/bin/flutter.bat --version`：Flutter3.32.0/Dart3.8.0；测试使用`--no-pub`，未刷新依赖。
- 新增`native_presentation_parity_test.dart`共13项：首批8项中6项失败，修复后通过；追加连续交互两项失败后修复；文档协调和跨确认命令轨迹两项再现失败后修复。既有`terminal_receipt_overlay_parity_test.dart`首轮1项失败，修复同次有效字幕保留后3项通过。
- 最终相关回归：505项全部通过，退出码0，耗时1分37秒。日志`D:/Caches/flutter-orchestration-20261016-final.log`；此前扩展集合为502通过/1失败，未掩盖失败。
- 最终`flutter analyze --no-pub`：No issues found，退出码0。
- `openspec validate align-native-orchestration-presentation --strict`通过；最终`openspec validate --all --json`为150通过/3失败，退出码1。失败均为本轮修改前已存在的MODIFIED场景遗漏：`incremental-validation-policy`、`login-presentation`、`native-feature-parity-audit`。新增其他线程change使总数从152增至153，不把全仓标记通过。
- `git diff --check`退出码0；新增/修改源码、测试UTF-8读回无替换字符，均不超过500行。共有文件中的既有thinkingText/思考卡方法保留；本轮仅对MessageStore的交互ID作业务修改，不提交其他线程代码。
- 本轮未涉及平台/依赖或构建链，不重新打包；未真实外呼，不修改原生/后端/数据库，不提交推送，不归档未验收change。

最终定向测试命令（在项目根目录，PowerShell）：

```powershell
$env:PUB_CACHE = 'D:\Caches\Pub\Cache'
$affectedTests = @(rg -l 'ConversationMessages|ConversationMessageMerge|ConversationMessageStore|ConversationController|ConversationPresentationProjection' test/features/conversation -g '*_test.dart')
$affectedTests += @('test/features/calls', 'test/shell_history_workbench_test.dart', 'test/shell_receipt_workbench_test.dart', 'test/shell_batch_confirmation_test.dart', 'test/shell_conversation_ports_test.dart', 'test/shell_contact_tools_workbench_test.dart', 'test/shell_attachment_workbench_test.dart')
& 'D:\Tools\flutter-3.32.0\bin\flutter.bat' test --no-pub @affectedTests --reporter expanded
```
