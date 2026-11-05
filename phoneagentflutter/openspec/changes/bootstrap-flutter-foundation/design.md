## Context

空目标目录已初始化独立 Git 和 OpenSpec，用户授权实现及验证后 push。Flutter 3.32.0 / Dart 3.8.0 两端已核；Windows Flutter 当前使用 Android Studio JBR 21，非旧原生项目 JDK 11。Mac 现已识别有效 Apple Development 身份，但工程安装尚未验证。

## Goals / Non-Goals

**Goals:** 可构建可测试的双端基础；明确环境、方向、包身份；可维护的后续开发入口与 Git/OpenSpec 记录。

**Non-Goals:** 本批不实现设计复刻、短信、对话、SIP/ASR/TTS、认证、完整 OTA 或升级迁移；不对正式 Android 包覆盖安装。

## Decisions

- 固定 SDK 版本，首批仅解析 Riverpod 2.6.1、go_router 15.1.2、Dio 5.8.0+1（稳定低约束候选）；后续音频/SDK 按需加入，不一次下载所有候选包。
- lib/app 负责组装，lib/core/config 是纯 Dart 配置；启动验证页只显示 Foundation 状态，明确非业务页面。env 必须 local/dev/prod；API 地址缺失显示未配置，不发网络、不假登录。release 要求显式 prod 和 HTTPS，阻止误打开发配置。
- Flutter 模板生成属于一次机械宿主生成，之后手写修改按 ≤3 文件/批。500 行默认上限由用户明确覆盖技能 300 行规则；例外写职责理由、测试和复核条件，生成代码另标。
- Android namespace/applicationId 基准 com.vvtech.aiassistant；debug applicationIdSuffix=.dev，不覆盖现有正式应用。release 没有正式签名时明确失败，不沿用模板 debug 签名。
- iOS Debug/Profile Bundle ID com.chaken.phoneagent.test，Release com.chaken.phoneagent；竖屏配置覆盖 iPhone/iPad，禁止设计未授权横屏。
- B0 mac 验证可使用隔离临时快照，内容 hash/提交与 Windows 对齐；长期使用已确认 Git remote。不得同步 Windows build/.dart_tool 或覆盖已有 Mac 工作区。

## Risks / Trade-offs

- 插件原生/传递依赖未知 → 本批仅最小 Dart 依赖，pubspec.lock 入库，双端构建实测。
- 首次 Android 下载缓慢 → 保留构建输出，诊断仓库可达性，不无界重试或全局改镜像。
- iOS signing Team 不明确 → unsigned build 先验编译；仅从现有身份/项目配置核实 Team 后做测试包签名，冲突时询问。
- 还没有真实设计页面 → 明确工程验证页；不声称登录首页已完成，不发布 APK。

## Migration Plan

独立目录生成，不搬旧业务源码与密钥；后续按 v65 文档和设计提交逐 feature 接入。正式升级签名及旧数据兼容作为专门批次。回滚只回退本项目明确提交，不修改旧项目或设备正式包。

## Open Questions

远端已由用户指定 worldcall/phoneagentflutter；检查可访问性和是否已有提交后仅 push 新分支，不 force。iOS Team/描述文件及签名安装按现场证据处理。

## 2026-09-16 开发签名会话补充

用户选择复用已解锁终端，暂不引入 Runner。Mac 使用内置 screen 的 phoneagent-build 持久会话：用户通过同账号多端接入，在隐藏密码提示中解锁，自动化随后在同一 shell 执行签名及构建。重连只能接入既有会话，不能假设新 shell 继承授权；会话丢失、机器重启或钥匙串重新锁定时，重新请求用户安全解锁，不关闭安全策略或保存明文密码。

验证：断开自动化 SSH 后重新接入，screen 会话与 shell PID 均不变；codesign 重签与严格验签通过；同一 shell 的 Debug xcodebuild 返回 0。此结果不代表重启后零人工恢复，也不改变 Debug 真机需要工具启动的边界。
