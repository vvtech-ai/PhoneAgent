## ADDED Requirements

### Requirement: 联系人技能保留实时翻译入口
联系人技能弹层 MUST 在目录存在未 disabled 的 openTranslation 卡片时展示可用“实时翻译”选项，不受该首页卡片的 comingSoon 状态或最低版本限制。disabled 卡片 MUST 继续隐藏。其他 OpenSkill MUST 继续遵守已启用状态、非空 Skill ID 和实际安装版本门禁。

#### Scenario: 首页翻译卡片暂不可用
- **WHEN** 已加载目录中的未 disabled 翻译卡片 comingSoon 或最低版本高于当前版本
- **THEN** 联系人技能弹层仍展示可选“实时翻译”，其他不可用 Skill 不展示

### Requirement: 联系人翻译复用统一拨号
选择联系人实时翻译 MUST 进入现有统一翻译拨号页，预填当前联系人姓名及查询号码并开启翻译，不创建任务会话、不自动发起电话。进入前 MUST 沿用当前页面、账号和在线门禁。

#### Scenario: 用户选择实时翻译
- **WHEN** 用户在当前账号有效联系人详情中选择实时翻译
- **THEN** 进入统一拨号页，联系人姓名/号码保持一致，translationEntry 为 true，preview 状态沿用
