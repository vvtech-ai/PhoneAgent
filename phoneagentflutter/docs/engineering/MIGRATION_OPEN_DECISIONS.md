# 迁移剩余决策：限定范围，不重复开发

2026-09-21，Flutter核对基点`5630830`。旧Android固定`4c781e3ccfcd148c1f205921534907ee0c5aa864`，iOS固定`ddb996a28f98559ea7d8b76ca9d7712703dedbc1`；只读Git对象，未切换源仓库。本文记录已确认事实及待答选择，不替用户批准功能取舍，也不宣称整体完成。

## D01 日志功能范围（2026-09-21已确认）

### 代码事实

- Android `features/app_logs/AssistantLogUploadRuntimeController.uploadAppLogs`调用`AppFileLogger.exportLogs(context)`后直接上传；`zipLogs`打包统一目录，并非账号目录。
- `AppFileLogger`虽有`shareLogs`及`exportLogs(context, openSharePanel)`，固定提交的自有源码调用检索未找到有效页面使用；不能因方法存在而要求Flutter新增登录页导出入口。
- iOS `Features/Settings/AISettingsViewController.uploadLogsTapped`也是打包后上传，成功清理；这不是登录前独立导出页面的依据。
- Flutter [diagnostics_providers](../../lib/app/diagnostics_providers.dart)把未登录事件放入`signed-out`作用域；[设置上传装配](../../lib/app/log_report_providers.dart)只取当前账号Journal。未绑定Android crash摘要也不能假定属于后来登录账号。

### 已确认决定

用户明确现有功能是“日志上传”。撤销自行扩展的“匿名日志本地导出”开发项，不新增登录前导出/分享入口，也不将其作为迁移阻塞或待确认问题。保留现有设置日志上传和账号隔离；内部打包ZIP属于上传实现，不是独立产品功能。本项为范围纠正，不是导出功能实现完成。

## D02 旧未绑定异常补偿（2026-09-21已确认）

### 代码事实

Android `features/assistant_tasks/TaskErrorRecoveryPendingStore`只在`index9_task_error_exit`保存两组sessionId，缺账号、环境、创建时间、命令ID及观察到的服务端版本。旧`TaskErrorRecoveryPendingSyncUseCase`将每个ID与当时当前账号发送，没有版本比较。

固定后端`assistant/history/application/interrupt/ConversationInterruptApplicationService`有owner校验，且仅对`RunFailed`且当前`COMPLETED`做保留；不是所有状态/所有恢复命令都具备过期保护。`ConversationInterruptRequest`只有accountId/sessionId/reason/commandId/idempotencyKey/traceId，没有expectedVersion/旧事件时间；服务端新事件使用当前时间。

因此“能查到归属”不等于“旧命令仍应生效”。先GET再POST也不能消除并发窗口或证明旧标记比服务端新。客户端不能自造旧时间/幂等ID，就宣称安全恢复。

### 已确认决定

用户确认“以服务端最新状态为准”：保留旧文件，不导入或重放旧未绑定异常标记，不用旧标记覆盖任务状态。现有SecureTaskErrorStatusStore仅读取Flutter账号/环境作用域队列，正式Provider没有旧源导入，已符合决定，无需新增业务代码。新Flutter产生的有效队列继续按现有逻辑持久化和重试；本决定不取消正常异常退出/恢复同步，不修改后端协议。

详见[现有新队列实现](CONVERSATION_ERROR_STATUS_VALIDATION.md)。没有执行真实interrupt、读取设备旧数据或修改任务。

## D03 正式OTA发布边界（尚未批准策略）

固定旧源为`features/app_ota/FinalOtaActiveDownloadStore`、`FinalOtaDownloadedFileStore`、`FinalOtaInstallerFilePolicy`：

- 活动记录含DownloadManager ID、路径、目标版本/摘要/大小/force，但没有新Flutter作用域；版本码可缺失。
- 已下载记录允许版本名或版本码匹配，摘要可空；存在文件不等于适合安装到当前版本。
- 原目标为App外部Downloads（不可用时files）下`ota/chaken-ai-<version>-<checksum>.apk`。不能将记录任意路径当成可信新下载，更不能直接删除该路径。
- Flutter [UpdateDownloadStore](../../android/app/src/main/kotlin/com/vvtech/phone_agent/ota/UpdateDownloadStore.kt)只恢复自己的scope与UUID目标文件，已有真实包/版本/签名校验；这不自动提供旧job兼容。
- [Gradle](../../android/app/build.gradle.kts)生产签名尚未配置且Release保护仍在；本期没有取消保护、构造正式签名或发布升级。

正式发布前必须确定并验证：兼容的生产证书、更高versionCode、旧目标已过期时的处理、高版本旧下载是否经新服务端元数据核对后继续，以及回退旧App不识别新退出/清理标记的限制。旧APK不是用户身份数据，但“统一不迁移”或“无条件继续”都不能未经确认声称无缝升级完成。

## 当前执行边界（09-22更新）

- Android09-21后续真实登录/文字恢复已验证，09-22 16:59恢复普通Dev后再次冷启动确认已登录首页；覆盖本页旧14:26登录页状态，详见[主清单](MIGRATION_HANDOFF.md)。不要求用户确认安装或重复发送验证码。
- D01/D02已关闭：不新增匿名页面、不重放旧补偿；D03仍不信任旧下载路径。现有有效页面/新队列/正常OTA仍保留。
- 用户允许的真实声音、认证、权限、后台收件等人工验收继续集中在[主清单](MIGRATION_HANDOFF.md)，不要再当成尚未实现的功能重复制作。
- 基础页面/共享实现的交接核对见[目标审计](MIGRATION_GOAL_AUDIT_20260922.md)。D03仍是正式发布决策，不因基础迁移交接而擅自批准；人工能力由用户按主清单集中验收。Android增量27点已批准暂缓且仍未执行，不扩大成后续自动测试一律跳过。
