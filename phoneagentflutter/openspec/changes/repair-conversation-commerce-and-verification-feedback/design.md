## Context
已读根与仓库 AGENTS、知识库导航、迁移基线及关联 OpenSpec；按当前源码为准。Flutter codex/dev，Java feature/test_v1.7.0。用户明确授权实施。

## Decisions
- 国内翻译使用现有 onSettled 服务端金额回执，由独立反馈规则去重；国外不变。
- 对话输入模式/录音起始强制到最新消息，普通回复跟随尾部，主动翻阅历史不抢位置；待确认卡仅首次出现定位，不在每次更新重新吸附。
- Composer 使用统一可交互条件禁用 + 与模型；停止保持可用。思考卡与后续回复留12逻辑像素间距。
- 套餐明细入口在积分卡下方当前会员/到期行右侧，空记录隐藏，独立弹窗复用权益组件，去除序号，保留顺序与数据。
- 每日上限继续读取 GlobalConfigKey.VOICE_CLONE_MFVC_DAILY_LIMIT。初始化/取消/未完成不计；服务端确认 PASS/FAIL 的 completedAt 事实计一次。结果未确认不伪造失败，防止过期覆盖已确认结果；保留请求锁、模型槽位准入与成功冷却。客户端诊断不作为计数凭证。
- 无数据库迁移；历史仅有初始化记录不计，已确认完成记录继续计，认证成功后声音处理失败不抹除认证计数。

## Validation
定向 Flutter widget/domain测试与analyze；Java SDK 认证准入/结果测试；OpenSpec校验。真实通话、认证与设备UI验收标记待验，不以单测替代。
