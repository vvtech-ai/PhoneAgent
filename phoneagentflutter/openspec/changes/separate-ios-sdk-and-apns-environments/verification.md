# 执行与验证证据

基线 codex/dev@6f0fcec0a88a，保留进入时所有可信推送诊断修改。SDK 与 APNs 耦合回放先失败，再修复生产判断；未通过删除旧账号、权限、Token、重复回调或解绑断言使测试通过。

- Python：28 项 iOS 环境/邀请/签名、8 项根凭据、6 项 iOS Properties、7 项准备阶段、1 项 Xcode APNs 配置、16 项工作空间生命周期，共 66 项通过。
- Foundation：registration、binding state、binding driver、incoming diagnostics 四程序通过。合成 OS/SDK，不代表真实推送。
- 两个扩展接线脚本已修复重复源引用，verify_trusted_extensions 检查三种 configuration 的精确 ID、Team、版本、依赖和 Embed 通过。
- strict OpenSpec 与 git diff --check 通过。
- 原旧 test Ad Hoc IPA 被新 APNs 交付门禁拒绝；pro 临时 APP_ENV=test 在构建前被拒绝，未修改文件。
- 完整 Profile/ARM64 编译成功；1.0.52(45) 使用 Apple Development 和开发 profile。主包 plist、签名、profile 均为 development，get-task-allow=true。
- 两个扩展实际嵌入：com.chaken.phoneagent.test.KXPushServiceExtension、com.chaken.phoneagent.test.KXLiveActivityExtension；均 1.0.52(45)，开发签名和独立授权通过。扩展未声明 APNs，不复制主包 APNs 权利；这不影响主包向 APNs 注册。
- 原生 Runner dSYM 与二进制 UUID 相符，符号保留在 IPA Symbols/，不进入安装 App。
- USB XFeng iPhone 15 已覆盖安装并启动，未卸载/清数据。主包 Bundle ID com.chaken.phoneagent.test；安装读回 1.0.52/45。pro/test defines 与根 local.properties 的 SHA256 均未变。

最终 IPA：deliveries/test-build-20261022_165052-c161rskn-1rt8ehjh/Phone_Agent_TEST_1.0.52_45_test_20261022_165052.ipa。
SHA256：7e8ca66276ac14f5830f913d9f2eabd18de16c0d1da8b61c26a6d8d6e04f6f9f。

## 未验证与问题边界

可读取 App 容器元数据，Library 中有诊断归档，但 iOS 归档加密且密钥由原账号 Keychain 管理，不读取密钥、不改为明文、不通过越权导出。尚未取得本包真实 IOS_APNS_TOKEN_RECEIVED、IOS_BIND_SUCCEEDED/CONFIRMED 或送达事件证据。需使用 App 原日志导出流程分别验收；不得以安装、启动、模拟或签名通过宣称 Token/绑定/推送成功。change 不归档。

当前会话未提供可读取的 systematic-debugging / verification-before-completion Skill；未宣称加载。按已确认问题模型、先失败再修复、定向回归及成包/真机证据实施。

## 防错措施补充验证（2026-10-22）

- 添加 .gitlab-ci.yml：Python 合同与 macos 原生/扩展任务均非 allow_failure，无私有凭据/SDK/APNs调用。YAML 本地解析通过；远端流水线未触发，需提交后及可用 macos Runner，不能声称已在 GitLab 运行。
- 共享脚本本地运行：42 项 iOS 环境/签名/清单/安装前回归、18 项工作空间、8 项根凭据、7 项准备阶段、1 项 Xcode APNs，共 76 项 Python；4 组 Foundation 原生回归通过。清单隐私、错环境/版本/摘要/设备/源码、包被替换、清单重复字段/未知字段/丢失/扩展不完整、verify-only 无安装副作用均覆盖。
- 公共 IPA 导出入口要求对应 .ipa.build.json，拒绝普通 JSON/孤立清单及无清单 IPA（含大写 IPA 后缀）。成对导出及摘要失败保留工作空间的生命周期不变。
- 实际 1.0.52(45) test/Profile 开发签名完整构建通过。清单含三个真实签名包，实际叶证书均在各 profile 中且证书一致。IPA 与清单成对导出，导出摘要一致后本次 workspace 已清理。
- 新 IPA：deliveries/test-build-20261022_171110-ujddgprp-10fl74_q/Phone_Agent_TEST_1.0.52_45_test_20261022_171110.ipa。
- IPA SHA256：9ef81487488988c2caed8be547ff65189c33523aef132fdb404bccbdc4ad7ebd。
- 相邻 .ipa.build.json SHA256：11214d9b93ad5a8ba9aa4bd93cee27bff39cdce2d0ab4baa8b62c60b2615942a。
- 快照：56d5959ef279bd5d06f3a8b44e799c3c436dfec256ad92829771ba06022e9c4d。此为本次真实快照，不给旧包补造清单。
- 新安装入口对该 IPA/清单/源码摘要/目标 USB 设备执行 verify-only 通过；实际 CLI 错误 SHA256 返回失败。没有重装/启动，未执行推送。root local.properties 与 cloud-pro 临时配置摘要保持原值。
