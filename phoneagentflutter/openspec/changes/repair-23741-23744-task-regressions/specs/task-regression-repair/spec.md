## ADDED Requirements

### Requirement: 权限弹窗不得取消当轮查询回复播报

系统 MUST 区分 inactive 权限弹窗与真正后台状态；权限弹窗返回后保持当轮回复的播报资格，用户主动停止及真正后台仍 MUST 隔离旧回复。

#### Scenario: 通讯录授权返回

- **WHEN** 当轮查询期间页面 inactive 后 resumed，并收到 TEXT_REPLY
- **THEN** 在原播报偏好开启时 MUST 通过既有 TTS 通道播报，不重发查询

#### Scenario: 真正退到后台

- **WHEN** 页面 hidden、paused 或 detached
- **THEN** MUST 中断旧播报并拒绝迟到回复自动播出

### Requirement: 单路录音入口必须保留旧版有效对话门槛

系统 MUST 在存在有效通话对话及录音锚点时才显示单路录音；MUST NOT 将 callId、结果摘要或缺失时长视为接通证明。明确未接通或零接通时长 MUST 隐藏入口。

#### Scenario: 未接通的实时或历史结果

- **WHEN** 结果包含 callId 但无有效对话，或明确 answered=false、接通时长为零
- **THEN** MUST 不创建录音卡或发起录音查询

#### Scenario: 任务失败但有有效对话

- **WHEN** 结果为 FAILED 且有 AI 或对方的有效对话、有效录音锚点，无未接通反证
- **THEN** MUST 保留录音入口，不把任务失败等同通话未建立

### Requirement: 通话页面必须禁止任何回退

系统 MUST 在通话页显示期间拦截返回键、返回手势与 maybePop；MUST NOT 提供返回按钮或通过返回动作收起通话页，不论回退目标为何。显式挂断和服务端终态仍沿用原流程。

#### Scenario: 通话进行中尝试回退

- **WHEN** Android 或 iOS 用户触发返回，或导航器执行 maybePop
- **THEN** MUST 保持当前路由与通话页可见，保留观察且不隐式挂断
