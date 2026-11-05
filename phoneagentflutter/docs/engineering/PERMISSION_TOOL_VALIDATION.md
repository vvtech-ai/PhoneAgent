# 统一对话权限工具：实现与集中验收

更新：2026-09-22。范围为v65有效REQUEST_PERMISSION工具，不代表全部权限、定位数据或语音功能迁移完成。

## 完整App连续演练（09-22增量）

此前独立演练已有权限控制器，但完整App工作台缺少权限事件和隔离端口。本批只补`tool/previews`接线，正式权限规则、API及双端原生实现不变。

入口：[8122目录](http://127.0.0.1:8122/) → 首页→模型→任务→设置→积分→翻译 → 订餐厅 → 切文字。分别发送`演练权限允许`、`演练权限拒绝`、`演练权限设置`，应得到OK、DENIED、SETTINGS_REQUIRED，并可继续文字。关闭对话→任务→该对话，应保留结果、不重放权限申请。端口仅合成通讯录授权结果，不访问系统权限或联系人；这些短语仅是工作台测试指令，不是正式App新增功能。

新增[连续回归](../../test/shell_permission_workbench_test.dart)3项：320/430宽各覆盖三种结果、同session无额外用户回声、退出恢复不重复申请、续聊、账号代际重置；另测错误session和重复结果拒绝。禁止真实权限/安全存储通道的断言通过。直接调用方及相邻联系人/基础导航21项也通过，共24项定向验证，无全量回归；analyze无问题。

8122实际浏览器验证：从首页进入统一页，在同一会话依次获得三种结果，关闭→任务列表打开刚才的对话，三轮历史仍在且未再次显示权限检查；切文字发送补充后收到正常合成回复。结果和恢复续聊截图已在本轮查看，未见布局溢出；真实设备权限与后台收件仍待下方集中验收。

下方995项/构建记录属于09-18历史证据，不是本批执行结果；本批没有双端构建、安装或真实系统授权。Android增量27点按用户决定暂缓，不被本批Web验证替代。

## 行为证据

- Android固定4c781e3的AssistantRootSecondaryShellEffects在根页面接入FinalAgentPermissionEffect，统一页也有效；不是旧文本页的独占能力。
- AgentService支持microphone、contacts、location、document_picker，明确排除CALL_PHONE。AssistantAgentPermissionGrantPolicy将文档选择视为可用，定位精确/粗略任一授权即可；空androidPermission只检查，不弹申请。
- AgentStreamNormalActionEntryHandler及UserActionPolicy使用permission_result，appendUserEcho=false；ActionSubmitUseCase继续同一session的chat stream、voice channel，不是新接口或用户文字。
- iOS参考ddb996a的AILocationService使用WhenInUse；Assistant页面检索到的REQUEST_PERMISSION分支将进度推进到需求确认，未发现完整工具授权续接证据。因此使用平台系统API薄适配，不复制旧定位采集或敏感日志。

## 已实现位置和边界

| 部分 | 实现 | 边界 |
|---|---|---|
| 共享规则 | domain/tools/conversation_permission.dart | 嵌套/平铺协议、四项白名单、native标识核对、同tool一次、状态映射、permission_result命令 |
| 共享对话 | ConversationController、conversation_presentation_projection.dart | live申请后新command续流；旧done不影响新流；无用户回声；历史恢复不重放；退出/账号代际销毁丢弃晚到 |
| Flutter平台端口 | data/tools/device_permission_channel.dart | 只发送typed权限key和是否请求，不传任意Android权限；90秒超时不伪造拒绝结果 |
| Android薄适配 | PermissionChannel.kt、MainActivity注册 | 检查/申请录音、通讯录、前台定位；coarse/fine一起申请，任一满足；不加拨号/后台定位权限 |
| iOS薄适配 | PermissionChannel.swift、AppDelegate注册、Info.plist | CNContactStore授权、AVAudioSession录音授权、CLLocationManager WhenInUse；不录音、不读取联系人/坐标、不自动打开设置 |
| 隔离演练 | preview_permission_session.dart、permission_preview_page.dart | 与正式Controller/页面相同，只有平台与Agent端口是内存合成；不请求权限或HTTP、不改账号 |

文档选择仅代表系统选择器可用，不代表获得所有文件读取授权。iOS有限联系人授权视为可用范围，不声称全通讯录可读。真实系统弹窗不能由页面强制取消；页面退出后返回值会被忽略，不能回传到下一会话。原生请求繁忙时失败关闭，不以“授权成功”冒充结果。

平台资料：[Android前台定位权限](https://developer.android.com/develop/sensors-and-location/location/permissions/runtime)、[Android运行时授权](https://developer.android.com/training/permissions/requesting)、[Apple通讯录授权](https://developer.apple.com/documentation/contacts/accessing-the-contact-store)。保持Xcode15.2/iOS15.5基线，录音权限使用兼容AVAudioSession API；录放音实现仍是后续独立能力。

## 自动化与Web验证

新增23项：11共享契约/生命周期、4MethodChannel、5正式Controller流代际/恢复、3手机宽度连续Widget。验证允许、拒绝、需设置、继续输入、返回；错误session/无效标识不触发端口；旧流结束和退出晚到不重复提交。平台测试模拟MethodChannel回包，不能证明真实系统已授权。

Web入口：普通拨号输入既有开发序列20142014*#并点击拨号（仅本地解锁、清空号码、不拨号）→设置→开发者功能→进入隔离交互演练→统一对话权限演练。选择场景后切文字发送即可；允许/拒绝/需设置/已授权分别运行同一共享逻辑。演练后退回原页，真实账号/模型/权限不变。

最终995项全量测试、analyze、499文件格式、19项OpenSpec、Web/Android Debug/Mac iOS无签名构建通过。首次Android编译捕获MainActivity字段与permissions参数同名，改名permissionChannel；新增入口使旧320宽测试滚动后未等布局稳定，补pumpAndSettle，不移除原功能断言。

浏览器连续验证允许→OK、拒绝→DENIED、不可用→SETTINGS_REQUIRED，每次均收到演练续接回复并恢复输入；截图确认三轮消息和底部输入可见，无溢出报错。该证据只验证共用交互，真实系统权限与后台收件仍按下方清单验收。

## 集中真机/后台验收

前提：获得阶段安装授权，安装独立测试包，保持原安卓App、现有登录和测试环境；真实权限仅由用户操作，不通过脚本替用户同意。使用可控测试Agent触发工具，不用真实外呼任务探测。

1. **已授权**：触发联系人/麦克风/定位请求，系统不重复弹窗；同session发出一次permission_result，status=OK/granted=true，随后继续回复，无额外用户消息。
2. **首次允许/拒绝**：用户操作系统弹窗。允许为OK，拒绝为DENIED；拒绝也应继续Agent处理，不自动重试、打开设置或拨电话。
3. **定位近似/仅使用期间**：Android只给近似也为OK；iOS仅WhenInUse即可，不要求Always或精准定位。本动作不应采集/上报经纬度。
4. **受限/永久拒绝/设备限制**：不得伪装OK；无申请标识且未授权或Web不可用为SETTINGS_REQUIRED；系统拒绝为DENIED；系统异常/超时显示恢复提示，不伪造成用户拒绝。
5. **退出/切账号/重复工具**：弹窗期间退出，随后操作弹窗不得在新页提交；重复相同tool只一次；历史重入有pending标识但不自动弹权限。
6. **通话与隐私边界**：本动作不会录音、取坐标、读取或上传通讯录，不申请CALL_PHONE/后台定位。后续真正使用能力由相应业务端口单独验证。

排查关联当前sessionId/commandId/traceId与工具toolCallId，检查chat stream中actionId和状态；日志只保留白名单关联字段，不输出用户话语、令牌、联系人或坐标。`conversation_failure`的类型可区分平台异常与协议不匹配；后端收件必须查对应测试环境时间窗，不能只看App提示。

当前未进行新增设备安装、真实权限弹窗、后台收件验收；已解锁Mac签名会话保持不动，iOS无签名构建不等于真机安装成功。视觉差异沿用共享页面留统一校准。
