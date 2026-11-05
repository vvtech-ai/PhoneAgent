# 修复任务音色选择与试听未生效

## Why
用户在 iOS 开发包发现 Maia 女声试听和实际任务播报仍为男声。旧客户端只写设备偏好，当前 Runtime 从账号 TASK_VOICE_TTS 配置选择实际音色。真机 GET 成功且已选/默认 Ethan，固定 Maia/Andre 解析不适用。用户指定原生 aiassistant-app feature/test_v1.6.0 为对照，当前设置使用动态目录，试听使用 SDK 音频预览接口。

## What Changes
- 正式任务音色 Store 使用 SDK GET/PUT api/account/settings/task-tts-voice，展示动态目录及当前选择，服务端确认后才发布选择。
- 账号代次隔离 Store/controller，失败不以设备旧值替代服务端事实。
- 试听按原生当前接口获取/下载音频，复用音频焦点与播放器；普通任务播报不以前端目录读取为前置条件，Runtime 选择账号音色。

## Impact
Android/iOS 共用修复，不修改通话/克隆音色、后端、凭据或依赖。覆盖 complete-v66-cross-platform-settings 的正式设备偏好假设。自动验证协议和状态；真实音色听检由用户完成。
