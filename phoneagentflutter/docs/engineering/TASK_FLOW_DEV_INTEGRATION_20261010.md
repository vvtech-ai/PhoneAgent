# 任务功能合入 codex/dev（2026-10-10）

## 授权与基线

用户明确要求“当前代码合并到 codex/dev 分支上，那边也有更新的，然后切换到 codex/dev 分支上开发”，覆盖此前保留 dev 旧版本的限制。本轮仅集成 Flutter，不修改后端、数据库、旧 Android 工作区或真实任务。

- 最新 `origin/codex/dev`：`c75511de585b48b74a1a63fd12ccedcb961a8a90`，相对共同祖先有12个独立提交。
- 任务分支 `codex/refactor-conversation-task-flow`：`b005131bc4a74fedb2d7891359d1e722eff6cc3a`，有35个独立提交，已经推送。
- 复用隔离工作树 `D:\work\04phoneAgent\_isolated\phoneagent-task-flow`，开始时干净；本地 dev 从9a8d4e64快进到最新远端，再三方合并任务分支。
- 原始 `phoneagentflutter` 工作区保持 `codex/flutter-foundation` / `dbb274f756b5c4acbebc1a398e066ffcdba87627`，开始时干净，交付前复核。

## 合并与边界

自动 Git 三方合并属于机械批次，手写解决冲突与记录按至多三个文件一批进行。三个冲突：

1. `android/app/src/main/AndroidManifest.xml`：保留最新 dev 的供应商 receiver/service 所有权，不恢复已移除的旧 Flutter 可信来电组件；保留任务分支 `roundIcon` 和新图标。
2. `docs/codex_issue_log.md`：双方追加记录都保留。
3. `tasks.md`：双方追加记录都保留，旧分支限制作为历史记录，由本轮授权明确覆盖。

自动合并后的 Android Gradle 保留 Glide 4.15.0 等可信来电依赖，Android/iOS 入口保留两边平台适配，iOS 最低16.1不回退。锁文件保留 dev 的七个依赖更新，同时保留任务分支新增 pointycastle 与 path 直接依赖。未添加新的业务功能或另一套任务状态机。

当前 `AGENTS.md`、迁移基线和 active OpenSpec 已更新为在 codex/dev 开发及交付。其他历史报告不重写，变更不归档。

## 验证进度

- 固定 Flutter3.32.0：`pub get --offline --enforce-lockfile` 因本机缺少七个新版本缓存未通过；随后 `pub get --enforce-lockfile` 联网成功，锁文件无额外变化，未降级依赖或升级 SDK。
- `openspec validate --all`：75通过、0失败。
- `flutter analyze --no-pub`：无问题，100.1秒（与全量测试并行）。合并文本452个 UTF-8 文件检查通过，无替换字符或冲突标记。
- Android 云端开发包构建通过，assembleDebug 179.2秒；`com.vvtech.aiassistant.dev` / `1.0.51` / `45`，正式 main、开发域名三前缀和既有本地完整 C1 配置，演练入口关闭。
- `python tool/check_trusted_caller_apk.py build/app/outputs/flutter-apk/app-debug.apk` 通过：SDK runtime SHA-256、AAR 无重复、19个 SDK/Glide 必需类定义及最终供应商清单所有权。
- APK SHA-256：`9059F29C3DD1B084BC15A7BF76765AB82756DEB0077A7D49ECC84DE4277004AC`；产物留在忽略的 build 目录，不入 Git。
- `flutter test --no-pub --concurrency 8 --reporter expanded`：17:06结束，4402通过、1既有跳过、2失败，退出码1。两项失败为 domestic_recording_cleanup_test 与 domestic_recording_session_test 的符号链接安全用例，均因 Windows errno1314“客户端没有所需的特权”，与历史记录一致；本次没有修改这两份测试，也没有跳过或伪称全绿。首页、对话、列表、详情/恢复、可信来电、翻译和直接调用方均纳入全量；环境失败需在具备权限的环境重验。
- 原生 `:app:testDebugUnitTest` 默认全架构依赖下载长期阻塞，线程证据为 HTTPS 读取等待；仅取消本次已核对的 Gradle 客户端，未停止共享 daemon。离线重试33秒失败，明确缺 ARMv7/x86_64 引擎缓存；再次按已成功 APK 的 ARM64 目标运行相同测试，未缩减用例。
- `gradlew :app:testDebugUnitTest --offline -Ptarget-platform=android-arm64 --console=plain`：36秒，13套/48项，46通过、2失败、0跳过，退出码1。LegacyTranslationArchiveFileTest 的符号链接用例因 Windows 权限失败；CrashSummaryStoreTest.randomNonceChangesCiphertextForSamePayload 在现有文件第二次写入时 renameTo 返回 false，JDK21本机独立探针确认 Windows 覆盖已存在目标返回 false。相应生产/测试文件与最新 dev 完全一致，本轮不改无关日志及翻译业务、不跳过测试、不声称原生全绿；需在目标平台或合适宿主环境复验。可信来电与其他原生测试通过。
- 按 PMReport 内置登记表检查，phoneagentflutter 未登记；本轮不对其他项目误报。

## 运行验证界限

Windows 无 macOS/Xcode，本轮不声称完成 iOS 原生编译或真机验收。真实通话、监听、录音、ASR/TTS、后台与生产升级不由合成测试或 Android 编译证明；未触发外呼、收费、上传或清除手机数据。本轮没有重新安装手机包，保留此前已安装包和数据。会议评分资格的后端关联问题仍由原交接文档跟踪。

## 交付核对

提交前再次 fetch，origin/codex/dev 仍为 c75511de；无未解决冲突，暂存范围为 Git 自动合并的功能分支文件、上述冲突解法及本轮集成文档，不包含 .local、secrets、APK、缓存或其他仓库内容。

中文合并提交 `39aebc53b5f9f7548f6b9ad079e24f084fa4a53a` 已非强制推送 origin/codex/dev；两父提交为 c75511de 与 b005131b，双方祖先关系核验通过。当前隔离工作树使用 codex/dev，原任务分支及其已推提交保留。后续交付记录作为文档提交补齐，不重跑未改变的业务测试。原始 foundation 工作区再次核对仍为 dbb274f7 且干净；本轮无安装、外呼或后端修改，未验收不归档。
