## Decisions

1. 根因候选是思考合并仅寻找同 command 的 assistant，缺失时使用列表尾。结果补查会使原先临时 user 被 durable user 取代，早轮没有 assistant 时思考便落到所有 durable 内容后。
2. 保留已有有 assistant 的定位；否则放在同轮已知内容之后，或下一有事实的轮次之前。只处理思考条目，不排序整个对话。
3. 首先记录真实 controller 回放 RED，再最小修复与相邻合并、思考、账本和道歉回归。
4. 历史未持久化的思考不凭空生成；恢复流程不自动播报。现场日志没有思考 command 身份，只能证明结果与补查交错，不能据此签收全部现场根因。

## Validation

两轮本地 thinking → 第三轮 finalResponse / gap committed 到达顺序互换 → 相同账本重复补入，检查消息身份、轮次相对位置、结果说明顺序、思考结束状态及无重复命令。必要页面坐标核对通过同一 ConversationState 渲染。
