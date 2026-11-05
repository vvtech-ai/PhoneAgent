## 实施
- [x] 核对检出、代码链路、AIAssistant 对照及用户批准边界。
- [x] 先建立原生生命周期回归并记录失败证据。
- [x] 实现 iOS 按进程初始化保护，仅正常返回后复用。
- [x] 执行原生与 Dart 定向回归、analyze、OpenSpec 校验；Dart 3 项基线失败单列于 verification.md。
- [x] Mac iOS Debug/Release 无签名 arm64 构建、匹配符号保留、原生录音配置回归，核对无 UI/Dart/Android/参数变动并记录证据。
- [ ] 真机认证、连续重试/取消、账号切换、实际音频交接和诊断共存回放。

未取得真机证据不得标记完整验收或归档。
