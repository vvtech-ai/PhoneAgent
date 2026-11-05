# OTA修复验证（2026-10-16）

用户授权只提交推送codex/dev，后续其他任务统一打包；本轮未生成APK，未安装或部署后端。

- 旧行为RED：最初3项下载完成/恢复/不兼容证据均因inspect阻止交接而失败，删除检查后通过。后续删除inspect接口与过期预览/测试断言。
- 文件丢失RED：预期failed，旧结果ready；现通过OTA_FILE_UNAVAILABLE领域映射进入重新下载。原生覆盖完成记录失效、文件丢失/为空，权限及系统Intent失败仍允许重试安装。独立只读复核发现的P2已关闭。
- `flutter test test/features/app_update test/native_business_dialog_test.dart test/features/settings/settings_update_entry_test.dart --reporter expanded`：151项通过。
- `flutter test test/features/settings/about_update_test.dart test/features/app_update/ota_actions_render_test.dart --reporter expanded`：10项通过（含上面已覆盖的4项渲染），关于页6项新增验证；原测试按旧提示替换规则断言失败，修正为等待FIFO前一提示完成。
- 最终将上述模块、共享弹窗、关于页和设置更新入口合并一次运行：157项通过、0失败（25秒）。
- 渲染：320/393逻辑像素、1/2.75/3倍DPR、1/2倍字体及按压；等高等宽、12逻辑像素间距和缝隙像素断言通过。强更单按钮与共享业务弹窗默认回归通过。可选截图仅用于本机观察，不作为设备GPU证明。
- Kotlin2.1.0/JDK17 JVM：UpdatePackageStagerTest、UpdateInstallReceiptTest共8项通过；使用Android35、Flutter embedding及AndroidX实际依赖编译所有OTA Kotlin源码通过，不生成APK。
- 定向`flutter analyze lib/features/app_update lib/core/design/native_business_dialog.dart test/features/app_update test/features/settings/about_update_test.dart`：无问题。全项目检查当时4项info来自另一个声音克隆任务，保留其改动，不混入本提交。
- `openspec validate --all`：171项通过、0失败；本change strict通过，UTF-8中文读回、格式和diff检查完成后提交。

限制：提供的ZIP只有版本检查成功，缺失实际下载/安装失败证据；小米具体失配字段无法归因。OPPO竖线现象尚无该设备GPU重现，已针对按钮绘制边界修复并回归；系统安装/取消返回、OPPO/小米实机均待后续打包验收。系统能否接受降版本或签名由系统安装器决定。
