# 设计

1. `PHONE_CAPACITY_UNAVAILABLE` 是 CALL 类业务失败，展示固定文案“电话线路正忙，本次未拨出，请稍后重试”。
2. 收到结构化 `task_failed` 后，当前轮必须完成 thinking、取消 pending call launch、清空 activity、进入 `ready`；不保留“正在思考”状态。
3. 批量 `BATCH_CALL_RESULT` 只要成员状态均非 running 就是终态；线路忙结果不触发新的用户提交，也不把模型文本当作重试指令。
