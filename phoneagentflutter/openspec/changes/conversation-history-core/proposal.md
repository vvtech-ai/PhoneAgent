## Why

首页与账号请求已接通，下一步是统一对话和任务恢复。v65 时间线为持久事件事实源，不能只展示详情中的旧 messagesJson，也不能把 done 当作任务成功。先建立协议、历史同步与状态边界，再接页面，避免重新形成超大 Controller。

## What Changes

- 实现任务列表与通话历史读取、排序和状态兼容；所有普通 sessionId 保留恢复入口。
- 实现详情与分页 timeline 同步、事件去重、缺口重同步、限定旧数据 fallback。
- 实现 SSE 帧解析、v65 流事件与统一文字提交契约，文字 channel 固定 voice。
- 分批接入任务列表及统一页基础消息/输入；录放音、单路自动确认与外呼、批量/复杂工具卡明确留独立完成项，不以普通聊天替代完整功能。

## Capabilities

### New Capabilities
- conversation-history-core: 任务入口、历史 ledger、流式协议与统一文字状态。

### Modified Capabilities
无。前批未验收规格保持 active，不提前同步归档。

## Impact

Flutter core/network 和 features/tasks、conversation；不修改后端、数据库、提示词或原生音频。新增合成协议、分页/晚到/退出测试和页面自动化。2026-09-16 用户授权测试环境真实文字多轮与恢复联调；不通过自动化下达真实外呼任务。每个手写微批最多三文件，默认 500 行。
