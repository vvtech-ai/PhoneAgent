## Decision
向 AppEnvironment.prod 的 apiHosts 增加精确主机 phoneagent.chaken.net.cn。API 地址是配置，入口信任策略是代码；不将 API 主机自动作为可接受的邀请链接主机。

## Scope and invariants
基线 codex/dev@cd09cc8d，工作区开始时干净。owner 为 invitePolicyFor；实现只改 invite_environment_policy.dart，测试在已有 invite_environment_policy_test.dart。保留 HTTPS/443、跨环境隔离、现有三个邀请域名策略、四字符邀请码、登录状态与 pending 身份处理。不修改原生签名、AASA、服务器、UI、凭据或任务编排规则。

## Validation
先以新增 API 主机运行原有正式入口正反场景复现失败；补齐后运行邀请模块回归与定向 analyze，校验 OpenSpec/diff。增加精确给定链接 VYFX、Android 直接调用方以及 dev/test、相似域名和非标准端口拒绝。不把离线解析通过视为真机唤起或奖励绑定验收。
