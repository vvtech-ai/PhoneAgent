## Why

用户要求将 Android origin/feature/test_v1.6.0 最新任务编排修复迁移到 Flutter codex/dev，并保留双方修复后交付开发环境签名包。

## What Changes

- 以原生 9a95803 为只读行为依据，Flutter 54bf1a74 为集成基线。
- 补齐实时批次停止身份、迟到进度隔离、确认与历史投影去重。
- 保留活动通话观察，分离主线路关闭、暂定判断和最终回执，禁止提前展示结果资产。
- 保留现有音色、ASR/TTS、支付、开票、翻译及账号生命周期修复。
- 用户追加首页和任务全部相关代码：一并核对当前模型选择、数字联系人、入口回调、停止与结果展示直接依赖；模型延迟缺样本不再误称全部不可用，服务端尚未接入仍保持禁选。

## Capabilities

### New Capabilities
- `task-160-parity`: 原生任务修复迁移及开发包交付。

## Impact

仅 Flutter conversation/calls/call_models/contacts 的 domain、controller、展示接线及语音提交门槛和测试；首页沿用共用模型契约。不改后端、数据库、SIP 或供应商协议。不执行真实外呼、短信或支付。使用既有开发身份和签名覆盖安装，保留数据。
