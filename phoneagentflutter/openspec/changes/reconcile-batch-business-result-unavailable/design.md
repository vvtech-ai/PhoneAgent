# Design

## 输入合同

后端仅在物理撤销与账务核对足够后追加 schemaVersion 1 的 `BATCH_RESULT_RECONCILED`。公开 payload 为 `batchId`、整数 `sourceResultSequence`、`resolutionCode: BUSINESS_RESULT_UNAVAILABLE`、`batchCallResult`。结果包含相同 `batchId`、`status: INCOMPLETE`、`executionStatus: FINISHED`、`resultCode: BUSINESS_RESULT_UNAVAILABLE`、安全的 headline 与逐路记录。`attemptProofs` 属服务端审核证据，不需要进入 Flutter 展示。原 `ASSISTANT_TURN_COMMITTED` 或 `TOOL_RESULT_RECORDED` 保留，追加事实不改写其内容。

## 历史投影

`BatchReceiptProjector` 先按 session 与 sequence 建立原结果索引，再按序处理事件。核对事件必须指向较早且同会话的原错误结果，顶层和内层 batchId 一致，结果状态与 resolutionCode 符合合同；否则不提升。事件先到而原页未加载时不单独成卡；旧页进入本地事实集合后重新投影，在原批次锚点替换内容，仍只有一张结果卡。普通业务正文按原事件身份保留。

## 进度与停止

进度接口的 `resultSequence` 附着于本地批次回执；同批较新的进度结果可以临时覆盖旧账本卡的展示，但继承原卡位置。新账本事实进入后由持久结果接管。恢复读取拒绝低于已应用序号的快照，不让 seq27 错误倒退 seq28 核对结果。旧 `PENDING / EXECUTION_ERROR` 继续保持已受理停止门禁；新结果只有在逐路均非运行态并符合 `BatchReceipt.stopSettled` 时才解除门禁。客户端不推断 Phone 撤销证明，也不改写旧事实。

## 展示与验证边界

`BUSINESS_RESULT_UNAVAILABLE` 卡片显示“业务结果无法确认”，不使用“首轮完成”“结果回传”“已产生结果”暗示业务结论。自动回放覆盖：事件先到/原页后到、错来源和错批次、seq28 进度与 seq27 账本交错、停止受理后新结果经进度或账本到达。自动回放只证明客户端接线；真实服务端证明和真机显示另行验收。

## 既有文件行数例外

`conversation_stop_binding.dart` 在本次前为 587 行，本次仅补进度序号传递后为 590 行；停止门禁仍由同一 owner 持有。`stop_reentry_recovery_test.dart` 在本次前为 535 行，本次为 634 行；复用同一控制器、账号作用域和停止请求 fixture 才能核对旧错误到新结果的连续副作用。两文件本次均由定向回放及静态分析覆盖。下次增加停止场景时复核测试 fixture 拆分，若停止 owner 出现第二职责再拆生产文件，避免为行数复制状态机。
