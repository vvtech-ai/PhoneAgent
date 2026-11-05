## Tasks
- [x] 核对分支、脚本与旧描述文件的分发混选和设备遗漏。
- [x] 使用 Xcode 更新正式环境 Ad Hoc 主包与两个扩展至16台。
- [x] 使用 Xcode 更新开发/测试描述文件并核验16台设备覆盖。
- [x] 先重现旧缓存排序、分发混选，再修复选择阶段类型门禁和排序；保留通用验包 API。
- [x] 运行 Python 定向回归、OpenSpec 校验和真实配置选择/签名检查。

验证：新增回归先复现5个失败，修复后 ios_build_config 16项通过；run-ios-contract-checks.py 共82项通过；OpenSpec 全量279项通过。使用已有归档通过 xcodebuild 自动签名重新导出 Development 与 Ad Hoc，两组共六个嵌入 Profile 均为16台相同设备集合，包含新增三台；codesign 严格核验、实际证书/profile匹配、各组同证书、Team/Bundle ID、主包通讯通知及 APNs通过。实际选择器对 dev/test/prod直装及三台新设备逐一选择，主包/两个扩展均覆盖16台；prod上架三个目标均选择 App Store。云端手动 phoneagent_test 未修改，Xcode 重新签发受管配置并更新 UUID。cloud-pro 临时test内容未修改，仍不能通过正式业务配置门禁。

安装与业务运行未执行；不把重新导出旧归档作为新版本交付。

分支迁移：按用户指令移植至 feature/test_v1.8.0_zys / 5d34f57a，保留该分支已有构建模式与符号规则。目标分支 run-ios-contract-checks.py 85项通过，OpenSpec全量278项通过，diff检查通过；仅提交本批七个文件，不推送远端。原目录 test_v1.8.0_fix 保持原HEAD并清除本批未提交改动；本机Xcode签名缓存独立于Git分支。
