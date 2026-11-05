# iOS来电身份对齐（2026-10-10）

## 来源和原因边界

只读参考AIAssistant固定提交bb9ff34966f40a3c2794a9a8b8e935669a9faa12。diagnostics-6共943条，其中74条可信设置事件；没有推送接收、SDK验签或凭据展示阶段，不能断言测试现场唯一根因。源码确认冷通知误用Activity新鲜度、失败丢预览、type6活动被过滤、事件流异常终止、Activity失败不再重试等阻断点。原始日志与真实身份不提交。

## 实现

原生收到四字段有效通知后按当前账号处理；冷启动最多25秒缓存，缺少callTime不再阻止凭据验证，但仍禁止Activity。SDK失败保留明确未验证预览，SDK成功type6展示未认证警示，无证书。点击当前通知增加presentationRevision重新展示，不重放SDK解析；重复后台投递仍去重，结束与换账号清理。

EventChannel诊断封套不会清空当前身份；原生64条内存环，固定stage/code/result/time。Dart流异常最多重连两次；MissingPlugin终止，不无限重试。凭据展示在路由下一帧且isCurrent时记录。NSE独立OSLog不假称写入账号journal。日志不带姓名、电话、token、URL或SDK message。

头像原生HTTPS下载，拒绝嵌入凭据/不安全跳转，5秒/2MB上限，最多4096像素边长，压缩至128像素/32KB，Dart只收图片数据，失败用本机头像。Activity额外压缩至40像素/1536字节且总载荷<=4096，别名映射对齐。相同Activity恢复时不重建；失败最多一次后台/两次前台请求，新事件重置。用户关闭不立即重建。

通知头像失败继续生成无头像通信外观，转换或整体超时回退原通知。普通字号凭据标题单行截断、大字号可换行和滚动，复用原生证书素材/文案；普通原生/Flutter隔离host配对截图已读，大字号截图已读，返回按钮可达由widget专项覆盖。配对素材全部合成，未启动业务SDK。

## 平台限制

参考原生后台也调用公开Activity.request，本实现按其流程尝试并记录真实成功/失败；这不保证后台或锁屏创建。Apple公开能力的可靠远程启动需要ActivityKit推送：参考仅观察pushToStartToken，未找到可用服务端绑定契约；用户无其他文档。不虚构API、使用私有接口或把收到普通推送当展示成功。

用户随后明确iOS App最低版本改为16.1：Runner、Framework声明、两扩展、本地Pod及Podfile统一，通知生成器防止回退；Activity stale仍16.2判断。固定原生隔离参考工具保留来源自己的15.5基线，不改变参考项目。系统升级范围变化已记录raise-ios-minimum-16-1。

## 验证与待验

来电109项定向、日志journal/host13项、原生Foundation6组及Swift投影/重试通过（含流耗尽/诊断不清页面）。analyze无问题，无签名iOS构建通过；最低版本配置守卫通过，OpenSpec71项通过。签名Profile2026101008构建82.0秒通过、codesign深度校验通过；App与两扩展成品MinimumOSVersion均16.1；USB保留数据覆盖安装成功，真实推送前台、后台、锁屏、冷启动、通知点击/账号切换仍需设备结果，不把编译等同运行验收。未归档。

## 故障恢复

原生诊断变量重名导致编译失败，核对后改名并6组通过；MissingPlugin旧测试发现重试产生多个null，改终止后107通过；RichText替换普通Text导致旧finder未匹配，核对显示实现后更新断言再次107通过。一次workdir=ios误执行根相对文件路径，核对后根目录重做，该部分无副作用。stale版本编译错误经16.2判断修复。Pods本地校验变化只涉及两个podspec及Podfile，无依赖升级；pubspec.lock为外部修改，不纳入。

源码路径中固定原生参考构建工具的15.5是参考来源编译基线，未用于生产App。Pods只刷新本地podspec和Podfile校验。未进行全仓回归，本次覆盖来电及直接诊断调用方定向；不把定向通过表述为全量通过。

## diagnostics-7真实推送未展示（后续修复）

用户反馈点击真实推送只进入App，无身份页。新日志182条，覆盖北京时间14:12:46–14:48:24；14:46:34.290/34.543/35.045三次IOS_STREAM_FAILED，随后IOS_STREAM_EXHAUSTED。没有IOS_STREAM_STARTED、原生推送/验签或IOS_PRESENTED。14:47设置prepare/open/refresh成功不代表来电流可用。

确认代码缺陷：incomingEventsAvailable使用@(环境匹配 && SDK已链接)，Objective-C逻辑与结果为int，NSNumber类型i、CFBoolean=false；Dart invokeMethod<bool>收到整数会类型转换抛错，在订阅前触发有限重试耗尽，关闭监听，后续点击通知不能经该流进入凭据页。不是据此证明推送payload或SDK验签一定成功；后续链路仍需真实推送复验。

单源码微批改为BOOL判断后显式@YES/@NO。工具verify_incoming_availability.py提取实际生产分支编译Foundation替身（仅SDK可用状态注入），8种环境/链接/非法参数组合断言CFBoolean及单次回复；旧代码RED因类型断言SIGABRT，修复GREEN。不是用Dart假布尔mock证明原生布尔正确；已有Dart端口定向另验。真实日志不提交。

修复验证：实际原生分支8组合、Dart端口8项、analyze4.2秒、OpenSpec71项、diff通过。签名Profile2026101009构建12.3秒；深度签名、App/双扩展最低16.1及build核验通过，USB保留数据覆盖安装、安装版本核验与launch成功。真实推送后续仍需用户复验，没有把此前失败改记通过。
