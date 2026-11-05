# Design

在现有文件工厂通过 kDebugMode 与 Android 平台双重条件选择 DebugReadableDiagnosticFiles，编译期 Release 条件不能由运行参数开启。独立适配器包裹原加密档案，为已成功读写的数据生成独立 readable-debug 目录副本。保留 encrypted adapter 的严格格式校验和唯一权威，Debug / Release 同包名覆盖不出现格式冲突；副本失败不影响主档案。

测试注入平台与允许开关以运行真实文件工厂。覆盖 Debug 明文、禁用时加密、非 Android 加密、旧加密档案读回/追加/重启、密钥遗失时不覆盖旧数据。Release 交付检查 debuggable=false，与 Debug 读取能力分别验证。

用户询问 Release 直接 ADB 读取的风险后，当前仍沿用其已明确选择：仅 Debug 放开。Release 本地用户导出属于可另行批准的方案，不默默开放私有目录。
