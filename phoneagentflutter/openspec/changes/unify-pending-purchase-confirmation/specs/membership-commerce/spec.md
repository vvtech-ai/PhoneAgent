## ADDED Requirements

### Requirement: 待购买取消确认复用统一 App 弹窗
待处理会员购买的取消确认 SHALL 使用 NativeConfirmationDialog，复用 NativeBusinessDialog confirmation/danger 及 NativeGradientAction 主次按钮。客户端 SHALL 保持原订单关闭资格、确认后账号和路由检查，不因样式调整推断取消成功。

#### Scenario: 双端确认与暂不取消
- **WHEN** 用户在 Android 或 iOS 打开取消确认
- **THEN** 展示统一确认组件、危险确认按钮与次要暂不取消按钮
- **AND** 仅显式确认且账号/路由仍当前时请求原单关闭

#### Scenario: 确认期间切号或销毁
- **WHEN** 确认框打开后登录 epoch 变化或发起页面销毁
- **THEN** 不再提交原账号关闭请求或操作已销毁页面

#### Scenario: 确认期间自动查询
- **WHEN** 定时查询周期到达但取消确认仍打开
- **THEN** 不发起新的查询；退出确认后按既有生命周期恢复
