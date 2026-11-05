# Tasks

- [x] 读取当前规范、需求和相关实现，确认仅本地执行范围。
- [x] 创建本 change 并通过 openspec validate --all（211 项通过）。
- [x] 微批 1：两个业务文件区分结算未确认原因并映射指定正文，保留主错误优先及清理诊断。
- [x] 微批 2：拆出协调器测试 fixture，补结算/清理/回调和主错误优先回归（至多三个测试文件）。
- [x] 微批 3：文案映射及双端 Toast 去重、跨页回归（两个测试文件）。
- [x] 微批 4：补真实国内展示控制器的结算错误文案传递及无扣分提示回归（一个测试文件）。
- [x] 定向 Flutter 测试、flutter analyze、OpenSpec 和 diff 检查；更新根任务及问题记录。
- [ ] 用户验收及 Android/iOS 真机验证（不在本次触发真实外呼或收费）。

## 验证记录

- Flutter 3.32.0 / Dart 3.8.0；`flutter test --no-pub` 指定以下 9 文件，共 99 项通过（非全量）：
  - domestic_sip_call_coordinator_test.dart
  - domestic_settlement_failure_test.dart
  - translation_call_failure_test.dart
  - translation_terminal_toast_test.dart
  - domestic_translation_session_controller_test.dart
  - domestic_points_owner_test.dart
  - domestic_translation_session_factory_test.dart
  - translation_session_coordinator_test.dart
  - translation_session_controller_test.dart
- 文件均位于 test/features/translation/。测试 fixture 拆分后初轮漏导入 SipLease，导致 1 文件加载失败；修复后上述 99 项全部通过。
- 首次 analyze 的 5 条 private type in public API 提示已修复；公开测试夹具类型修正后，前两个文件 20 项复验通过，`flutter analyze --no-pub` 无问题。
- `openspec validate --all`：211 项通过、0 失败；Dart 格式与 `git diff --check` 通过。
- 生产源码仅两个文件、合计增加 5 行，均低于 500 行；fixture 304 行，原协调器测试拆分后 199 行。
- 未改平台、依赖或构建链，无需本批重打包；未安装、未真实外呼/收费，真机及用户验收未完成，不归档，不提交推送。

## 后续提交授权

- 用户明确要求本次 Git 提交并远程推送，覆盖此前不提交推送限制；仅包含本 change 对应源码、测试、规格与记录，正常推送 origin/codex/dev，不强推。
- 不归档，不扩大打包、安装、真实外呼或收费授权；实际提交及推送结果以 Git 核对为准。
