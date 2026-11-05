# 可信来电 Android 三环境配置读取

## Why
用户确认将三个构建模式下硬编码的可信来电凭据迁入既有 cloud 环境文件，Git 保存读取接线和脱敏说明，真实密钥继续保留在忽略目录。

## 后续来源调整
用户随后批准centralize-trusted-caller-local-properties，将可信字段集中至工程根目录local.properties；本变更的cloud可信来源描述保留为历史实现证据，当前读取规则以新变更及当前工程说明为准。cloud业务配置和原发布边界保持。

## What Changes
- dev/test/pro 分别从 `.local/cloud-dev|cloud-test|cloud-pro/device-defines.json` 读取独立的 TRUSTED_CALLER_APP_KEY、TRUSTED_CALLER_APP_SECRET。
- Gradle 校验并注入原生 BuildConfig；main 源集保留唯一读取器，移除本地重复类，Android 生成工具不再读取原生历史提交。
- 缺失、环境不符、重定向路径立即失败，保持 SDK 映射 dev/test→test、pro→pro，生产 Release 门禁保留。

## Impact
仅 Android 配置与构建链，不改 UI、iOS、业务 API、签名或版本。本侧聊不切分支、不提交推送、不安装或真实外呼。现有 cloud-pro 的 APP_ENV 为 test，保留非可信来电字段并作为生产待配置项，不将其认定为有效生产配置。

## 后续Git授权
用户在实施完成后明确要求提交并推送远程，覆盖上段实施阶段不提交推送的约束。本项仅同步可提交代码、脱敏示例及记录至已核对的origin/codex/dev，真实凭据、安装及运行验收边界不变。
