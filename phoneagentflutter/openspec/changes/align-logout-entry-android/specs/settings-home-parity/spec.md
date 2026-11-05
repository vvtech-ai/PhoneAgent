## ADDED Requirements

### Requirement: 双端退出入口必须使用Android参考样式
Flutter设置首页退出入口 MUST 采用Android SettingsLogoutAction目标：左侧FFFF3B30的16粗体退出文字，右侧8A8F99的13字号脱敏手机号，24圆角、80%白底、78%白边、16内边距、10底距和常规点击反馈。MUST NOT 保留此前iOS入口的居中布局和按压缩放。

#### Scenario: 双端显示与点击
- **WHEN** Android或iOS用户查看并点击退出入口
- **THEN** 显示同一Android目标样式和当前脱敏手机号，单次点击进入既有确认流程，取消不登出

#### Scenario: 小屏与大字体
- **WHEN** 屏幕窄或字号增大
- **THEN** 文字保持可读且不重叠，允许自然增高，入口可滚动到达
