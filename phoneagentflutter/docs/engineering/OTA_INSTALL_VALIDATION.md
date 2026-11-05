# Android 启动/手动更新链路与验收

## 2026-10-16 最新版本规则

用户确认取消客户端的版本大小检查及后台元数据与APK版本一致性检查；同号、低号及后台/APK版本名或码不同均可进入系统安装。仍保留包名、兼容签名、文件摘要/大小、下载归属及系统权限。后台hasUpdate发现规则不变，系统能否覆盖由Android决定。恢复任务只在安装时间推进且当前安装APK摘要匹配该任务已验包回执时清理；旧记录缺证据时保守恢复。下方历史版本比较规则由本节覆盖。验证见 openspec/changes/sync-call-model-scope-and-relax-ota/ota-verification.md；真实安装和安装后恢复清理仍待设备验收。

## 最新进展：启动恢复与每日检查（2026-09-18）

本节覆盖下方手动安装历史批次中的“启动未接入”。已完成 `settings-interactions 2.1d1`；2.1d2 正式同签名旧登录/数据升级和真实系统验收仍未完成。

### 实现与源行为

- 固定 v65 `AssistantOtaRuntimeController` / `FinalScreenContract`：已登录 Android 启动先读取同环境/API/账号/包的活动下载；有记录直接恢复，不先请求版本、不重复创建下载。记录无 URL/请求头，下载丢失时显示“刷新下载信息”，重新检查后才允许新下载。
- 无恢复任务时：force 标记为真，或最后成功日期不是本地当天才检查。成功（含手动检查）记录日期和 `hasUpdate && forceUpdate`；失败不记成功日、不清 force。启动与手动只合并正在进行中的同包版本请求，显式后续检查仍访问 API。
- 原 v65 **没有凭缓存 force 标记离线锁死 App**：普通启动网络失败静默，既有 force 失败提示重试；收到有效强制响应后弹窗才不可返回/稍后。旧文档“持久强制门禁”指持久标记驱动复查及有效响应门禁，不是新增离线封锁。
- `StartupUpdateController` 负责策略、单飞、账号/关闭世代；`SecureStartupUpdateStore` 串行存储设备策略（环境/API/包隔离），不保存账号资料或下载凭据。`StartupUpdateHost` 管理自己的弹窗/安装路由，退出登录只移除自有路由。
- 原生 `peek` 返回非敏感版本元数据；若安装时间推进且已安装APK摘要匹配任务回执，只清理本 scope 旧 job 及其自有文件。该清理不代表旧 Android 数据导入已完成。iOS/Web 正式不调用启动检查/下载端口。
- 独立 `startup_update_preview.dart` 和开发者场景页共用正式 Host、弹窗、安装页和状态机；跨路由显式继承模拟容器，根正式 Provider 抛错测试保证不会误触真实服务。

### 本批验证

- 新增 **36 项**：16 控制器、8 Host、3 存储、2 单飞仓库、2 原生通道契约、5 嵌套容器演练；全量 **1,405 项**通过，analyze 无问题，629 文件格式检查通过，OpenSpec 19 项通过。
- Web 和 Android Debug 构建通过，测试 API 均保留 `/aiassistant-api/` 上下文。当前批无新 iOS 构建/双端安装；前一批 iOS 构建结果不冒充本批验证。
- 浏览器独立 `127.0.0.1:8095`：普通更新→稍后；强制更新→模拟下载/校验→授权返回→安装交接→取消回到“继续安装”→模拟无需更新清除提示；缺失恢复任务从0次请求→刷新下载信息→1次请求的新版本提示。没有真实 APK/权限/安装或正式账号请求；未重启真实 8080 登录实例。
- 320/390/430 宽 Host 测试、当天 0 次请求、离线 force 不锁死→恢复后强制提示、恢复已下载无需 API、恢复缺失先刷新均有自动回归。未把这些测试当作真实系统下载/旧包升级成功。

### 新增集中验收步骤

1. 测试包首次启动无活动下载时检查一次；同日本地成功后重启不重复检查，次日再查；设置手动检查不受当天限制。
2. 失败不更新成功日期。有效 force 响应不可返回、不能点外部关闭；取消安装仍停留可继续安装页。持久 force 后断网重启按 v65 提示失败，不新增缓存离线封锁；恢复网络后手动重试可继续。
3. 下载中或下载完成时终止进程，断网再启动应优先恢复同一系统任务；文件/任务缺失时重新获取版本与下载信息，不向空地址请求，不使用持久签名 URL。
4. 授权的同签名测试更新成功后，核对实际安装版本；启动清本 scope 旧任务，其他账号/环境任务不受影响。正式 v65 登录/偏好/数据导入另属 2.1d2，未完成前不得交付无缝升级。

## 以下为手动安装子批历史记录

## 本批边界（2026-09-18）

已实现设置→检查版本→立即更新→恢复/下载→校验→未知来源授权→系统安装器→取消后继续安装。业务状态和页面共用 Flutter；Android 仅实现系统下载、包信息和 Intent。iOS 无入口、无更新通道。Web 使用明确 MOCK，不下载 APK、不修改权限、不安装。

这不是正式 OTA 交付：启动每日检查、全 App 持久强制门禁、已发布 v65 的同签名/versionCode/旧登录与数据导入仍未完成，见 settings-interactions 2.1d。现有 Release 构建保护保留，`.dev` Debug 包不能覆盖正式包。

依据：固定 Android `4c781e3` 的 FinalOtaUpdateInstaller、AssistantOtaRuntimeController、FinalOtaUpdateDialog；现有 ShellTokens/AppUpdatePage。按用户批准先完成可交互页面，原生对话框尺寸与完整视觉统一留后续校准，不声称像素还原通过。

## 实现与状态

| 层 | 文件/职责 |
|---|---|
| 共享领域 | `app_update/domain/update_install.dart`：下载快照、安装包证据、与当前包身份及服务端完整性要求的匹配规则 |
| 共享编排 | `presentation/controller/update_install_controller.dart`：单飞、轮询、恢复、校验、权限返回、安装返回、退出/账号晚到保护 |
| 页面/装配 | `update_install_page.dart`、`update_install_route.dart`、`app/update_install_providers.dart`；现有检查页接立即更新；页内强制标记禁返回，不代替全 App 启动门禁 |
| 原生 | `android/.../ota/UpdateDownloadStore.kt` 系统下载与记录；`UpdatePackageInspector.kt` 私有副本/包校验；`UpdateInstallChannel.kt` 系统交接；`UpdateRelease.kt` 非敏感元数据 |
| 隔离演练 | `data/preview_update_install_port.dart` + `pages/update_install_preview.dart`，使用正式页面与控制器，不注入账号/网络/文件服务 |

状态：idle → downloading/paused → verifying → ready → permission/installing。系统安装器返回仍为 ready，并提示安装未完成；没有“Intent 成功即升级成功”的终态。授权返回只继续一次；授权拒绝可再点去授权。异步平台回调尚未结束就收到 resume 时保留该事件。

进入页面只恢复，不自动下载或弹安装器。显式下载操作完成后可交接系统。恢复已下载任务只校验并等待“继续安装”。下载失败显式重试；摘要/大小/包名/版本/签名不匹配时清理本任务，不请求安装授权。

## 文件、签名与恢复边界

- Android DownloadManager 管理后台下载，页面销毁只停止观察，进程结束不主动取消；显式“稍后更新”/返回取消本任务。恢复前需先取得匹配的版本检查结果，本批不是无网络启动恢复入口。
- 环境/API/账号/包名哈希隔离记录，只存 UUID job、系统下载 ID 和预期包元数据。应用自己的持久记录不含下载 URL/头；DownloadManager 系统任务仍必须持有请求信息，不能误称全系统不落地凭据。
- enqueue 前先记录 job；若进程在系统任务创建与 ID 提交间结束，可按该 job 的唯一自有目标路径找回本应用系统下载行。相同版本的重复 begin 重新附着，不另建下载。真实进程终止恢复仍待真机验收。
- 源下载仅在 App 自有外部 Downloads/flutter-ota；安装前复制到私有 files/ota-installs。检查实际包名、版本名/码、当前证书集合或 Android 认可的轮换历史，计算 SHA256 和大小；服务端提供的可选摘要/大小必须匹配。安装前原生再次完整核对，Dart 不能传任意路径。
- FileProvider 只暴露专用 ota-installs，exported=false；没有 broad storage 权限。系统安装器是最终完整签名、兼容和安装权威，本地兼容检查不代替其判定。
- APK 地址可能为后端签名对象存储地址，只传版本检查返回的下载头，不附加账号 API Bearer，不展示/记录 URL 和头值。下载/重定向由系统下载器处理，需在验收中核对发布环境的实际下载域和响应。
- 没有新 SDK/依赖；只加 REQUEST_INSTALL_PACKAGES 声明，不在后台自动申请。iOS/Web 端口调用在平台门禁处拒绝。

## 自动与浏览器验证

- 新增 **39 项**（24 控制器/规则、8 通道、7 页面）；OTA 子集 **62 项**、全量 **1,220 项**通过，analyze 无问题，OpenSpec **19 项**通过。
- 覆盖重复点击、恢复只读、暂停后继续、错包/签名/摘要/版本/大小拒绝、晚到 enqueue/restore 的显式取消、dispose 保留后台任务、账号变化、清理失败、授权早返回、安装取消不误报。
- 320/390/430 宽度连续操作与系统返回通过；强制页无返回/稍后按钮。已有版本检查页面回归保持。
- 浏览器 `localhost:8080` 复用登录：设置→Android 更新演练→正常下载→拒绝→去授权→授权返回→系统安装交接→取消返回→稍后更新→场景列表。截图无明显溢出，未做像素评分。
- Web、Android Debug、Mac iOS Debug 无签名构建通过。合并 Android manifest 确认 `.dev.flutter.ota.fileprovider`、不可导出、专用路径和安装权限声明；iOS 构建只证明共享 Dart 编译兼容。
- 未真实下载、安装或覆盖任何设备 App；未发新短信、改登录、触碰 Mac 保留解锁会话或上传真实资料。DownloadManager/PackageInstaller 的实际权限与进程恢复不由这些合成测试证明。

## 集中人工验收（尚未执行）

前提：先恢复设备安装授权；测试环境发布**独立测试包名**、同测试证书且较高 versionCode 的 APK。生产 v65 覆盖须等 2.1d 完成、签名材料与数据备份方案确认，不能用当前 Debug 包替代。

1. 设置检查：实际 package/version 与设备安装信息一致，点击检查无下载；点立即更新进入准备页，再点下载才创建系统任务。
2. 下载与恢复：断网显示暂停/失败；恢复网络能继续；下载中终止进程后重新打开、检查同一更新并进入，应恢复同一 job，不重复下载。系统服务异常明确失败，不显示已下载。
3. 文件与证据：分别测试错包、错误大小/摘要、不同签名 APK，均不得打开安装器；同号、低号或版本名/码与后台不同但身份完整性合格时允许交接系统。正确同签名更新可继续；证书轮换需单独在受支持版本验收。
4. 未知来源：拒绝后提示可重试；重新授权回到 App 只打开一次安装器。已授权时不反复跳设置。设置 Activity 无处理器或系统安装被策略限制时给可恢复错误。
5. 安装取消：返回显示“安装未完成/继续安装”，再点可重新交接；不得显示更新成功。稍后更新/系统返回清本次任务和自有 APK，不能删除别的文件或别的账号任务。
6. 安装完成：只针对授权测试包验证重启后版本真的增加、登录与资料不丢；正式 v65 旧数据迁移另有实现与证据门禁。本批未实现升级后的统一清理/启动协调。
7. 平台：Android 26、29、当前主测版本各测系统下载存储/权限差异；iOS 设置无 OTA，Web 仅 MOCK。检查短屏滚动、返回、安全区；视觉最后统一校准。

定位：记录脱敏测试时间窗、UUID job、系统下载 ID、预期与实际包名/版本、固定错误码 `OTA_OPERATION_FAILED` / `OTA_HANDOFF_FAILED`。不要复制签名下载 URL、HTTP 头、账号凭据或原始异常到日志/工单。禁止把 Web MOCK、编译成功或安装器启动当作真实升级通过。

## 官方接口依据

[DownloadManager](https://developer.android.com/reference/android/app/DownloadManager)、[FileProvider](https://developer.android.com/reference/androidx/core/content/FileProvider)、[SigningInfo](https://developer.android.com/reference/android/content/pm/SigningInfo)。使用系统能力及证书轮换历史；平台结果仍须实际设备验收。
