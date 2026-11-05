# Android 私有构建输入工程内固定化

## Why
用户批准后续不再从外部“安卓签名和配置”目录读取文件，所需配置和登记签名迁入本工程的 Git 忽略目录。

## What Changes
- 复用 `.local/cloud-dev/device-defines.json`、`.local/cloud-test/device-defines.json`；签名固定为 `.local/android/signing/{signing.properties,registered.keystore}`，不建立重复配置目录。
- Windows 构建入口及 Gradle 只接受工程内私有输入，新增 macOS 测试构建入口；缺失或路径越界立即失败。
- 保留 Flutter 3.32.0、测试 Release 门禁、原登记证书及原始文件，不修改 UI/iOS。

## Impact
涉及构建脚本、Android 签名路径策略及当前工程约定；私有文件不进入 Git。用户确认后执行；本轮无安装、提交或推送。
