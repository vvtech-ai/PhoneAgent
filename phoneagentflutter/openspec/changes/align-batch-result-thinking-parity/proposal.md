## Why
Flutter 多路任务的回执作为独立消息先于结果渲染，实时结果被 ledger 替换后编排发生跳动；执行阶段提示与 thinking_delta 内容也未完整迁移。用户已批准按原生 v1.6.0 修复并交付测试签名包。

## What Changes
- 同批次进度、执行结果、模型评价、任务评分之后展示回执，实时与历史一致。
- 对齐原生回执的绿色卡片、文件/类型说明及下载状态按钮。
- 恢复执行阶段提示和实际思考内容，支持结束状态、最近三行显示及自动滚动。
- 测试 Release 使用用户指定 1.0.52 (45)，沿用原登记签名。

## Capabilities
### New Capabilities
- `batch-result-thinking-presentation`: 多路任务结果编排与思考展示。

### Modified Capabilities
无协议变更。

## Impact
仅 Flutter conversation domain/presentation 和定向测试。无 Java/Web、数据库、提示词、SIP、ASR/TTS 或供应商协议修改；不执行真实外呼、部署、安装或支付。
