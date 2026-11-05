# 验证记录

2026-10-20，Android Debug 可读镜像与 Release 交付分别验证。

- 工厂真实目录回放先复现旧加密 JSON 无法直接读取，再实现独立镜像；不更换正式档案格式。
- 独立审查补出两类 RED：正式文件已删除但镜像删除失败后的孤儿副本、受保护模式升级后遗留的 `.pending` 明文。已补重试清理及限定名称删除，保留拒绝符号链接和正式读写白名单。
- `flutter test --no-pub test/features/app_logs`：100 项通过。
- 合入远端最新 iOS 支付诊断后，日志族与 commerce_diagnostics_test 共 108 项通过。
- 全量 `flutter analyze --no-pub` 无问题；OpenSpec strict、UTF-8 及中文读回通过。
- 真实 Debug → 受保护工厂的同目录连续回放已验证；尚未安装 Debug 包执行手机 ADB 命令。Release 的包身份、版本和 debuggable 结果记录在最终交付清单。

本轮不新增 Release 本地导出入口，不开放 Release 私有目录；真机与实际音频验收不由文件单元测试替代。
