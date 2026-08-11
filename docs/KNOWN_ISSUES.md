# 已知问题 / Known Issues

## 中文

- 客户端历史代码量较大，JDK 11 首次全量 Kotlin 编译在本机约需 4–7 分钟。项目使用单进程 Kotlin 编译和 5 GB Gradle 堆，建议构建机至少提供 8 GB 可用内存。
- 2026-08-11 基线完整执行 `testProdDebugUnitTest`：1613 项测试中 1584 项通过、29 项失败。失败项主要是内部重构期间遗留的源码结构断言和部分既有行为回归用例，公开整理没有把它们伪装为通过。
- 公开 CI 会编译全部主源码和测试源码、生成 `prodDebug` APK，并执行与开源边界直接相关的 SDK 隔离、SIP 自动租约、网络配置、首页配置和通话策略烟雾测试。
- 缺少商业身份认证或可信来电 SDK 时，对应可选入口会提示组件未安装；基础登录、任务、托管后台 AI 通话和记录功能不依赖这些二进制。
- 服务端不在本仓库中，第三方无法仅凭本仓库在本地复刻官方完整后台。

完整测试集的既有失败需要在后续客户端重构中逐项确认：区分已失效的源码形态断言、需要更新的测试夹具，以及真实行为回归。

## English

- The historical client source is large. A first full Kotlin build with JDK 11 takes roughly 4–7 minutes on the verification machine. The project uses in-process Kotlin compilation and a 5 GB Gradle heap; at least 8 GB of available build memory is recommended.
- Baseline result on 2026-08-11: `testProdDebugUnitTest` ran 1,613 tests; 1,584 passed and 29 failed. Most failures are stale source-shape assertions from internal refactoring and pre-existing behavior regression tests. The open-source preparation does not misrepresent them as passing.
- Public CI compiles all main and test source, builds the `prodDebug` APK, and runs smoke tests for proprietary-SDK isolation, backend-assigned SIP leases, network configuration, home configuration, and call policy.
- Without commercial identity or trusted-call SDKs, only their optional entry points report that the component is unavailable. Base sign-in, tasks, hosted AI calls, and history do not depend on those binaries.
- The backend is outside this repository, so the official complete service cannot be reproduced locally from this source alone.

Future client refactoring should triage each full-suite failure into an obsolete source-shape assertion, a fixture that needs updating, or an actual behavior regression.
