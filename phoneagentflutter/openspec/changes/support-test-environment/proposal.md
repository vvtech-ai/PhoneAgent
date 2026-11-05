# 支持独立测试环境

## Why
用户批准增加 APP_ENV=test 并使用 .local/cloud-test 双端私有配置构建安装。当前解析仅允许 local/dev/prod，测试环境会关闭业务网络。

## What Changes
- 增加 test 环境，服务地址仍显式配置，不自动替换域名。
- test 沿用非生产 SDK 和翻译默认规则，旧数据导入保持仅 prod。
- Release 仍仅允许 prod；双端测试包采用 Android Debug、iOS Profile。

## Impact
仅配置解析与定向验证；保留原包身份、签名和设备数据。私有配置不入 Git，不触发短信或真实电话。
