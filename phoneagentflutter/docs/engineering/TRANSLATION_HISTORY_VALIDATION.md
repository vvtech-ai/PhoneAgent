# 翻译历史只读详情与任务入口

2026-09-16；行为固定 v65 4c781e3，设计 0cd58de memory 的 v64HistoryDetail。

## 交付范围

- Phone Agent GET api/realtime-translation-calls/{callId}；严格 callId/route、账号代际；不连接 world-call、不下载录音。
- 双方字幕保留 final=false；按 myLanguage 选择主文本；同语系重复次文本隐藏；对齐原文/译文、姓名/电话/时间/时长。
- WORLD_CALL 与旧 DOMESTIC_ANDROID 记录可读；仅是历史兼容，不新增国内 SIP 通话。
- 录音 locator/国内 checksum 等单独校验，异常不破坏字幕。录音授权不进入 presentation，不输出请求体或字幕日志。
- 任务普通无 session 行按 FinalTasksPageV3 → openAssistantTaskResult 进入新统一页；不新增独立旧 Result 路由。翻译行单独详情。

## 验证

- 全量134 tests、analyze、OpenSpec11/11、设备集成 Android 构建/安装/交互通过。
- 最后普通入口重新构建并安装的组合命令被环境执行策略拒绝，未执行，不通过改写命令绕过；模拟器暂仍保留离线集成测试入口包。普通入口安装待允许后补做，本批无原生/依赖变更。

- 8 项新增测试：映射/非最终字幕/语系/旧路由/元数据容错/失败重试/退出晚到/小屏，以及实际 Repository GET 路径、账号头、无媒体访问和旧账号拒绝。
- 离线 emulator-5554 扩展原统一页流程，新增翻译加载失败→重试→双语详情→关闭，以及普通无 session→新统一页。所有数据为合成替身，无真实通话/录音/身份写入。
- .local/conversation-validation/translation-history.png 已视觉检查；设计提取56节点、1原始SVG；设计schema有效。
- 录音播放/保存按用户要求后置，页面只说明尚未接入；未伪造媒体可用或成功播放。

## 剩余

真实账号/iOS验证、完整统一回执/批次结果/评分、媒体播放缓存下载仍待后续。不将本批只读详情等同完整翻译功能。OpenSpec active，用户验收前不归档。
