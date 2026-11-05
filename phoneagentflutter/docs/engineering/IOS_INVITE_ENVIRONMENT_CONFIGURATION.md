# iOS 邀请三环境配置与验证

2026-10-19 用户确认全环境检查及修复；本轮不打包安装、不切分支或提交推送，后端及 Apple 开发者配置只读。

## 环境契约

| PHONEAGENT_IOS_ENV / APP_ENV | 专用 Universal Link 域名 | 网页域名 | Scheme | Runner Bundle ID |
| --- | --- | --- | --- | --- |
| prod | ioslink.chaken.ai | www.chaken.ai | phoneagent | com.chaken.phoneagent |
| test | phoneagent-ioslink.vvtech.tech | chakenai-test.vvtech.tech | phoneagent-test | com.chaken.phoneagent.test |
| dev | phoneagent-ioslink.vvtech.tech | chakenai-dev.vvtech.tech | phoneagent-test | com.chaken.phoneagent.test |

关联域名只写 `applinks:<host>`，不带协议、路径、查询。Debug/Profile 权限额外保留 `agent.vvtech.tech`；Dart dev/test 分享解析兼容该域名，prod 继续兼容 `chaken.ai`。关联网页域名不意味着服务器已提供覆盖网页路径的 AASA；当前按钮通过专用域名的 `/phoneagent/ios/invite/` 唤起。

Xcode Debug/Profile 默认 dev，Release 默认 prod。运行环境为 test 时必须显式覆盖，不能把 Debug 当作 test。构建阶段解析 Dart APP_ENV 并校验域名、Scheme、Bundle ID、实际 CODE_SIGN_ENTITLEMENTS。无 APP_ENV 的 local 仅允许 dev 的不签名编译，不作为可交付包。

保持既有应用身份：默认允许 Debug/Profile dev/test、Release prod。Release/test 只改环境仍是正式 Bundle ID，门禁会拒绝；不自动修改主 App、扩展 ID、描述文件或签名。dev Release 仍受 AppConfig 保护而拒绝。若未来需要新的签名模式，单独完成主 App/扩展/配置一致性设计。

## 构建与导出接线

构建任务在其自身临时工作目录生成公开 xcconfig，例如：

```bash
python3 scripts/ios_invite_config.py settings --environment test > <本次临时目录>/Invite.test.xcconfig
```

将该文件的绝对路径通过 `XCODE_XCCONFIG_FILE` 传给本次 Flutter/Xcode 子进程；同时沿用工程内私有 defines，APP_ENV 必须为 test。直接执行 xcodebuild 时也可以显式传 `PHONEAGENT_IOS_ENV=test`。不要向全局配置写入覆盖值。工具不输出私有 defines，也不覆盖扩展 Bundle ID。

签名/导出完成后运行邀请专项门禁：

```bash
python3 -B scripts/verify_ios_invite_artifact.py --environment test --artifact <签名App或IPA路径>
```

对 prod/dev 分别显式选择对应环境。工具验证主包及嵌套代码签名、最终权限、Info.plist 环境标记与 Scheme、登记 App ID/团队和描述文件授权；支持描述文件的 `*` 关联域名授权，不输出描述文件、设备列表或凭据。

`run-test-build.py` 对 IPA 强制要求 `--ios-environment prod|test|dev`，在平台完整验证之后、导出之前自动运行该门禁。该检查不能替代已有版本、全部运行配置、扩展身份、供应商库等完整平台检查。失败保留本次工作目录，不导出、不重签名、不安装。

## 线上检查及剩余边界

- 本次匿名 GET：prod（www.chaken.ai）返回 ioslink.chaken.ai；dev 返回 phoneagent-ioslink.vvtech.tech，均与本地契约一致。
- test 下载配置本轮请求/重试连接失败，未重新确认现网值；此前侧会话成功读取为 phoneagent-ioslink.vvtech.tech，本次不把历史读取当作重新验证通过。
- ioslink.chaken.ai、phoneagent-ioslink.vvtech.tech、www.chaken.ai、agent.vvtech.tech 的 AASA 本轮均返回 200，且均同时包含正式/测试 App ID，路径仅 `/phoneagent/ios/*`、`/phoneagent/ios/paywx/*`。
- 两个专用域名的 Apple CDN AASA 也已读取，均返回 200、同时包含两个 App ID，问题不只是源站模板内容。
- test/dev 网页域名的 AASA 首轮 HTTP 错误、重试连接失败，网页路径关联未通过验收。具体设备行为仍需检查 Apple CDN 与真机，不能由网页域名已写入权限推断成功。
- 若要求正式与测试共存时准确选择版本，服务器应让 ioslink.chaken.ai 仅关联正式 ID、phoneagent-ioslink.vvtech.tech 仅关联测试 ID；本轮不部署 AASA。
- dev/test 共用 Bundle ID、Scheme 及专用域名，不能同时独立安装；若需要三套共存，需另行批准 dev 应用及扩展身份、Apple 登记/签名和独立域名或路径，不能仅修改 Associated Domains。

## 验证范围

实际命令与结果见对应 change tasks。已有两个 1.0.52(45) IPA 均因重复网页域名、缺少专用域名被新门禁拒绝；不代表已经产生修复后的签名包。设备覆盖安装、冷/热唤起、邀请码传递和 Store 回退仍待验。
