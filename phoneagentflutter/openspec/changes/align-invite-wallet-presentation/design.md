## Decisions
固定Android a0bedb12 PointsWalletScreen与InvitePosterScreen、iOS bb9ff349对应控制器为参考。复核纠正此前报告：Android邀请内容位于余额状态分支之后，不因首次失败隐藏。余额加载区域高度120，iOS原生100。钱包已有缓存时展示余额卡与既有stale文案，不加失败块。海报复制邀请码数据能力不删除，仅删除额外UI入口。
## Validation
flutter analyze；邀请/积分定向测试、钱包到海报及流水返回连续流程；双端主题及大字体测试。无平台变更不构建安装，真实视觉待验。
