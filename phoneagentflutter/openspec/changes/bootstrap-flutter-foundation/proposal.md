## Why

用户已批准按 v65 有效功能、指定 HTML 设计和 Flutter 架构提案开始跨平台开发。首先建立可验证的独立工程，尽早暴露 Android/iOS 工具链问题，避免等全部页面写完才首次构建。

## What Changes

- 初始化 Flutter 3.32.0 / Dart 3.8.0 的 Android/iOS 工程、独立 Git 和中文 OpenSpec。
- 设置默认 500 行手写文件约束、按职责拆分、例外记录及验证后自动提交/push 规则。
- 建立基础启动验证页、竖屏、环境配置、Riverpod/go_router/Dio 基础依赖、测试与构建脚本。
- Android 保留生产 applicationId 的目标映射，但开发 debug 使用独立 .dev 身份；iOS debug 使用用户指定测试 Bundle ID，release 使用正式 ID。
- 实际发布签名、旧数据迁移、设计页面、登录/语音/通话属于后续批次；本批不能发布为已完成业务版本。

## Capabilities

### New Capabilities

- `app-foundation`: 工具链、启动验证、环境隔离、平台标识和构建门禁。
- `migration-governance`: 有效范围、500 行规则、需求/设计依据和 Git 交付约束。

### Modified Capabilities

无。已有 AI 工作流规范保持，补充项目级边界。

## Impact

仅新项目 app/lib/test/android/ios、scripts、docs、OpenSpec；不修改旧 Android/backend。不发真实短信、认证或外呼，不接数据库/SIP/ASR/TTS。验证 OpenSpec、格式、analyze、test、Android debug APK、Mac iOS unsigned build，并在可用签名/设备上验证启动。用户已指定 https://gitlab.vvtech.tech/worldcall/phoneagentflutter.git，仅 push 本项目开发分支，不 push 到旧项目。
