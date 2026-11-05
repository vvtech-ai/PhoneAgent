# 国内实时翻译参照配置接线

用户确认执行两端参照配置接入，豆包配置 voice 按 Android 使用 Nofish；本批不执行真实电话或收费。

## 来源及取舍

固定 Android `0f8879e4baf1d56fe6d7f8f356101fdf61d602ed` 的 build.gradle、AssistantCallEngineConfiguration、AssistantDoubaoProtocol；固定 iOS `bb9ff34966f40a3c2794a9a8b8e935669a9faa12` 的 AIQwenRealtimeTranslationProtocol。

| 配置 | 共同值 |
|---|---|
| Qwen 地址 | wss://dashscope.aliyuncs.com/api-ws/v1/realtime |
| Qwen 模型／音色／输出 | qwen3-livetranslate-flash-realtime／Nofish／24kHz |
| 豆包地址 | wss://openspeech.bytedance.com/api/v4/ast/v2/translate |
| 豆包资源／配置voice／输出 | volc.service_type.10053／Nofish／16kHz |

Android 默认凭据为空，当前 local.properties 未发现有效凭据；iOS 固定源码有非空默认值。工具优先读取 Android 非空本地覆盖和默认值，缺失凭据采用 iOS 同服务默认值。本次两端私有输入因此使用同一组模型参数；未核对外部 Gradle 命令行注入，不宣称参照安装包必然使用这些值。

用户最新授权覆盖旧 domestic-sip-parity 等待短期配置来源的阶段限制。采用参照客户端长期凭据模式，不能称短期凭据或不可从安装包提取；不复用登录token，不创造测试／正式许可隔离。豆包协议不消费voice，不新增未知音色字段；SIP仍用后台租约，不恢复手动设置或复制静态SIP密码。

## 本地部署

运行 `python3 tool/prepare_domestic_model_configuration.py` 生成两份0600、Git ignored/untracked输入：

- `android/app/src/main/assets/domestic-model-configuration.json`
- `ios/DomesticModelConfiguration/Private/domestic-model-configuration.json`

拒绝符号链接目标和父目录，单文件最大16KB。Android assets自动打包，iOS可选resource phase复制到App包；缺失时不阻止编译，但清除该资源的旧构建副本并在运行时拒绝。新机器需先生成私有输入；普通构建不读取参照工程路径。

原生只读通道不初始化SDK、模型、音频或电话。Dart仅在已有APP_ENV/API_BASE_URL有效且Android/iOS时读取，严格核对provider、原服务端点、专用认证头、Nofish和采样率。配置和异常细节不向UI回传，账号/取消/音频/积分/租约门禁保留。本批不修改业务后台环境。

## 验证记录

初步配置专项8项及国内factory/拨号/协议/协调器/准入/正式Shell/架构共57项定向通过，6秒；8项包含在57内。工具3项合成测试0.071秒通过。首analyze测试if缺大括号提示修正后4.2秒无问题。真实凭据只核对私有输入0600/ignored/untracked/非symlink及包内字节，没有输出值。

首次Android完整构建在复制320MB APK时No space left on device；已组装APK资源和通道类核对通过，不把失败命令当构建通过。只清理本批47MB不完整复制与本批320MB组装产物，改arm64定向构建，不动其他缓存或设备。

iOS首轮Failed to parse Target Device Version；fresh Xcode26.3/iphoneos26.2后有限verbose重试明确无法保存manifest/attachments/日志，No space left on device。文档首次写入及后续测试补充heredoc也因空间不足未执行；原57项测试范围不被扩大。最终构建与验收状态接续追加。

未安装普通包或发起通话；供应方凭据是否有效、真实字幕/听感/计费及用户验收独立待验。OpenSpec保持active。共享build/ios清理已询问用户，未获答复不得执行。


最终结果：Android target android-arm64 Debug15.4秒、iOS真机目标无签名Debug17.0秒通过，最终两端包内配置字节核对通过；Android vendor多ABI保留，iOS新通道符号位于Runner.debug.dylib。59项独立定向范围为先57项及后新增2项factory准入（复验14含重叠12），不是单次全量；analyze3.6秒clean，工具3项0.065秒及公用写入helper4项0.165秒。已有API环境、登录、地区、模型可用性及权限门禁仍保留，需重新构建安装后使用新配置，不宣称当前已安装旧包立即生效或真实电话可用。空间恢复后未执行共享build/ios清理，此前询问无需继续执行。
