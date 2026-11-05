# 最终整合审查与修复

最终门禁PASS：F1/F2及逆序回包残余已关闭，无新增Important/Critical。下面保留原始发现、修复RED/GREEN及最终差异确认；不改写真实运行证据边界。

# Final whole-branch independent review

Date: 2026-10-21. Read-only review of the immutable Flutter `dc535c9b..387e35a84ed32992eee0bd9a246b0afb4fe226aa` package, Java `final-java.diff` ending at `a51780fa0e0ae372c41d00e318031e128e760ff2`, and Web `final-web.diff` ending at `2c898b6dbdca8995183cb7ad51743d0f23e8a5fe`. This report is the sole file written by this reviewer. No tests, build, installation, network operations, source/index/ref changes, or additional reviewers were used.

Reviewed the final brief including USER LATEST OVERRIDE, progress rulings, repository rules, current R01–R09 deltas and implementation/commerce verification records, completed task reviews, production differences and relevant calling/test code. The external knowledge navigation describes Chaken-OMS and is not a source of PhoneAgent runtime facts. Root is independently running the latest integrated verification; its eventual results are not preclaimed here.

## Strengths

- Payment failures retain their authoritative HTTP status through AccountApi and the commerce adapter; payment 5xx takes precedence over an allowed business code, while the four service protection codes preserve the existing limits and HTTP 200 business envelope. Both purchase surfaces now consume safe controller errors. No automatic repayment or new payment state machine was introduced.
- Membership names come from a shared structured-fact formatter. Active paid rank determines renewal/upgrade without using queued durations; ledger navigation has a separate full-width action. The supplied SVG is registered and wired to the existing home callback, and the extra voice template removal is narrowly scoped.
- Task feedback is an ephemeral operation stream with notice ownership, and the actual App Navigator registers the PageRoute observer. Popup menus preserve the current business page; account/route disposal can revoke visible and queued task notices without clearing unrelated owners.
- Restaurant phone availability is one nullable fact through search, normalization, option selection, live projection, historical projection and Flutter display. The actual restaurant call target is validated before confirmation; summary text cannot supply a missing execution phone. The earlier brand-plus-district regression is repaired.
- Existing task-level evidence distinguishes automated fixtures from real devices, SQL and payment channels, and records baseline failures without counting them as passes. Protected memory and STOP changes remain separately owned; the requested additions do not directly replace their state owners.

## Critical (Must Fix)

None identified.

## Important (Should Fix)

### F1 / P2 — Ordinary cuisines outside the short category list retain no-phone recommendations

- File: `D:/work/04phoneAgent/aiassistant-java/aiassistant-agent-sse/src/main/java/com/vvtech/aiassistant/agentsse/assistant/agent/tools/SearchTool.java:113` (also the keyword/broad routing calls; classifier at lines 247–256).
- Trigger: `search(category=restaurant, query=附近湘菜)` with valid location and a real upstream candidate named `湘菜馆` whose telephone is absent. Normalization produces `湘菜`; `isGenericCategory` does not recognize it, so `explicitNameTerm` returns `湘菜`. The new routing flag becomes `includeMissingPhone=true`; the no-phone candidate survives AMap filtering and then passes the name-contains filter. It is returned and displayed as a named no-phone exception despite the user requesting an ordinary cuisine recommendation. Common examples such as 鲁菜 and 杭帮菜 have the same classification problem.
- Impact: R08's ordinary nearby/area/cuisine callable-only contract is not met for normal cuisine searches. Users can again receive and select unusable recommendations. The prior name-filter heuristic existed, but this patch newly relies on it to grant the no-phone exception; the exception must require an actual named-place intent.
- Fix/verification: distinguish common cuisine/category intent from an explicit shop/brand using the existing classification extension point. Add a real SearchTool → AMap/filter RED/GREEN replay for non-listed common cuisines with mixed/all-no-phone candidates and filtering before the limit. Preserve explicit brands containing cuisine words and all previously repaired brand/district orders; avoid a blanket rule treating every name containing 菜 as generic.

### F2 / P2 — One deletion's automatic refresh discards another successful deletion

- File: `D:/work/04phoneAgent/_isolated/phoneagent-task-flow/lib/features/tasks/presentation/controller/task_controller.dart:203`; affected local removal at line 335 and final refresh at lines 204–208.
- Trigger: start allowed deletes for distinct tasks A and B in the same account/page. Let A succeed, and let its automatic `refresh(synchronizeStatus: false)` complete while B is still pending server-side, so the refreshed list contains B. That refresh increments the shared `_refreshEpoch`. When B subsequently succeeds, `hide` skips its local removal because its saved epoch no longer matches; the new `_operate` early return then skips both B's post-success refresh and its success feedback.
- Impact: B has been deleted on the server and its draft cleanup may have run, but the list still shows B and no success notice is delivered until a later user refresh. This is reachable through the UI because `TasksPage` disables only `state.busy.contains(record.ref?.key)` (line 185), preserving the approved per-target concurrency. Before the added `_operate` epoch return, the later successful hide still ran its own refresh.
- Fix/verification: separate account/explicit-refresh invalidation from a sibling operation's internal reconciliation, or otherwise guarantee durable successful deletion is reconciled for the still-valid account/page without resurrecting stale rows. Add a production-controller replay with two controlled deletion completions and A's page refresh explicitly completed before B succeeds; assert both rows removed, both requests once, and each valid result once. Keep manual-refresh stale-response, account disposal, delete-refresh-failure, per-target single-flight and route/Popup ownership regressions intact.

## Minor (Nice to Have)

None reported. No unrelated style or cleanup requests.

## Recommendations

Resolve F1 and F2 in one bounded final correction wave, retaining separate Java search-policy and Flutter task-controller responsibilities. Use the two concrete sequences above as failing evidence, then run their direct adjacent regressions. The already-reviewed payment, membership, SVG and voice source need no speculative changes.

## Declined to judge

- Historical ten-plus-minute payment duration attribution: expressly removed by the user's latest clarification; it is not a packaging prerequisite.
- Real payment/provider recovery, production deployment, isolated MySQL concurrency, real AMap results, physical Android/iOS appearance/audio and iOS packaging: no such execution occurred in this review; recorded fixture evidence cannot certify them. These are not newly imposed build gates.
- Independent correctness of protected memory-save-offer and newly merged STOP/media work: owned by other tasks. Reviewed relevant overlap and observed no additional R01–R09 interaction defect; did not launch a separate audit or request their modification.
- The known baseline shell-login failures, token-refresh test hang and Java OpenSpec no-delta failure: already distinguished and reproduced/reported by the owning workflow, with no new causal connection found in this patch; not counted as passing or silently repaired here.
- Artifact identity/signature and latest integrated test outcome: root's build/verification responsibility and not completed by this readonly reviewer.

## Assessment

**Ready to merge/package? With fixes — F1 and F2 remain open.**

The requested capabilities are largely coherent across the latest merged branches, but ordinary cuisine recommendations and overlapping successful deletions have concrete source-level gaps. After these two targeted fixes and their relevant verification, no additional source-review blocker has been identified; historical duration or unavailable real-device/SQL evidence must not delay the authorized build.


---

# 最终评审 F1 / F2 修复报告

日期：2026-10-21。按最终评审的一轮有界修复执行，未创建子代理。历史十余分钟支付归因不属于本轮范围。

## 固定范围与提交

| 仓库 | 基线 | 修复提交 |
| --- | --- | --- |
| Flutter `codex/dev` | `387e35a84ed32992eee0bd9a246b0afb4fe226aa` | `348e522ae7bb791b0224075b5e06c52a87f31761` 修复任务内部刷新误丢弃并发删除和置顶结果 |
| Java `feature/test_v1.7.0` | `a51780fa0e0ae372c41d00e318031e128e760ff2` | `814a0fe9be4a2b9887243b7f1bcb07f536342930` 修复普通菜系搜索误保留无号餐厅推荐 |

已读取 final-review.md、任务 brief / 实施报告 / 餐厅复审、本仓 AGENTS、相关 OpenSpec、任务编排知识库、README 和当前源码。外部导航明确属于 Chaken-OMS，未把它当作 PhoneAgent 环境事实。采用 systematic-debugging、test-driven-development / writing-good-tests 与 verification-before-completion。回归严格按本次授权范围，未重复根代理已完成的整包回归。PMReport 仍由根代理按本轮实际仓库统一处理。

每仓仅 1 个生产文件与 1 个测试文件；生产微批均不超过 3 文件。两处都是现有职责的缺陷修复，不新增状态机、接口、协议、配置、数据库表或 Redis key。

## F1：普通菜系资格分类

- `SearchTool.java`：仅扩展既有 `isGenericCategory` 的精确类别表，增加湘菜、鲁菜、苏菜、浙菜、闽菜、徽菜、杭帮菜、本帮菜、东北菜。继续按完整类别相等判定，不使用“含菜字”规则，不改变品牌 / 行政区顺序剥离、酒店、号码策略或候选排序。
- `SearchToolRestaurantPhonePolicyIntegrationTest.java`：新增 3 个真实 SearchTool → AMap service → candidate filter 测试。只模拟外部 AMap HTTP；对湘菜、鲁菜、杭帮菜分别覆盖两个前置无号 + 两个后置有号（候选上限为 2）、全无号后一次扩大仍为空，以及含上述菜系词的指定品牌保留真实无号门店。旧品牌 / 区域次序用例继续保留。
- 未来常用菜系通过同一精确分类入口扩展；本次未声称通用自然语言实体识别，也未增加 NER 框架。

工作目录 `D:/work/04phoneAgent/aiassistant-java`。环境已实际读回 OpenJDK 17.0.20.1 Microsoft：

```powershell
$env:JAVA_HOME='D:/tools/phoneagent-jdk17/jdk-17.0.20.1+1'
$env:JAVA_TOOL_OPTIONS='-Dfile.encoding=UTF-8'
& "$env:JAVA_HOME/bin/java.exe" -version
```

有效 RED（退出码 1；10 tests / 2 failures / 0 errors / 0 skipped）：

```powershell
& 'D:/tools/apache-maven-3.9.14-bin/apache-maven-3.9.14/bin/mvn.cmd' -q -pl aiassistant-agent-sse -am '-Dtest=SearchToolRestaurantPhonePolicyIntegrationTest' '-Dsurefire.failIfNoSpecifiedTests=false' test
```

失败均为预期业务断言：`commonCuisinesFilterMissingPhonesBeforeLimit` 期望湘菜馆丙，实际返回前部无号湘菜馆甲；`allMissingPhoneCuisineQueriesStayEmptyAfterBroadening` 期望 empty，实际 ok。品牌例外等 8 项通过。没有将编译或测试夹具错误冒称 RED。

最小修复后一次完整定向 GREEN（退出码 0）：

```powershell
& 'D:/tools/apache-maven-3.9.14-bin/apache-maven-3.9.14/bin/mvn.cmd' -q -pl aiassistant-agent-sse -am '-Dtest=SearchToolRestaurantPhonePolicyIntegrationTest,SearchToolTest,SearchToolPoiIntegrationTest,AmapRestaurantSearchServiceTest' '-Dsurefire.failIfNoSpecifiedTests=false' test
```

Surefire XML 读回：10 + 19 + 4 + 7 = **40 tests / 0 failures / 0 errors / 0 skipped**（原 37 项加本轮 3 项）。保留上限前号码过滤、扩大范围、V5 fallback、城市无坐标、明确品牌次序与酒店对照。

## F2：并发操作与内部刷新归属

- `task_controller.dart`：现有 `_refreshEpoch` 仍作为公开 / 手动刷新失效旧操作的边界；将其递增从私有 `_refreshPage` 移至公开 `refresh` 的分页分支。操作完成后的内部对账直接调用 `_refreshPage(false)`，不再使兄弟目标的在途操作失效。对账完成后仍核对本操作的原 epoch；公开刷新和 mounted/dispose 继续使旧反馈失效。查询代次 `_generation` 与已有分页流程保留。
- 删除成功仍先执行原精确 TaskRef 移除，再按原账号 / mounted 边界调用 afterHide，随后对账与一次性反馈；没有修改 afterHide、分页投影、未读、乐观置顶或通知 owner 实现。
- `task_concurrent_mutation_test.dart`：新增受控真实 TaskController 回放，分别为 delete A / delete B 和 delete A / pin B。在 B pending 时明确完成 A 的服务端删除与内部页面回包，确认当前页面仍有 B，之后才完成 B。断言 B 删除后的局部移除 / 后续刷新或 B 置顶权威投影、两次结果各一次、每个目标 single-flight、草稿清理与 busy 释放。
- 继续复用既有 owner 与两个既有计数器；没有添加第二套 mutation 状态、恢复队列或 UI 分支。

工作目录 `D:/work/04phoneAgent/_isolated/phoneagent-task-flow`。

有效 RED（退出码 1；0 通过、2 失败）：

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' test test/features/tasks/task_concurrent_mutation_test.dart --reporter expanded
```

delete B 回放实际还剩一行，期望为空；pin B 回放实际返回 false，期望 true。均已执行真实控制器、真实 TaskPageMutation 与 effect 流，不是复刻 epoch 算法的单元测试。

修复后一次完整定向 GREEN（退出码 0，**69/69**）：

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' test test/features/tasks/task_concurrent_mutation_test.dart test/features/tasks/task_operation_feedback_test.dart test/features/tasks/task_feedback_route_lifecycle_test.dart test/features/tasks/task_pagination_test.dart test/features/tasks/task_mutation_projection_test.dart test/features/tasks/task_pin_window_parity_test.dart test/features/tasks/task_action_overlay_test.dart test/features/tasks/tasks_pinned_host_test.dart test/features/conversation/task_draft_cleanup_test.dart --reporter expanded
```

覆盖新增 2 项和直接相邻的手动刷新失效迟到 pin 成败、账号 dispose 不清旧草稿、删除刷新失败仍移除、每目标重复抑制、pin/unpin/pin、乐观回滚与未读、分页窗口、真实 PageRoute / PopupRoute 及可见 / 排队通知归属、草稿清理 owner。无新增队列或恢复策略。

静态检查（退出码 0，No issues found）：

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' analyze lib/features/tasks/presentation/controller/task_controller.dart test/features/tasks/task_concurrent_mutation_test.dart
```

执行 Dart format 后发现它连带重排原 markReadRef / clearUnread 的未改块，已精确恢复该原块，最终生产 diff 仅 3 个必要 hunk（7 行新增 / 6 行删除）。该恢复仅还原无关格式，不改变已验证语义，未重复整组测试。

## 最终检查与边界

- 4 个源 / 测文件严格 UTF-8 解码成功，无 U+FFFD；中文分类、测试内容及现有中文提示读回正常。`git diff --cached --check` 均通过。
- 两仓均显式路径 add / commit；每份提交恰为本轮两个文件，提交命令均退出码 0，完整 SHA 已读回。
- 根代理拥有的两仓 `openspec/changes/polish-ui-payment-and-restaurant-search/implementation.md` 未暂存。Flutter 提交前另发现 `test/features/conversation/task_160_stop_test.dart` 新的外部修改，已告知根代理且未触碰或纳入提交。
- 这是合成 HTTP / repository 边界下的自动连续回放；未请求真实 AMap、真实业务后端、MySQL、支付、外呼、设备、音频、安装或部署。不把自动用例当作现场验收。
- 未 pull / push / 打包 / 安装 / 部署 / 业务写入，也未重跑根代理已通过的整包回归或已知基线挂起用例。
- 本报告不代替独立评审；交根代理安排既有最终评审员对上述两个固定修复范围恰好一次复审。

## 同一最终修复波的 F2 反向时序补正

当前唯一复审门禁仍在进行，根代理转交同一 F2 的残余交错；没有新建代理或启动第二轮全面评审。补正基线固定为 `348e522ae7bb791b0224075b5e06c52a87f31761`，追加中文提交 `309e621ec4204d015cbfadb78f65d15731c35b6f`（防止迟到任务刷新覆盖已确认的置顶结果）。Java 未变，仍为 `814a0fe9be4a2b9887243b7f1bcb07f536342930`。

### 基线与并行改动说明

原 Flutter 任务指定基线是 387e35a8，但执行期间其他 owner 合入了 7ab69373 / 19354f8f / 139477bc 的 iOS 诊断更新。348e522a 的实际父提交为 139477bc，本代理首份提交依然只包含上述两个自有文件。第一次 69 项命令没有同时打印 HEAD，故不伪称该次运行精确基于 387e35a8；已记录当时源码与命令及随后提交身份。此次补正执行前与 GREEN 命令开始前均实际读回 HEAD=348e522a，再叠加本轮两个自有工作区文件。并行 STOP 的源码、测试、OpenSpec 与根代理交付记录均未修改 / 暂存；其验收由各 owner 负责。

### 机制与最小修复

原新增测试只控制 A 的刷新先结束，然后 B 成功。反向时序中，A 删除后的 loadPage 已取得旧快照但尚未返回，B 的 updatePin 先成功；旧页面随后在未变化的 `_generation` 下被接受，覆盖已经确认的置顶投影。

本次只在既有 `mounted && epoch == _refreshEpoch` 的有效 updatePin 成功分支加入两行：递增已有 `_generation`，同时将 loading / loadingMore 设为 false，再应用权威目标。旧查询会被现有 generation 判断丢弃；加载状态由使旧查询失效的当前 mutation 收尾，不依赖已经失效的旧查询 finally。公开 refresh 的 epoch、dispose、反馈 owner、分页、未读和 afterHide 均未改。

对紧邻 delete B 的同样反向交错也做了生产控制器回放：它原有成功删除分支已递增 generation，并启动自己的后续刷新，较新页面完成后再返回 A 旧页不会复活 B，因此不新增删除侧代码。

### RED / GREEN

在同一并发测试文件新增两个反向回放：A 内部页面 pending → B pin / delete 完成 → A 旧页返回。断言权威目标仍置顶 / 删除、两次有效 feedback 各一次、busy 释放且 loading / loadingMore 均为 false。测试不构造第二套状态机。

RED 命令（实际 HEAD=348e522a，退出码 1）：

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' test test/features/tasks/task_concurrent_mutation_test.dart --plain-name 'late delete A page' --reporter expanded
```

首次 1 通过 / 1 失败，置顶列表被覆盖为空使 `.single` 抛 No element。将断言改为直接比较 ID 列表后再次同命令，明确得到 **1 通过 / 1 失败**：期望 `['b']`，实际 `[]`。这是同一丢失权威投影的失败，第二次仅改进失败证据可读性；删除反向回放两次均通过。生产修复只实施一次。

修复后一次 GREEN 使用上文同一 9 文件命令（含新增 2 项），退出码 0，**71/71 通过**。本次未扩大测试范围。相同定向 analyze 命令退出码 0，`No issues found`。

最终生产 diff 仅 2 行新增；测试新增 55 行。两个自有文件严格 UTF-8 解码和 U+FFFD 检查通过，中文原文读取正常，暂存 `diff --check` 通过。显式路径中文提交只含两个文件；未改写前一次固定提交，没有混入并行工作。仍未 push / pull / build / install / deploy 或执行真实业务。交同一进行中的复审门禁继续确认。


---

# Final F1 / F2 scoped re-review

Date: 2026-10-21. Exactly one scoped rereview of Java `a51780fa0..814a0fe9be4a2b9887243b7f1bcb07f536342930` and the task-fix portion of Flutter `387e35a8..348e522ae7bb791b0224075b5e06c52a87f31761`, using the supplied immutable packages and `final-fix-report.md`. Read-only except this report; no repeated tests, builds, external calls, source/index/ref mutations or subagents.

## Strengths

- F1 changes only the existing exact category table. It does not classify every phrase containing a cuisine word as generic, so the explicit-brand exception and prior brand/district repair remain intact.
- F2 separates public refresh invalidation from mutation-driven reconciliation without adding a second controller or operation state machine. The original double-delete reproduction is directly represented by a controlled production-controller test.
- Reported RED failures match the actual findings: ordinary cuisine returns no-phone results; later successful deletion remains visible. GREEN evidence is 40 Java tests, 69 Flutter tests and targeted analyze; this reviewer inspected the code/assertions and did not rerun or independently claim execution.

## Original finding verdicts

### F1: ADDRESSED

`SearchTool.java:256–258` now recognizes the original 湘菜 / 鲁菜 / 杭帮菜 cases and other common regional cuisines as exact categories. Their name term is empty, so all existing nearby/broad/keyword routes select callable-only filtering. The added real SearchTool → AMap/filter tests verify mixed results before the candidate limit, all-no-phone results after broadening, and named brands containing those cuisine words. No new Important/Critical breakage identified in this Java fix.

### F2: ORIGINAL DOUBLE-DELETE SEQUENCE ADDRESSED

`task_controller.dart:203–206` now invokes private reconciliation without changing `_refreshEpoch`, while public `refresh` advances that epoch. Consequently A's completed internal refresh no longer prevents B's subsequent successful deletion from removing its target, cleaning its draft, refreshing and reporting success. The new test fixes the ordering from the original finding rather than merely checking the counter implementation. Public refresh/mounted invalidation remains present.

However, the newly permitted concurrent pin response has the concrete stale-page interleaving below. Therefore the complete Flutter correction cannot receive a clean quality verdict yet.

## Critical (Must Fix)

None identified.

## Important (Should Fix)

### F3 / P2 — Internal refresh can overwrite a sibling pin after reporting pin success

- Primary changed location: `D:/work/04phoneAgent/_isolated/phoneagent-task-flow/lib/features/tasks/presentation/controller/task_controller.dart:203–206`. Related accepted page publication: lines 124–131; pin response projection: lines 292–299.
- Concrete order: start delete A and pin B; let A succeed and start its internal `loadPage`; let that read capture B still unpinned but delay its response; complete B's `updatePin` with the authoritative pinned target; finally deliver A's older page containing unpinned B.
- With the new unchanged epoch, B applies its target and emits pin success. But B's response does not advance `_generation` (only the earlier optimistic start does), so A's read still satisfies the generation check and overwrites the entire page with the older unpinned B. The user sees a successful pin undone, and the normal-page cursor also reverts to the stale window.
- This is directly exposed by retaining sibling pin validity during internal reconciliation. The added pin test only completes A's page **before** B responds; it does not cover this opposite response order. The original code did not accept/report B's success after the changed epoch, so the new successful-then-overwritten behavior is a correction interaction rather than an unrelated requested audit.
- Fix: protect the authoritative pin result from an older internal page snapshot, using the current controller reconciliation/generation ownership. If invalidating that read, also settle or replace its loading lifecycle: simply incrementing `_generation` at response time would cause the old `_refreshPage` finally block to skip clearing `loading`. Add the reverse-order production-controller replay and assert final pinned identity, cursor/loading, each request/effect once, plus preserved public refresh/account isolation.

## Minor

None.

## Declined to judge

- Concurrent iOS APNs diagnostic commits in the Flutter range are outside these two corrections; their changed native/diagnostic paths do not touch the task controller or Java search classification. No independent re-audit or new observation requiring their revision is raised.
- Natural-language entity recognition beyond the original common-cuisine finding is not a new requirement for this scoped fix. The exact-category solution is accepted for F1; no taxonomy expansion loop is requested.
- Real devices, SQL, AMap, payments, field duration, packaging/signature and root's integrated verification remain outside this readonly correction review. Historical duration is explicitly not a build prerequisite.

## Assessment

**Ready to package? With fixes.** F1 and the original F2 sequence are addressed; one Important correction interaction, F3, remains. No other Important/Critical issue was found in the actual fixes. Resolve the stated reverse-order pin/page sequence and verify its direct neighbors; do not restart the whole-branch or field-duration audit.

## Final amendment confirmation — supersedes the preceding open assessment

Root explicitly retained this same review owner to close the remaining F2 response-order gap (previously labeled F3 above). This confirmation is limited to immutable Flutter `348e522ae7bb791b0224075b5e06c52a87f31761..309e621ec4204d015cbfadb78f65d15731c35b6f`, its two added production lines, the accompanying reverse-order tests and the appended implementation evidence. F1/Java and the already-addressed original F2 sequence were not reopened. No repeated tests, source/index/ref changes, builds, external calls or additional reviewers.

**Residual F2 / former F3: ADDRESSED.** The valid authoritative `updatePin` response now increments the existing `_generation` before publishing its target, so A's older in-flight page fails the existing generation check and cannot overwrite B's pin or cursor. The same branch explicitly clears `loading` and `loadingMore`; it therefore does not leave a spinner dependent on the invalidated read's skipped finally block. Both lines remain inside the existing mounted/public-refresh-epoch guard, preserving account disposal and explicit-refresh invalidation. Sibling mutation completion remains governed by its own target and the unchanged epoch.

The added production-controller tests explicitly capture A's old page, complete B's pin/deletion first, and deliver A's old page last. They assert preserved pinned/deleted state, each result once, released busy state and both loaders cleared. The implementation report records the reverse-order baseline as 1 pass / 1 failure, followed by the same nine-file suite at **71/71 passed** and targeted analyze with **No issues found**. These are implementation-run results, inspected but not rerun by this reviewer.

**New Critical / Important findings in these two lines: none.** No unrelated scope was reconsidered; prior evidence limitations and declined-to-judge boundaries remain accurate.

**Final gate: PASS — ready to proceed with the authorized packaging workflow.** F1 and F2, including the reverse-order amendment, are closed at Java `814a0fe9be4a2b9887243b7f1bcb07f536342930` and Flutter `309e621ec4204d015cbfadb78f65d15731c35b6f`. No source-review blocker remains. This conclusion does not claim that the APK has already been built/verified or that unexecuted runtime acceptance has passed.
