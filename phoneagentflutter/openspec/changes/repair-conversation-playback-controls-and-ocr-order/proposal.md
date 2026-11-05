## Why

用户确认生成中保持辅助入口禁用，仅TTS播报时放开；文字输入复用语音停止播报能力。首次选图的0锚点在后端补存开场白后，恢复时会把OCR卡片插到开场白前。

## What Changes

- 仅删除辅助入口对TTS的额外限制，继续使用canSend约束思考和回复生成，并保留录音、预检、拨号和停止保护。
- Composer向文字输入及展开编辑器传递已有停止播报回调，优先级与语音模式一致，不新增提示。
- 按明确初始开场账本身份修正OCR最小显示边界，保留上传锚点、普通对话位置与图片顺序。

## Capabilities

### New Capabilities
- `conversation-playback-controls-and-ocr-order`：区分生成与播报交互，兼容OCR历史开场顺序。

### Modified Capabilities
无。

## Impact

仅Flutter任务对话展示与锚点投影、相关测试。无后端、数据库、接口、付款、版本及平台配置变化。已有翻译/拨号未提交改动保持。
