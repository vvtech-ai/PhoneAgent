## ADDED Requirements
### Requirement: 最终注销的邀请人不能产生新邀请注册
系统 MUST 在新注册校验及最终提交检查邀请人是否CANCELLED或已到注销截止且未撤销。系统 MUST 返回HTTP409、INVITER_ACCOUNT_CANCELLED及“邀请码无效”；Flutter MUST 通过既有Toast显示“邀请码无效”，保留有效本人验证上下文，允许更换邀请码。系统 MUST NOT 对已COMMITTED历史注册追溯撤销，不改变未到期冷静期和其他错误规则。
#### Scenario: INVITER-01 最终注销
- **WHEN** 正常活动邀请码归属最终注销账号
- **THEN** 系统 MUST 拒绝新注册且不预占名额或奖励
#### Scenario: INVITER-02 提交竞争
- **WHEN** 预占后邀请人到期或被最终注销
- **THEN** 系统 MUST 在提交锁内拒绝、沿原abort回收名额，无新账号或奖励
#### Scenario: INVITER-03 更换重试
- **WHEN** App收到专用业务码后更换有效邀请码
- **THEN** 系统 MUST Toast显示原文、保留原手机号与未过期验证、不先进首页，新操作成功后才登录
#### Scenario: INVITER-04 历史及冷静期
- **WHEN** 重放COMMITTED或邀请人冷静期尚未到期
- **THEN** 系统 MUST 保留原成功结果或正常注册规则
