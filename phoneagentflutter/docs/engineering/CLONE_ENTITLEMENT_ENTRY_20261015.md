# 声音克隆权益前置拦截验证（2026-10-15）

本记录对应 `repair-commerce-and-task-entry-experience` 第 3 项。仅修改声音克隆的领域、目录适配、入口编排、独立权益提示及相关测试；不修改会员购买、积分金额、身份 SDK 或供应商协议。

## 行为与契约

- `/api/account/settings/voice-clone/models` 每个模型独立读取 `cloneEntitled`（可空 Boolean）及 `entitlementReason`；不使用 `available`、积分余额或会员等级推断权益。服务端负责按当前有效购买快照判断。
- 全部模型明确无权益时，统一 `openCloneCreation` 在显示可选模型前展示“暂无声音克隆权益 / 当前会员未包含声音克隆权益，可前往会员页查看并升级。”；部分模型拒绝在选择该模型时展示。
- “取消”关闭本次克隆入口并保留来源页面；“去升级”进入既有 `MembershipRoute`，返回后重新读取模型权益。未升级仍拦截，升级期间切号不刷新旧端口、不进入认证。
- `cloneEntitled` 缺省/null，以及 `ENTITLEMENT_UNAVAILABLE` 均为未知状态，显示“声音克隆权益读取失败，请重试”，不误报无权益，不进入身份填写/认证。网络或目录读取失败保留安全错误与“重试”。
- 新建、重新认证、认证录音复用和流程内重新录制均保留新鲜目录准入；积分不足继续独立处理。只读候选 API 未修改，统一创建入口仍要求确认权益。

## 验证证据

- RED：新增 API/Controller 权益回归初跑 1 通过、3 失败，实证无权益/旧版未知目录会创建认证入口，权益读取异常误显示模型不可用。
- RED：入口 Widget 初跑 3 失败，缺少前置提示和重试；流程内新鲜权益初跑 2 失败；升级期间切号初跑 1 失败（旧端口读取 2 次，预期 1 次）。对应最小实现后均 GREEN。
- 新增权益准入 6 项、实际路由交互 7 项均通过。覆盖允许/拒绝/未知、异常原因、积分与录音零副作用、全部/部分模型、取消、真实 MembershipRoute 导航、返回重读及会话隔离。
- 旧入口/价格/页面 4 文件集合 53 项通过；流程及权益相关 5 文件集合 50 项通过（不同集合存在重叠，不累加）。
- 扩展 17 文件定向集合初跑：158 通过、4 失败。4 项均为 `shell_clone_workbench_test.dart` 的合成目录 fixture 未显式提供新权益字段，未知状态使 `clone-create-QWEN_OMNI_PLUS` 不展示。经主代理授权，仅在 `tool/previews/shell_clone_ports.dart` 增加合成模型的 `cloneEntitled: true`；最终重跑 `shell_clone_workbench_test.dart` 与 `clone_entitlement_route_test.dart`，12 项全部通过（包含两端身份来源保留、320/430 两模型克隆流程和全部新增入口交互）。没有修改导航或放宽旧目录未知门禁。
- 首轮额外指定了不存在的 `test/features/identity/identity_route_test.dart`，139 项通过但该路径加载失败；随后更正为实际 identity Widget/编辑返回测试，全部通过。保留此执行输入错误，不将其描述为产品失败。
- 最终 `flutter analyze --no-pub`：No issues found（30.0 秒）。首轮发票测试的无用 import 已由主代理清理。
- `openspec validate --all`：154 passed / 0 failed。`git diff --check` 通过；新增中文及修改中文已 UTF-8 重读，无替换字符。

## 交付依赖与未验项

- 新 APK 消费新增服务端权益字段。尚未发布该 SDK API 时，旧目录字段缺失会按未知安全拦截，付费/免费账号均不能由客户端猜测放行；需要同步发布服务端字段后验证当前账号权益。当前实现没有从营销目录补造权益，也未新增旧版本会员快照回退查询。
- 未执行真实升级支付、身份填写、人脸认证、克隆生成或供应商联调；自动测试不代表这些真实能力验收通过。测试 Release 构建、安装与主任务总体验证由主代理执行。
- 本子任务未切分支、提交、推送、打包或安装；Flutter 测试均使用固定 3.32.0、`--no-pub`，未升级依赖。
