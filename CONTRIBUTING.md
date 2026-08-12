# Contributing / 参与贡献

Phone Agent 欢迎 Android 客户端、稳定性、测试、文档、翻译和未来 Call Skill 设计方面的贡献。

Phone Agent welcomes contributions to the Android client, reliability, tests, documentation, translations, and future Call Skill design.

## 贡献方式 / Ways to contribute

- 修复 Android 功能或兼容性问题 / Fix Android features or compatibility issues.
- 增加单元测试、协议测试或人工验证说明 / Add unit, protocol, or manual verification coverage.
- 改进中英文文档、截图和无障碍体验 / Improve bilingual docs, screenshots, and accessibility.
- 提交新电话场景的需求与风险分析 / Propose a phone scenario with a risk analysis.
- 参与 Call Skill Manifest、输入、结果、权限和测试规范讨论 / Help design Call Skill manifests, inputs, results, permissions, and tests.

## Call Skill 提案 / Call Skill proposals

Call Skill SDK 尚未发布，因此当前应提交设计提案，而不是声称可运行的 Skill 包。提案至少包含：

The Call Skill SDK has not been released, so contribute design proposals rather than claiming executable Skill packages. A proposal should include:

1. 场景、目标用户和明确的非目标 / Scenario, target users, and explicit non-goals.
2. 必填与选填输入，以及确认时机 / Required and optional inputs, and confirmation points.
3. 通话策略、可能使用的外部工具 / Call policy and possible external tools.
4. 成功、部分完成、失败和人工接管结果 / Success, partial, failure, and human-handoff outcomes.
5. 电话、联系人、录音、位置和数据保留风险 / Telephony, contacts, recording, location, and retention risks.
6. 正常、拒绝、无应答、冲突信息和异常测试 / Happy-path, rejection, no-answer, conflicting-data, and failure tests.

详见 / See [Call Skill vision](docs/CALL_SKILLS.en.md) / [通话技能愿景](docs/CALL_SKILLS.zh-CN.md).

## 工程规则 / Engineering rules

1. 不提交后台源码、服务端配置、账号、密钥、生产数据或无分发授权的商业 SDK。
2. UI、Domain、Data 与 Integration 保持单向依赖，不在 Composable 中直接发起网络、SIP、ASR 或 TTS 操作。
3. 新增状态应有单一事实源；一次性事件使用明确的 Effect/事件流。
4. 新增日志必须可关联且不泄露敏感信息。
5. 面向托管服务的能力应在运行时判断，不硬编码账号、模型、区域或线路承诺。

1. Do not commit backend source, server configuration, accounts, credentials, production data, or commercial SDKs without redistribution rights.
2. Keep UI, Domain, Data, and Integration dependencies directional. Composables must not start network, SIP, ASR, or TTS operations directly.
3. New state needs a single source of truth; one-shot work should use an explicit effect or event stream.
4. Logs must be correlatable and must not leak sensitive data.
5. Detect hosted capabilities at runtime; do not hard-code promises about accounts, models, regions, or telephony.

## 提交前 / Before submitting

至少运行 / Run at least:

```bash
./gradlew :app:compileProdDebugUnitTestKotlin :app:assembleProdDebug
```

Pull Request 应说明：

- 行为变化和用户影响 / Behavior change and user impact.
- 服务端契约、权限及隐私影响 / Backend-contract, permission, and privacy impact.
- 自动测试结果与人工验证路径 / Automated results and manual verification path.
- 界面变化截图 / Screenshots for UI changes.
- 已知限制和回滚方式 / Known limits and rollback approach.

涉及真实外呼、录音、翻译或声音克隆时，不得上传真实号码、验证码、Token、音频、转写或身份材料。

Never attach real numbers, verification codes, tokens, audio, transcripts, or identity material when working on calls, recordings, translation, or voice cloning.
