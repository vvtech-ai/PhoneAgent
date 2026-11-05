## Context
日志显示 2026-10-19 11:38:28 上传结果未知，11:38:40 旧槽位 READY 被对账标为成功并扣 400 积分；槽位有其他账号历史。候选与确认后资产 ID 一致。iOS 已下载 WAV，但 prepare 报 NSOSStatusErrorDomain/561017449。

## Decisions
- 对齐原生 VoiceCloneEnrollmentReducer.resetVerificationWithError：保留本次表单、授权和模型，清除旧 attempt/certify/候选控制器。失败提示在身份表单内；处理中/未知不变成可重提。
- 身份只保留在当前页面内存，退出、账号切换或主动身份重置清除。两端共用 Dart 展示及恢复规则。
- iOS 播放前由独立平台适配器在媒体租约下准备 playback/default/mixWithOthers；不在初始化时改变会话，不抢占系统通话，不恢复陈旧快照。
- Seeduplex 使用独立训练证据模块，保存 candidate/model/speaker 与提交前版本。版本未变化、缺失、回退或无法确认时保持未知，禁止成功扣费、确认或播放。新槽位需明确基线及新训练结果；供应商协议字段需用文档和测试明确。
- 旧记录没有训练证据且存在其他账号槽位历史时阻止继续作为可用克隆；不自动重训或退款。生成事实与安全证据分开，接口结构保持兼容。
- 控制器只接线，新增恢复规则/平台会话/训练证据各自独立，不扩大已有大文件职责。分批最多三个手写源码文件。
- Java审查后将共享纯训练规则放入common，由SDK/SSE各自Mapper适配，覆盖旧设置、激活和默认/显式通话；不会只隐藏目录却继续使用异常音色。裸状态查询保留库存含义，新训练对账必须携带完整候选。

## Validation
先复现失败，再改实现。验证 Android/iOS 同流程保留表单、错误位置、取消/重试/异步迟到/账号切换；iOS 会话前置与取消；旧版本 READY、上传未知、新版本成功、历史槽位串音及计费保护。执行 Flutter 定向测试/analyze、Java SDK 定向测试、OpenSpec。Windows 不代替 iOS Xcode/实机验收，迁移及真实供应商结果单独记录。
