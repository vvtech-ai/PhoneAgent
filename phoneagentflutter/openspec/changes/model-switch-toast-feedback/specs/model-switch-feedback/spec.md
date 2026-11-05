## ADDED Requirements
### Requirement: 模型切换必须通过共用Toast反馈
首页和会话通话模型实际切换成功或失败 MUST 显示共用品牌Toast，成功包含已确认模型名称；国内翻译失败 MUST 显示Toast并保留重试。已有初始化和翻译成功提示 MUST 不重复。
#### Scenario: 请求成功失败
- **WHEN** 当前页面所属模型切换请求完成
- **THEN** 成功提示通话模型已切换为模型名，失败提示检查网络或服务连接
#### Scenario: 无效旧请求与重复选择
- **WHEN** 页面离开、账号或Controller变化、重复选择当前模型
- **THEN** 不弹出旧结果或重复成功提示
#### Scenario: 正在切换
- **WHEN** 忙状态下调用选择入口
- **THEN** 不重发请求并提示正在切换中；原禁用控件保持禁用
