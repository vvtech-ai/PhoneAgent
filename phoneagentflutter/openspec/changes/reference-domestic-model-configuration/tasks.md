# 子任务
- [x] 从固定参照生成私有工程配置及无密钥清单，合成工具验证。
- [x] 双端只读原生通道与资源构建接线。
- [x] Dart配置解析及正式Provider接线，合成准入/协议验证。
- [x] 定向测试、analyze、双端Debug构建及OpenSpec/diff。
- [x] 中文提交推送。
- [ ] 实际供应方认证、通话/听感/计费验收；无具体测试条件不执行。


2026-10-09 用户确认执行参照国内模型配置接入：见 docs/engineering/DOMESTIC_MODEL_REFERENCE_CONFIGURATION_20261009.md 和 active reference-domestic-model-configuration。固定Android默认密钥空且当前local无值，采用iOS同服务固定fallback，本地覆盖优先；豆包voice共同Nofish但protobuf不新增音色字段；SIP仍后台租约。生成工具90/专项56/.gitignore三源码微批；原生Android52/iOS37/工程脚本27三源码微批；MainActivity215/AppDelegate103二源码注册微批、PBX机械接线；Dartdata85/Provider110/专项170三源码微批，factory专项234独立微批，均500内。私有两JSON0600/ignored/untracked/non-symlink，不输出或提交值，构建只读工程副本，通道不初始化模型或电话。57项关联定向6秒通过，后新增双平台真实配置Source→factory准入2项，连同重叠12项共14项复验通过，不合计71；独立范围59项。工具3项0.065秒及既有私有写入helper4项0.165秒通过，analyze最终3.6秒无问题。首次if大括号lint修复，再foundation/services重导出Uint8List提示各按实际import收窄，最终clean。
首次Android320MB APK复制因No space left失败，读取当前产物确认仅删除本批47MB不完整复制和本批已核对320MB组装APK，改target android-arm64后15.4秒构建成功，Flutter仅arm64运行库而vendor多ABI保持；首包检查过严误要求所有JNI无x86，fresh实际清单后只校验Flutter ABI及私有资源。iOS首Target Device Version解析失败，fresh Xcode26.3/SDK26.2有限verbose重试确定manifest/attachments/log磁盘满；后新空间930Mi证据允许再验证，17.0秒无签名Debug成功。两端最终包内私有资源字节核对通过，iOS源码符号实际在Runner.debug.dylib而非70KB启动器，fresh产物恢复核对，无SDK/电话执行。原SDK51哈希/portrait通过。磁盘满曾使文档及追加test heredoc未写入；恢复空间后重做，未清理共享build/ios，前清理问题已无需执行。未安装普通App/调用供应方/真实计费或拨号，真实验收未勾；APP_ENV/API后台配置不变，旧c14全量不冒充覆盖本批。外部pubspec.lock保留，不归档，中文提交至codex/dev_zys。

2026-10-09 实施提交dd1a632已推送origin/codex/dev_zys，OpenSpec43项通过。用户随后允许清理build/ios，但双端构建和空间恢复已经完成，未执行该清理，保留验证产物。真实电话/供应方认证/用户验收保持待验，不归档。
