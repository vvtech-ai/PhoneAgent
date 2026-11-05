# 统一 Flutter 源码验证

## 当前版本边界
- 最终基准 `origin/codex/dev` 为 8445d06f21f04d3511498b73aa16d7d32bc39867。该提交在整合期间新增，已继续合入；iOS 更新、翻译、布局、播报控件、图片/文档开场顺序、草稿清理和暂停行为保留基准实现。
- 相对基准仅保留批量结果/逐路进度和诊断、结果评分刷新、系统音色试听三类独立运行增量，共 18 个 lib 路径。共享 ConversationRoute 仅保留 resultRevision 评分刷新接线；不保留 showPrompt=false 或额外询问投影。
- 道歉目录、确认询问投影、CallConfirmationCard、ConfirmationBillingRoute 和相关撤回测试已按基准恢复；新 client_interaction 运行文件无残留。已撤回方案的 active change 删除，历史提交保留。

## 实际验证
- 第一轮针对 afd919df 整合执行 29 个相关文件：192 项通过、1 项架构行数门禁失败。失败为基准中的 `lib/features/translation/domain/sip/domestic_sip_media.dart` 已有 504 行、默认上限 500；已对最新 8445d06f 逐字节确认该文件相同，架构规则也未给该路径例外。本轮不修改该基准文件或增加通用豁免，不宣称全量通过。
- 合入 8445d06f 后执行最新草稿、暂停、对话/开场播报、批量停止/恢复、评分、翻译与 Shell 接线等 18 个定向文件，134 项全部通过，退出 0；全仓 flutter analyze --no-pub 返回 No issues found。
- 当前 change 和系统试听 change strict validate 通过；OpenSpec 全仓 220 通过、3 个既有失败：incremental-validation-policy、login-presentation、native-feature-parity-audit。diff check 通过。
- Controller 比基准 523 行只多四行批量诊断端口，单一路径上限精确复核为 527；其他架构规则保持不变。系统试听改动和测试来自原工作区，原始源码/文档快照及 SHA256 留在工作区外缓存；原工作区在同步前再次核对未被其他任务改写。

## 交付范围
仅统一源码、提交和正常 push，目标 xiaosy/dev_v1.7.0。不部署后台，不打包或安装，不清理私有配置/产物，不宣称手机播报或完整历史恢复已经现场验收。原系统试听提案中的打包说明属于前一版本，不能作为当前统一版本的安装证据。
