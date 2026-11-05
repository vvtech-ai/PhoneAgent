## ADDED Requirements
### Requirement: 原登录接口会话失效准确分类
系统 MUST 在原鉴权范围内返回明确的注销中/已注销/代次失效标识；普通停用及权限不足 MUST NOT 触发客户端退出。
#### Scenario: SESSION-01 并发失效
- **WHEN** 同会话多个请求收到失效
- **THEN** 系统 MUST 仅清理及导航一次，提示一次
#### Scenario: SESSION-02 旧响应
- **WHEN** 原账号或旧token响应迟到
- **THEN** 系统 MUST 不退出新登录或已更新凭证
#### Scenario: SESSION-03 兼容
- **WHEN** 普通403、账号不匹配、网络错误或可续期的401
- **THEN** 系统 MUST 保留既有处理，不误退出
#### Scenario: SESSION-04 注销仲裁
- **WHEN** 本机注销提交或原结果查询期间收到失效
- **THEN** 系统 MUST 保留原操作，不重复申请，不覆盖注销成功提示
#### Scenario: SESSION-05 清理失败
- **WHEN** 本地退出清理失败
- **THEN** 系统 MUST 保持业务阻断并提供有界手动重试，不连续弹提示
#### Scenario: SESSION-06 再次登录
- **WHEN** 退出后新登录
- **THEN** 系统 MUST 不重播旧提示，后续新会话独立处理
