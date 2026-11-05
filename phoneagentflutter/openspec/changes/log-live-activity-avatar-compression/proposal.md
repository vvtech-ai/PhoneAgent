> 历史排查记录：2026-10-29用户已确认头像恢复显示，并要求移除本次专用调试日志；下文为此前诊断阶段记录，当前实现以fix-live-activity-avatar-size-fallback为准。

## Why
同推送不同设备Live Activity头像有的回退默认；用户确认先增加日志确定原因及所选0.6/0.35/0.15档位，不修改处理策略。
## What Changes
- 压缩输入/渲染/各实际尝试/选择/整体预算/Activity请求携图结果的白名单日志。
- 既有native环形缓冲→EventChannel→账号日志→既有上传及序列化读取闭环。
## Impact
仅iOS可信来电Activity与Dart诊断投影/测试。当前test_v1.8.0_fix不切分支、不提交推送，不改共享编排规则、NSE、头像下载和认证音频/崩溃处理器。无真实来电/认证/上传动作。
