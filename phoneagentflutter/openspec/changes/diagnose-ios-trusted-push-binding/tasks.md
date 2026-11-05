## Tasks
- [x] 1 核对当前分支、源码、供应商成功码和现有日志证据。
- [x] 2 添加当前身份只读状态诊断和白名单，不修改业务请求与 UI。
- [x] 3 Foundation 四程序、Dart 脱敏专项、analyze、可信插件 iOS device arm64 编译及规格验证。
- [ ] 4 完整 App 编译：现有 Podfile.lock 与 Pods/Manifest.lock 不一致而阻断；不在本次调试修改依赖锁。
- [ ] 5 真机 APNs 注册、SDK 成功回调与重启日志验证；无新真机证据不得宣布成功。

可信模块回归 145 通过、1 失败；设置页 iOS 缺 SDK 测试残留 Timer，单独重跑仍失败，未修改该 UI/测试使其通过。详细见 verification.md。
