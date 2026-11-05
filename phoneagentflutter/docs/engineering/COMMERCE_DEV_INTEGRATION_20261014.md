# 会员积分成果合入 codex/dev

## 用户授权与基线

用户要求全面检查后将当前 Flutter 成果合并推送 `codex/dev`；Java/Web 分别交付 `feat/tts-indextts25-qwen`。此次只交付代码，不部署、不安装、不执行业务库迁移、支付或开票。

- 会员积分来源：`e4b202e1`（`codex/story1837-membership-commerce`）。
- fetch 后目标：`c10ad11c`（`origin/codex/dev`）。
- 共同祖先：`36f76ec0cd57f59367ff737c2421f7d9e9bcd23c`。
- 来源修改 230 文件、目标修改 200 文件，交叉仅 `tasks.md`、`docs/codex_issue_log.md`。每份记录各两段追加冲突，保留双方全部章节。其余来源 228 文件和目标 198 文件逐一比对 Git blob，均与对应父版本一致。

沿用 `D:/work/04phoneAgent/_isolated/story1837-flutter` 隔离树，使用目标 detached HEAD 三方 no-ff 合并，避免移动另一工作区使用中的本地 `codex/dev`。原始工作区未切换或清理。推送时使用 `HEAD:codex/dev`，禁止强推。

## 原有文件保护

切换前 `account_protocol_diagnostics.dart` 被 Git 标记修改，但规范化 blob 与来源 HEAD 同为 `8cc79fd4f68404d86fb2e18e86b4f59a38919034`。原始字节已复制到本机 `D:/Temp/story1837-account-protocol-diagnostics-before-integration.dart`；按路径暂存 stash 后切换，stash 仍保留。目标此前无此文件，合并按来源带入，不是新增未提交业务改动。

切换前及合并后原始 SHA256 都是 `90e4ef7b7c256c7cc2a196877d9027e34a39ccc92be200cafe26e921635b1d0b`，与备份相同。私有输入、APK、缓存和测试截图均不入 Git。

## 独立复核

- 任务音色、翻译关键文件逐一保留最新目标实现；Android MainActivity 与 iOS AppDelegate 只新增独立支付桥注册，原 PCM、通话和音色入口保留。
- 商业化 provider 均受登录 epoch 约束；钱包缓存绑定环境/地址/账户，AccountApi 拒绝跨登录旧请求；发票控制器销毁清空草稿。
- SDK 服务路由、鉴权、刷新和签名主体未被替换，新增 commerce/membership 受保护前缀；诊断默认关闭，仅受控 metadata，无 token/full payload。
- 对照合并后 Java `308d79b7`，目录、权益、报价、订单、支付材料、恢复和发票 DTO/路径一致；真实金额仍来自服务端整数分，订单等级周期使用历史字段，支付宝环境由原单投影。

## 验证记录

- `flutter analyze --no-pub`：无问题，31.4 秒。
- `openspec validate --all`：117/117；本集成 change 严格校验通过。
- 最终另外运行全仓 `--strict`：113 通过、4 个既有规范因 Purpose 少于 50 字符被警告阻断（app-foundation、conversation-error-status-sync、migration-governance、web-development）。逐一检查仅该警告，四文件与 c10ad11c 相同；未扩大范围改历史文档。随后普通全仓 117/117、本集成 change strict 再验均通过，不能称全仓严格检查全部通过。
- `python -X utf8 tool/verify_trusted_sdk.py`：53 个 SDK 文件、10 个 Android Activity 及 iOS 竖屏声明通过。首次未开启 UTF-8 的 Windows Python 默认 GBK 读取失败，纠正调用后通过，未改 SDK 文件。
- 全量 `flutter test --no-pub --reporter expanded`：18 分 44 秒，4945 通过、5 失败、1 个既有文档捕获开关跳过。保留原始失败日志 `D:/Temp/story1837-dev-integration-flutter-tests-20261014.log`，不把首轮写为全绿。两个失败是既有 Windows 文件系统链接权限（errno 1314）；三个失败是旧日期夹具只填 timestamp、未提供最新翻译任务使用的历史 summary。后续最小测试修正与定向复验结果见下方。
- Android `flutter build apk --debug --no-pub --target-platform android-arm64 --build-name=1.0.51 --build-number=2026101402`（沿用本机私有开发配置，关闭协议诊断及迁移预览）：退出码 0。APK 另存 `D:/Temp/story1837-local-device/phoneagent-dev-integrated-1402.apk`；aapt 确认 `com.vvtech.aiassistant.dev` / `1.0.51` / `2026101402`，SHA256 `35df919a8827298f998515b4ef3fcf9c0b6488ed6d89dc1ac44e7363ffa4740c`。未安装。

## 首轮失败处置

仅在测试层和参考夹具修正环境适配及输入，不修改生产逻辑。微批一限录音两份测试和测试辅助模块：账号变更与文件符号链接独立验证，Windows 使用真实目录 junction 验证拒绝目录越界与外部文件不被删除；文件 symlink 仅精确捕获 Windows 1314 并标记未覆盖，其他异常仍失败。微批二限日期测试与参考夹具：采用既有历史投影生成 summary，并保留无匹配历史时不以任务 timestamp 替代详情的断言。

- 日期三文件集合：21 项全部通过，0 跳过；日志 `D:/Temp/story1837-record-time-green-20261014.log`。原三个失败断言均保留并通过，另补空历史详情反例。
- 录音九文件集合：24 项执行通过，1 项明确环境跳过，0 失败；日志 `D:/Temp/story1837-recording-fs-related-20261014.log`。Windows 两项真实目录 junction 防逃逸/保护外部 marker、独立账号变更均执行。仅文件 symlink 创建精确遇到 1314 时跳过，其目标不被删除断言仍须有权限的 Windows 或 Mac/Linux 验证；不计为通过。
- 最终全仓 `flutter analyze --no-pub`：无问题，11.3 秒。测试与参考工具微批未修改 `lib/`、Android 或 iOS；189 个双方受影响产品文件再逐一核对 index blob，无差异。APK 仍对应相同产品源码，不因测试夹具修改重打包。
- 首轮全量和后续受影响复验分别记录，未重复运行全量，不能把局部复验描述为第二次全量全绿。最终测试层改动限定为两份录音测试、一份安全临时文件辅助、日期测试及日期参考工具；各微批不超过 3 文件。

## 交付方式

按用户授权中文提交合并结果，推送前重新读取 `origin/codex/dev`，仅允许非强制快进更新。远端若前进则重新合并与验证，禁止覆盖并发更新。最终提交与远端回执以本次交付回复及本机 `D:/Temp/story1837-three-repo-push-20261014.json` 记录为准。

## 仍属运行态待验

Windows 无法替代 Mac/Xcode 的 Swift 构建和 iPhone 沙箱验收。StoreKit 数值价格/币种核验、真实商品映射及通知配置沿用原待办；税航企业税局会话、蓝票/冲红流程继续按用户要求暂停。原 UI 包 1401 不代表本次整合后的版本已安装。以上不作为本次代码合并已经完成的运行验收。
