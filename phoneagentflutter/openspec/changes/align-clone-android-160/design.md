## Context
Flutter 基线 414299ba，旧 Android origin/feature/test_v1.6.0 基线 8f23592。用户已明确批准实施；覆盖历史按旧 iOS 保留独立失败跳转的决定。

## Decisions
- 模型选择器接收可选 targetModelId，首次载入后自动选择该模型，复用权益、价格、候选恢复及重新认证确认。全局入口不传模型。
- 系统音色恢复 PUT selectionMode=AI、voice=null，由后台选择真实系统音色；只读核对返回的 activeVoice 和目录，不再硬编码供应商名单。
- 路由结束后刷新目录以及实际进入的模型，非当前通话模型也使用已加载的对应音色数据。
- 扣费通知由候选展示映射生成，页面按本次生成操作的通知 ID 去重，兼容 candidateId 缺省的旧响应；仅本次新创建的 ready 候选显示实际 chargedPoints/remainingPoints，读取历史候选及确认不重复提示。
- 删除后重新进入按最新目录及有效认证录音选择流程，Android/iOS 使用相同状态路由；平台权限/SDK 保留适配。
- 下载重试只重试读取，不重放收费请求。iOS 试听按用户 2026-10-21 决策对齐 AIAssistant：原生准备仅设置 Playback 类别后激活，不显式设置 mode 或混音选项；Flutter 播放器的 iOS 参数也不添加混音选项。遵守现有媒体租约及 SDK 释放顺序；实机验收与自动测试分开，此配置调整不等于已验证解决 !pri。
- 每批最多三份手写源码。新增 shell_clone_navigation 专管打开流程和返回刷新；扣费展示扩展现有 candidate_presentation，主控制器保持 500 行、Shell 491 行，不放宽架构上限。

## Validation

2026-10-21 真机 diagnostics.jsonl 26 明确为 setCategory 返回 !pri，失败前仍为 PlayAndRecord / Default / options=0。试听持有媒体租约且无采集 owner、无通话、前台时，遇到录音类别先显式停用，再设置 Playback 并激活；停用失败保留错误，不伪造释放成功。每次有界重试重新检查采集 owner 与插件有效性，不能在延迟期间新启动的 SDK 上重设音频。
先添加失败用例，再实现；覆盖新模型恢复、指定模型入口、删除后重建、非活动模型默认音色、扣费去重、试听重试与播放配置。运行受影响测试、analyze、OpenSpec 校验。Windows 无法执行 iOS 编译及实机音频验收，明确保留待验。
