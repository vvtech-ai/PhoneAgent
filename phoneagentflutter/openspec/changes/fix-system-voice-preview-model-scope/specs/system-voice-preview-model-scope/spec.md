## ADDED Requirements

### Requirement: 系统音色试听使用所属通话模型
通话音色页 MUST 以当前展示的通话模型 ID 获取系统音色目录和缺失试听 URL 时的动态试听地址；是否支持声音克隆 MUST 不改变该 ID。试听 MUST 不保存或切换当前选中的音色。

#### Scenario: 模型不支持克隆且音色没有试听 URL
- **WHEN** 用户打开不支持克隆的豆包模型音色列表并点击 `xiaohe` 试听，该音色没有 `previewAudioUrl`
- **THEN** APP 使用该豆包模型 ID 查询统一音色目录，并用同一模型 ID 请求动态试听地址
- **AND** 不因克隆模型 ID 为空而在客户端拒绝请求

#### Scenario: 模型支持克隆且系统音色已有试听 URL
- **WHEN** 用户打开支持克隆的通话模型音色列表并点击具有 `previewAudioUrl` 的系统音色
- **THEN** APP 仍使用该系统音色所属通话模型 ID，并直接下载已有试听 URL
- **AND** 不调用动态试听生成接口或更改克隆音色归属
