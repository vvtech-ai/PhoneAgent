## Why
用户确认实施 OTA 版本放开、会员模型权限刷新/默认值校正，以及道歉任务模型与全局默认的展示和切换一致性。现有更新链路多处拦截低号/同号和版本元数据差异；模型列表持有旧状态；任务标签与全局选中项混用。

## What Changes
- OTA 按后台 hasUpdate 下发结果处理，取消客户端版本大小及后台/APK版本一致性限制，保留身份、签名、摘要/大小和系统安装权限检查。
- 首页、任务列表、设置及模型面板统一刷新，可信会员购买完成后同步刷新；旧请求不得覆盖新权益。
- Java 读取通话模型时校正无效默认值到后台排序的第一个可用模型并保存；无可用项不选中，不改有效选择。
- 道歉 Agent 模型选项仅影响当前任务；任务面板手动切换同时更新任务及全局默认。历史任务优先恢复自己的模型，只有无记录时使用全局。

- 用户追加：确认拨打先回显用户内容、等待期AI处理反馈；拨打结束后的结果同步/总结反馈对照旧版补齐。

## Capabilities
### New Capabilities
- `model-refresh-task-scope`: 模型刷新与任务/全局选择作用域。
- `ota-version-handoff`: 不依赖客户端版本比较的安装交接。

### Modified Capabilities
无新增 HTTP 字段；复用现有模型设置、taskCallModelId 和 callVoiceSelection。

## Impact
Flutter app_update/call_models/shell/conversation/apology 与 Android OTA 边界；Java 对应 reconcile-current-call-model-default。用户最新要求验证后提交推送并打测试环境原登记签名包，沿用 com.vvtech.aiassistant.test、1.0.52 (45)，文件名仅更新时间戳；不安装、不部署、不执行真实外呼/支付。
