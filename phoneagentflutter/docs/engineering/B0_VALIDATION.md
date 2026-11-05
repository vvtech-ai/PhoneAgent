# B0 工程基础验证（2026-09-15）

状态（2026-09-16 更新）：代码基础、双端编译、iOS 签名与真机调试启动已验证。共享持久会话经用户一次解锁后，SSH 重连及自动签名构建已通过。change 保持 active，待用户验收后归档。当前是工程验证页，不是设计稿页面或业务功能完成；重启或授权失效后的零人工恢复不在本次完成范围内。

## 2026-09-16 真机接入复查

### 共享构建会话已验证

- 使用 Mac 内置 screen，创建 phoneagent-build 会话；禁用该构建 shell 的历史文件保存，不启用 screen 日志。用户接入同一会话，在 security unlock-keychain 的隐藏密码提示中自行输入密码；自动化没有获取或保存密码。
- 解锁后在该 shell 对临时二进制重签并严格验签成功。随后自动化分离 screen、退出 SSH，再新建 SSH 接入既有 screen；会话及 shell PID 均未改变，再次签名和验签通过。
- 同一持久 shell 执行面向 iPhone 的 Debug xcodebuild，明确输出 IOS_BUILD_EXIT=0。此路径可以复用，不再要求用户每次手工构建。
- 复用时先 screen -ls 确认会话，再通过交互 SSH 执行 screen -x phoneagent-build。使用 Ctrl+A 后按 D 只分离当前终端；不要在共享 shell 输入 exit。允许多个显示端，但构建命令必须串行，用户解锁完成后不与自动化同时输入。
- 后续自动化必须接入原 screen，不能换成新 SSH shell 直接签名。会话丢失、Mac 重启或钥匙串重新锁定后需重新解锁；未修改证书 ACL、自动锁定策略或系统安全设置。
- 本轮只复验签名和构建，未重复安装；此前 iPhone 调试启动和截图证据仍见下一节。Profile 和 Runner 按用户选择暂缓。

### 签名、安装和页面启动的最新结果

- 用户在 Windows 的交互 SSH 会话中解锁 login 钥匙串，同一会话最小签名测试无错误，并执行 Debug xcodebuild。随后检查 2026-09-16 10:59:17 生成的 Runner.app，codesign --verify --deep --strict 返回 valid on disk / satisfies its Designated Requirement，退出码 0。
- 包身份 com.chaken.phoneagent.test、arm64、TeamIdentifier 425F285BQA；Windows/Mac 的 pubspec.lock、lib/main.dart 和 iOS project.pbxproj SHA-256 一致，未手改 Mac 工程源码。
- iPhone 8 / iOS 16.7.16 USB 在线，Developer mode enabled。使用 Flutter SDK 自带 ios-deploy 安装已签名 DerivedData 产物，InstallComplete；没有卸载或清空已有测试包数据。
- 首次 --justlaunch 退出调试器后虽报告 success，截图却显示 Flutter Debug 启动限制，不能作为页面通过证据。改用 --noinstall --debug 保持调试器连接后，Runner PID 12058 输出 Dart VM service listening，实际渲染 B0 页面。
- 用户在手机授权本地网络调试权限；11:08 截图确认完整的“Flutter 工程已启动”、local 环境、API 未配置提示，无权限弹层、白屏或错误页。证据保存在忽略目录 .local/ios-foundation-ready-20260916.png，不提交设备截图。
- 运行观察期未见 Dart 未处理异常；系统输出缓存失效和方向请求警告，当前页面实际为竖屏。这里只验基础启动，不代表后台恢复、全部方向场景或业务回归通过。
- Windows 重跑 scripts/verify.ps1：OpenSpec 4/4、格式、analyze、14 项测试、Android debug 构建全部通过（增量 19.1s）。Mac 重跑 analyze 和 14 项测试全部通过；APK 哈希未变化。
- 本轮满足 B0 签名/安装/调试启动门禁。调试包从桌面独立冷启动和无人值守签名尚未验证；日常脱离调试器测试需后续提供 Profile/Release 测试包，不把当前 Debug 当分发包。

### 本机与 SSH 对照的历史结果

- 用户提供 Mac 本机 Terminal 对临时 SignTest 的签名输出，只有 replacing existing signature，无错误。随后通过 SSH 对同一文件、同一身份重签，返回 errSecInternalComponent，退出码 1；后续 verify 因 && 短路未执行，不宣称验证通过。
- SSH 下默认钥匙串及搜索列表均为 login.keychain-db；find-identity 仍有一个有效身份，但 show-keychain-info 返回 User interaction is not allowed。当前证据指向 SSH 执行上下文的钥匙串访问问题，不是再次登录 Apple ID 或重建证书的依据。
- 下一步用户在 Windows 的交互 SSH 会话中运行 security unlock-keychain，密码仅在交互提示中输入；随后复测 SSH 签名。是否还涉及私钥 ACL 需按结果判断，不自动修改权限。
- 本轮没有重复完整构建或安装。OpenSpec 仍为 8/10，签名门禁未通过，等待安全的本机密码交互后继续。

### 重新登录后的构建结果

- 用户重新登录 Xcode 后，以同一 iPhone destination 重跑 Debug 自动签名构建，退出码 1；本次输出已不再出现 Apple portal Code 1100 / session expired，不要求重复登录。
- 当前失败点是 DerivedData 中 Flutter.framework/Flutter 的 codesign，仍返回 errSecInternalComponent。有效签名身份仍可见，但尚不能确定是 SSH 私钥访问、钥匙串状态还是其他签名问题。
- 下一步按 Apple 官方排查建议在 Mac GUI 登录会话的本机 Terminal 执行签名测试，检查系统授权提示，再对比 SSH 签名。用户在本机输入钥匙串密码，不在聊天或命令参数中传递；不自动修改 ACL 或证书信任设置。
- iOS 安装与启动仍未完成，OpenSpec 3.5 保持待办；未提交、推送或归档。
- 参考：https://developer.apple.com/forums/thread/712005

### 重新登录前的历史结果

- Flutter devices 已识别 iPhone 8，iOS 16.7.16（20H392）；xcrun xcdevice 标记 available=true、USB，开发镜像准备结束。设备未连接的问题已解除。
- security find-identity 仍显示一个有效 Apple Development 身份，但这不证明当前 SSH 进程可以使用私钥签名。
- 使用该真机 destination 重跑 Debug 签名构建，仍返回 Apple portal Code 1100（Your session has expired. Please log in.）；Flutter.framework codesign 再次以 errSecInternalComponent 失败，构建退出码 1。
- 本轮未安装或启动测试包，未改变钥匙串 ACL、签名材料或业务源码。需要用户在 Mac 重新登录 Xcode，并在本机登录会话检查 login 钥匙串解锁和签名授权；不能仅凭错误码确认是钥匙串锁定。
- OpenSpec 真机签名任务保持未完成；不将“设备可见”标记为“真机验证通过”，不新增 commit/push 或归档。

以下 2026-09-15 记录保留作历史证据；其中“设备未连接”已由本次复查更新。

## 已通过

| 验证 | 证据 |
| --- | --- |
| OpenSpec | openspec validate --all：4 passed / 0 failed |
| 依赖锁 | Flutter 3.32.0 / Dart 3.8.0 两端解析成功；pub get --enforce-lockfile 通过 |
| 格式／分析 | dart format 检查通过；Windows/Mac flutter analyze 无问题 |
| 自动测试 | Windows/Mac flutter test：14 passed；配置、防错误环境、UI 小屏/2倍文本、结构与平台约束 |
| Android | flutter build apk --debug --no-pub 成功，首次约 191.6s |
| Android 身份 | APK com.vvtech.aiassistant.dev；versionCode=1；1.0.0-foundation；minSdk=26，target/compileSdk=35 |
| APK 签名 | apksigner verify：V2 通过，Android debug 证书，不是正式发布签名 |
| Android 启动 | emulator-5554 安装成功，am start -W Status: ok；进程存在，截图已检查；本次未覆盖设备上的已有正式包 |
| iOS 编译 | flutter build ios --debug --no-codesign --no-pub 成功，Xcode 编译约 116.9s |
| iOS 产物身份 | Runner.app Info.plist：com.chaken.phoneagent.test，MinimumOSVersion=15.5 |
| 发布误用保护 | :app:assembleRelease --dry-run 按预期失败，明确要求正式签名与 OTA 迁移先验收 |

Android APK SHA-256：`93D6F1BE25157149B4C0094CD54C415AD67E44D30E55BDB999CE628693415CDB`。

Windows/Mac pubspec.lock SHA-256：`7F1250FA5AEF0253D0E6D1FDD38E24B1AA6255DBCE6231DAEB7EB4ACA708E7EB`，一致。

首次源快照 SHA-256：`1C8F6D5C3B1A731DB938A27DD06065C1322ED5AA225B66E01DCE8D9841BBCB64`，两端一致；之后补充的架构和大字号测试定点同步，Mac 重跑 14 项通过。应用/平台代码未在 Mac 手改。快照仅用于首次提交前验证，长期仍用 Git。

本地 Android 截图：`.local/android-foundation.png`（不入库）。构建缓存和真机诊断不提交；不是通过截图声明设计高保真。

## 2026-09-15 历史阻塞（设备及本次签名安装已在上文更新）

1. Flutter devices 与 xcrun xcdevice list 本次均未发现 iPhone；此前连接记录不能代替现场设备状态。
2. Mac 有有效 Apple Development 身份，证书 OU 显示 Team `425F285BQA`；但 xcodebuild 自动签名请求返回 Apple portal Code 1100，登录会话已过期。
3. 同次签名构建在 Flutter.framework codesign 出现 `errSecInternalComponent`。私钥可见不等于非交互签名可用；钥匙串访问／解锁原因尚未定位，不能保证仅重新登录即可解决。
4. 需要用户在 Mac 重新登录 Xcode、连接解锁并信任 iPhone；然后复核钥匙串签名权限并重跑测试包安装/启动。不索取或记录密码，不擅自修改钥匙串 ACL。

签名失败命令：`xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphoneos -destination generic/platform=iOS -allowProvisioningUpdates DEVELOPMENT_TEAM=425F285BQA CODE_SIGN_STYLE=Automatic -quiet build`。

以上为 9 月 15 日历史结果；9 月 16 日已完成 iOS 安装与调试启动。仍未进行真实业务请求、短信、认证、外呼、Android 正式升级或 App Store 发布。Android 构建的 SDK XML/Gradle 弃用警告未阻断 debug 构建，留后续工具链维护，不借机升级 SDK。

## 同步与交付

origin 为用户指定 worldcall/phoneagentflutter。9 月 16 日双端基础验证门禁已通过，按用户既有授权执行里程碑提交/push；实际同步结果以 Git 记录及 tasks.md 为准，不包含签名材料、调试服务凭据或截图。用户验收前不归档。

环境结论：独立 SSH shell 仍不应依赖其他会话授权，但重新接入已解锁的 phoneagent-build 持久会话已验证可自动签名构建。重启、会话丢失和钥匙串重新锁定后仍需人工授权。本轮没有收集密码或修改证书信任/私钥 ACL。
