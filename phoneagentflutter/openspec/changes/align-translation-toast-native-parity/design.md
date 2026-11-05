# Design
原生基线为 aiassistant_app 8f23592：CallFailureKind.kt、CallFailureUserMessagePolicy.kt、AssistantCallsDialSheet.kt、AssistantRootCallEntryActions.kt、TranslationCallLauncher.kt 与 PointsAwareTranslationCallGateway.kt。

共用入口 lib/core/design/native_notice.dart 不改外观。拨号动作直接发 Toast；输入限制在翻译拨号 host 接收控制器事件时发 Toast，不修改其他普通拨号调用方。路由终态在 root Overlay 发一次 Toast 后退出；失败字符串保留用于开发演练/非拨号调用方，但正式拨号页不再重复展示。正常结束不发失败或兜底结束 Toast；保留远端已批准、服务端确认结算金额的扣分 Toast。

纯 Dart 错误策略映射 SIP REGISTER/INVITE 状态：5xx 服务不可用、486/600 忙线、408/480 暂不可达；明确的网络失败映射 NETWORK，其余 UNKNOWN。后端错误码使用同类分类。诊断继续保留原阶段/错误码，不输出后台任意正文。

清理异常保留 cleanupUnconfirmed 和诊断；不覆盖已经确认的忙线等主错误。仅清理不确定也按失败呈现原生未知失败提示；不新增账单、扣费成功提示、重试呼叫。原生账单细节不属于本次 UI 范围。

验证为 OpenSpec、Flutter analyze、策略和国内/海外协调器定向测试、共用 Toast 与跨页流程测试。重点覆盖终态只发一次、正常无提示、二次尝试可再提示、输入和配置保留。每批最多三个手写源码文件；未验收不归档。

## 用户可见文案
| 触发条件 | 共用 Toast |
| --- | --- |
| 中国号码无效 | 请输入正确的手机号码 |
| 没有可用模型 | 当前没有可用的实时翻译模型 |
| 主叫位置未确认 | 主叫所在国家尚未确认 |
| 麦克风未授权 | 请授予麦克风权限后再使用实时翻译通话 |
| 国内供应商限制 | App SIP 实时翻译仅支持千问或豆包 |
| 积分准入拒绝 | 积分不足，无法发起通话 |
| 积分服务不可用 | 积分服务暂不可用，请稍后重试 |
| SIP 5xx / SERVICE_UNAVAILABLE | 暂时无法接通，请稍后重试 |
| SIP 486/600 / BUSY | 对方正在通话中 |
| SIP 408/480 / TEMPORARILY_UNAVAILABLE | 对方暂时无法接通 |
| 明确网络错误 | 网络连接异常，请检查网络后重试 |
| 未知失败或仅清理未确认 | 通话未接通，请稍后重试 |

号码14位限制、三种模型语种校验、模型路由缺失等原文保持。Flutter独有的环境不可用提示保留原文并改共用Toast；位置/通话环境状态标签、录音/历史同步重试、权限业务弹窗不属于瞬时提示替换，不移除对应功能。
