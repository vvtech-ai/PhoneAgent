## Why

多路外呼中，来电期间事件流失败会将当前会话转为 ready，而批次仍通过既有进度接口继续执行。执行占位卡仅依赖 sending，因此消失，顶栏随后可能回落到语音待命；历史重进重新投影活跃批次后又显示正常。用户已确认历史重进是正常对照，本次修复当前页的展示缺口。

## What Changes

- 从当前批次的已有临时进度投影派生执行展示，事件流断开、来电返回和只读补查期间保留原卡位置及批次状态。
- 卡片与顶栏共同区分执行中、拨号状态核对、等待汇总及观察耗尽后的静态未确认。
- 沿用已受理停止的三点禁用门禁、明确失败重试、可信终态清理及历史恢复，不重复外呼或停止。
- Android / iOS 使用同一 Dart 展示规则并运行连续控制器与页面回归。

## Capabilities

### New Capabilities

- `interrupted-batch-execution-presentation`: 运行中批次在来电、断流与前台恢复后的连续展示及终态撤销。

### Modified Capabilities

无。本次落实既有 THINK-01、STOP-01、HISTORY-01 与 VOICE-01 合同，不修改服务端业务状态或协议。

## Impact

实现归属 Flutter presentation，基于最新 origin/codex/dev；Java feature/test_v1.7.0 仅核对进度和账本合同，本次未发现需要改动的后端接口、表、Redis 或配置。复用现有批次投影和恢复 owner，新增小型只读展示判断，不扩大大型控制器，不新增轮询、持久状态、TTS 或平台分支。真实现场结果与自动回归分别记录；本次不含打包、安装或部署。
