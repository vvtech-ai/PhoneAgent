# 已登记测试环境 Release APK

## Why
用户要求后续测试交付采用 Release，减少调试产物体积，并安装到当前连接的手机。

## What Changes
- 显式 test 允许 Release，沿用已登记的 .test 包名和原项目签名；默认 dev 的生产 Release 门禁保留。
- 测试构建入口默认 Release，可显式选择 Debug；test Release 仅保留 ARM64，暂不启用 Java 混淆和资源裁剪。
- 保留供应商受保护原生库字节，不修改业务流程、后端或数据库。

## Impact
Android 构建策略、脚本、定向验证和真机覆盖安装。真实支付另需业务验收。
