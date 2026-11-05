# Design

## Evidence and baseline
Flutter origin/codex/dev=4bca81c0；旧 Android origin/feature/test_v1.6.0=8f23592。当前工作树干净，远端已读取并核对。诊断 ZIP 1792144490681 在 17:49:47–17:52:39 有 17 次监听播放资源获取/释放，缺少分层断开原因，不能直接断言丢失 AI 音频的唯一根因。

## Responsibilities
权限动作仍由 ConversationActionFlow 回传，反馈展示由小型权限通知组件消费并调用现有 NativeNotice，ConversationPage 仅接线；不把设备调用或 Toast 管理塞入会话 Controller。转写 revision 属于通话展示，依据实际 transcript lines，而非只读轮询 source。音色页启用条件使用当前目录音色 ID，复用 ApiSystemVoicePreview 的独立下载和后台生成接口，不复制本地资源判断。

监听沿 CallMonitorStream / DeviceCallMonitorOutput / Netty PhoneCallMonitorTap 分层检查。未证实的问题先记录原因、首帧及队列状态；可重复的缺陷必须先 RED，再做最小修改，不调整真实电话媒体或重放请求。

## Validation
先增加真实页面/SSE 跟随与动态音色按钮回归，确认现状失败，再实现。权限覆盖拒绝、永久拒绝、后台/退出及重复 rebuild 不重复 Toast，真实 permission_result 不变。执行受影响 Flutter tests、analyze、OpenSpec 和 UTF-8/diff。监听真实双向音频及系统权限需后续设备验收。

## Confirmed monitor reproduction
170 个合法 640 字节/20ms PCM 帧连续到达，旧实现超过 64,000 字节便断流，RED 测试 lost=1。现增加 socket 接收回压：待播放达到约一秒暂停接收，降至半秒恢复；保留单帧与总容量校验。Dart 3.8 的 WebSocket 实现将订阅 pause/resume 传递到底层 socket。合成及真实本机 WebSocket 均验证顺序保留、不触发重连；静音时禁用接收并先排空暂停队列，防止旧音频重放。该证据修复确定的突发断流路径，不证明诊断会话 AI 丢声唯一原因。生产监听共用 MediaDiagnosticScope，记录安全枚举原因、首帧及回压/关闭，禁止日志输出音频、转写、URL、票据或异常原文。
