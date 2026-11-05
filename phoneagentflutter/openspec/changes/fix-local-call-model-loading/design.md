# 边界

SDK 模型配置为 GET /api/account/settings/realtime-call-provider。先区分请求前、HTTP 传输、业务拒绝及 DTO 映射失败。模型读取与会员目录共用 AccountApi，但不得因此假设根因相同。

Honor 调试日志未提供 Flutter 异常；临时本机采集仅发送异常类型、枚举类别和首个源码栈帧到回环端口，不发送错误正文、账号、令牌或签名。保留数据安装，禁止卸载或清数据；所有临时采集文件在最终包前移除。

## 已确认根因与修复归属
Java RealtimeModelSettingsService.callItem 对未接入 INDEXTTS_QWEN 调用 RealtimeCallVoiceService，后者按执行枚举拒绝，整个目录返回 AC0001。Java RealtimeCallModelSelection.supportsImplementation 按 AiModelCodeImpl 与 REALTIME_VOICE 判断；未实现条目返回 available=false、空音色和中文原因，不调用 VoiceService，默认/激活与更新选择同样限已实现模型。Flutter DTO 与模型业务源码无需修改。

主代理记录 2026-10-13 21:20 真机 1310 重试 GET：HTTP200、code000000、providers4；Qwen/Seeduplex/SeeduplexV3 正常，IndexTTS 显示“当前模型尚未接入”。私有图 D:/Temp/story1837-local-device/model-catalog-fixed-20261013.png 不进入 Git。该证据证明修复后接口与既有客户端可工作；1310 仍为临时诊断包，最终无探针包验收单独待主代理完成。临时 local_model_probe.dart 与导入/调用已删除，不为 git diff 为空的 account_protocol_diagnostics.dart 修改业务代码。UI 保持中文失败及重试，不在页面加入网络或存储逻辑。
