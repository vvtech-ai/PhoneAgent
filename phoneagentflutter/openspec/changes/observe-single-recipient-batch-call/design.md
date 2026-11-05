## Context

批准范围见工作区 docs/single-recipient-batch-call-PDR.md。基线 Java 55df4507、Flutter e1ffcd4c；用户进一步要求对全部多路 Skill 生效。

## Goals / Non-Goals

一人批次复用现有页面；不改确认卡、普通单呼、拨打准入、结果及多人成员执行。并发数不是人数，最后剩一路不转单路。

## Decisions

服务端独立 BatchSingleCallSessionService 按 sdkAdmission(account,session,batch) 校验冻结名单恰为一人，并验证确定性 attemptId，读取现有 SDK Outcome。新增 GET /api/agent/conversations/{sessionId}/batch/{batchId}/call/{attemptId}/status；未找到、非一人、错身份均不返回可展示快照。launchReady 原样来自 SDK，无 begin/START 副作用。

客户端独立 BatchSingleCallController 组合已有 CallSessionController 和共享 CallSessionPage。批次适配仓库绑定 session/batch/attempt，查询上面接口，监听票据使用真实 batch taskId/callId，挂断调用原 stopBatch 后读取真实状态。实时进度与原 batch 恢复快照共用接入点；旧 attempt/批次失效，不生成确认或拨打命令。结果和评分不交给普通单呼 owner。

## Risks / Trade-offs

不修改底层门禁，只复用 launchReady、physical closure 判定。重复/迟到进度不替换新 attempt；不同批次需使用当前活动身份，恢复只读。后端不可用时继续原批次进度，不伪造就绪。真实音频/外呼与设备验收独立列证据。

## Implementation plan

### Bug 23841：连续执行（2026-10-29 用户批准）

复用 Flutter 独立检出，起点 e02e4b20。真实日志证实首通有 75 次状态 GET，而第二批次虽已 SDK RINGING 却未查询。后端规范化事件没有 makeBatchCalls toolStart，观察器不能把它当作必要的执行边界。

仅修改 BatchSingleCallController 的展示身份切换与定向测试：由当前会话/有效命令传入的合法一人进度识别新执行；上一批次已 finish 且命令与批次均为新身份时重置本轮观察、顺序和停止标记，保留已结束批次集合。活动批次、旧命令、未知人数、多人和无效身份不能触发切换；重复 toolStart 不清空状态。launchReady 与闭合判定、批次停止、普通单呼和多路执行 owner 不变。沿用既有只读适配接口，不新增状态机、表、Redis key 或拨号请求；后续 Skill 自动走相同人数规则。

实现只扩展独立观察器，避免向大 ConversationController 追加判断。验证第二/第三次执行、同批重试、停止后新执行与旧响应隔离，以及实际 ConversationCallHost 的跨 Skill 连续展示。授权包含独立测试、test_v1.8.0_fix 推送和测试包，不含安装与真实外呼。

1. 写归属/一人数/attempt/launchReady 的失败测试，再实现独立 Java service/controller，运行定向 Maven。
2. 写一人/多人/准备/关闭/重拨/恢复的失败测试，再实现 Flutter 观察器和 API 适配，连接实时与恢复进度，运行定向测试。
3. 回归原单呼、确认补充、停止、监听；静态检查、UTF-8、diff、规格校验，独立子代理验收并记录缺证据。
