## ADDED Requirements

### Requirement: 手工邀请码提交必须具有独立幂等身份
客户端 MUST 为手工及外链邀请码注册持久化稳定 registrationRequestId；来源 MUST 来自输入入口，MUST NOT 按格式猜测 REFERRAL。相同提交重试复用 ID，手机号、码或来源变化重新生成，短信和 challenge MUST NOT 持久化。
#### Scenario: 手工好友码由服务端分类
- **WHEN** 手工输入邀请码后提交或恢复重试
- **THEN** 携带稳定请求号而不强制 REFERRAL，由服务端可信分类；普通登录行为保持

### Requirement: 邀请分享必须使用完整同源响应快照
客户端 MUST 使用 me/code 响应的活动、个人信息与邀请码作为整体快照；缺少有效活动 MUST 返回 INVITE_ACTIVITY_CHANGED 并禁止分享，MUST NOT 回退拼接旧活动。
#### Scenario: 发码期间换期
- **WHEN** activity 和 me/code 返回不同周期
- **THEN** 使用完整新快照，海报与事件归属新周期；缺快照显示刷新提示

### Requirement: 邀请刷新必须清旧并合并忙碌请求
客户端 MUST 清除刷新前有效分享状态，忙碌时刷新 MUST 合并并在当前请求或操作结束后执行，MUST 保留账号及异步代次隔离。
#### Scenario: 保存海报期间回前台
- **WHEN** 操作未结束时收到多次刷新
- **THEN** 操作仍绑定原快照，结束后执行一次刷新，统计失败不撤销设备成功

### Requirement: 双端邀请提示必须按业务场景对齐
客户端 MUST 按 AIAssistant1 的活动页及注册错误提示分别映射，补齐关闭/不可用错误；MUST 保留 Flutter 共用控件及 iOS 欢迎页业务错误放行白名单。
#### Scenario: 活动不可用
- **WHEN** 服务返回 ACTIVITY_DISABLED 或 ACTIVITY_UNAVAILABLE
- **THEN** 活动页显示活动暂未开放新邀请码；欢迎页不能将未知不可用错误当作有效奖励
