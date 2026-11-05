## Context

Android feature/test_v1.6.0 为 Kotlin 原生工程，不能 cherry-pick 到 Dart。逐项对照已发布源码与回归测试，在已有 Flutter 所有者中迁移语义，不另建任务状态机。来源包含停止确认、确认卡身份、活动交互、拨号失败收尾、暂定结果和进行态结果卡门槛。

## Decisions

1. 停止协调器接收现有 BatchProgressTracker 身份与最终整理门槛；确认前后校验原批次，不依赖 UI taskId，停止受理不等同完成。
2. 保留 CallReceiptProjector 进行态数据用于恢复观察；展示层只对终态开放结果、录音、评价。消息合并以工具身份跨轮去重，旧 alias 仅在 callId 证据匹配时归一化。
3. 单路关闭证据和版本化暂定结果单独建 domain 模型，既有 CallSessionController 管理投影，继续读回；确认主线路关闭不可被迟到 CONNECTED 撤销。暂定结果不成为最终账单或结果资产。
4. 通话页系统返回保留会话和观察；新交互使旧待确认动作失效。已存在的同 pending 防重、零音频重试、按住打断与当前模型接线保留。
5. 每批最多三个手写产品/测试文件；核心会话控制器只作接线，复杂规则独立文件。最终通过固定 Flutter3.32 analyze、受影响回归及开发 APK 验签、显式 install -r 和版本/启动读回。

## Runtime boundaries

真实 SIP、供应商、后端部署和 iOS 原生运行另行验收。PMReport registry 未登记 phoneagentflutter 与 aiassistant-app；不以 aiassistant 同名业务推测映射或上报。
