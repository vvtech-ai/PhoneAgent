# 双端共享页面扩展阶段（2026-09-20）

代码基点 `83003f3` 加本批共享测试、诊断/启动更新演练隔离。正式 `lib/` 与原生实现没有改动。**本报告是阶段检查，不是迁移完成或真实外部能力验收。**

## Preconditions

- Flutter 3.32.0/Dart 3.8.0；Android OCE-AN10，独立 `com.vvtech.aiassistant.dev`；iPhone iOS 16.7.16，`com.chaken.phoneagent.test`，Xcode 15.2。
- 同一 `integration_test/shared_stage_test.dart`，扩展步骤位于 `extended_stage_pages.dart`。Windows/Mac 的上述两文件和三个相关 tool 文件最终 SHA-256 逐一相同。
- 复用正式 App/页面/控制器，外部端口为明确 MOCK。没有真实短信、电话、相机、录音、积分发放。视觉精校按用户要求后置。
- Android 本轮开始即未登录；此前登录丢失事故见[历史报告](SHARED_DEVICE_STAGE_20260920.md)。本轮不重新发送验证码，不把内存登录当真实账号恢复。

## Build / Install

- 构建、`adb install -r`、启动与驱动分开；只通过 `tool/run_shared_stage.dart` 附加已运行的 VM，固定 `--use-existing-app` 与 `--keep-app-running`。失败和成功结束均观察到 `Leaving the application running.`，包未被卸载。
- 最后一次测试入口构建 Android 9.7 秒、iOS 21.1 秒；iOS 安装启动 45.3 秒。后续纯 Dart 修复使用热重启，最终通过所对应源码已再次核对哈希，不把最初二进制当最终源码证据。
- 最终自动流程 Android 67 秒、iOS 64 秒；各 21 张 PNG、22 个完成步骤、`agentCommands=2`、`nativeStorageCalls=0`、`completed=true`。结果 UTC 时间分别为 13:35:02 和 13:34:59。
- 原始结果/图片保留在本机 `.local/shared-stage/android/` 和 `.local/shared-stage/ios/`，不提交临时产物或调试认证 URL。
- Android 恢复普通 `lib/main.dart` 测试环境包，构建 7.3 秒、`install -r` 成功；UID 10496、firstInstallTime `2026-09-20 16:56:07` 始终不变。普通入口登录状态另行核对，不由这些数字推导登录成功。
- iOS 普通入口恢复记录见下方；沿用解锁 screen，不重置钥匙串、不重新登录 Apple ID。

### 普通包复核

Android 21:36:35 保留数据覆盖后启动普通入口，UI 层级确认为“登录 / 注册”、无 MOCK 目录，仍需一次真实登录恢复。恢复普通包并启动后再次检查，两份加密偏好摘要仍与本次安全复核前相同。

iOS 普通 `lib/main.dart` 构建 23.4 秒、严格签名校验通过、安装启动 46.5 秒；实时 `getVM` 返回 `ios`、`main`、PID 16013。screen 已安全分离，进程保留。不据此声称已登录 iOS 或已通过真实服务验证。

## User Actions / 自动执行路径

| 截图 | 页面/操作 | 核心断言 |
|---|---|---|
| 01–11 | 首页、模型、默认语音切文字、候选、任务恢复、两条翻译历史、保存取消、设置与原音 | 恢复不重发；新选择仅追加一次；不同历史字幕不串；取消不显示保存成功；原音内存值返回后保留 |
| 12–13 | 联系人备注、另一联系人、拨号回填与美国区号 | 备注不串人；系统拨号端口调用 0 次 |
| 14–16 | 单路回执赞、四维评分、首次失败/显式重试、恢复只读 | 重试沿用同一提交身份；成功后无提交按钮；样例奖励不修改真实钱包 |
| 17 | 批量回执展开 | 对应字幕可见；无 eligible 评分入口，不进入单路通话页 |
| 18–20 | 身份、Qwen 合成认证/候选、保存与默认克隆音色 | 只更新场景内资产；返回音色页“已使用克隆音色”可见；没有真实 SDK/声音/文件 |
| 21 | 首页钱包、积分流水、返回 | 合成流水存在；原首页滚动位置不阻断钱包入口 |

新增十个状态的双端截图已检查可读性、可达区域和结构。Android 字体更粗、MOCK 横幅换成两行，iOS 横幅一行；两端列表/长评分表滚动位置不同。评分草稿截图为表单下部，录音/批量截图也不是整条长内容截图；不能据此宣称所有内容像素一致。未发现本次查看区域的横向溢出或操作区被固定控件遮挡。顶部 MOCK 工具栏占用高度，不是普通 App 全屏视觉基准。

系统键盘没有验收：`tester.enterText` 后显式收起输入，不能代替真实 IME、键盘安全区和系统返回测试。

## 数据核对与本轮实际修复

1. 最初扩展步骤搜索钱包时向下滚动，但首页保留了之前的下方位置。两端均失败；改为先回到首页顶部。两宽 VM 预检主动保留低位滚动，覆盖同一前置状态，不修改产品导航。
2. 第一轮页面通过后，Android 加密偏好文件变大，不能称为无损。最小失败回归捕获正式 `diagnosticJournalProvider` 的 read/write；其退出 flush 在演练作用域写入诊断。仅在 tool 宿主替换成按登录代次隔离的内存 `DiagnosticJournal`，正式诊断不变，也不删除设备既有日志或凭据。
3. 真机零存储断言继续查出 Android `phoneagent.ota-startup.v1.*` 读取。桌面预检因为设备信息通道不可用，未走到存储。演练现在复用正式启动控制器及内存“当天已检查”记录，不停用正式 OTA；更新提示/安装仍由独立 OTA 场景验证，本次不包含它们。
4. VM 和真机增加存储通道防护：意外调用先被截断，**仍使测试失败**，不是返回空值就算通过。最终两端调用次数 0；Android 在修复后的完整执行前后，两份加密偏好 SHA-256 均相同。密钥文件也保持原值。旧失败结果不能追改为成功。
5. 这证明本次既有文件保持不变、驱动不卸载及该流程未调用安全存储，**不证明原来丢失的登录已恢复，也不是整个数据目录的完整性证明**。

## Expected Logs

- 驱动最终 `All tests passed.`、`Leaving the application running.`，结果 JSON `completed=true`、`nativeStorageCalls=0`、`agentCommands=2`。
- 普通包恢复 `install -r` 为 `Success`；iOS 普通启动出现 VM 服务并通过 `getVM` 返回 `ios` / `main`。
- MOCK 的 `CALL_MONITOR_STATE ... phase=off` 只是页面状态，不是监听取票、外呼或声音通过。

## Forbidden Logs

- `MOCK must not access device storage`、测试 `[E]`、未处理 Flutter 异常、`RenderFlex overflow`。
- 目标包 `FATAL EXCEPTION` / `ANR in` / iOS crash；不得把普通 AudioManager 查询或 Flutter 工具自身重连异常当目标 App 崩溃。
- 安装失败后卸载重试、firstInstallTime 改变、真实短信/外呼/采集、凭据或真实资料写入日志。

## Pass Criteria

页面步骤和隔离断言双端通过、截图实际查看、设备包保留、普通包恢复必须分别记录；不能只看测试退出码。最终 VM 定向 13 条约 7 秒通过，analyze 无问题；没有运行数千条全量回归。OpenSpec 26 项、179 个本地文档链接及 diff 校验通过。

Web 8122 仅重启该演练服务并重编译 12.6 秒，实际浏览器刷新后进入完整 App 首页、返回目录成功，error 日志为空；没有重跑所有浏览器流程，也未触碰 8080 真实账号。

## Failure Follow-up

- 有存储调用先保留失败证据并定位缺失 override，不放宽零调用断言、不读取/输出凭据正文。
- 出现页面断言失败先复用 VM 同一函数定位；两轮无新证据停止盲重试。热重启修复后重新执行同一驱动，不因为观察超时重装。
- 外部能力、全页面覆盖、初始化决策、正式 OTA/旧状态与日志实现缺口继续见[集中交接主清单](MIGRATION_HANDOFF.md)。本阶段没有替代这些工作。
