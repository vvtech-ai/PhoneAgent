# 一人批次实时通话验收记录

2026-10-28。批准范围：所有多路 Skill 的冻结可执行名单为一人时复用现有实时通话页；多人、确认卡、准入、唯一 START、计费和回执 owner 保持原合同。

产品候选：Java f1ba03bcdc22b6a388026afb2987b62909f3d250；Flutter 85d42c2ffab7475dc78689ebf3c7823b37ffbcfc。本文后续提交只更新验收文档，不改变已测试的产品内容。

## 已完成

- 自验 Java 62/62（新查询/身份与原批次停止、语义确认、SDK 准备推进、监听）；Flutter 最终 112/112；analyze 无问题。
- 未参与实现的独立代理重新读取本次批准 PDR、实际检出规范和源码：最终 Flutter 125/125（121 仓内 + 4 个独立交错回放）；Java 66/66 JUnit + 1 个独立真实解析/过滤/投影场景。无跳过，不重复累计首轮/自验数。
- 独立源链覆盖原名单多人、execute=false/无效号码过滤后只有一人；观察只调用 SDK findOutcome，不提交确认、拨号或 START。
- 原单呼/确认补充/媒体、批次停止在途与结果门禁、多人恢复均完成定向回归；本次未修改底层 SDK/Phone/Netty 准备启动代码。
- 两仓本 change 的 OpenSpec strict、diff 与 UTF-8 检查通过，主检出原有修改保留。

## 未通过

最终已执行的本机离线项无。首轮独立复现三类问题（四个交错回放）：callId 未解析前丢关闭事实、取消进度未及时隐藏、停止已接受但状态读回失败后迟到重拨重开。修复只在新观察模块按 attempt 保留关闭与停止接受事实；新增仓内五个失败先行回放，独立原断言复验通过。

## 缺证据

Android/iOS 真机画面及交互、真实 Agent/SDK/Runtime 连续联调、可听音频与实际外呼、共享 MySQL/Redis 运行证据尚未验证。本次没有打包/安装、推送、部署或真实业务操作；上述离线通过不代表全量套件或完整运行验收通过。

独立报告及完整命令/日志：D:/Temp/phoneagent-one-recipient-independent/acceptance.md。工作区任务卡：tasks/single-recipient-batch-call.md。开发阶段自验日志：D:/Temp/one-recipient-java-self.log、D:/Temp/one-recipient-flutter-self-final.log。
