# 集成方式

在已有 story1837-flutter 隔离树以 c10ad11c detached HEAD 执行 no-ff 合并 e4b202e1，避免强行切换另一工作区正在使用的本地 codex/dev。最后仅非强制推送 HEAD:codex/dev。

任务和问题记录只存在双方头部新增冲突，完整保留两边内容。其余源码自动合并，逐文件对照两侧相对共同祖先的改动，确认新任务音色、翻译、iOS SDK 与本轮会员支付功能均保留。

已有 account_protocol_diagnostics.dart 仅换行标记，标准化 blob 与原 HEAD 一致。切换前原始文件复制到 D:/Temp/story1837-account-protocol-diagnostics-before-integration.dart 并记录 SHA256；按路径暂存 stash 后切换，不丢弃备份。合并后验证文件内容一致，再恢复原始字节。此文件不作为未提交业务修改推送。

本轮是跨模块里程碑，执行 flutter test 全量；analyze、OpenSpec 全量及新 change strict；验证可信 SDK 文件，Windows 仅 Android 构建，iOS 编译须 Mac。测试失败先查根因与基线，不以跳过替代修复。

首轮全量 4945 通过、5 失败、1 个既有开关跳过。失败分为既有 Windows symlink 权限问题和旧翻译日期夹具未提供历史 summary，生产源码与目标保持一致。仅修测试及参考夹具，录音账号隔离独立必测，Windows 目录逃逸用真实 junction 检查；精确的文件 symlink 权限不足单列未覆盖，不以其他链接类型冒充文件 symlink。日期夹具沿用真实投影，保留空历史详情行为。完成后执行受影响测试及 analyze，报告首轮和复验分别计数。
