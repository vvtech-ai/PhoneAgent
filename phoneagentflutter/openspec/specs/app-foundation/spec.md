# app-foundation

## Purpose

记录已批准的目标契约；实现进度以 active change/tasks 为准，不代表已完成验收。

## Requirements

### Requirement: 可重复的双端基础工程
项目 MUST 固定 Flutter 3.32.0 / Dart 3.8.0，提交依赖锁，提供 Android/iOS 宿主、分析和自动测试。

#### Scenario: 首次构建
- **WHEN** 使用指定 SDK 拉取同一提交并解析锁定依赖
- **THEN** analyze、test 和 Android debug 构建必须通过；iOS 编译与签名安装分别记录结果

### Requirement: 启动与配置隔离
基础应用 MUST 仅竖屏，校验 local/dev/prod 环境，缺少 API 配置不得发起业务请求，启动验证页不得宣称业务已完成。

#### Scenario: 未配置 API
- **WHEN** 无 API_BASE_URL 启动开发包
- **THEN** 展示明确未配置状态，不发真实短信、认证或外呼

#### Scenario: 非法环境或发布配置
- **WHEN** 环境未知、地址含凭据或 release 未显式使用 prod/HTTPS
- **THEN** 校验返回明确问题，不建立可用业务网络配置

### Requirement: 平台身份安全
Android MUST 保留生产身份目标 com.vvtech.aiassistant，debug 使用 .dev；iOS Debug/Profile MUST 使用 com.chaken.phoneagent.test、Release 使用 com.chaken.phoneagent。没有正式签名不得输出伪 release 包。

#### Scenario: 安装基础调试包
- **WHEN** 安装 B0 debug 构建
- **THEN** 不覆盖 Android 正式包，iOS 使用已指定测试身份
