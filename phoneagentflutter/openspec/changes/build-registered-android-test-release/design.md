# 设计

本次为既有构建策略的小范围扩展。android/test-environment.gradle 负责 test 身份、原项目签名、ARM64 和 Release 兼容策略；app/build.gradle.kts 仅调整任务图门禁，只有显式 test 允许 Release，未知环境仍在配置期失败。Release 签名不回退到 Android debug key。

scripts/build-task-test-apk.ps1 增加 BuildMode，默认 Release、显式 Debug 可用，沿用既有参数和 finally 恢复环境规则。未来其他环境继续增加独立策略，不开放默认生产 Release。

入口使用 --pub 让固定 Flutter 为当前模式重新生成插件注册；--no-pub 在该版本跳过 regeneratePlatformSpecificToolingIfApplicable，Debug 切 Release 时会残留测试插件，不能复用旧注册文件。依赖版本沿用现有锁文件。

test Release 使用 Dart AOT；Java/Kotlin 暂不混淆、不资源裁剪，避免供应商反射入口被裁掉。jniLibs.keepDebugSymbols 保留既有供应商保护名单，成包逐项对比 AAR/JNI 来源字节。过滤其他架构只适用于 test Release。

先验证脚本默认 Release 计划失败，再实现；实际 Gradle 配置验证 dev Release 拒绝、test Release 登记签名生效，最终验证 APK 无 debug 标志/无 kernel_blob、有 AOT、仅 ARM64、包名、版本、签名和三个 test URL。当前实体设备 e2e5aa93 安装前后核对版本和首次安装时间，采用 adb install -r，不卸载或清数据。

## 用户指定1.0.52(45)
用户明确本次版本1.0.52(45)，覆盖默认递增号选择：pubspec设1.0.52+45，测试脚本版本名同步1.0.52，计划回归核对精确版本参数；不改业务和签名/环境策略。当前实体已装2026101512，adb帮助明确-d仅debuggable允许降级，登记Release不能保留数据覆盖45；先交付精确版本包，安装方式等待用户选择，不擅自卸载或改包名。未来版本沿同一构建入口显式传BuildNumber，不新增业务抽象。
