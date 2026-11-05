# 实施设计
实际检出均为feature/test_v1.8.0，Flutter HEAD 3af2c3bf、后台HEAD c4976045，开始时工作区干净。
SDK层owner为邀请注册Service/提交事务。新增独立邀请人生命周期Guard/Mapper，读取逻辑删除墓碑及到期申请，在钱包→账号锁之后取当前Clock，避免worker延迟及提交竞争。查询异常不转为无效码。新校验保留原缺失账号INVITE_RESPONSE_INVALID语义；已确认CANCELLED或到期未撤销才返回新业务码。事务失败沿原abort/outbox释放预占，不新建奖励。COMMITTED重放不复验当前邀请人。
Flutter只增加白名单、InviteFailure固定映射，继续由AuthController.notice→AuthRoute共用Toast显示；不新增弹窗。新错误为可更换邀请码的确定失败，清理当前失败注册操作ID。
源码额外发现SDK邀请挑战在失败前即被消费；仅本次明确业务拒绝恢复未过期的原挑战，不延长、不泛化恢复其他错误，以满足更换邀请码重试。
验证：新错误→Toast→停留输入页→更换→重试、未保存会话/未奖励；SDK最终删除/截止边界/未到期/正常/提交中变化/已提交重放/原abort。对应新增INVITER-01～04及注销DEL边界。无真实短信/数据库写入/部署。共享任务规则不变。
