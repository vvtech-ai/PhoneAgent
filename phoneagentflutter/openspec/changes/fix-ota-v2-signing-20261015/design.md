## Decisions
1. 原生SdkC1SigningInterceptor将同一appKey/appSecret传给SdkRequestSigningInterceptor；Flutter复用DeviceC1Credentials的部署SDK_API_KEY/SDK_API_SECRET，不复制原生密钥或添加源码默认值。没有配置继续失败关闭。
2. 精确限定SDK的/api/ota/check路径后缀；签名输入v2、HTTP方法、实际编码路径（含已配置网关前缀）、原始query、appKey、SHA256(body)，换行拼接，HMAC-SHA256小写hex。JSON只序列化一次并发送同一字符串；无Bearer。
3. AccountApi仅OTA401抛rejected；保留普通受保护接口刷新机制及账号epoch检查。不重构公共鉴权。
4. 请求诊断独立辅助类记录固定operation/result、HTTP、耗时、UUID；仓库记录检查及解码结果，不接受原始错误文案、URL、包名、账号或凭据。DiagnosticEvent已有主线程变更仅追加枚举，保留其全部字段。
5. 现有单次共享、离页晚到、切号隔离、forceRequired保留和安装检查沿用，用定向测试验证。
6. 每个源码微批最多3文件，格式化单列。AccountApi原474行，辅助职责独立，保持500行以下。

## Validation
固定Flutter3.32/Dart3.8；签名固定向量含中文JSON、网关路径及query，其他请求C1；实际Dio出站字节/头、401不刷新/清登录、诊断脱敏/回读；app_update、关于直接调用方及网络鉴权定向测试，analyze，OpenSpec；Android Debug编译不安装。真实测试环境401归因、凭据服务端注册及生产OTA保留数据升级待设备/服务联验。
