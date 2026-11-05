# 本次验证

## 候选及授权

- 2026-10-28 用户批准聊天中的 PDR v1，并要求不破坏正常流程。
- Flutter 来源 test_v1.8.0_fix@f285726b；本检出 codex/semantic-call-confirmation。
- 仅本机实现与回归，未部署、打包、安装或实际外呼；无平台/依赖/版本调整。

## 失败与修复证据

- 新增连续控制器回放初次 +3/-10：确认白名单、否定后缀及“随便”未交语义模型；模型同意又被本地规则否决。
- 批量补充回放初次失败：收到 supplement 后 pendingToolCallId 为 null。现只按同会话、最新未结束工具及合法补充事实恢复同一输入绑定。
- 长卡 API 回放初次 ApiFailure.invalidResponse；现在传有界兼容提示，后端按账本读取完整当前卡，客户端仍保留完整内容签名。
- 原本只测固定规则的单测，替换为原相同同意/修改/取消/提问/暂缓语句的真实 controller 回放；显式演练按钮和测试 helper 使用明确按钮动作。外部分类测试替身只在 test 下，正式运行缺分类能力时不凭话术拨号。

## 自验结果

- 最后一次定向：18 个确认、恢复准入、准备倒计时、积分输入门禁、监听页面、通话返回、结果播报等相关文件，123/123 通过。排除 5 个独立确认的原分支既有失败（task160 暂定结果 1、长批量卡滚动 4），未改其断言。
- flutter analyze：No issues found。
- openspec validate unify-semantic-call-confirmation --strict：valid。
- git diff --check 通过；已修改中文文件 UTF-8 读回，无替换字符。
- 初次扩大 conversation+calls suite：1901 通过、75 失败；独立代理在相同 f285726b 基线逐项核实 50 项既有失败。新增 25 项涉及缺少显式语义替身或演练按钮错误通过自然输入确认，已在最终相关定向回归修复。未把扩大 suite 写为全通过。

本机日志：D:/Temp/phoneagent-confirm-analysis/flutter-semantic-red.log、flutter-semantic-green.log、flutter-batch-supplement-red.log、flutter-batch-supplement-green.log、flutter-long-card-red.log、flutter-final-targeted.log、flutter-analyze.log。原始用户日志/视频不进入仓库。

## 独立验收与边界

独立代理已重新读取原视频、截图和 diagnostics zip，并完成最终候选源码/新增文件审查及实际回归：第一轮 11 文件 97 通过 / 1 既有失败，第二轮 8 文件 43 通过 / 4 既有失败，两轮有 20 个恢复/准入用例重叠。5 项失败与基线同名，之前 25 个新增失败均已消除，没有调整其核心行为断言。独立静态检查无问题，OpenSpec、diff 与 UTF-8 检查通过。独立报告保存在 D:/Temp/phoneagent-confirm-independent/acceptance.md。

已完成：本次语义入口、非终结补充保留、身份/迟到隔离、原倒计时/准入/监听/结果等相关自动回归。未通过：原分支已有的 task160 暂定结果 1 项、批量长卡滚动 4 项，本次不修无关问题。缺证据：无真机画面、实际音频、真实模型调用和服务端现场 decision，不能称现场全链路已修复或已上线。
