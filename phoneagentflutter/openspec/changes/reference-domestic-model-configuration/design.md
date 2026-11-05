## 固定来源
Android 0f8879e4baf1d56fe6d7f8f356101fdf61d602ed的build.gradle/AssistantCallEngineConfiguration与iOS bb9ff34966f40a3c2794a9a8b8e935669a9faa12的AIQwenRealtimeTranslationProtocol。源码默认地址/模型一致，Android密钥默认为空，iOS有非空fallback。读取Android local.properties非空覆盖优先，缺少凭据时使用iOS同服务fallback供两端本地装配，清单仅记录来源/非敏感字段，不输出值。用户已授权参考配置读取及执行，覆盖domestic-sip-parity旧“不迁移参照密钥/等待短期服务”阶段限制。

## 工程与边界
私有JSON0600、ignored/untracked、非symlink父目录；Android assets与iOS Private文件分平台，iOS构建phase可选复制到App资源，缺失不妨碍编译但运行拒绝。本地JSON有16KB上限，版本1、平台标记、QWEN/DOUBAO两项。通道仅read指定provider，无文件路径或网络动作。Dart只在有效API环境和Android/iOS调用，拒绝畸形类型、未知provider、非原服务wss地址、非法头/采样率，错误不携带配置。配置只供对应WS握手，不复用账户token。iOS/Android值可能同源，不虚构服务测试/正式许可隔离。

## 模型与协议
Qwen端点api-ws/v1/realtime，模型qwen3-livetranslate-flash-realtime，Nofish，输出24k；豆包api/v4/ast/v2/translate，资源volc.service_type.10053，配置voice=Nofish，输出16k。豆包协议不消费voice，保持原生protobuf字段；Android/apiKey优先，accessKey仅备用；Qwen Bearer专用API key。SIP仍使用后台租约，不增加手动设置。

## 验证
工具用合成凭据验证提取/覆盖/私有写入/拒绝；mock MethodChannel验证双平台Provider装配、缺失/畸形/异常/不支持及头、采样率；受影响国内协议/factory/拨号测试，analyze；双端Debug构建，不安装或实际通话。每个手写微批最多3源文件，所有源码500内。
