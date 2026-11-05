# 固定外呼号码正式接线与验收

## 已实现（2026-09-18）

开发者解锁后可读取当前账号固定号码，进入共享编辑表单、保存、删除、失败重试、取消返回。成功响应更新摘要并返回；普通返回不保存草稿。Web/Android/iOS 共用 Dart，无新增原生端口。

固定 v65 `4c781e3` 证据：AssistantOutboundNumberRuntimeController、FinalOutboundNumberPageV3、FinalContactMethodPolicy、TaskApiService、AppModels、AccountSettingsController 和 SafeOutboundNumberPolicy。iOS 参考 `ddb996a` 未检索到对应配置页或接口，未虚构已有平台逻辑。

| 层 | 位置与职责 |
|---|---|
| Domain | `settings/domain/outbound_number.dart`：服务端 number/configured，v65 号码归一与摘要 |
| Data | `settings/data/api_outbound_number_repository.dart`：账号 GET/POST/DELETE，校验返回 accountId 和字段 |
| Controller | `settings/presentation/controller/outbound_number_controller.dart`：读取/保存/删除单飞，草稿/错误/晚到生命周期 |
| Page/Route | `outbound_number_page.dart`/`outbound_number_route.dart`：表单、键盘滚动、进程解锁门禁和账号重建 |
| Entry/Provider | `outbound_number_entry.dart`/`app/outbound_number_providers.dart`：开发者摘要、同容器导航和账号依赖 |
| 演练 | `preview_outbound_number_repository.dart`/`outbound_preview_page.dart`：同一正式页面，仅替换内存后端 |

## 契约与边界

- 路径 `api/account/settings/outbound-number`：读取 GET，保存 POST `{outboundNumber: ...}`，删除 DELETE；响应 `{accountId,outboundNumber,configured}`。沿 AccountApi 的 X-Account-Id 与登录代次隔离，不擅自加 Bearer 策略。
- 全角数字/加号、分隔符、`+86`/`0086` 按固定 Android 函数处理；空结果只提示不提交。删除旧演练独有的“3–15 位”限制，不添加源代码没有的号码门禁。服务端返回值才是已保存事实，configured=false 不显示已生效。
- 后端 SafeOutboundNumberPolicy 仅对订餐/酒店/机票等支持场景应用配置，普通人对人目标保留。本批不更改后端或在 App 侧覆盖拨号目标，不发起电话，不把保存成功当作实际路由验证。
- 写失败保留草稿和原快照，可显式重新读取确认或再次写入；没有循环重试。加载失败保留重试入口；忙时禁编辑/重复请求。退出后同账号写响应可以更新摘要，但不能关闭新页面；换账号销毁旧控制器、重建表单并清旧草稿。
- 不新增号码日志、持久本地号码缓存或测试真实账号数据。正式编辑页可显示账号号码，摘要遮罩沿 v65 仅大陆手机号规则；未扩大产品行为。

## 验证与本轮发现

- 新增16项回归，最终1,574项全量、analyze、708文件格式及19项OpenSpec通过。Web、Android Debug、Mac iOS Debug无签名构建通过；无签名构建不是安装证据。Web保留既有CupertinoIcons字体构建警告，本批页面不新增该图标依赖。
- 首次读取失败进入编辑时，discardDraft误清错误导致无重试出口；保留无已读快照时的错误，回归通过。
- 浏览器发现父控制器已读取后进入嵌套演练触发Riverpod作用域断言。新增 `nested preview scopes never reuse an already loaded parent controller` 先复现失败，再声明仓库依赖；修复后子写入不改父状态。不是禁用断言或放宽隔离。
- 本机8101复用正式开发者路由，注入合成来源：空输入拦截；全角美国示例保存成`+12025550123`；返回摘要、重开删除恢复未配置；失败演练保留输入、关闭失败开关后显式保存成功；返回父页面仍未配置。控件运行检查不等于最终视觉校准。
- 自动测试覆盖账户头/方法/请求体、错账号/畸形响应、未知结果不重放、读写失败、忙时互斥、退出晚到、换账号草稿清理及320/430宽度。未调用真实号码接口或发短信、电话、配置写请求。

## 集中人工验收

1. 批准阶段安装后，两端复用登录并解锁开发者入口，检查当前账号摘要和编辑页原值；无需重发验证码。
2. 使用专门授权的测试账号和可控测试目标，记录原配置，再显式保存；核对测试后台同账号值、configured和重新进入结果。测试完恢复原配置。
3. 分别测试删除、断网失败、读取重试、请求中返回、换账号；新账号不能显示旧草稿/号码，不能因晚到响应被自动退页。验证日志没有号码正文/凭据。
4. 真正外呼路由验证必须另获授权，分别核对支持场景和普通人对人场景；仅本页保存测试不需发起任何电话。

本批保留8080原登录、Mac解锁screen；没有新设备安装。完整开发者列表/网络/模拟权限等消费者、翻译媒体、阶段真机及最终视觉仍待完成，不勾选整个迁移目标。
