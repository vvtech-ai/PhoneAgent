## Why

无缝升级核对固定v65发现条件评分草稿保存在task_rating_drafts，按账号/taskType/taskId的SHA256定位。Flutter已有评分页面与安全草稿存储，但没有旧源导入，导致升级后未提交分数、建议和重试提交标识不可见。用户已明确保留条件入口及旧数据兼容。

## What Changes

- 在Android同生产包与精确prod作用域内按当前任务只读导入，不枚举账号或全部偏好。
- 共享Dart转换分数、跳过克隆、建议与submissionKey；新存储优先、导入成功落盘后返回，清除留标记防止旧草稿复活。
- 按账号串行并绑定仓库生命周期，失败允许重试，旧文件不写不删；列出真实同签名升级步骤。
- 补齐共享页面读取失败保护：控制器/存储解析错误不得退化成可编辑空草稿，三端统一显示失败与显式重试，保留原内容和提交key。

## Capabilities

### New Capabilities
- `android-legacy-rating-drafts`: 有效条件评分草稿的安全一次导入。

### Modified Capabilities
无。

## Impact

原导入影响评分data/store/provider及Android薄只读通道/MainActivity注册；后续读取保护仅改共享Controller/Sheet/Route及存储错误语义，对Android/iOS/Web统一生效。无新依赖，无后端API/数据库/提示词/SIP/ASR/TTS或真实积分操作。原生改动已单独编译验证，纯Dart保护增量只做相关定向及analyze；不覆盖真实设备或生产签名，不改变资格显隐、服务端只读和奖励规则。
