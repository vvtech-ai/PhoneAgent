# 验证记录：任务反馈与监听

## 范围与来源
- Flutter 基点与拉取的 origin/codex/dev：4bca81c0；本轮无遗漏远端提交，无合并 dev_zys。
- 旧 Android 仅对照 origin/feature/test_v1.6.0=8f23592。
- Java feature/test_v1.7.0 保留本地已有10个提交，远端无遗漏更新；本次单独提交，不将其余既有提交推送。

## 实施与职责
- ConversationPermission 的两条瞬时文案、ConversationActionFlow 的真实结果接线、独立 LocationPermissionNotice 负责单次提示；主 ConversationPage 只接线。真实 permission_result 的状态和上下文保持，已有显式设置入口保持。
- CallSessionPage 以实际转写 speaker/text 生成内容 revision，SSE 更新即跟随，相同内容计时不打断浏览。
- CallVoicesPage 按后台当前目录非空音色 ID 启用已有动态试听端口；不改默认音色或模型。
- CallMonitorStream 在约一秒已提交音频处暂停接收，降至半秒恢复；硬件完成回调驱动，保留两秒容量及坏帧保护。静音时清理暂停队列；关闭和账号生命周期沿既有 owner。
- MediaDiagnosticScope 增加 callMonitor 安全组件，区分连接、首帧、坏帧、缓冲回压、播放失败和超时；不记录原始音频、正文、地址、票据、密钥或异常原文。

## RED / GREEN
- SSE 跟随及两端动态音色按钮：现状5项失败；修复后连同动态媒体接口8项通过。
- 普通/永久定位拒绝：现状4项失败；修复后包含真实回传、关闭/恢复不提示、重建不重复以及既有设置回读通过。
- 合法170帧 PCM 突发：现状 lost=1，修复后内存与真实本机 WebSocket 保序，不重连；暂停旧音频不重放。
- 安全诊断两项先失败后通过。
- 最终定向：calls、call_models、权限/定位/开场直接调用方、媒体诊断及架构共475项通过；flutter analyze --no-pub 无问题。
- openspec validate --all：172 passed / 0 failed；git diff --check、UTF-8/中文读回通过。
- Dart format 仅涉及本轮15个 Dart 文件，机械格式批次未改无关文件。

## 服务端与运行态边界
Java 同名 change 的24项定向测试通过；历史列表按新规则只读重放，无需改存储行。发布后权益拦截显示未完成。未改 Netty、Phone、SIP、ASR/TTS供应商或 Web。
本轮无打包、安装、数据库写入、部署、真实电话或供应商付费请求。170帧回归证明一个确定的客户端断流路径得到修复，不能替代用户日志对应通话的双向音频验收。Android/iOS 系统权限、真实监听及预置声音生成试听待后续设备验证，task7保持未勾选。
