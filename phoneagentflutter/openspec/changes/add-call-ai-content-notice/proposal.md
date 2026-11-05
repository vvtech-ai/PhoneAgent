# 通话控制区 AI 生成说明

## Why
用户确认在实时翻译通话与任务电话通话页的“挂断”文字下方增加“内容由AI生成”，且必须完整显示。

## What Changes
- 共用说明控件，按最新附件采用统一中性灰 #999999、常规字重系统字体，沿用各页挂断文字的文字横向对齐设置；说明字号按原字号 × 0.7 四舍五入（实时翻译 9sp、任务电话 8sp），沿用及按钮到文字的原间距（实时翻译 7dp、任务电话 8dp）。
- 说明不受单个按钮固定宽度限制，允许自然换行，不截断或缩小字号。
- 保留 Flutter 控件、所有控制按钮与通话业务。

## Impact
- 仓库：PhoneAgent；层：presentation；状态 owner 仍为 TranslationCallView / CallSessionState / CallMonitorView。
- 入口：TranslationSessionRoute 及其预览、CallSessionPage 及其预览共用的控制区。
- 不新增或改变接口、账号/session/task/call/attempt 身份、挂断请求、音频或停止状态；保持 STOP-01、VOICE-01。
- 新说明为只读文字，既有对话输入区说明样式保持。
