## ADDED Requirements

### Requirement: 临时待裁决路由不得显示成功完成

批量外呼客户端 MUST 将 `UNCLEAR`、`PENDING`、`ABNORMAL`、空值及未知临时路由状态显示为待确认或核对中，MUST NOT 将其显示为“任务完成”。

#### Scenario: 物理结束后等待业务裁决

- **WHEN** 客户端收到没有最终 `BATCH_CALL_RESULT` 的 `UNCLEAR` 或 `PENDING` 路由进度
- **THEN** 路由卡显示“结果确认中”或等价待确认文案
- **AND** 批量进度继续等待最终聚合回执

#### Scenario: 新增未知状态

- **WHEN** 客户端收到未识别的临时路由状态
- **THEN** 客户端显示“结果待确认”或等价安全文案
- **AND** 不得把该路由投影为成功完成

### Requirement: 等待线路的逐路文案保持一致

批量进度与逐路回执收到 `LINE_BUSY_WAITING`、`WAITING_FOR_LINE` 或 `WAITING_CALL` 时 MUST 显示“等待呼叫中”，MUST 保持该路运行中事实、原始明细与终态裁决边界。

#### Scenario: 并发线路繁忙后排队

- **WHEN** 某路因线路占用进入等待，后台 headline 仍描述线路繁忙
- **THEN** 当前进度卡和逐路回执均显示“等待呼叫中”，不显示已拨出或已完成
