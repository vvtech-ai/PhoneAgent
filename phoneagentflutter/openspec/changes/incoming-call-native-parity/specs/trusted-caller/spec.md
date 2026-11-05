## ADDED Requirements
### Requirement: 可信来电必须保持当前事件导航归属
凭据展示 SHALL 统一四验证状态和有效原生资源，关闭动作 MUST 仅作用于当前存活路由的当前展示事件，旧回调不得关闭新事件或覆盖业务。
#### Scenario: 后来事件替换凭据
- **WHEN** 来电A的关闭回调保留到来电B展示后执行
- **THEN** B保持显示，A旧回调不触发B关闭
#### Scenario: 原页面已销毁或被覆盖
- **WHEN** 旧凭据关闭回调再次执行
- **THEN** 不导航、不访问已释放State、不影响覆盖页面
### Requirement: Android来电后台必须随有效账户准入
Android来电组件 SHALL 根据当前账户/环境/配置及有效平台条件启用和清理，不以本地guide或权限成功伪造SDK授权，不启用无资格系统精确状态能力。
#### Scenario: 退出或切换账户
- **WHEN** 当前来电账户失效
- **THEN** 先停止旧账户后台组件，再执行SDK及SIM归属清理
### Requirement: iOS双扩展必须匹配指定环境身份
iOS MUST 为Debug/Profile使用com.chaken.phoneagent.test.KXLiveActivityExtension与com.chaken.phoneagent.test.KXPushServiceExtension，为Release使用com.chaken.phoneagent.KXLiveActivityExtension与com.chaken.phoneagent.KXPushServiceExtension；Team SHALL 与对应App一致。
#### Scenario: 构建测试或正式版本
- **WHEN** 解析三个配置的构建设置
- **THEN** 双扩展均正确嵌入且身份/Team/版本一致，不回退到旧TrustedIdentity身份
### Requirement: 通知服务扩展必须保持有界回退和验证边界
NSE SHALL 参照有效原生通信通知，头像仅HTTPS且有5秒/2MB边界，失败/超时回退原通知并仅完成一次；通知外观 SHALL NOT 声称SDK验签成功。
#### Scenario: 畸形通知或头像失败
- **WHEN** 四来电字段缺失或头像请求失败/超限/扩展即将超时
- **THEN** 保留可交付通知，不挂起或重复回调，不向Flutter输出token

### Requirement: 设置入口必须按平台直接展示目标页面
可信来电设置点击 SHALL 保持原设置页可见，MUST NOT 展示Flutter状态读取中间页。iOS SHALL 使用应用级幂等初始化和本地首次说明事实后直接全屏展示说明或SDK设置；Android SHALL 复用应用级初始化并由平台适配同步SIM后直接进入首次SDK引导或后续设置。授权查询 SHALL NOT 阻塞打开。失败 SHALL 原页提示并允许重试，重复点击及失效owner/覆盖/销毁不得迟到打开或误关闭其他页面。
#### Scenario: 准备等待或失败
- **WHEN** 点击入口后SDK准备未完成或失败
- **THEN** 原设置页保持可见，无新增状态route；失败原页反馈，再点可重试
#### Scenario: 首次或后续打开
- **WHEN** 有效当前账户准备完成
- **THEN** 按对应平台首次/后续直接展示目标页，不等待授权查询；退出回原设置页
#### Scenario: 旧入口异步结果
- **WHEN** 准备期间账号切换、页面被覆盖或销毁
- **THEN** 不继续打开目标页，不关闭覆盖页面或新账号页面
