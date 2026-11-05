# 设计

ApiTaskVoiceStore 复用 AccountApi 的 SDK 路由、C1/Bearer 和账号代次。读取目录中的 modelId、selectedVoice、defaultVoice 与已启用 voices，接受 Ethan 等动态 voice code，保留 displayName/description/previewAudioUrl；默认和已选必须存在目录。每个正式音色行保留展示时的 modelId，Controller 原样传递所选行；设备旧音色没有模型身份，不能提交到正式 Store。失败不展示固定列表冒充有效目录。保存先获取当前目录并确认其模型仍与所选行一致，变化则在 PUT 前拒绝；以展示时 modelId/voiceCode PUT，由服务端再次防止 GET 后模型变化。验证回执仍属于相同模型并确认目标音色。不上报旧设备偏好，不自动覆盖账号配置。

正式 Store 和设置 controller 随账号代次销毁，旧请求不能影响新账号。普通回复保持已有 TTS 连接/PCM/焦点生命周期，不读取设置目录作为前置条件；Runtime 按账号配置选择音色，避免目录异常造成无声。

对照 aiassistant-app feature/test_v1.6.0 1e67c2d，试听读取当前任务模型/音色，优先 previewAudioUrl，否则 POST system-voice-preview/models/{modelId}/voices/{voiceCode} 获取 URL。复用 ApiSystemVoicePreview 的有界 HTTPS 独立客户端下载与 SystemVoicePreviewController/FocusedClonePreviewPlayer 生命周期。任务适配器只映射 UI 状态，不写选择；关闭/后台/账号变化停止，普通播报不走试听接口。旧本地/WS 试听仅保留已有合成测试构造，不接正式任务设置。

验证：GET/PUT 回执、Ethan 与动态列表、双端选择反馈、账号迟到/失败；正式试听 provider 的 SDK 音频路径，独立客户端不泄漏鉴权头；普通播报在目录失败时仍连接 TTS。flutter analyze、定向测试、OpenSpec、iOS Profile 构建安装启动。真实声音留用户听检，不发起电话或短信。
