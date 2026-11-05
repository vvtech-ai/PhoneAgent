# 验证

基线 codex/dev@15b92fc2，开始时工作区干净。只补主包模板和签名/验收合同，不修改 SDK 环境、APNs、头像处理、绑定状态或 UI。

- RED：真实 Xcode 配置模板回归在 Debug/Profile 因缺权限失败；新增签名保留和最终丢失/未授权拒绝场景。
- GREEN：79 项 Python 合同/签名/工作空间/凭据回归，4 组 Foundation 原生回归通过。扩展三种 configuration 接线校验、OpenSpec strict、diff 检查通过。
- 完整 1.0.52(45) test/Profile ARM64 开发签名构建成功。实际 IPA 主包签名与 profile 的 com.apple.developer.usernotifications.communication 均为 true；APNs 保持 development。
- 两个 extension 仍嵌入并通过各自 ID/Team/版本/profile 校验，不向未授权扩展复制主包权限。
- 旧 17:11 IPA 被新门禁以“主包通讯通知权限缺失或 profile 未授权”拒绝，证明验收不只检查模板。
- 新包和清单：deliveries/test-build-20261022_173729-st5x7gi2-5g9zfzxw/Phone_Agent_TEST_1.0.52_45_test_20261022_173729.ipa（相邻 .build.json）。
- IPA SHA256：a6118c5b2d5af3dc6d6e6ee3558ff75e27cefcf9289b170a2d414faeef3b8076。
- 清单 SHA256：2adc53419ca28569192fcb356e5bfc6119ee1cd9713d4fe88db65325c42970fb。
- 源码快照 ec3965041fa31ac83dfbb48a340ed360ca185eb069e55b4b4ed9a7e5b031ef7d。USB 目标设备 verify-only 安装前门禁通过，本轮未安装/启动，也未触发真实推送。
- 根 local.properties 与 pro 临时配置文件摘要未变，无凭据输出。原生符号保留在 IPA，UUID 匹配。

真实通讯通知头像展示尚无新推送证据，不能以能力/签名/构建通过代替；任务 5 保持未完成，不归档。Apple 官方要求的主 App capability 与 INSendMessageIntent 声明均保留： https://developer.apple.com/documentation/usernotifications/implementing-communication-notifications 。
