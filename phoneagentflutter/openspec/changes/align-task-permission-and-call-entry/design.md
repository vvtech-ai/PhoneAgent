## Context
用户已明确修Flutter，旧原生仅对照。已有21项探索定向测试通过但部分断言正好固化错误行为：拒绝后整个任务不再请求、非空消息隐藏开场白。实施必须先更新有意义的验收并观察RED。
## Decisions
1. 首页入口新增小型独立授权门禁，复用ConversationPermissionSource；导航拥有者负责账号/页面/重复点击代次。授权成功才创建/进入任务；拒绝留首页，永久拒绝有用户主动设置入口，绝不循环弹。恢复入口的权限与既有入口语义统一但不改变历史查询及只读详情。
2. TaskLocationPermission区分同轮防重和新的用户意图。附近/重新获取定位等明确意图可重试；用户明确拒绝不弹；Agent同一pendingToolCallId重投不弹；后台或切号晚回不续接。已授予直接读，系统永久拒绝显示真实权限状态和用户主动设置操作；系统定位服务关闭保持既有location null语义，不把服务关闭误报为App权限拒绝。
3. TTS是权限动作续接的一部分，在新续接流开始时恢复当前有效播报轮次；单纯resume不重放历史/中断文本，不重启ASR。权限弹窗临时inactive不能当作用户永久静音；真实后台取消保护保留。
4. 消息投影保留授权卡的必要信息及授权结果，普通search过程按旧版收尾；不因同toolId普通文字笼统吞结构化卡。新任务开场白使用稳定身份放在任务起始位置，不伪造ledger事实；历史已有opening时去重、历史无证据不随意补新开场。generic处理中只在当前轮工作期间，真实thinking按既有增量展示保留。
5. CallIcons移植原XML路径（52按钮/24图标尺寸一致，不用放大/裁边掩盖）；ConversationCallHost活动showCall时返回无副作用，不调用returnToConversation/hangup。子音源sheet自己的返回保持，物理结束和挂断成功按原流程。
## Architecture
每手写微批不超过3文件，UI不发网络/权限请求。新增入口门禁与必要设置端口独立小模块；Shell仅接线，原499行先评估抽取而非超过500；ConversationController只加续接钩子，权限/展示/播报策略位于各自owner。未来相同任务入口复用门禁，同类消息策略放命名规则，不新增第二套状态机。
## Verification
各组RED/GREEN、模块与直接调用方集成，analyze、OpenSpec、UTF8/中文读回/diff、独立复核；平台权限按合成状态与通道测试验证，不冒充真实设备授权。最后冻结源码后test Release1.0.52(45)签包核验，不在编译期运行Fluttertests。无真实账号、系统授权弹窗、外呼或部署操作。
