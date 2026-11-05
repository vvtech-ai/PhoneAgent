# Android登录复用、真实文字与确认卡阶段

2026-09-21 14:36–14:46 CST，源码基点`34529a0`。本轮无业务代码修改，不是全项目完成报告。

## Preconditions

- OCE-AN10真机、Flutter3.32.0、独立Dev包`com.vvtech.aiassistant.dev`，测试环境；不操作原安卓正式包。
- 上轮14:26截图是登录页；本轮开始只读UI已是首页。中间状态变化原因未取证，不推断自动登录或人工操作。**本轮强制结束进程后冷启动仍回首页**，因此当前会话可复用，没有发送验证码、读取凭据或要求用户再登录。
- 真实业务冒烟仅创建一个明确不搜索、不外呼的文字测试会话。其余确认卡步骤为隔离MOCK，不发送真实电话、音频、身份或日志上传。

## Build / Install

- 普通包沿上一轮构建的main产物；先留存本机APK用于恢复，它不作为账号数据备份。
- confirmation测试目标Android Debug构建15.9秒；显式`adb install -r`返回Success，启动后用现有`tool/run_shared_stage.dart`附加VM，`STAGE_GROUP=confirmation`，不让drive安装或卸载。
- 9项定向预检通过：4个双尺寸/双平台样式流程和5项安全驱动测试；未重复全量测试或analyze（源码未改）。
- 测试完成后恢复留存的普通main APK，覆盖Success、冷启动Status: ok；更新时间14:45:10。UID10496、首次安装09-20 16:56:07保持不变。

## User Actions / 已自动执行

### 真实普通App

1. 冷启动自动进入首页，模型Seeduplex、真实动态入口可见。
2. 订餐厅→统一页默认语音→切文字，发送明确禁止搜索/外呼的英文回归说明，收到`ANDROID_TEXT_OK`。
3. 关闭→任务列表→本轮新任务，原消息与回复恢复；默认语音，切文字续聊得到`ANDROID_RESTORE_OK`。
4. 完成下方MOCK设备阶段并恢复普通包后，无验证码自动回首页；再次打开本轮任务，两条回复各出现一次、默认语音、无第三次提交。

本机截图位于`.local/android-normal-restored/`：`home-after-restart.png`、`first-reply.png`、`restored-reply.png`、`final-history.png`。首页与最终历史截图已查看。测试消息留在测试账号便于核对，不自动删除。

### 确认卡六点（与iOS同一共享脚本）

| 检查点 | Android结果 |
|---|---|
| 53普通确认 | 合成挂断返回确认卡，100/10费率可见 |
| 54换模型恢复 | 当前模型Seeduplex，历史仍100/10，没有新增确认命令 |
| 55扩展确认 | 任务/补充信息、联系人6/5/1统计及缺号问题可见 |
| 56展开收起 | 第五人和收起入口可见；收起后恢复默认四人 |
| 57待确认恢复 | 原Pending身份、计费提示保留，无重复提交 |
| 58确认后恢复 | 原卡为已确认，无第二张普通卡、无单路页，只有原两次命令 |

14:44完成，驱动约32秒，`completed=true`、`forbiddenNativeCalls=0`；六张1080×2256图片已逐张查看。结果和图片位于`.local/shared-stage/confirmation/android/`。

对照[iOS同组](IOS_CONFIRMATION_STAGE_20260921.md)六点结果，并重新查看iOS的55/58图；`5630830..34529a0`的业务/原生/本组测试源码无差异。两端结构、状态和交互相同，Android字重更粗、MOCK栏换两行、视口与滚动位置不同。卡片可滚动、底部模式/输入保持可达；不声称像素一致，也不将MOCK计费或内存恢复当真实后台/生产升级通过。

## Expected Logs / Forbidden Logs

- 驱动实际输出`All tests passed.`及`Leaving the application running.`，安装两次均Success。
- 真正普通进程的`AndroidRuntime:E / flutter:E`过滤未返回错误；此有限过滤不是整机无错误的证明。
- 不允许卸载回退、首次安装时间改变、跨账号存储访问、真实短信/外呼，或Flutter未处理异常/布局overflow。

## Pass Criteria

本阶段已满足：真实登录冷启动复用、两轮文字与退出恢复、确认卡六点、普通包恢复后登录和历史保留。MOCK前后`FlutterSecureKeyStorage.xml`及`FlutterSecureStorage.xml`各自SHA256相同，且原生禁止调用为0；未读取/输出文件正文。该证据不扩展为全目录数据迁移证明。

## Failure Follow-up / 剩余

未发现需修改业务代码的问题。后续继续补Android其他已完成Web/iOS的阶段缺口；真实声音、权限、SDK、后台收件和正式OTA按[集中清单](MIGRATION_HANDOFF.md)分别验收，不能再以安卓未登录为阻塞，也不因为本阶段通过而声明整个迁移完成。
