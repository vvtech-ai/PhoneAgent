# 已知问题 / Known Issues

## 中文

- 客户端历史代码量较大，JDK 11 首次全量 Kotlin 编译在本机约需 4–7 分钟。项目使用单进程 Kotlin 编译和 5 GB Gradle 堆，建议构建机至少提供 8 GB 可用内存。
- 2026-08-11 基线完整执行 `testProdDebugUnitTest`：1613 项测试中 1584 项通过、29 项失败。失败项主要是内部重构期间遗留的源码结构断言和部分既有行为回归用例，公开整理没有把它们伪装为通过。
- 公开 CI 会编译全部主源码和测试源码、生成 `prodDebug` APK，并执行与开源边界直接相关的 SDK 隔离、SIP 自动租约、网络配置、首页配置和通话策略烟雾测试。
- CHAKEN 可信通信 SDK 及经授权公开分发的客户端 AppKey/Secret 已随仓库提供，直接构建即可执行服务初始化；阿里云商业身份认证 SDK 仍未分发，因此新建声音克隆的身份认证不可用。基础登录、任务、托管后台 AI 通话和记录功能不依赖该身份认证能力。
- 2026-08-11 对 `https://chaken-ai.vvtech.tech/aiassistant-api/` 的真机联调中，主要业务接口均返回成功；但当前发布的首页配置引用了 7 个不存在的图片资源，资源接口返回 404，客户端会显示本地兜底图。
- 同次联调中 Qwen TTS WebSocket 以关闭码 `1007` 结束，影响 Qwen 语音播报；登录、文本任务和其余已验证的 HTTP 接口不受影响。该问题需要在托管后台的 Qwen TTS 代理或供应商配置侧排查。
- 服务端不在本仓库中，第三方无法仅凭本仓库在本地复刻官方完整后台。

完整测试集的既有失败需要在后续客户端重构中逐项确认：区分已失效的源码形态断言、需要更新的测试夹具，以及真实行为回归。

## English

- The historical client source is large. A first full Kotlin build with JDK 11 takes roughly 4–7 minutes on the verification machine. The project uses in-process Kotlin compilation and a 5 GB Gradle heap; at least 8 GB of available build memory is recommended.
- Baseline result on 2026-08-11: `testProdDebugUnitTest` ran 1,613 tests; 1,584 passed and 29 failed. Most failures are stale source-shape assertions from internal refactoring and pre-existing behavior regression tests. The open-source preparation does not misrepresent them as passing.
- Public CI compiles all main and test source, builds the `prodDebug` APK, and runs smoke tests for proprietary-SDK isolation, backend-assigned SIP leases, network configuration, home configuration, and call policy.
- The CHAKEN trusted-call SDK and its client-scoped AppKey/Secret authorized for public distribution are bundled, so a direct build performs service initialization. Alibaba Cloud identity binaries remain excluded, so new voice-clone identity verification is unavailable. Base sign-in, tasks, hosted AI calls, and history do not depend on that identity-verification capability.
- During real-device testing against `https://chaken-ai.vvtech.tech/aiassistant-api/` on 2026-08-11, the main business APIs succeeded, but the published home configuration referenced seven missing image assets. Those asset requests return 404 and the client displays local fallback images.
- In the same test, the Qwen TTS WebSocket closed with code `1007`, which affects Qwen voice playback. Sign-in, text tasks, and the other verified HTTP APIs remain available. The hosted Qwen TTS proxy or provider configuration needs server-side investigation.
- The backend is outside this repository, so the official complete service cannot be reproduced locally from this source alone.

Future client refactoring should triage each full-suite failure into an obsolete source-shape assertion, a fixture that needs updating, or an actual behavior regression.
