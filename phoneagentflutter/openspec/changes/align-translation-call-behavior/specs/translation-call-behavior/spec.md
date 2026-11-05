## ADDED Requirements
### Requirement: 模型决定承载路线
客户端 MUST 从当前国家绑定的可用模型transport决定LOCAL_SIP或BACKEND_WEBRTC，保持模型语言准入和既有区域节点；WebRTC MUST 支持OpenAI/Gemini/千问国际站。
#### Scenario: 千问国际站
- **WHEN** 当前国家绑定有效QWEN BACKEND_WEBRTC模型
- **THEN** 可选择并以qwen3.5-livetranslate-flash-realtime创建会话
#### Scenario: 非中国SIP
- **WHEN** 可信国家绑定LOCAL_SIP模型
- **THEN** 按主被叫国家是否一致选择domestic/international租约，不按中国号码固定分流
### Requirement: 字幕收尾保持会话隔离
客户端 MUST 冻结终止时已有字幕，500ms内允许已有片段最终更新进入原会话归档，拒绝新片段及过期账号更新，不延长媒体采集。
#### Scenario: 页面退出后的末句补全
- **WHEN** 终止后500ms内已有片段译文到达且登录仍有效
- **THEN** 更新旧会话归档，不污染下一通话
### Requirement: 接通计时一致
客户端 MUST 首次connected或translating建立唯一接通起点，显示非负秒向上取整，不改变后端计费契约。
#### Scenario: 直接进入翻译中
- **WHEN** 首个接通类状态是translating
- **THEN** 建立接通时间并正常计时归档
### Requirement: 格式提醒后有限兼容
客户端 MUST 按原生目录格式规则提示，只有显式确认后允许受限号码兼容；保留国家模型语言和登录门禁。
#### Scenario: 用户取消
- **WHEN** 号码格式提醒被取消
- **THEN** 不创建会话或外呼
#### Scenario: 确认期间输入改变
- **WHEN** 登录号码国家或设置快照改变
- **THEN** 旧确认失效，不发起电话

### Requirement: 模型质量反馈与承载一致
客户端 MUST 对已绑定LOCAL_SIP和BACKEND_WEBRTC模型使用对应质量来源，支持千问国际站诊断，保留原面板样式；环境不可用时 MUST 拒绝字幕更新。
#### Scenario: 同一国家绑定不同承载模型
- **WHEN** 同时绑定本地千问和千问国际站
- **THEN** 两者分别显示自身质量结果，不持续加载、不因同名ID覆盖
#### Scenario: 环境不可用
- **WHEN** 有效环境补丁标记overall unavailable
- **THEN** 不接收字幕修正，终止后的迟到更新也不得覆盖已有内容
