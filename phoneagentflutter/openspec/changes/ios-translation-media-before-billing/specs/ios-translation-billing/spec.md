## ADDED Requirements

### Requirement: iOS 媒体准备后启动计费
iOS LOCAL_SIP SHALL 在录音、播放基础初始化成功且通话仍有效后，才发布业务 Connected 和上报计费；Android SHALL 保持原顺序。

#### Scenario: 音频准备失败
- WHEN SIP 已接通且媒体准备失败
- THEN 不发送积分 connected，关闭呼叫并终止原积分会话；不新增用户文案

#### Scenario: 准备期间取消或远端结束
- WHEN 用户挂断、对方结束或账号失效，随后准备返回成功
- THEN 不发送 connected，不运行媒体，并释放原通话资源

#### Scenario: 正常通话
- WHEN 媒体准备成功且身份有效
- THEN 只发送一次 connected，正常启动开场、翻译、计时和录音；保持控件、字幕、结算和历史

#### Scenario: Android 与其他入口
- WHEN Android 或海外翻译使用现有入口
- THEN 不启用新准备门槛，不改变调用顺序和文案
