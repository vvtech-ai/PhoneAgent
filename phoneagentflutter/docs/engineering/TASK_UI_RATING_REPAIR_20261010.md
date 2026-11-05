# 任务录音、外呼 UI 与评分资格修复

## 基线与边界

本次在 `codex/refactor-conversation-task-flow` 实施；不向 `codex/dev` 推送。历史 Android `origin/test/v66.0.3` 为 a0bedb12，独立 App 最新 `origin/v71` 为 6309bc55。旧工作区只读，Java、数据库、部署未修改。

界面依据历史树中的 `android/app/src/main/java/com/vvtech/aiassistant/features/assistant_recording/PureVoiceCallRecordingRoute.kt`、`features/assistant_ui/AiCallAudioSourceSheet.kt`、`features/assistant_task_rating/TaskRatingRoute.kt`，评分请求对照独立 App 当前 `app/src/main/java/com/vvtech/aiassistant/features/assistant_task_rating/TaskRatingRoute.kt`。

## 客户端原因及修复

1. 保存结果原先留在录音卡下方，改为共用短暂通知；重新挂载不会重放通知，旧录音的迟到保存结果不能通知新录音。
2. 关闭按钮的 Tooltip 导致长按显示“关闭任务对话”，移除 Tooltip，保留无障碍语义与关闭事件。
3. 外呼三控件上方多渲染了一行监听状态，移除该文字。发声源弹层恢复原深色背景、标题、说明、单选圆及取消按钮。
4. 普通录音原先只有定时模拟柱形。改为 Android MediaPlayer/Visualizer 和 iOS AVPlayer/MTAudioProcessingTap 从实际播放源采样，沿用共享录音互斥和音频焦点。Dart 负责 24 柱、平滑、静音和异常采样降级；平台层负责播放器与采样生命周期。翻译录音端口不替换。
5. 没有录音的编排状态变化曾无条件取消首次语音引导。只在活动录音时取消；切文字模式隐藏。保留 v66 的设备首次规则：成功发送有效按住语音后才持久完成，已完成的设备不会每次进入重新显示；不重置手机偏好。
6. 评分资格的 `clientVersion` 写死 `1.0.0`，低于 v66 策略最低版本 `1.0.45`；独立 App 使用实际 VERSION_NAME。Flutter 改为等待 Android/iOS 已安装版本再请求，旧页面销毁后不继续请求，版本读取失败不伪造版本。用户指定本次版本 `1.0.51（45）`，评分参数为 `1.0.51`，包版本名无 foundation 后缀。

## 后端确认清单

SDK 请求为 `GET api/task-ratings/calls/{callId}?clientVersion=1.0.51` 或 `GET api/task-ratings/batches/{batchId}?clientVersion=1.0.51`；沿用 SDK 的 C1/Bearer，不经过 Agent/SSE。提交沿用 `POST api/task-ratings/eligibilities/{eligibilityId}/submissions`。未修改接口或强制显示资格。

如果更新后仍不显示，请后端同事按同一账号、同一 CALL/BATCH 锚点核对：

- 响应是否成功、eligible、eligibilityId、taskType、taskId、receiptAnchorType、receiptAnchorId 是否有效且一致。
- 任务终态、技能白名单、策略启用/紧急关闭、最低版本、日限额/七日限额；100% 仅覆盖抽样比例，不能绕过其余规则。
- 是否已有该任务资格快照及已提交状态；修改后台比例不等于重写历史资格。
- 开发域名实际部署提交、策略生效时间与历史任务资格语义。当前本地 Java 源码只能证明代码门禁，不能证明云端某次任务返回。

本次没有上传手机诊断、读取用户评分或发起真实外呼，因此不把客户端测试通过当作开发环境评分返回已确认。不要求后端为了 UI 合成录音、评分或积分。

## 验证与设备交付

固定 Flutter 3.32.0。首次 UI 用例先红，修复后 8 项通过；波形隔离 3 项通过。第一轮受影响 632 项通过。扩大回归 1513 通过、1 失败，失败是新端口构造时过早初始化原生事件订阅；改为首次 prepare 才订阅后，元数据提供器、实际波形宿主、迟到事件及安装版本 17 项复验通过。首次引导正式 provider、原偏好与双平台尖角 15 项通过。最终全仓 analyze 无问题；最后新增测试和直接调用方分析也无问题。OpenSpec 67 通过/0 失败。单路/批量资格的 Android/iOS 共享宿主验证安装版本与资格卡，不等于 iOS 原生编译。源代码/测试按最多三个文件微批实施，格式化单独执行。

一次 analyze 未加 no-pub 触发重新解析，改变锁文件源和四个间接依赖版本，已仅恢复本次产生的 pubspec.lock 变更；使用原镜像 `pub get --offline --enforce-lockfile` 成功。最后分析、测试与构建均使用原锁定依赖，锁文件无差异。

最终 Android main 云端开发包 29.0 秒构建成功。包 `com.vvtech.aiassistant.dev`、名称 PhoneAgent Dev、版本 1.0.51/45；私有 C1 define 及三服务地址由原构建脚本检查，未输出或提交凭据。APK 备份为忽略目录下 `D:/work/04phoneAgent/_isolated/phone-local-runtime/task-ui-rating-20261010-v45.apk`，SHA256 `DF2A860A0F8EE5C96CB8CB8A3D845A12DA83D7B5CE8B96F488BF8CC5C3982B20`。

14:40:41 `adb install -r` 成功，首次安装时间保持本次操作前的 2026-10-10 12:36:18。启动后当前首页显示 QwenOmniPlus、首页/任务 tab，无登录拦截或首页配置/模型失败文字。未点击真实任务、发送消息、申请短信或外呼，不把该启动证据写成评分/录音/监听已验收。

PMReport 1.5.0 registry 未登记 phoneagentflutter/aiassistant-app/aiassistant-java，本批不推测映射到旧 aiassistant；旧仓库只读对照按 reporting-rules 的探索例外不作进度上报。

全量 `flutter test --no-pub --concurrency 8` 的实际结果为 **4372 通过、1 既有跳过、8 失败**，耗时 15:28。六项非环境失败已逐项复验，不能把原始全量改写成无失败：

- 三种宽度首页导航仍要求已移除的正常页 MOCK 按钮，改旧断言后 3 项通过。
- 任务时间仍要求“周二”，实际 v66 `TaskDisplayTimePolicy.kt:168` 及已合入 22b7b2eb 均为“星期二”，改旧断言后原生日期/页面/任务专项 16 项通过。
- 两种宽度完整回执流程在 post-frame 通知绘制前断言保存文字。临时布尔诊断证明 mounted/entry/TickerMode/当前路由都有效；初步怀疑路由过滤并移除判断的尝试无效，已经完整撤回，不留诊断代码。测试补一帧后完整回执/独立短通知/录音宿主 17 项通过，包含保存取消、保存成功、单路/多路评分、草稿恢复、退出和账号切换。最终客户端代码与已安装 APK 保持一致。

剩余两项是 `domestic_recording_cleanup_test.dart` 与 `domestic_recording_session_test.dart` 无法创建符号链接，Windows errno1314“客户端没有所需的特权”；不跳过、不修改翻译业务或扩大系统权限。需在有符号链接权限的 Windows 或原生目标环境重验。

暂存时一次错误覆盖 autocrlf 导致 CRLF 被当作整文件差异，已按仓库原设置 true 重新归一化暂存，最终差异只保留需求改动，UTF-8 与 staged diff --check 通过；工作区正文未重写。

Windows 没有 macOS/Xcode，iOS 原生文件已实现并接入 Runner，但编译与真机仍待验。真实录音下载/播放采样、后台中断、通话监听音源、服务端 100% 资格、生产升级均不得用合成测试替代。
