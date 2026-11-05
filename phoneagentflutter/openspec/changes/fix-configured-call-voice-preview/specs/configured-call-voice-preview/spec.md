## ADDED Requirements

### Requirement: 已配置 URL 的系统音色允许试听
通话音色页 MUST 对目录中 previewAudioUrl 非空的系统音色提供试听入口，不得要求其 ID 位于本地样音名单。MUST 保留加载、保存和待刷新时的禁用状态，试听 MUST 不改变音色选择。

#### Scenario: lzy 已有试听链接
- **WHEN** 当前目录返回不在本地名单中的 lzy 及其 previewAudioUrl，页面不处于忙碌或待刷新状态
- **THEN** Android/iOS 的试听按钮可点击
- **AND** 直接下载该 URL 播放，不调用在线生成接口，不保存音色选择

#### Scenario: 刷新或保存期间
- **WHEN** 当前音色正在加载、保存，或克隆状态待刷新
- **THEN** 已有 URL 的音色试听按钮仍禁用

#### Scenario: 远端动态试听目录
- **WHEN** 系统音色具有有效ID但没有previewAudioUrl，页面不处于忙碌或待刷新状态
- **THEN** Android/iOS允许通过既有动态试听接口获取音频，不保存或切换音色选择
