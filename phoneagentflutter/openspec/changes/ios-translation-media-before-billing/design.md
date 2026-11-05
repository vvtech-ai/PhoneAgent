# 实现与边界

- 仓库 PhoneAgent；domain coordinator 拥有 SIP/业务 Connected、计费、取消；media 拥有准备/运行；PCM data 与 iOS 原生拥有硬件；factory 只按 iOS 接线。仅国内实时翻译入口受影响。
- 保留账号/clientCallId/积分 session/lease 的原身份、事件序列和幂等规则；使用原 connected、terminal 接口。后台 PointsUsageSessionRules.billableDuration 支持未 Connected 的 terminal(false,0)，已 Connected 不能反向释放。
- 默认路径保持原顺序；仅生产 iOS 工厂开启 prepare-before-connected。媒体准备不等待开场、模型输出或对方发声。录音时间原点与新业务 Connected 对齐。
- iOS 准备期间提前监听远端结束；账号/取消校验覆盖所有 await 后边界；迟到准备不得复活计费。采集准备期间数据不投递业务，开始运行时丢弃准备期间缓冲。
- 保留权限申请入口、准入、授权时长、错误文案、UI/控件、其他音频调用方。新增技术错误码只进入既有白名单诊断，不显示底层错误正文。
- 回放关联 DEVICE-01、VOICE-01/03、ENTRY-05/06/08、CONFIRM-01/02；本次为翻译端内实现，不修改共享任务编排区域。
- 文件职责：coordinator 时序；media 准备/运行；PCM bridge 可选准备能力；factory iOS 接线与延迟录音创建；Swift 仅音频准入诊断分类。
- 不修改服务端或历史扣费，不承诺开始计费后的故障免费。真机/后台证据不足时不得签收完整验收。
- 文件长度例外：DomesticSipMedia 从原约 500 行增加至 537 行，仍只有一个媒体生命周期 owner；本次不为准备/运行拆出第二个有状态 owner，避免关闭/取消状态分裂。准备、关闭及默认路径有直接测试；后续继续扩展时复核职责拆分。
