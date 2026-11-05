## ADDED Requirements

### Requirement: 实时确认补充回复取得一次播报资格
App MUST 在当前输入的确认补充事实被有效应用并完成显示后，将assistantText送入原任务回复播报队列。App MUST 核对会话、command/record和待确认卡身份；MUST NOT 因播报而确认或拨打任务。

#### Scenario: 模糊回复继续待确认
- **WHEN** 多路任务对问题、等待或不明确回复产生CALL_CONFIRMATION_SUPPLEMENT
- **THEN** 对应文字显示且可播报，原确认卡仍待确认，无新增拨号动作

#### Scenario: 重复与相同文案
- **WHEN** 同事实重复交付或不同输入返回相同文案
- **THEN** 同事实不重复播报，不同输入的事实各有独立资格

#### Scenario: 恢复与播放门禁
- **WHEN** 事实来自历史恢复/补查，或当前已静音、离页、打断、失活
- **THEN** 不自动重播旧补充，不绕过原音频门禁；正常文字/确认/结果播报规则保留
