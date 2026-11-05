## Context
用户提供的诊断会话：batch_plus 三路结束后生成 makeCall；两次“是的。”仅补充记录，无拨号请求。Skill绑定正确。接口HTTP200且模型被调用；旧日志无法区分不明确与内部失败，不能宣称已确定具体模型根因。
## Decisions
1. 按 workflow=batch_plus 通用拦截 makeCall，回灌纠正给原模型，强制 confirmBatchTask→当前明确确认→原 makeBatchCalls 门禁；保留重拨所选 itemId、任务上下文，禁止扩大目标或自动重拨其他联系人。普通单路不受影响。
2. 完整语义仍由模型判断。显式标识当前确认问题与完整回复；不增加关键词白名单。仅调用/解析异常至多重试一次，正常UNCLEAR/WAIT等立即返回。两次异常返回unavailable标记，不授权拨号。
3. 同一次请求按账号、会话、pending、内容与请求ID复用；有界进程缓存不授予执行权限，前后仍核对当前pending。批量已有账本幂等保留。
4. 客户端异常使用临时失败反馈，原卡保留；不当作用户含糊回复落账，不改拨号执行器、记忆或权益逻辑。
## Validation
独立首轮挑战发现仅回灌路由提示不足，已补充：BatchRetryIntentClassifier在同账号同会话确有前批次可信结果时，结合其后有序用户输入识别本次重拨集合/新任务；无前批不调用。BatchRetryConfirmationPolicy在展示前核对retrySource.batchId/itemIds及原ID/姓名/号码，仅限用户明确选中者；不明确/失败不创建执行卡。批量执行Gate仅对重拨快照严格核对解析后的完整规格，正常首次参数兼容合同保持。结果sourceSnapshotId关联本次确认，确认中的retrySource再关联原batch/item；新尝试保留新的batch/attempt。缓存仅是进程内有界复用，不宣称跨重启持久幂等或授予执行权限。
失败回放→最小修复→原单/多路语义、修改/取消/等待/询问、旧卡/并发重复、记忆确认及无记忆回归；独立agent重读截图、日志和批准方案。未实际外呼不声称真机通过。
