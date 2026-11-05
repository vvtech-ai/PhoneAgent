## Why

全量回归的既有 fresh_balance_admission 批量拒绝用例暴露解码缺口：task_failed 仅排除 callResult，遗漏 batchCallResult，结构化批量结果变成普通 error，导致既有钱包刷新和一次业务播报未触发。

## What Changes

- 结构化单通与批量失败都沿用现有 finalResponse 分支；无结构结果的未知失败仍保持 error。
- 保留原结果、命令和拒绝语义，不报告成功，不重拨。
- 增加单通 / 批量失败解码守护，并重跑既有真实 controller 拒绝回放。

## Capabilities

### New Capabilities

- `structured-batch-failure-results`: 失败事件保留结构化批量结果。

### Modified Capabilities

无。

## Impact

仅解码 guard 与测试；API、后端、计费规则、SIP 和播报协议不变。
