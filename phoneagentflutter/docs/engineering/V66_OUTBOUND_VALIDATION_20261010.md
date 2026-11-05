# v66外呼OpenSpec续批验证记录

本轮唯一代码工作树D:/work/04phoneAgent/_isolated/phoneagent-task-flow，分支codex/refactor-conversation-task-flow。固定Flutter3.32.0/Dart3.8.0；App参照146152a2，历史a0bedb12，Java只读8ebd7db4。测试使用合成数据和隔离端口，不访问真实账号或拨号。

## 已执行自动验证

| 验证 | 结果 | 范围/限制 |
| --- | --- | --- |
| 前段受影响定向集合 | 329通过/0失败 | 模型、回执、timeline、监听、候选及直接调用方；首轮失败按源码证据修复，不虚报为全量 |
| 接通计时与账号契约专项 | 27通过/0失败 | call_preview_test、conversation_call_timer_test、conversation_call_flow_test、call_account_contract_test |
| Skill/首页/联系人/路由专项 | 35通过/0失败 | contact_skill_opening_parity、contact_task_entry、contact_skills_sheet、home_repository、skill_task_orchestration_parity、service_routes、call_account_contract |
| flutter analyze --no-pub | 无问题，20.9秒，退出0 | 当前冻结源码及测试 |
| openspec validate --all | 35通过/0失败，退出0 | 本change及当前仓库规范，不归档 |
| flutter test --no-pub --reporter compact | 3544通过/1既有跳过/0失败，10分57秒，退出0 | 因跨首页/模型/对话/监听共享模块，触发本里程碑一次全量；没有用前批全量代替 |
| 正式main ARM64 debug构建 | 最终5.8秒，退出0 | 固定3.32/JDK21，云域名私有define；包/前缀核验见下方；10-10 09:03:49覆盖安装成功 |
| 当前真实手机adb install-r | Success，退出0 | 用户重新要求安装；v45/1.0.51-foundation，firstInstallTime不变，未卸载或清数据 |

回归覆盖两平台Theme/提供器、账号/session/command/attempt隔离、历史不重放、自然回答、停止/退出、单/多路媒体与账单、模型选择和任务列表分页/详情/恢复。连续页面证据来自Shell导航、conversation_navigation、shell_history_workbench、task_detail_route等widget测试，属于合成主流程。既有integration_test/task_flow_stage_test设备链之前未完整通过，本轮未自动操作用户手机，也不把widget主流程当真机成功。

原始测试、索引和只读诊断输出仅保存在被Git忽略的.local/v66-outbound-audit；不提交原始账号日志、环境参数、票据或音频。

## 待验项目

- 前次安装INSTALL_FAILED_ABORTED/用户拒绝权限后没有盲目重试；用户重新要求安装后，2026-10-10 09:03:49最终包覆盖安装成功。firstInstallTime仍2026-09-18 12:54:52；仅只读核对包信息，普通登录和真实运行效果未验证。
- Android真实监听首音频与听筒/外放、转写/录音/评分/最终账单、订餐联系人记忆和实际供应商音色，需有效服务响应及用户明确确认后的运行证据；不自动拨号。
- iOS共享Dart及平台主题/MethodChannel合同已有自动覆盖；Windows没有macOS/Xcode/iOS真机构建环境，未验证iOS原生播放、Files、键盘及后台。
- 真实电话、媒体、后台恢复及生产升级各自待验；调试包不是生产升级验收产物。
- 新App的SDK监听票据/Runtime monitor路由与当前Java源码冲突，及订餐Skill差异见BACKEND_TASK_OUTBOUND_CONTRACTS_20261010.md。后端/库/部署未改，本轮不追加后端构建。

## 新包与交付核验

最终构建参数为--debug --target-platform android-arm64 --build-number=45 --build-name=1.0.51 --dart-define-from-file=.local/cloud-dev/device-defines.json。Gradle自动附加-foundation；aapt确认com.vvtech.aiassistant.dev、v45/1.0.51-foundation，与手机现有包版本相符。首次默认构建得到v1，第二次参数含后缀导致后缀重复，均在安装前验包发现；未尝试降级/卸载，只修正构建参数，不改源码或手机数据。

可安装备份：D:/work/04phoneAgent/_isolated/phone-local-runtime/v66-outbound-openspec-20261010-v45-phone.apk。SHA256=F1BACB4B5A5BE05D4833E7EB43938C1D24CEAD8FCF66E54A407DDE99715FBA88。此前同日期不带-v45的v1备份未安装、不是交付包。

从APK kernel_blob只核对布尔结果：三个https://chakenai-dev.vvtech.tech前缀aiassistant-api/、aiassistant-sdk-api/、aiassistant-runtime/均存在；原127.0.0.1:28080/28082/28085不存在。未输出私有define、凭据或完整kernel文本。

提交前fetch Flutter，需求远端仍d196e16b、origin/codex/dev仍9a8d4e642ec1e892df4128992b84e8686233e732；dev_zys只更新远端引用，无合入。原仓库保护检查：foundation干净、App v4干净、Java22条未提交、旧工程31条未提交，与进入本轮一致。PMReport实际拆分仓库未登记，历史只读不代报。

48个本需求文件严格UTF-8/中文复读、Dart默认500行及暂存白名单检查通过，未提交.local原始日志/环境参数/凭据或APK。中文实现提交114f8065已非force推送codex/refactor-conversation-task-flow，ls-remote核对一致，codex/dev保持9a8d4e642ec1e892df4128992b84e8686233e732。运行待验项保持未勾选，不归档。

用户最新安装指令执行补记：使用上述-v45最终备份，安装前SHA256与aapt信息一致；只向当前真实荣耀手机执行install-r，未向模拟器安装。成功后dumpsys核对lastUpdateTime=2026-10-10 09:03:49，versionCode=45、versionName=1.0.51-foundation。未启动、点按任务、发送或拨号；本批只补安装记录和执行文档校验，不重复构建或全量回归。OpenSpec24.6包含真实媒体/UI及iOS，仍保持未完成。
