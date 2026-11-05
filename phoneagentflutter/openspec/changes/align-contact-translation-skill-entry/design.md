# 设计

- 目录层：`contact_skills_controller.dart` 在现有可用 OpenSkill 筛选外纳入未 disabled 的 `HomeAction.translation`，文案固定“实时翻译”。翻译入口按 Native 不受该首页卡片 comingSoon 状态和最低版本控制，其余 skill 继续核对实际安装版本；disabled 卡片仍隐藏。
- 导航层：`contact_actions.dart` 在选择翻译后复用 `openDialer(number: contact.phone, name: contact.name, translationEntry: true)`，传递 preview，沿用返回前的页面/账号/在线门禁，不创建 Agent 会话。
- 不新增抽象或修改统一拨号页。未来目录类型继续按现有 HomeAction 接入；普通 OpenSkill 路径保持现状。
- Native 证据：`AssistantContactSkillPolicy.kt:20-33`、`AssistantContactSkillSheet.kt:72-82`、`AssistantContactPageHostArgs.kt:61-63`。保留回退依据 `docs/requirements/MIGRATION_BASELINE.md:27`。
- 验证：目录包含 comingSoon/版本不足的翻译入口，disabled 翻译与其他不可用 skill 仍正确过滤；Android/iOS 合成选择进入预填统一拨号页且不进入任务会话。真实拨号和设备媒体独立待验。
