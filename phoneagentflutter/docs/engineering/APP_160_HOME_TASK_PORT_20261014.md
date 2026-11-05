# App 1.6.0 首页与任务修复迁移

## 来源与保留

用户要求把最新原生 App 1.6.0 的首页、任务相关代码迁到 Flutter codex/dev，保留双方修复，构建开发环境签名包并覆盖安装当前手机。原生仅作只读来源：`origin/feature/test_v1.6.0`，`9a95803a4885e7d9fcd948084f0b66e26946da97`。Flutter 原任务语音核对点为原生 `1e67c2d`；本轮继续对照该点以后的有效修复及其直接依赖，不照搬 Kotlin 文件。

Flutter 工作树 `D:/work/04phoneAgent/_isolated/phoneagent-task-flow` 从 `9975afe7` 快进至远端最新 `54bf1a74` 后开发。保留该基线全部支付、开票、翻译、定位、语音首句和任务音色改动；foundation 及其他工作树未修改，原生分支未重置或提交。

## 行为核对

| 原生修复能力 | Flutter 落点与处理 |
| --- | --- |
| 首页与任务共用当前模型、计费与确认身份 | 正式 Home/Conversation route 使用账号当前目录和已有 BillingRequest；已等价，不复制原生嵌入式首页状态机 |
| 当前模型选择与历史通话模型分离 | `ConversationRoute` 全局 CallModelController、历史计费快照保留；无 Qwen Audio 白名单 |
| 同内容新 pending 需要独立确认/播报 | CallLaunchRequest identity 使用 session/tool；SpeechController 以 session/pending 防重，已等价 |
| 新交互使旧拨号确认失效 | SignalFlow 对新 ASK_USER/其他交互取消旧准备，即使没有新 pending ID；历史卡只显示事实，正式 route 仅当前卡展示拨打提示 |
| 确认卡跨轮恢复重复、回执旧 alias | MessageMerge 按工具身份跨命令合并；仅有同 callId 证据才归一化 `call:<callId>` |
| 零题 ASK_USER 标题与确认后重复文字 | 已有 questions(title/items)；追加仅省略同轮已确认批次卡的相同独立文案，保留原 ledger 和不同回复 |
| 实时批次停止，UI taskId 可空 | StopCoordinator/Binding 使用所属 session、真实 batch 和修订代次；真实 ID 未推送时服务端确认回执仍可证明目标 |
| 停止受理、逐路终态和最终结果分离 | 保留 Recovery/ledger 门槛；最终账本先于 progress 返回时统一完成回调清除活动批次锁 |
| 已完成批次迟到事件、跨批次终态 | Tracker 保存完成 ID；EventFlow 拒绝旧批次结果清理当前批次；RUNNING 结果快照不记为已完成 |
| 数字联系人 | Pinyin tokenizer 保留数字读音，区分小4/小5/小6；纯拼音单候选仍需用户选择 |
| 活动通话系统返回 | CallHost 保留活动页面、会话和观察，不发送停止或释放观察者 |
| 挂断受理/恢复 ENDING、CANCELLING | 禁重复挂断，回任务页继续读回；不冒充已经物理关闭 |
| 主线路关闭与拨号失败 | CallProgress 独立建模；HTTP/SSE 同步 flags；有效 CONNECTED 可撤销失败观察，但不能撤销可信主线路关闭 |
| call_outcome_preview | 校验版本1、provisional、closureProofPending、session、attempt与递增序号；显示暂定判断并继续等最终回执，不生成账单/录音/评价 |
| 进行态结果资产 | 保留原始 projector 进行态用于恢复观察；消息和实时 final payload 不提前生成结果卡，避免提前加载录音和评分 |
| 普通物理终态回执等待超时 | 原有只读同步最多32次、间隔1500ms；超时不伪造终态，允许新输入，正式提交入口释放旧终态观察者 |
| 语音入口回调与播报独占 | 既有 generation/current/closed、权限及释放门槛、300ms按住打断、零音频仅重试一次和失败保留；保留并回归 |

## 模型反馈的边界

用户报告首页/任务模型红色“不可用”，Qwen Audio3.1 灰卡下写“当前模型尚未接入”。原生与 Flutter 均 SDK GET/PUT `api/account/settings/realtime-call-provider`，PUT 原始 modelId；延迟均 Agent GET `api/assistant/realtime/call-models/latency?refresh=true`。独立只读审查未发现 Flutter 专有模型禁用名单。

SDK 源码 `RealtimeModelSettingsService.callItem` 由 supported、price、memberAllowed 返回 available 与 statusMessage。“当前模型尚未接入”对应服务端 supported=false；不能在客户端强设可选。本轮未修改 Java 或部署服务。

客户端确有展示误判：延迟请求失败或缺少样本被补为 unavailable，整列显示红标。本轮区分 unknown 与明确 unavailable，完整卡片读屏同步；不影响服务端模型资格。已用失败回归验证，服务端明确禁用的模型仍不可选择。有任务播报声音不证明所选通话模型已接入。

只读运行态探测未获得当前登录响应：无 token 的远端探测返回401/AC0002，旧包启动日志没有可发现 VM service URL；不据此声称开发环境延迟或目录已正常。旧私有目录快照不作为当前 Qwen3.1 的运行证据。

## 验证与交付

首轮范围回归发现历史确认提示/系统返回旧断言及 RUNNING 快照被误标完成；均按当前有效需求修复并定向验证。独立审查发现主动 ledger 结算遗留批次锁，新增失败回归后统一完成路径；收尾复核未发现剩余实际阻塞点。

产品源码冻结后执行 `flutter test --no-pub --reporter json test/features/conversation test/features/calls test/features/contacts test/features/home test/features/tasks test/features/call_models test/features/feedback`，437.1秒内1675项通过、2项失败。两项失败均依赖旧有“RUNNING也生成结果卡”的断言：`receipt_overlay_test.dart` 改用显式旧卡测试终态覆盖，`conversation_structured_failure_test.dart` 改为断言进行态保留观察但不展示结果资产。仅调整测试，随后这两个文件与 `task_160_projection_test.dart` 共21项全部通过。未为测试断言调整重复整个范围集合，原始失败记录保留于私有 `.local/task160-regression.jsonl`，不把单次失败运行记作全绿。

固定 Flutter3.32 的产品源码及最后测试调整后两次 `flutter analyze --no-pub` 均无问题。OpenSpec139项通过，`git diff --check` 通过。

开发 APK `D:/Temp/PhoneAgent-dev-1.0.51-2026101408.apk` 为 `com.vvtech.aiassistant.dev`、`1.0.51-dev.1408`、versionCode2026101408，使用既有开发环境私有配置及签名。构建前后私有配置和产品源码摘要一致；产品摘要为 `368a058498aa07b419b941caae734fe79e4847522f8e3118de58a8d7632e1276`，APK SHA256为 `11c7ba03c7fac8b4af04d78ba74060a14323bccd6d16d1f2cbac6df8cf67d370`。`apksigner verify` 通过，与已安装1407证书一致；12个ARM64供应商库逐字节摘要与1407一致。私有构建日志、签名材料、设备回执和APK均不入库。

当前物理手机以显式 `adb -s <当前手机> install --no-incremental -r` 覆盖安装成功，未卸载或清数据；读回版本2026101408/1.0.51-dev.1408，firstInstallTime仍为2026-10-10 12:36:18，lastUpdateTime为2026-10-14 18:20:14。`am start -W` 返回Status:ok，进程存在。仅证明覆盖安装保留原应用数据目录及启动成功，未把它扩称为登录或真实业务验收。安装回执为私有 `D:/Temp/task160-build-1408-verification.json`。

产品提交 `4283efae74a6b6f83f9b1054966148acfa8bb160`（同步1.6.0首页与任务修复并保留开发分支更新）已普通推送 `origin/codex/dev`，`ls-remote` 读回一致，`54bf1a74` 保持祖先；产品提交后工作树干净。推送前再次fetch确认原生来源仍为9a95803，Flutter原远端仍为54bf1a74。后续交付记录提交仅改文档，不改变1408的产品源码摘要。

真实外呼、SIP、供应商、后端部署和 iOS 原生运行未执行，不用离线测试或包启动替代。PMReport 1.5.0 registry 仅有 aiassistant，未登记 aiassistant-app/phoneagentflutter，本轮不猜测项目映射、不上报这两个仓库。
