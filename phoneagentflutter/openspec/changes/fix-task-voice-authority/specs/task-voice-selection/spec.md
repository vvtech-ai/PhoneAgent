## ADDED Requirements
### Requirement: 任务音色使用账号有效配置
正式 Android/iOS 任务音色 MUST 通过 SDK task-tts-voice 接口读取和保存，MUST 使用服务端模型与音色目录，MUST 在服务端确认后才显示已选择。读取/保存失败 MUST 显式失败，不以本地偏好伪造成功，账号变化 MUST 隔离旧请求。
#### Scenario: 选择女声
- **WHEN** 用户选择 Maia 且 SDK 确认成功
- **THEN** 设置当前标记与后续任务播报使用账号的 Maia 选择
#### Scenario: 保存被拒绝
- **WHEN** 模型变更、音色不支持或请求失败
- **THEN** 保留原有效选择并显示失败，不提交其他音色或设备旧值
#### Scenario: 服务端返回新音色
- **WHEN** 当前目录选中 Ethan 或其他服务端有效音色
- **THEN** 外层卡片与列表显示服务端名称，不限制为 Maia/Andre，不把有效目录判为加载失败
### Requirement: 试听使用任务模型的音频预览
正式任务音色试听 MUST 优先使用目录 previewAudioUrl，否则调用 SDK system-voice-preview 的当前任务 modelId/voiceCode 获取音频 URL；MUST 使用独立 HTTPS 客户端有界下载，不带账号鉴权头，MUST 不改变已保存音色。关闭页面、后台和账号变更 MUST 停止试听。
#### Scenario: 试听未选音色
- **WHEN** 当前账号选中 Andre 而用户试听 Maia
- **THEN** 使用当前任务模型的 Maia 音频预览，账号仍选择 Andre
### Requirement: 普通播报不依赖设置目录可用性
普通任务合成 MUST 保持 Runtime 账号音色选择，MUST 不以任务设置目录加载成功作为连接 TTS 的前置条件。
#### Scenario: 设置目录失败时播报
- **WHEN** 设置目录读取失败且 Runtime 连接可用
- **THEN** 普通任务回复仍连接 TTS，不走试听接口
