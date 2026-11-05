## Context

`ShellRoute._voices` 使用选中模型 ID 加载系统音色目录，但 `SystemVoicePreviewHost` 当前收到 `state.cloneProvider`。当服务端 `supportsVoiceClone=false` 时，该值为空；`ApiCallModelRepository.voicePath` 拒绝空 ID，因此试听在访问 SDK 前失败。dev 模型 `5` 为 `REALTIME_DOUBAO_DIALOG`，未绑定克隆模型；它的 `xiaohe` 音色启用但无试听 URL。后端已有该实现的动态试听分支，不应把页面名称“Seeduplex”误当成 V3 实现。

## Goals / Non-Goals

**Goals:** 系统音色试听始终使用弹层当前模型 ID；无克隆能力时仍可进入现有统一试听流程。

**Non-Goals:** 不改克隆音色入口、SDK 生成策略、数据库或试听文案，不在 APP 中写死豆包音色 URL。

## Decisions

在现有弹层接线中把传给 `SystemVoicePreviewHost` 的 ID 改为已用于加载目录的 `model.id`。`cloneProvider` 继续只用于克隆能力与克隆音色行为。通过真实 Shell widget 回归检查无克隆模型的试听宿主 ID，另用现有 API 试听测试保护统一目录和 URL 路径。

## Risks / Trade-offs

- 弹层切换模型时宿主 owner 改变，现有 `SystemVoicePreviewHost` 生命周期会停止旧播放；用既有宿主测试复核。
- 源码修复和测试通过不等于真机播放成功；dev 包安装后需重试 `xiaohe` 并观察 SDK 回包、CDN 下载与实际音频。

## Migration Plan

无数据迁移。dev APP 验证后按用户批准的版本打包并保留数据覆盖安装；如运行回归，恢复旧 APP 包，不改后台数据。

## Open Questions

无影响本次 APP 接线修改的待确认项。
