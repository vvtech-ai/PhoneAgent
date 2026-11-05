## 1 基线和配置
- [x] 1.1 核对当前代码/固定参考及用户扩展身份，建立本专项。
- [x] 1.2 核验工程SDK字节/私有配置环境和有效原生调用链，输出差异表。
## 2 共用业务/UI
- [x] 2.1 修正凭据旧关闭回调及事件/账号/连续来电导航保护，定向验证。
- [ ] 2.2 校准四状态凭据/首次说明/设置反馈及普通/大字短屏交互。
## 3 Android
- [x] 3.1 核验SDK公开组件/权限/角色并实现账户级后台准入与退出清理。
- [x] 3.2 完善有效首次/后续设置和SIM流程，JVM/定向/Debug构建。
## 4 iOS
- [x] 4.1 Live Activity测试/正式身份与App Team/版本同步，工程验证。
- [x] 4.2 新增通知服务扩展和安全通信通知/头像/超时/一次回调处理，工程嵌入及专项。
- [ ] 4.3 前后台/点击/冷启动/结束/Live Activity生命周期完善及原生专项和构建。
## 5 验证交付
- [ ] 5.1 双端隔离UI连续流程及原生运行对照，记录必要差异。
- [x] 5.2 跨模块全量回归与双端构建，记录实际范围。
- [ ] 5.3 具备明确条件的真机SDK/通知/来电/锁屏/权限拒绝/账号切换验收。
- [x] 5.4 更新任务/问题日志/报告并中文提交推送，用户验收前不归档。

阶段证据：Android可信JVM34项/8套件、Debug构建15.6秒；iOS通知Foundation7组及路由专项、Swift策略/一次完成专项、NSE模拟器构建及双扩展Release无签名构建、完整iOS Debug无签名构建14.6秒通过。4.3自动检查已通过，真实APNS/冷启动/锁屏/连续来电仍待设备条件，不以源码替代运行验收。

共享UI补验：专用iOS26.3模拟器隔离固定原生与Flutter凭据普通字号配对，verified/pending/failed/uncertified、大字长内容滑动至返回并关闭通过；Android双平台widget已有88项专项。2.2/5.1保留未勾选：Android原生运行对照及真实首次/后续SDK反馈未验，不扩大声明。

最终源码复核：NSE头像下载失败严格回原通知，真机SDK typecheck和完整App无签名25.0秒通过；Android最终APK17.8秒、合并manifest准入默认禁用/绑定权限通过。52e6b1f0已推送。其他模块15失败已单独复现，不能勾选全量通过；真实验收条件未提供，5.3继续待验。

## 来电专项最终回归记录（2026-10-09）

全量运行6分18秒：4047通过、37失败、1跳过，exit1，不能称全量通过。启动时旧联系人/关闭定位6失败已另以11项8秒补验修复，未重跑全量；其余31失败保留原始结果，不通过减法伪造新全量计数。四个身份/翻译文件另定向18通过15失败，已复现。

- test/shell_contacts_workbench_test.dart：2失败
- test/core/native_sheet_close_route_test.dart：4失败
- test/features/identity/identity_widget_test.dart：1失败
- test/features/translation/translation_model_sheet_test.dart：2失败
- test/features/translation/translation_overseas_entry_guard_test.dart：4失败
- test/features/translation/native_translation_model_panel_test.dart：8失败
- test/widget_test.dart：3失败
- test/extended_device_stage_test.dart：4失败
- test/migration_increment_device_stage_test.dart：2失败
- test/shell_receipt_workbench_test.dart：2失败
- test/shell_translation_workbench_test.dart：3失败
- test/shell_developer_workbench_test.dart：2失败

可信feature88项、Android可信34项、Foundation7组与通知路由、Swift通知有界/一次完成专项通过；SDK51SHA、私有配置固定参考内存比对、扩展三配置/合并AndroidManifest通过。最终analyze无问题/OpenSpec62通过；Android Debug17.8秒、iOS Debug无签名25.0秒构建通过，扩展Release无签名及NSE模拟器构建通过。固定原生和Flutter隔离凭据四状态已运行，2x长内容滚动返回已验证，截图保存在.local/ui-reference/incoming-call-20261009。

未完成验收：Android原生SDK页面与叠层运行对照、真实首次/后续授权反馈、双卡/后台进程恢复/锁屏/账号切换、真实APNS/冷启动/Live Activity、签名及服务端mutable-content配置；测试设备/账号/环境/次数问题尚无回复。不触发真实短信、SDK认证或呼叫，不以无签名构建交付为正式升级包。需要真实条件的任务保持未勾选，change不归档。160b53f4及之前实现已推送codex/dev_zys，中文日志。

## 6 设置入口原生流程修订（2026-10-10）
- [x] 6.1 更新入口规格并校验，固定原生职责复核。
- [x] 6.2 移除可见中间route，拆分prepare/guide事实与授权读取，设置页协调打开。
- [x] 6.3 首次/后续/失败重试/连点/覆盖/销毁/账号切换定向，analyze和相关平台构建。
- [x] 6.4 更新记录并中文提交推送；真实SDK视觉待验不归档。

## 2026-10-10 可信来电设置入口取消加载中间页

用户在侧会话确认修订计划并执行。固定参考iOS bb9ff349/Android 0f8879e4：iOS设置入口调用应用级幂等初始化，首次本地guide事实与readAuthorization分离；Android Application级初始化/SIM同步和首次SDK引导/后续SettingActivity回退保持，不新增授权查询前置。

删除TrustedCallerSettingsRoute/SettingsPage及只针对旧中间页的布局测试，设置页附着TrustedCallerSettingsEntry116行；构建设置页不prepare，点击期间保持原页，按动作持有autoDispose provider订阅，SDK结束释放surface；iOS说明fullscreenDialog，SDK返回原设置页，失败NativeNotice、再点重试。prepareEntry仅准备和读取本地guide，readyToConfigure不当作授权；SDK打开与退出后的refresh独立，刷新错误不当打开失败提示。iOS prepare仅增加needsIntroduction白名单字段，无新增SDK授权调用。账号变更/覆盖/销毁不迟到打开；重复点击单次，关闭不pop原设置或覆盖页。后台来电账户服务、Android原生打开链、密钥配置均保持。

源码按职责微批<=3：domain/device/controller，entry/provider/settings，iOS薄适配1文件；测试分批<=3，修改源码均<500。最终114项定向10秒通过（可信目录、架构、设置平台返回、账号Shell、设置展示），最终analyze5.2秒无问题；iOS Debug无签名7.5秒构建通过。本批未改Android原生/依赖/构建链，不重打Android包；没有全量回归、普通App安装、SDK真实授权或来电测试。先期32项重叠补验不累计。首次analyze两处curly braces及async mounted提示已核对修正后干净。旧基线trusted-caller spec无独立文件，核对active trusted-caller-parity delta与本专项，未由archive覆盖。

OpenSpec/diff最终校验及中文提交推送随后核验；外部pubspec.lock保留。真实双端SDK动画/设备视觉仍待验，本专项不归档。
