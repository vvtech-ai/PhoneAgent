# 合并重复通知扩展目录

用户批准2026-11-03修改计划并明确执行：仅处理TrustedCallerNotificationService重复引用及接线脚本；复用原LiveActivity修复隔离检出，不回写主检出、不提交、不推送。业务与Android保持不变。

事实：两个group指向同物理目录，实际一个Target、一次Embed。第一group关联三个Swift源文件与三套配置，第二group五个引用未构建。脚本只查name而两个group只有path，导致重复创建。

职责：PhoneAgent/iOS工程及tool脚本持有构建引用状态；无业务状态owner/API变化。保留源文件、资源、配置、依赖、签名、包身份、最低系统及推送运行行为，不涉及任务编排回放；验证专用NSE-WIRING-01至05及既有iOS合同、Debug/Release无签名编译。
