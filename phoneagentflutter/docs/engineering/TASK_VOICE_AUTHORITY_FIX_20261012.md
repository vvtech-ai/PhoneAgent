# 任务音色与播报排查

Flutter 基点 codex/dev 36f76ec0。只读对照 Java feature/test_v1.6.0 8f302087、新版 App feature/test_v1.6.0 1e67c2d。用户先要求「不要提交」，真机测试后最新允许无问题时提交修复；最终核验和复审通过后按既有授权提交、推送语音修正。

## 根因与最终实现

最初设备本地 Maia/Andre 偏好未写账号 TASK_VOICE_TTS，Runtime 普通合成实际按账号选择。正式 Store 改为 SDK GET/PUT api/account/settings/task-tts-voice，校验模型、有效目录和保存回执；账号代次隔离迟到请求。

首轮 2026101203 错误地将目录限制为 Maia/Andre，且普通播报读取目录作为前置条件。用户反馈加载失败、无声后，临时诊断包 2026101204 捕获真机 SDK HTTP 200、业务码 000000、selectedVoice/defaultVoice=Ethan：接口成功，客户端目录解析失败。该限制也阻断普通播报。新增失败回归后改为动态目录和名称，外层与弹层共用有效状态；普通播报移除目录门禁，由 Runtime 选择账号音色。旧包不作为修复验收。

新版 App 的任务试听优先 previewAudioUrl，否则 POST SDK system-voice-preview/models/{modelId}/voices/{voiceCode} 获取 URL。正式试听复用 ApiSystemVoicePreview 有界 HTTPS 独立客户端下载、SystemVoicePreviewController 和 FocusedClonePreviewPlayer 生命周期；下载媒体不带账号头、不写选择，关闭/后台/账号变化停止。首轮 WS purpose/fixed-text 方案已撤回，普通播报维持原协议。临时 TASK_VOICE 诊断代码已删除。

## 验证与设备状态

首轮命令含两个不存在路径，造成 2 项加载失败；修正路径后完整定向集合 239 项通过。独立审查发现展示模型 A 变为 B 时客户端会改用 B 提交的竞态：新增回归复现错误成功，再让每个正式音色保留展示模型 ID，拒绝无模型设备音色及模型变化，PUT 提交展示 ID，保留后端二次模型校验。20 项受影响测试复验通过（含 2 项新增，不与 239 累加），最终 analyze 无问题；独立复审无阻塞项。

最终全仓 OpenSpec 校验 89 通过、3 失败（incremental-validation-policy、login-presentation、native-feature-parity-audit 的既有 delta 缺规范场景），未修改无关规范，本 change 有效。

iPhone 诊断包 2026101205 记录本轮 permission=OK/hasPosition=true；用户回复「看起来是可以的」。临时定位回调与日志已从源码移除。最终 Profile 开发 IPA 1.0.51(2026101207) 构建成功，导出签名与 ZIP/开发配置核验通过，USB 覆盖安装、版本读回和启动主进程确认通过，生产包仍为 1.0.46(11)。私有 dev 配置与现有签名用于保留数据覆盖安装；凭据、构建产物与已有 Podfile/lock 启动补丁排除于语音提交。用户最新要求拉取最新代码、合并推送 codex/dev，后续集成单独核验。

用户报告同一订餐任务此前提示定位、现在恢复；系统为「使用 App 期间」，本轮权限与有效位置都可用。源码每轮刷新位置/权限，位置 TTL 两分钟、取样九秒超时或回调错误返回空位置；因此不同轮次可能得到不同位置结果，但上一次缺原生错误码日志，不能证明具体失败原因。未修改定位实现，不声称定位已修复。对照 Apple requestLocation 文档确认单次取样可能数秒后以 locationUnknown 结束：[Apple 文档](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestlocation%28%29?language=swift)。真实各音色听检仍分项待验，不自动发送短信或电话。
