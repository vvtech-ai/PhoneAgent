# 2026-10-17 回归验证

## 基线与对照
Flutter codex/dev 8e53537c；Java feature/test_v1.7.0 e95ebaa0；旧 Android origin/feature/test_v1.6.0 只读对照。实施前再次 fetch，两仓库均无新远端提交。

## Java 已执行
先失败后修复，SDK RealtimeCallVoiceServiceTest 33 项、SSE 状态/拒绝分类/真实 SDK Begin 单路路径 21 项，共 54 项通过。未改 AgentService 生产主流程。空音色恢复采用模型动态默认，非空无效音色仍拒绝；未拨出权益拒绝不会覆盖旧真实结果。列表按完整账本重放，无数据库 UPDATE。

命令（显式 JDK17，Maven 3.9.14）：
```powershell
mvn.cmd -o -pl aiassistant-agent-sse,aiassistant-sdk-api -am '-Dtest=EntitlementTaskStatusTest,ConversationTaskStatusReducerTest,RealtimeCallVoiceServiceTest,PointsInsufficientExecutionResultFactoryTest,CallAdmissionFailureMessageTest,AgentServiceTest$MakeCallConfirmCancelTest#sdkBeginPointsDenialReturnsStructuredResultWithoutRetryOrLegacyDial' '-Dsurefire.failIfNoSpecifiedTests=false' test
```

本次两个 change 的 OpenSpec 校验通过。Java 全库校验 85 通过、1 个已有 audit-v66-single-call-stop-ui-parity 因缺 delta 失败，未改无关历史规格。

初次 RED 在生产修改前运行完整 AgentServiceTest，除新增回归外有六项已有失败：dedicatedJudgmentWithoutReportKeepsOriginalResultPending、dedicatedPostCallJudgmentKeepsValidatedBusinessResult、semanticCommitTimeoutReadbackPreservesAlreadyGeneratedOptions、stopAfterPhysicalTerminalDoesNotCancelOriginalResult、v70ConfirmationUsesSdkTerminalProofWithoutLegacySip、v70FinalizedCaptionsReachSseBeforeTerminalAndRemainCompleteAtEnd。它们涉及现有 V71 测试脚本/mock，未在本次范围修改；不得将定向 54 项通过表述为 Java 全量通过。

## Flutter 验证记录
认证初始化/网络安全映射先复现 13 个失败，修复后原7文件122项通过，后补401刷新回归在联合网络测试通过。积分新增回归先复现余额缓存、SDK拒绝及卡片不更新，再补齐首次刷新、单/批量SSE、TTS及卡片作用域。完整 calls/voice_clone/core-network 范围曾通过812项，其余9个旧calls用例暴露刷新时机/fixture依赖，随后保持 restored 输入语义并更新首次余额读取fixture；最终定向重跑结果由本变更任务记录。

Flutter 全库 OpenSpec 185 项通过。独立真实 Dart product/AOT 配置探针接受三个独立测试 HTTPS 服务并拒绝16种不安全配置；未发送短信。

## 运行态边界
最终冻结源码后联合验证：Flutter calls、voice_clone、core/network、conversation/voice、4份 EventFlow 直接调用测试、architecture、AppConfig、DioAuthGateway 共 1093 项全部通过；flutter analyze --no-pub 无问题。Java 上述命令再次通过 54 项。本次两个变更规格通过，Flutter OpenSpec 全部 185 项通过；Java 已有1项缺 delta 的无关规格与6项 V71 旧测试失败保留上述说明。

独立复核追加覆盖：当前模型切换费率、当前卡变历史后冻结、拒绝余额按执行 command→tool 结算、真实 SSE 无 commandId 传输归属、清理通话上下文后的迟到拒绝、重复事件与两个独立任务分别刷新及播报。仅备用播报键纳入 command，真实 call/attempt/batch 去重规则不变。

无真实认证、外呼、收费、数据库操作或后台部署。两份用户诊断缺服务端错误正文，不能以源码回归声称已复现唯一线上异常。Java 新代码须经测试环境部署后才能与 APK 联调；Windows 未执行 iOS 构建/真机验收。用户批准版本 1.0.52（45）及测试 Release 原登记签名交付，打包信息在对话给出，不额外落盘打包日志。

