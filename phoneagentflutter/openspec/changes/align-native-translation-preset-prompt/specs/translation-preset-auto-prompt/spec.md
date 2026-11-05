## ADDED Requirements
### Requirement: 预设自动弹出对齐原生
Flutter Android和iOS MUST 仅在实时翻译开启且拨号前提示开启且尚未预设确认时自动弹出。普通呼叫 MUST 保留号码检查并直接调用原有系统电话端口。
#### Scenario: 翻译关闭提示开启
- **WHEN** 翻译关闭且prompt已保存为开启，用户点击拨号
- **THEN** 不自动弹预设，不执行翻译准备，通过原有号码检查后交给系统电话
#### Scenario: 翻译开启
- **WHEN** 翻译开启且用户点击拨号
- **THEN** prompt开启才自动弹预设，关闭则继续原翻译预检
### Requirement: 手动入口与UI保持
客户端 MUST 保留手动打开、弹层样式/文案/控件及prompt偏好，关闭翻译 MUST 不清除提示偏好。
#### Scenario: 手动确认或取消
- **WHEN** 用户手动打开预设并确认或取消
- **THEN** 确认继续原有拨号且不二次自动弹出，取消不拨号；原有UI及已保存提示偏好不变
