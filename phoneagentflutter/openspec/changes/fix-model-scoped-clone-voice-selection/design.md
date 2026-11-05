# 设计

## 范围与身份
基线ab31098b，当前codex/dev_zys；参考aiassistant_app当前TaskRepository及SdkRealtimeCallVoiceApi/SdkVoiceCloneSettingsApi。音色路径使用公开modelId，数字ID不替换为cloneModelId。保留AccountApi账号归属、Bearer/C1及刷新规则。

## 状态流
已有克隆：POST voice-clone/activate?modelId，GET realtime-call-voice/models/{modelId}确认CLONE；不调用旧全局CLONE PUT。候选继续独立confirm，不附加activate。
系统音色：先按模型GET，若CLONE则同模型deactivate；失败仅查询status，明确active=false才继续。重读后若目标AI音色已选中则返回，否则按模型PUT。PUT失败仅GET确认实际目标，未确认则失败。任何链路结果不明在现有错误控件提示刷新，禁止再次写入直到只读同步。账号切换沿AccountApi owner边界拒绝。
Controller保留generation及busy保护，捕获操作目标；不得将迟到结果发布到其他模型。无新布局，仅错误反馈更准确。

## 验证
按最多3源码文件微批。仓库离线协议测试验证模型A当前/模型B目标、数字ID、双向切换、未知结果只读恢复及账号切换；Controller/UI回归验证重复点击、关闭/重开、旧响应、候选独立。运行flutter analyze、call_models及直接调用方定向测试、OpenSpec与diff检查。真实设备和SDK联调待验，不归档。
