## ADDED Requirements
### Requirement: 双端共用品牌提示
Flutter 普通瞬时提示 MUST 统一通过 showNativeNotice，使用与 iOS invite_brand_logo 相同的22×22品牌图标、8间距及可换行居中文字；MUST 保留既有背景、边框、阴影、间距、动画、键盘避让、最新替换与点击穿透规则。
#### Scenario: 长文案与大字体
- **WHEN** 小屏或系统放大字体显示长提示
- **THEN** 图标保持22×22，文字换行且无横向溢出
#### Scenario: 普通提示迁移
- **WHEN** 原普通 SnackBar 入口显示反馈
- **THEN** 显示品牌 Toast，保留文案和原4秒默认时长，业务对话框和行内错误不变

### Requirement: 积分星号必须采用iOS颜色
共用 Toast 内的积分符号 ✦ MUST 单独显示为 #FFC400，其余文字保持深色，品牌图标和布局不变。
#### Scenario: 积分到账提示
- **WHEN** 提示包含一个或多个 ✦
- **THEN** 全部星号为黄色，金额和其他文字仍为原深色
