# 隐私与权限 / Privacy and Permissions

## 中文

应用仅应在功能需要时请求权限：

| 权限类别 | 典型用途 | 拒绝后的影响 |
| --- | --- | --- |
| 麦克风与音频 | 语音任务、通话、翻译 | 无法录入语音或进行相关通话 |
| 相机 | 获得授权后的身份认证 | 声音克隆认证不可用 |
| 联系人 | 选择电话联系人 | 仍可手工输入号码 |
| 电话与号码 | 拨号、SIM/可信来电辅助 | 对应电话能力受限 |
| 通话记录 | 展示设备通话历史 | 仅显示后台记录或无设备记录 |
| 定位 | 地点相关任务和地图搜索 | 需要手工描述地点 |
| 悬浮窗 | 部分通话辅助界面 | 不显示悬浮控制 |
| 安装应用 | 用户确认后的 OTA 安装 | 只能手工更新 |

用户应避免在任务、通话或日志中提供与任务无关的身份证号、银行卡、密码、验证码、健康信息等敏感数据。日志上报应由用户主动触发，发布或提交 Issue 前必须脱敏。

电话外呼、录音、翻译、身份认证和声音克隆必须遵守所在地法律、运营商规则及供应商条款，并在需要时取得通话参与者的明确同意。

## English

Permissions should be requested only when the selected feature needs them:

| Permission group | Typical purpose | If denied |
| --- | --- | --- |
| Microphone and audio | Voice tasks, calls, translation | Voice input and related calls are unavailable |
| Camera | Authorized identity verification | Voice-clone verification is unavailable |
| Contacts | Contact selection | Numbers can still be entered manually |
| Phone and phone numbers | Dialing, SIM, trusted-call assistance | Related phone features are limited |
| Call log | Device call history | Only backend history, or no device history, is shown |
| Location | Location-aware tasks and map search | Location must be described manually |
| Overlay | Optional call controls | Floating controls are unavailable |
| Package install | User-confirmed OTA install | Updates must be installed manually |

Do not provide unrelated identity numbers, payment data, passwords, verification codes, health data, or other sensitive information in tasks, calls, or logs. Log upload must be user initiated, and logs must be redacted before publication or inclusion in an issue.

Outbound calls, recordings, translation, identity verification, and voice cloning must follow applicable law, carrier rules, and vendor terms, including explicit participant consent where required.
