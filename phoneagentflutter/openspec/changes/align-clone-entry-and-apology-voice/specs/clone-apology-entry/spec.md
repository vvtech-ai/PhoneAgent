## ADDED Requirements
### Requirement: 声音克隆按钮必须立即检查当前权益
系统 MUST 在模型页和音色弹层共用入口读取当前会员权益；明确禁止时直接显示取消和去升级，不进入模型选择或认证。

#### Scenario: 无克隆权益
- **WHEN** 当前会员 cloneEntitlements.enabled 为 false 并点击任一声音克隆按钮
- **THEN** 显示暂无声音克隆权益；取消回到来源页面；去升级打开会员积分页面

### Requirement: 道歉任务必须确认本次使用的克隆音色
系统 MUST 对齐原生最新道歉流程，在使用确认和可用音色核验完成前阻断任务提交，拒绝时停止任务；切换模型时重新核验并保留提示卡。

#### Scenario: 确认后继续
- **WHEN** 用户确认使用当前模型的可用克隆音色
- **THEN** 后续聊天及拨号确认携带当前会话的 callVoiceSelection；不改变默认音色

#### Scenario: 正式页面首次创建
- **WHEN** 首页打开道歉会话，且正式Provider接有OCR生命周期回调
- **THEN** 在owner构造完成后才允许OCR访问owner；首张本地确认卡可见，不发生未初始化读取或灰屏

#### Scenario: 候选音色和过期查询
- **WHEN** 选择READY且CHARGED的候选，或连续切换模型
- **THEN** 候选以activate=false确认后重查；旧代次结果不能覆盖新模型

#### Scenario: 测试签名交付
- **WHEN** 验证通过后打包
- **THEN** 使用最新合并源码与登记签名生成测试环境Release ARM64包，版本号递增并记录核验证据
