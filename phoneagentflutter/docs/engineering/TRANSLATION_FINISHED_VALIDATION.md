# 翻译结束、本机记录与服务端归档：实现及集中验收

## 2026-09-21 增量：v65旧待归档队列导入

同生产Android包及精确prod API下，首次新队列缺失时读取当前账号v65待办，将有效WORLD_CALL原ID/时间/字幕/locator先写安全存储，再交既有恢复和幂等PUT。新队列包括空值优先、失败不覆盖、登录换代保护，国内/已完成/未接通不导入，旧文件不删。12新增/29相关Dart、4JVM、analyze和Android Debug通过；不是实际同签名升级或后台收件验收。实现分工、边界及集中操作见[旧归档兼容专项](LEGACY_TRANSLATION_ARCHIVE_VALIDATION.md)。

## 2026-09-20 增量：国外持久归档

### 实现与边界

固定 Android v65 `4c781e3` 的 `RealtimeTranslationArchivePolicy/Coordinator/Runtime`、`PhoneAgentRealtimeTranslationApi`、`RealtimeTranslationHistoryRepository`：只迁移 WORLD_CALL，不带国内 PCM 录音上传或 SIP 计费。iOS 与 Android 共用下列 Dart 实现，仅安全存储复用既有双端插件。

| 位置 | 责任 |
|---|---|
| `translation/domain/translation_archive.dart` | 接通证明、不可变快照、已有字幕收尾和进程恢复规则 |
| `translation/data/translation_archive_codec.dart` | 版本/账号/作用域验证；仅必要 locator、时间和字幕，不存 LiveKit token/媒体 URL |
| `translation/data/secure_translation_archive_store.dart` | 环境/API/账号隔离的系统安全存储；同作用域串行，坏格式不覆盖，旧登录晚到不写新账号 |
| `translation/data/api_translation_archive_gateway.dart` | 原账号 `PUT api/realtime-translation-calls/{clientCallId}`；WORLD_CALL、UTC 时间、字幕、cluster/session/grant；有效 callId/created 才算成功 |
| `translation/presentation/controller/translation_archive_controller.dart` | 账号级持久待办、500ms 封口、失败显式重试、恢复与去重，不执行拨号/挂断/扣费 |
| `TranslationSessionController → TranslationSessionFactory` | 创建、locator、接通、字幕、观察时间、结束快照统一提交；归档不阻塞媒体释放或页面返回 |
| `app/translation_archive_providers.dart`、`ShellRoute` | 登录后的待办恢复；token 刷新保持同实例，换登录销毁旧实例；归档成功使任务列表失效刷新 |
| `TranslationArchiveStatusView`、既有拨号页 | 与本机保存分开的同步失败/重试提示，不伪装已经归档 |

未接通的待办不提交；进程退出后的已接通待办按最后观察时间封口，不以重新启动时间延长通话。结束时间至少为接通时间加 1ms。500ms 窗口仅用于排队中的已有字幕，不保活麦克风，不允许新增尾部段。持久归档失败不取消已结束通话；服务器成功但本机删除待办失败，重试沿相同 clientCallId 幂等 PUT。

存储失败时保留当前内存并显示失败，但未成功写盘的最新部分不能承诺跨进程恢复；不会覆盖损坏/未知版本数据。保存中的授权 grant 和字幕不得输出到日志、Git 或普通配置文件。现有 AccountApi 只记录请求结果/状态码；定位真实归档需后台按测试时间窗及 clientCallId/callId 交叉查验，不把无敏感正文的 App 诊断当作完整后端证据。

### 自动与浏览器验证

最终工作区全量2015项、OpenSpec19项通过。全量包含未提交原生在制部分的3项方法通道测试；Android构建也基于当前工作区，未交付或安装该产物，不能据此声明独立iOS原生草稿已验证。

新增17项：控制器/生命周期10、codec/安全存储/HTTP5、正式provider恢复与账号代次1、同页失败重试1。覆盖未接通丢弃、进程恢复、只补已有字幕、冻结final、持久失败、幂等重试、旧账号晚到和返回后同步。终态快照先于Finished回调捕获，避免同步销毁页面丢失结束；存储初次读取失败时仍保留内存封口/未接通丢弃状态，显式重试先持久化再归档。后一边界先最小失败测试复现，再修复，10项控制器回归通过；不代替真机存储验证。现有准入回归补有界滚动以适配新增演练项，没有移除断言或改变产品门禁。

Web 构建31.6秒、Android Debug构建9.8秒、analyze与913文件格式检查通过；本批不安装设备。Web仍有既有Cupertino字体族构建提示，字体/视觉需集中核对，不作为视觉验收通过。浏览器 `http://127.0.0.1:8119/`：模拟US → 开启配置流程/归档失败 → 共享会话就绪/接通/字幕/挂断 → 原配置 → 摘要显示本机1条、归档0条/请求1次 → 解除故障/重试 → 本机仍1条、归档1条/请求2次。媒体、HTTP和存储均为显式内存替身；共享工厂、协调器、codec和状态组件不是替身。

### 集中人工验收（待真实媒体总装配与阶段安装）

1. 测试环境、已登录账号、授权测试通话：接通后结束，返回配置不等待归档；稍后任务列表新增一条国外翻译记录，进入已有历史详情核对号码、语言、接通时间与双语字幕。
2. 未接通取消：本机拨号记录与服务端翻译归档分开判断，禁止仅凭振铃/merchant started创建服务端已接通归档。
3. 归档服务断网/失败：显示“翻译历史同步未完成”；恢复后显式重试只发生相同clientCallId的PUT，禁止再create、merchant-call、hangup或扣费。
4. 杀进程后恢复：未接通待办丢弃；已接通待办使用lastObserved时间；恢复或重复结束不能产生两条服务器记录。不得为了验证而终止未经授权的真实通话。
5. A账号留失败待办→切B：B不上传A的记录；重新登录A才恢复A。token刷新不丢失当前待办。后台按归属账号、clientCallId/callId与时间窗查证。
6. Android/iOS锁屏/存储写入失败：不假报成功、不覆盖旧待办；解锁后仅重试同步。长通话字幕体量、进程中断与系统安全存储需真机验证。
7. 归档成功不弹国内结算、不本地修改余额；录音后续由历史页既有WORLD_CALL授权读取，不上传本机PCM。

Mac SSH本轮超时，iOS未重新编译；双工原生草稿仍独立在制。本增量完成共享归档接线，不等于真实媒体总装配、服务端收件、钱包权威结算或双端真机验收完成。原8080登录/保留Mac会话未变，未发短信或真实归档请求，视觉继续统一后置。

## 2026-09-20 增量：拨号配置到同一会话

- `TranslationDialRequest` 固定确认后的号码、名称、国家、语言、模型与服务节点；组合方提供原音快照，沿用现有 create 请求，不自动发送分机按键。
- `TranslationDialSessionBinding` 让既有拨号按钮进入 `TranslationSessionRoute`，结束回到原配置。未注入完整端口仍明确阻断真实翻译呼叫，不回退普通电话。
- 现有准入演练增加显式开关，复用同一入口、工厂、结束记录器；仅外部服务、媒体、存储合成。没有新增另一套业务页面或真实外呼。
- 固定 v65 `PointsAwareTranslationCallGateway.start` 只包装 LocalSipDomestic/LocalSipInternational，BackendWebRtc 直接委托。因此不应把国内 usage-session 心跳/授权/结算搬到国外链路。钱包更新只能来自实际 settlement，服务端归档仍独立待办；下面历史批次中的“积分准入”描述不代表已确认的海外前置条件。
- 新增 9 项回归：参数/原音/校验/记录 4 项，三宽度页面、地区拦截、取消确认 5 项；全量工作区 1998 项与 analyze、OpenSpec 19 项通过。全量包含未提交原生在制部分的 3 项方法通道测试，不能当作 iOS 验证。
- Web 构建 27.3 秒、Android Debug 构建 9.9 秒通过（仅构建，未安装）。浏览器 `http://127.0.0.1:8118/` 验证 US → 开启配置流程/原音 → 法语 → 就绪/振铃/接通/字幕 → 挂断 → 原配置 → 记录 1 条、`GEMINI / DEFAULT / zh→fr`。原 8080 登录保持不变。
- 测试等待按状态节点推进；持续加载页面不使用无限静止等待，避免测试虚拟时钟误触媒体超时。320/390/430 宽度均通过，视觉没有标记验收。
- Mac SSH 当前不可用，本增量未做 iOS 编译或双端安装；原生双工在制部分不纳入共享批次。真实媒体工厂、远端归档、设备验证及最终视觉继续待办。

2026-09-19，overseas-translation-ui 2.2d。沿用现有页面和组件，视觉统一校准后置。本批不发真实电话、媒体、归档、计费、短信或账号写入请求，不改变原登录或 Mac 保留会话；没有新设备安装。

## 源码依据与范围

固定 Android v65 `4c781e3ccfcd148c1f205921534907ee0c5aa864`：

- `AssistantCallRuntimeControllers` 消费 `TranslationCallEffect.Finished`，写入本账号拨号历史、按实际 settlement 通知钱包，再返回拨号界面。
- `AssistantClientCallRecordPolicy.buildTranslationDialHistoryRecord` 使用 clientCallId、开始时间、目标名称/号码、国家及双方语言。Flutter 本机仓库目前仅迁移拨号元数据，不存字幕、音频、grant 或余额。
- `RealtimeTranslationArchiveRuntime/Coordinator/Policy` 是另一条独立链路：实际接通证明、500ms 字幕收尾、持久待归档记录、WORLD_CALL 定位及幂等 PUT。积分也需要真实结算事实。**本机记录不代表服务端归档或结算成功。**

生产拨号入口仍保留明确未接入提示：AppAudio、准入/计费及整体装配尚未齐备。本批提供可复用正式工厂/provider及保存状态接线，不声称已可真实拨打翻译电话。

## 共享数据路径

| 组件 | 责任 |
|---|---|
| `TranslationCallContext` | 每次会话生成独立本机 ID，固定目标名称、国家 |
| `TranslationSessionController` | 保留首次开始/接通时间；终态导航前仅通知一次 Finished；销毁不伪造结束 |
| `TranslationCallFinished.record` | 映射本机拨号元数据，无远端成功推断 |
| `TranslationSessionFactory` | 检查原账号仍有效，注入账号级记录器；不替代权限/位置/积分准入 |
| `translationFinishedRecorderProvider` | 非 autoDispose，通话页返回不取消保存；登录变更重建，token 刷新不重建 |
| `TranslationFinishedRecorder.accept/retry` | 串行保存、去重、显式失败状态；重试只 append 本机仓库，不重新拨号或挂断 |
| `SecureAppCallRecordRepository` | 复用环境/API/账号隔离、写入前后有效性检查及 ID 去重 |
| `AppDialRecentSource → DialRecentController` | 监听仓库变化，自动刷新同一最近记录列表 |
| `TranslationRecordSaveStatus` | 正式拨号页与演练共用保存中/失败重试提示 |

记录器仅在当前账号生命周期保留失败待重试元数据；进程退出未保存内容不保证恢复。已保存记录由既有安全仓库恢复。远端持久待归档机制另行实现，不能用内存失败队列替代。

## 自动验证

- 新增18项：记录器7、会话/工厂6、正式provider1、同页交互4。覆盖重复结束、写入中重试、失败后不自动重试、同步回调新增记录不丢、切账号/晚到/销毁、token刷新/容器恢复、320/390/430宽度及保存重试不增加 create/hangup。
- 全量1946项、analyze、903文件格式、19项OpenSpec通过。Web35.3秒、Android Debug10.8秒、Mac iOS Debug无签名15.5秒构建通过；无签名构建不等于安装。既有Web Cupertino字体提示保留到视觉核对。
- 首轮专项测试误在 StateNotifier 通知迭代中直接 dispose，触发其监听器并发修改限制；实际 Route 原本使用 post-frame 返回。专项改为验证 Finished 回调先于状态通知时的销毁保护，并保留真实 Route 的三宽度返回测试，没有改变产品时序规避断言。
- 浏览器使用现有 `tool/previews/translation_session_preview.dart`，独立地址 `http://127.0.0.1:8115/`；只有服务/媒体/存储输入是隔离合成，业务控制器、工厂、记录器、codec、列表复用正式实现。原8080登录不变。
- 浏览器已验证正常就绪→振铃→接通→结束返回，出现1条记录；第二次注入写入失败后仍保留1条并显示重试，解除故障后仅重试本机保存，变为2条，当前会话create/merchant/hangup仍各1次。没有伪造服务端归档或结算提示。

## 集中人工验收（待生产装配及设备安装后）

1. Android/iOS：授权翻译正常结束返回原页面，最近记录出现一次；名称、号码、国家和双方语言与本次拨号一致，点选只回填、不自动再呼叫。
2. 未接通取消/失败、重复结束事件及返回速度较快时，不重复记录、不延长媒体存活；不出现伪造积分结算。
3. 模拟锁屏/安全存储失败：明确失败，解锁后显式重试只保存本机元数据，不增加远端 create/merchant-call/hangup。
4. 切换账号、token刷新、关闭/重新打开页面与进程重启：旧账号回调不能写新账号，已保存记录正确恢复。未保存内存失败队列不承诺跨进程恢复。
5. 后续单独验收服务端归档、录音、钱包真实结算和历史刷新；本批不能据“本机列表出现”认定它们通过。

Android 旧数据导入/同签名OTA、真实媒体和系统权限、iOS/Android最终视觉仍在原任务中跟踪。2.2父项及整体迁移保持未完成，不归档。
