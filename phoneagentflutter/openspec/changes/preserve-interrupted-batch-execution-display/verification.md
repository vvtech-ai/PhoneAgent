# 验证记录

## 基线与现场边界

- Flutter 基于最新 origin/codex/dev 的 6689ec495069e55a2568d26f47acd47ddc2cf14d；Java 指定 feature/test_v1.7.0 为 3d5230dda59a945a6b7f786025c1e276290d0fd9。
- 原 Flutter 检出有另一项 iOS 诊断未提交内容并阻止快进，因此本次在独立干净检出实施，不暂存或改写原检出，不复制私有配置或构建输入。
- 用户视频显示：断流后当前页执行占位消失，历史重进正常。用户已澄清历史重进是正常对照，不将其签成新的异常。
- 2026-10-22 10:15:59 诊断记录 agentStream failed 后开始同批补查；10:17:54 发出取消请求；账本 seq32 于 10:18:33 提交 FINISHED，10:18:38 客户端 visibleResult 为 6/6、pageWaiting=false。逐路为三路取消、一路失败、两路结果不明确，不能称全部成功。
- 同时出现的 taskResultRead/state 是结果已读确认失败，不证明批次结果没有到达。原现场证据仅作问题形状与时间线依据，未取得现场 APK 对应源码 SHA，不宣称新代码已在该设备验收。未提交原会话 ID、账号、联系人、电话、原始日志或视频。

## 失败重现与最小修复

现有 batch_foreground_resume_test 基线 4/4 通过，但不检查执行占位。新增 interrupted_batch_execution_ui_test 在真实 Controller、VoiceHost 和 Page 中执行合法前后台生命周期、全屏 Navigator push/pop、SSE network failure 和原批次进度读取。

原代码的四项有效 RED 均为执行卡片消失：Android / iOS 各两例，分别覆盖断流与补查、断流后停止。修复只增加 ConversationBatchActivity 纯投影，页面与顶栏复用，不修改执行、停止或恢复状态 owner。

GREEN 连续覆盖：同一 slot element 在运行、来电断流、核对、可信逐路状态恢复和汇总期间保持；phase 仍为 ready，原输入准入保持；gateway.start 始终一次，补查只读原 session / batch。停止后原控件回调为空且请求一次，可信结果清理卡片及门禁；静态未确认停止加载，普通任务与真实思考保持。

## 关联基线失败

12 文件首轮结果为 74 通过、1 失败：task_160_stop_test 的 ledger final before progress recovery releases the active batch。该测试使用 PENDING / EXECUTION_ERROR，却期待停止门禁释放，与最新分支既有 stopSettled 合同相反。

临时仅回到 HEAD 的两处原展示源码运行同一用例，仍为相同失败（expected batch.active=false，actual=true）；随后按字节恢复本次源码。没有修改停止生产逻辑。将该终态释放场景的 fixture 改为 FINISHED，保留 PENDING / UNCLEAR 及原释放断言；stop_reentry_recovery_test 中 EXECUTION_ERROR 不释放停止门禁的相反场景继续通过。不是为本次展示修复放宽停止语义。

## 最终定向验证

固定工具链 Flutter 3.32.0 / Dart 3.8.0；未修改 pubspec.yaml、pubspec.lock、平台、插件或依赖。新检出复用相同锁文件的已有 package_config，使用 --no-pub；访问 SDK lockfile 需要受控工具权限。日志只保存在忽略的 .local 下。

- 12 文件、75/75：interrupted_batch_execution_ui、conversation_thinking_ui、batch_foreground_resume、stop_reentry_recovery、stop_transient_header_status、conversation_stop_coordinator、conversation_stop_late_event、task_160_stop、batch_progress_recovery、conversation_thinking_stream、conversation_message_merge、stop_button_dots。
- 6 文件、60/60：tts_composer_control、conversation_feedback_prompt_parity、native_business_recovery、native_task_result_ui_parity、batch_receipt_widget、batch_receipt。
- 上述均使用 flutter test --no-pub --reporter expanded，退出码为 0；总计 18 文件、135 项，不宣称全量测试通过。
- 六个本次 Dart 文件 flutter analyze --no-pub：No issues found；dart format --output=none --set-exit-if-changed：0 changed；git diff --check 与严格 UTF-8 检查通过。
- openspec validate preserve-interrupted-batch-execution-display --strict 通过。
- requesting-code-review 独立只读源码审查及补充的全屏路由 / 基线 fixture 复核均无 actionable findings。

## 职责与交付边界

实现仅涉及 Flutter 的三个 presentation 文件及定向测试。Java 当前进度、账本与停止合同已足够，本次无 Java 源码或配置修改，不新增后端提交。共享三端任务编排合同不变；知识库仅补充 Flutter 投影职责。

Android / iOS 一致性由共用 Dart 实现和两套主题 Widget 连续回放验证。未执行新 APK / iOS 原生构建、安装、真实来电、真实音频、外呼、支付、后端部署或线上写数据；不以模拟回放代替设备验收。PMReport 内置登记中无本次实际 Flutter / Java 仓库，不代报只读旧项目。

源码与规格提交 2059661b3563dd5b85f5522a30a5a08c7fc650b0 已正常快进推送 origin/codex/dev；未强推，提交前再次 fetch 确认基线仍为 6689ec49。Java 分支无本次修改且工作区干净，不创建无实际变化的 Java 提交。
