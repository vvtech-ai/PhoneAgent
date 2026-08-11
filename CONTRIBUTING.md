# Contributing / 参与贡献

## 中文

1. 不提交后台源码、服务端配置、账号、密钥、生产数据或商业 SDK。
2. UI、Domain、Data 与 Integration 保持单向依赖，不在 Composable 中直接发起网络、SIP、ASR 或 TTS 操作。
3. 新增状态应有单一事实源；一次性事件使用明确的 Effect/事件流。
4. 新增日志必须可关联且不泄露敏感信息。
5. 提交前运行：

```bash
./gradlew :app:compileProdDebugUnitTestKotlin :app:assembleProdDebug
```

PR 应说明行为变化、服务端契约影响、权限影响、测试结果和人工验证路径。涉及真实外呼、录音或声音克隆时，不得上传真实号码、音频或身份材料。

## English

1. Do not commit backend source, server configuration, accounts, credentials, production data, or commercial SDKs.
2. Keep UI, Domain, Data, and Integration dependencies directional. Composables must not start network, SIP, ASR, or TTS operations directly.
3. New state needs a single source of truth; one-shot work should use an explicit effect or event stream.
4. Logs must be correlatable and must not leak sensitive data.
5. Before submitting, run:

```bash
./gradlew :app:compileProdDebugUnitTestKotlin :app:assembleProdDebug
```

A pull request should describe behavior changes, backend-contract impact, permission impact, test results, and manual verification. Never attach real phone numbers, recordings, or identity material when working on calls, recording, or voice cloning.
