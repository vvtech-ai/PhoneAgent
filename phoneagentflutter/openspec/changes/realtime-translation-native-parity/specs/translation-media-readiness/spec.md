## ADDED Requirements

### Requirement: 通话准备展示共享原生样式
Flutter SHALL 在两个平台采用共享白色准备卡、紫色34点进度环和原生标题/说明层级，保留取消入口及结束时禁用状态。

#### Scenario: 短屏大字号取消准备
- **WHEN** 用户使用短屏和两倍字号查看准备状态
- **THEN** 标题和说明保持可读，通过滚动可操作取消，正在结束时不可重复取消

### Requirement: 通话控制支持辅助技术
通话控制 SHALL 提供与触摸一致的辅助技术点击动作；正在结束或终止的控制 SHALL 移除点击动作。

#### Scenario: 读屏操作静音
- **WHEN** 用户通过读屏激活可用静音按钮
- **THEN** 系统执行与触摸同样的静音回调

#### Scenario: 正在结束
- **WHEN** 会话正在结束
- **THEN** 读屏不能再次激活通话控制

### Requirement: 准备失败回退不得重复外呼
系统 SHALL 区分准备阶段的传输断开和拨号后的传输断开。准备阶段的事件流错误或结束 SHALL 释放当前媒体后尝试可用备用媒体，只有媒体准备成功才允许发起商户外呼。

#### Scenario: LiveKit 准备期间事件流错误
- **WHEN** LiveKit connect 尚未完成且事件流报告错误
- **THEN** 系统关闭 LiveKit 并尝试 AppAudio，成功后仅发起一次外呼

#### Scenario: LiveKit 准备期间事件流结束
- **WHEN** LiveKit connect 尚未完成且事件流结束
- **THEN** 系统关闭 LiveKit 后尝试可用备用媒体

#### Scenario: 已拨号后的连接丢失
- **WHEN** 媒体准备完成并已拨号后事件流断开
- **THEN** 系统结束当前会话，不回退媒体或重拨

#### Scenario: 准备期间取消
- **WHEN** 用户取消且底层 connect 仍在等待
- **THEN** 系统释放准备等待并关闭当前媒体，不外呼或尝试备用媒体
