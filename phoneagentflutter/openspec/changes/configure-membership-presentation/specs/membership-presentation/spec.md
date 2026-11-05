## ADDED Requirements

### Requirement: 每条权益独立字号和可选介绍
系统 MUST 通过已发布配置下发每条权益字号；未配置 MUST 使用常规字号。两项可选介绍 MUST 仅在该等级明确勾选时显示，MUST NOT 按高级等级推测展示，MUST NOT 改变真实功能授权。
#### Scenario: 旧配置与混合字号
- **WHEN** 旧配置缺少 displayOptions 或仅 monthlyPoints 配置 LARGE
- **THEN** 未配置权益使用常规字号，仅明确配置的积分行放大
#### Scenario: 免费开启而高级关闭
- **WHEN** 免费等级 priorityLine.visible=true 且高级未配置
- **THEN** 免费展示高峰极速优先线路，高级隐藏该介绍

### Requirement: 模型权限短提示忠于实际配置
客户端 MUST 按已发布实际支持等级生成短文案；只有从某等级至高级全部支持时才能展示及以上；MUST 保留当前套餐与运行环境限制的真实含义。
#### Scenario: 非连续配置
- **WHEN** 仅初级、高级支持模型
- **THEN** 显示初级、高级会员可用而非初级及以上会员可用

### Requirement: 会员支付与订单展示精简
会员协议 MUST 完整单行且可勾选并打开协议；即时积分到账下的小字与订单退款提示 MUST 移除。排队到账说明与实际支付规则 MUST 保留。
#### Scenario: 窄屏支付
- **WHEN** 用户在窄屏打开会员页并点击协议
- **THEN** 协议保持单行、无溢出且打开协议，提交仍受同意状态约束


### Requirement: 后台权益表单紧凑且自适应
后台 MUST 在宽屏成对排列相关字段，窄屏单列，MUST 保持表单可操作、无横向溢出和保存取消可到达。
#### Scenario: 桌面与手机
- **WHEN** 管理员编辑或新增会员等级权益
- **THEN** 桌面采用双列，窄屏采用单列，内容过长仅在弹窗内容区滚动，底部按钮保留
