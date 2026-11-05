## 基线与职责
- 检出：test_v1.8.0_fix / d678e713；开始实施时工作区干净。不切换分支，不触碰其他任务。
- 入口：声音克隆新认证采集、失败重新开始、取消后重新进入。
- 状态 owner：iOS 原生进程独立持有 SDK 初始化标记；captureOwner、session、meta、certifyId 和账号隔离继续由既有实现负责。
- 证据：当前 prepare 每次新会话调用 initSDK；上传日志去重后记录 15 次 init 进入/返回。AIAssistant 的 ensureFacadeClass 通过 prepared 复用初始化，fetchMetaInfo 仍逐次执行。

## 决策
- 使用仅主线程调用的进程级初始化保护；不更换调用线程，不在启动/注册时初始化，不保存认证信息。
- initializer 正常返回后才置标记；异常原样传播至插件既有 catch，不以 dispatch_once 消耗失败机会，也不承诺恢复进程崩溃。
- 初始化诊断进入/返回事件仅在实际 initSDK 调用时发出；MetaInfo 诊断每个新会话继续记录。没有新增诊断字段或采集器变化。
- reset/abort、账号变化、插件销毁重建不清除初始化标记；新的 App 进程自然重新初始化。不新增媒体服务重置后的特殊策略。
- 不缓存跨会话 MetaInfo；原方法通道、HTTP 字段、SDK extParams、返回判定、音频配置/租约与关闭顺序保持原样。

## 文件与验证范围
- IdentityCaptureSDKInitialization.h/.m：无 SDK/音频依赖的初始化保护，不提供 reset。
- IdentityCapturePlugin.m：仅包裹现有 initSDK 及其前后诊断；保持其余流程。
- tool/voice_clone：原生回归验证失败重试、多调用方复用、后续业务失败不撤销标记、新进程重新初始化。
- 现有 Dart 定向回归验证会话/参数、取消/释放与克隆流程；iOS 编译验证新源文件真实链接。
- 关联连续回放：VOICE-01/03 的采集与播放交接边界；不改变其播报规则，其他任务编排入口不受影响。本次新增 IOS-INIT-01～05，见 verification.md。
- 真机正常认证/失败重试/取消、试听与其他音频交接，以及诊断共存与重启报告须取得实际证据；自动测试不替代，未验收不归档。不得为回归自动使用个人身份或触发收费克隆。
