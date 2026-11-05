## Why

2026-10-29用户批准：首页首次登录先显示离线卡片，但后台配置只写缓存，必须切换才看到；随包旧卡片顺序、名称和启停状态过时。批准按环境隔离快照，保持首屏速度和原任务逻辑，独立回归后推送test_v1.8.0_fix，并出测试签名包。

## What Changes

- 首页先用完整有效缓存/环境随包快照，后台原有单飞请求成功后直接更新当前首页。
- 测试随包快照对齐已签名读取的测试发布20261012.37；dev/prod保留原已确认快照，测试配置不污染其他环境。环境选择仅为包内常量查找，不增加启动网络请求。
- 保留用户排序/隐藏、最低版本和启停规则；已打开任务冻结原卡片/Skill/开场及TTS，不随首页更新。
- 保留签名、ETag/304、账号代次、错误回退与单飞请求。

## Capabilities

### New Capabilities
- `home-published-live-refresh`: 首页即时接收有效发布配置与分环境随包快照。

### Modified Capabilities
无已归档规格；替代repair-home-entry-snapshot-readiness中“当前首页不接收HTTP”部分，任务内快照冻结要求保留。

## Impact

Flutter首页data/domain/controller及provider接线、定向测试和现有知识库。沿用1.0.54+47，测试Release ARM64原项目签名，不安装、不部署。
